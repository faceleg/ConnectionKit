//
//  SVRichTextDOMController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVRichTextDOMController.h"
#import "SVParagraphDOMController.h"

#import "KT.h"
#import "SVAttributedHTML.h"
#import "SVAttributedHTMLWriter.h"
#import "SVContentDOMController.h"
#import "KTDocument.h"
#import "KTPage.h"
#import "SVGraphicContainerDOMController.h"
#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"
#import "SVImage.h"
#import "SVLinkManager.h"
#import "SVLink.h"
#import "SVMediaGraphic.h"
#import "SVParagraphedHTMLWriterDOMAdaptor.h"
#import "SVTextAttachment.h"
#import "SVTextBox.h"
#import "SVWebContentObjectsController.h"
#import "WebEditingKit.h"
#import "SVWebEditorViewController.h"
#import "WEKWebViewEditing.h"

#import "NSDictionary+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"
#import "DOMTreeWalker+Karelia.h"

#import "KSOrderedManagedObjectControllers.h"
#import "KSStringWriter.h"
#import "KSURLUtilities.h"


static void *sBodyTextObservationContext = &sBodyTextObservationContext;


@interface SVRichTextDOMController ()
- (SVDOMController *)convertImageElement:(DOMHTMLImageElement *)imageElement toGraphic:(SVMediaGraphic *)image;
@end



#pragma mark -


@implementation SVRichTextDOMController

#pragma mark Init & Dealloc

- (id)initWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)node textStorage:(SVRichText *)text;
{
    if (self = [self initWithIdName:elementID ancestorNode:node])
    {
        _storage = [text retain];
        [self setRepresentedObject:text];
    }
    
    return self;
}

- (id)init;
{
    if (self = [super init])
    {
        // Create early, as super calls through to routine that begins observation
        _graphicsController = [[[self attachmentsControllerClass] alloc] init];
        [_graphicsController setSortDescriptors:[SVRichText attachmentSortDescriptors]];
        [_graphicsController setAutomaticallyRearrangesObjects:YES];
    }
    return self;
}

- (void)dealloc
{
    // Release ivars
    [self stopObservingDependencies];                           // otherwise super will crash trying..
    [_graphicsController release]; _graphicsController = nil;   // ... to access _graphicsController
    [_storage release];
    
    [super dealloc];
}

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

- (WEKWebEditorItem *)orphanedWebEditorItemForImageDOMElement:(DOMHTMLImageElement *)imageElement;
{
    WEKWebEditorItem *result = [super orphanedWebEditorItemForImageDOMElement:imageElement];
    
    if (!result && [[[imageElement absoluteImageURL] scheme] isEqualToString:@"svxmedia"])
    {
        // See if there's an imported embedded image that wants hooking up
        NSString *graphicID = [[imageElement absoluteImageURL] ks_lastPathComponent];
        
        SVTextAttachment *attachment = [[[[self richTextStorage] attachments] filteredSetUsingPredicate:
                                         [NSPredicate predicateWithFormat:
                                          @"length == 32767 && graphic.identifier == %@",
                                          graphicID]] anyObject];
        
        if (attachment)
        {
            // Convert the image. Disable undo since hopefully nothing much should happen
            NSManagedObjectContext *context = [attachment managedObjectContext];
            [context processPendingChanges];
            [[context undoManager] disableUndoRegistration];
            
            result = [self convertImageElement:imageElement toGraphic:(SVMediaGraphic *)[attachment graphic]];
            [result performSelector:@selector(update)];
            
            [context processPendingChanges];
            [[context undoManager] enableUndoRegistration];
        }
    }
    
    return result;
}

#pragma mark Hierarchy

- (void)itemWillMoveToParentWebEditorItem:(WEKWebEditorItem *)item;
{
    [super itemWillMoveToParentWebEditorItem:item];
    
    // Dirty, dirty HACK. Don't want to be selectable if sitting straight inside something naturally selectable. Makes inline Text Boxes work right
    if ([item isSelectable])
    {
        [self setSelectable:NO];
    }
}

#pragma mark Updating

- (void)writeUpdateHTML:(SVHTMLContext *)context;
{
    [[self textBlock] writeHTML:context];
}

@synthesize updating = _isUpdating;

- (Class)attachmentsControllerClass; { return [NSArrayController class]; }

#pragma mark Controlling Editing Behaviour

- (void)webEditorTextDidBeginEditing;
{
    [super webEditorTextDidBeginEditing];
    
    // A bit crude, but we don't want WebKit's usual focus ring
    [[[self textHTMLElement] style] setProperty:@"outline" value:@"none" priority:@""];
}

#pragma mark Responding to Changes

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    // When moving an inline element, want to actually do that move
    
    WEKWebEditorView *webEditor = [self webEditor];
    NSPasteboard *pasteboard = [webEditor insertionPasteboard];
    if (pasteboard)
    {
        // Prepare to write HTML
        NSMutableString *editingHTML = [[NSMutableString alloc] init];
        SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithOutputWriter:editingHTML
                                                                            inheritFromContext:[self HTMLContext]];
        
        
        // Try to de-archive custom HTML
        NSAttributedString *attributedHTML = [NSAttributedString
                                              attributedHTMLStringFromPasteboard:pasteboard
                                              insertAttachmentsIntoManagedObjectContext:[self managedObjectContext]];
        
        if (attributedHTML)
        {
            // Generate HTML for the DOM
            [context beginGraphicContainer:[self representedObject]];
            [context writeAttributedHTMLString:attributedHTML];
            [context endGraphicContainer];
        }
        
        
        
        
        // Insert HTML into the DOM
        if ([editingHTML length])
        {
            DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[node ownerDocument];
            
            DOMDocumentFragment *fragment = [domDoc
                                             createDocumentFragmentWithMarkupString:editingHTML
                                             baseURL:nil];
            
            [[node mutableChildDOMNodes] removeAllObjects];
            [node appendChild:fragment];
            
            
            // Remove source dragged items if they came from us. No need to call -didChangeText as the insertion will do that
            if (action == WebViewInsertActionDropped) [webEditor removeDraggedItems];
            
            
            // Insert controllers. They will be hooked up lazily by -hitTestDOMNode:
            for (WEKWebEditorItem *anItem in [[context rootDOMController] childWebEditorItems])
            {
                [self addChildWebEditorItem:anItem];
            }
        }
        
        [context release];
        [editingHTML release];
    }
    
    
    return [super webEditorTextShouldInsertNode:node replacingDOMRange:range givenAction:action];
}

- (void)removeOrphanedChildWebEditorItems;
{
    // By removing an item, previous -childWebEditorItems result is potentially invalid, so hang on to for duration of the loop. #115550
    NSArray *children = [[self childWebEditorItems] copy];
    for (WEKWebEditorItem *anItem in children)
    {
        if ([[anItem HTMLElement] ks_isOrphanedFromDocument])
        {
            [anItem stopObservingDependencies];
            [anItem setHTMLElement:nil];
            [anItem removeFromParentWebEditorItem];
        }
    }
    [children release];
}

- (void)webEditorTextDidChange;
{    
    _isUpdating = YES;
    @try
    {
        [super webEditorTextDidChange];
        [self removeOrphanedChildWebEditorItems];
    }
    @finally
    {
        _isUpdating = NO;
    }
}

- (void)setHTMLString:(NSString *)html attachments:(NSSet *)attachments;
{
    SVRichText *textObject = [self richTextStorage];
    
    
    [textObject setString:html attachments:attachments];
    
    // Wait, is the last thing an attachment? If so, should account for that…
    if ([textObject endsOnAttachment])
    {
        // …by adding a line break
        DOMElement *textElement = [self textHTMLElement];
        DOMElement *lineBreak = [[textElement ownerDocument] createElement:@"BR"];
        [textElement appendChild:lineBreak];
        
        // Continue writing from the line break…
        html = [html stringByAppendingString:@"<BR />"];
        
        // …and store the updated HTML
        [textObject setString:html
                  attachments:attachments];
        
    }
}

- (DOMNode *)write:(SVParagraphedHTMLWriterDOMAdaptor *)adaptor
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;
{
    DOMNode *result = [element nextSibling];    // must grab before any chance of editing DOM due to misplaced graphic
    
    
    // We have a matching controller. But is it in a valid location? Make sure it really is block-level/inline
    if ([[adaptor XMLWriter] openElementsCount])
    {
        SVGraphic *graphic = nil;
        id object = [controller representedObject];
        if ([object respondsToSelector:@selector(graphic)]) graphic = [object graphic];
        
        DOMNode *parentNode = [element parentNode];
        
        if (!graphic || [[[graphic textAttachment] causesWrap] boolValue])
        {
            // Floated graphics should be moved up if enclosed by an anchor
            // All other graphics should be moved up
            if (![graphic shouldWriteHTMLInline] ||
                [element ks_ancestorWithTagName:@"A"])
            {
                // Push the element off up the tree; it will be written next time round
                [[parentNode parentNode] insertBefore:element refChild:[parentNode nextSibling]];
                return result;
            }
        }
    }
        
    // Graphic is OK where it is; write. Callouts write their contents
    if (![controller writeAttributedHTML:adaptor])
    {
        result = element;
    }
    
    return result;
}

- (DOMNode *)convertImageElementToGraphic:(DOMHTMLImageElement *)imageElement
                               HTMLWriter:(SVParagraphedHTMLWriterDOMAdaptor *)adaptor;
{
    // Is there an orphaned item we should reconnect to?
    WEKWebEditorItem *orphanedItem = [self hitTestDOMNode:imageElement];
    if ([orphanedItem representedObject])
    {
        [orphanedItem writeAttributedHTML:adaptor];
        DOMNode *result = [[orphanedItem HTMLElement] nextSibling];
        
        // Fake a change of text selection so the new item gets noticed and selected if needed. #92313
        // Possibly the act of setting a WEKWebEditorItem's HTMLElement could do this automatically
        WebView *webView = [[self webEditor] webView];
        DOMRange *selection = [webView selectedDOMRange];
        
        [[webView editingDelegate] webView:webView
              shouldChangeSelectedDOMRange:selection
                                toDOMRange:selection
                                  affinity:[webView selectionAffinity]
                            stillSelecting:NO];
        
        return result;
    }
    
    
    // Make an image object
    NSManagedObjectContext *context = [self managedObjectContext];
    
    SVMedia *media = nil;
    NSURL *URL = [imageElement absoluteImageURL];
    if ([URL isFileURL])
    {
        media = [[SVMedia alloc] initByReferencingURL:URL];
    }
    else
    {
        WebResource *resource = [[[[imageElement ownerDocument] webFrame] dataSource] subresourceForURL:URL];
        if (resource)   // e.g. Chrome only provides the URL. #92311
        {
            media = [[SVMedia alloc] initWithWebResource:resource];
            if ([[media preferredFilename] length] == 0)
            {
                [media setPreferredFilename:[@"pastedImage" stringByAppendingPathExtension:[URL ks_pathExtension]]];
            }
        }
    }
    
    
    // Can't import; delete it
    if (!media)
    {
        return imageElement;
    }
    
    
    // Import
    SVMediaGraphic *image = [SVMediaGraphic insertNewGraphicInManagedObjectContext:context];
    [image setSourceWithMedia:media];
    [media release];
    
    
    // Make corresponding text attachment
    SVTextAttachment *textAttachment = [SVTextAttachment textAttachmentWithGraphic:image];
    
    [textAttachment setBody:[self richTextStorage]];
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    
    
    // Import size & wrap & controller
    SVDOMController *controller = [self convertImageElement:imageElement toGraphic:image];
    DOMNode *result = [[controller HTMLElement] nextSibling];   // do now, as might change while updating
    
    
    // Apply size limit
    if ([image width] && [image height])
    {
        NSSize size = NSMakeSize([[image width] floatValue], [[image height] floatValue]);
        size = [controller constrainSize:size handle:kSVGraphicNoHandle snapToFit:YES];
        [image setWidth:[NSNumber numberWithInt:size.width]];
        [image setHeight:[NSNumber numberWithInt:size.height]];
    }
    
    
    // Generate new DOM node to match what model would normally generate
    [controller setNeedsUpdate];
    [controller updateIfNeeded];
    
    
    // Write the replacement
    [controller writeAttributedHTML:adaptor];
    
    
    return result;
}

- (SVDOMController *)convertImageElement:(DOMHTMLImageElement *)imageElement toGraphic:(SVMediaGraphic *)image;
{
    SVTextAttachment *textAttachment = [image textAttachment];
    
    
    // Try to divine image size
    int width = [imageElement width];
    int height = [imageElement height];
    
    [image setWidth:(width > 0 ? [NSNumber numberWithInt:width] : nil)];
    [image setHeight:(height > 0 ? [NSNumber numberWithInt:height] : nil)];
    
    if (![image width] || ![image height])
    {
        [image makeOriginalSize];
    }
    
    if ([image width] && [image height]) [image setConstrainsProportions:YES];
    
    
    // Match wrap settings if possible
    DOMCSSStyleDeclaration *style = [[[self webEditor] webView] computedStyleForElement:imageElement
                                                                          pseudoElement:nil];
    
    [textAttachment setCausesWrap:[NSNumber numberWithBool:
                                   ([[style display] isEqualToString:@"block"] ? YES : NO)]];
    
    NSString *floatProperty = [style getPropertyValue:@"float"];    // -cssFloat returns empty string for some reason
    if ([floatProperty isEqualToString:@"left"])
    {
        [textAttachment setWrapRight:YES];  // believe it, this is the right call!
    }
    else if ([floatProperty isEqualToString:@"right"])
    {
        [textAttachment setWrapLeft:YES];  // believe it, this is the right call!
    }
    
    
    // Create controller for graphic and hook up to imported node
    SVDOMController *result = [image newDOMControllerWithElementIdName:nil ancestorNode:nil];
    [result awakeFromHTMLContext:[self HTMLContext]];
    [result setHTMLElement:imageElement];
    
    
    // Does this controller replace a first pass?
    WEKWebEditorItem *existingItem = [self hitTestDOMNode:imageElement];
    
    if ([existingItem parentWebEditorItem] == self)
    {
        BOOL selected = [existingItem isSelected];
        
        [self replaceChildWebEditorItem:existingItem withItems:NSARRAY(result)];
        
        if (selected)
        {
            // HACK: fake delegate request so that Web Editor View Controller selects the image once update completes
            WEKWebEditorView *webEditor = [self webEditor];
            [[webEditor delegate] webEditor:webEditor
               shouldChangeSelectedDOMRange:[webEditor selectedDOMRange]
                                 toDOMRange:nil
                                   affinity:0
                                      items:NSARRAY(result)
                             stillSelecting:YES];
        }
    }
    else
    {
        [self addChildWebEditorItem:result];
    }
    [result release];
    
    
    return result;
}

- (DOMNode *)DOMAdaptor:(SVParagraphedHTMLWriterDOMAdaptor *)writer willWriteDOMElement:(DOMElement *)element;
{
    // If the element is inside a DOM controller, write that out instead…
    WEKWebEditorItem *item = [self itemForDOMNode:element];
    if (item)
    {
        // Images need to create a corresponding model object & DOM controller
        if (![item representedObject] && [writer importsGraphics] && [[element tagName] isEqualToString:@"IMG"])
        {
            return [self convertImageElementToGraphic:(DOMHTMLImageElement *)element
                                           HTMLWriter:writer];
        }
        
        
        // …If there are 2 controllers with the same node (e.g. plain image), hit-testing favours the inner one. We actually want to write the outer.
        return [self write:writer DOMElement:element item:item];
    }
    
    
    
   return element;
}

#pragma mark Properties

@synthesize richTextStorage = _storage;
@synthesize importsGraphics = _importsGraphics;

#pragma mark Links

@synthesize selectedLink = _selectedLink;

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification
{
    [super webEditorTextDidChangeSelection:notification];
    
    
    // Does the selection contain a link? If so, make it the selected object
    WEKWebEditorView *webEditor = [self webEditor];
    DOMRange *selection = [webEditor selectedDOMRange];
    DOMHTMLAnchorElement *anchorElement = [selection editableAnchorElement];
    
    SVLink *link = nil;
    if (anchorElement)
    {
        // Is it a page link?
        NSString *linkURLString = [anchorElement getAttribute:@"href"]; // -href will give the URL a scheme etc. if there's no base URL
        if ([linkURLString hasPrefix:kKTPageIDDesignator])
        {
            SVSiteItem *target = [KTPage siteItemForPreviewPath:linkURLString
                                 inManagedObjectContext:[self managedObjectContext]];
            
            if (target)
            {
                link = [[SVLink alloc] initWithPage:target
                                    openInNewWindow:[[anchorElement target] isEqualToString:@"_blank"]];
            }
        }
        
        // Not a page link? Fallback to regular link
        if (!link)
        {
            link = [[SVLink alloc] initWithURLString:linkURLString
                                     openInNewWindow:[[anchorElement target] isEqualToString:@"_blank"]];
        }
    }
    
    //[[SVLinkManager sharedLinkManager] setSelectedLink:link editable:(selection != nil)];
    [link release];
}

#pragma mark Resizing

- (CGFloat)maxWidthForChild:(WEKWebEditorItem *)aChild;
{
    // Base limit on design rather than the DOM
    SVGraphic *graphic = [aChild representedObject];
    OBASSERT(graphic);
    
    KTPage *page = [[self HTMLContext] page];
    return [graphic maxWidthOnPage:page];
}

#pragma mark Moving

- (DOMNode *)nodeToMoveItemBefore:(SVDOMController *)controller;
{
    DOMNode *element = [controller HTMLElement];
    DOMElement *textElement = [self textHTMLElement];
    
    DOMTreeWalker *walker = [[element ownerDocument] createTreeWalker:textElement
                                                           whatToShow:DOM_SHOW_ALL
                                                               filter:nil
                                               expandEntityReferences:NO];
    [walker setCurrentNode:element];
    
    DOMNode *result = [walker ks_previousNodeIgnoringChildren];
    while (result && ![result hasSize])
    {
        result = [walker ks_previousNodeIgnoringChildren];
    }
    
    
    // Make sure it's a move up to a paragraph
    if (result)
    {
        if (result == textElement) return nil;
        
        DOMNode *parent = [result parentNode];
        while (parent != textElement)
        {
            result = parent;
            parent = [result parentNode];
        }
    }
    
    
    return result;
}

- (DOMNode *)nodeToMoveItemAfter:(SVDOMController *)controller;
{
    DOMNode *element = [controller HTMLElement];
    
    if ([element ks_isDescendantOfElement:[self textHTMLElement]])  //  this should always be true really
    {
        while ([element parentNode] != [self textHTMLElement])
        {
            element = [element parentNode];
        }
    }
    
    
    DOMTreeWalker *walker = [[element ownerDocument] createTreeWalker:[self textHTMLElement]
                                                           whatToShow:DOM_SHOW_ALL
                                                               filter:nil
                                               expandEntityReferences:NO];
    [walker setCurrentNode:element];
    
    
    // Seek out the next element worth swapping with. It must:
    //  1.  Be visible on screen (i.e. element or non-whitespace text)
    //  2.  Sit below the item being dragged, to account for dragging a floated item
    DOMNode *result = [walker ks_nextNodeIgnoringChildren];
    while (result && ![result hasSize])
    {
        // Seek out next node.
        result = [walker ks_nextNodeIgnoringChildren];
    }
    
    return result;
}

/*  We'll leave it up to the individual graphics
 */
- (void)moveObjectUp:(id)sender;
{
    [[self selectedItems] makeObjectsPerformSelector:@selector(moveUp)];
}
- (void)moveObjectDown:(id)sender;
{
    [[self selectedItems] makeObjectsPerformSelector:@selector(moveDown)];
}

- (void)moveItemUp:(WEKWebEditorItem *)item;
{
    WEKWebEditorView *webEditor = [self webEditor];
    WEKSelection *selection = [[webEditor webView] wek_selection];
    DOMNode *previousNode = [item previousDOMNode];
    DOMNode *targetNode = [self nodeToMoveItemBefore:(SVDOMController *)item];
    
    while (previousNode && [webEditor shouldChangeTextInDOMRange:[item DOMRange]])
    {
        [item exchangeWithPreviousDOMNode];
        
        // Have we made a noticeable move yet?
        if (previousNode == targetNode) break;
        
        previousNode = [item previousDOMNode];
    }
    
    
    // The target couldn't be found? Time to move manually I guess. This should only be reached for images, so not a problem display-wise
    if (!previousNode && [webEditor shouldChangeText:self])
    {
        [[targetNode parentNode] insertBefore:[item HTMLElement] refChild:targetNode];
    }
    
    
    [webEditor didChangeText];
    [[webEditor webView] wek_setSelection:selection];
}

- (void)moveItemDown:(WEKWebEditorItem *)item;
{
    // Save and then restore selection for if it's inside an item that's getting exchanged
    WEKWebEditorView *webEditor = [item webEditor];
    WEKSelection *selection = [[webEditor webView] wek_selection];
    DOMNode *nextNode = [item nextDOMNode];
    DOMNode *targetNode = [self nodeToMoveItemAfter:(SVDOMController *)item];
    
    while (nextNode && [webEditor shouldChangeTextInDOMRange:[item DOMRange]])
    {
        [item exchangeWithNextDOMNode];
        
        // Have we made a noticeable move yet?
        if (nextNode == targetNode) break;
        
        nextNode = [item nextDOMNode];
    }
    
    
    // The target couldn't be found? Time to move manually I guess. This should only be reached for images, so not a problem display-wise
    if (!nextNode && [webEditor shouldChangeText:self])
    {
        [[targetNode parentNode] insertBefore:[item HTMLElement] refChild:[targetNode nextSibling]];
    }
    
    
    [webEditor didChangeText];
    [[webEditor webView] wek_setSelection:selection];
}

- (void)tryToMoveController:(SVDOMController *)controller downToPosition:(CGPoint)position;
{
    CGPoint startPosition = [controller positionIgnoringRelativePosition];
    CGFloat gapAvailable = position.y - startPosition.y;
    
    DOMNode *nextNode = [self nodeToMoveItemAfter:controller];
    if (nextNode)
    {
        if (2 * gapAvailable > [nextNode boundingBox].size.height)
        {
            // Move the element
            [controller moveDown];
        }
    }
    else
    {
        // This is the last pagelet. Disallow dragging down
        if (position.y > startPosition.y) position = startPosition;
    }
}

- (void)tryToMoveController:(SVDOMController *)controller upToPosition:(CGPoint)position;
{
    CGPoint startPosition = [controller positionIgnoringRelativePosition];
    CGFloat gapAvailable = position.y - startPosition.y;
    
    DOMNode *previousNode = [self nodeToMoveItemBefore:controller];
    if (previousNode)
    {
        NSRect previousFrame = [previousNode boundingBox];            
        if (2*-gapAvailable > previousFrame.size.height)// || NSMinY(frame) < NSMidY(previousFrame))
        {
            // Move the element
            [controller moveUp];
        }
    }
    else
    {
        // This is the last pagelet. Disallow dragging down
        //if (position.y < startPosition.y) position = startPosition;
    }
    
    
    // Old logic from article controller:
    //DOMNode *previousNode = [self nodeToMoveItemBefore:graphicController];
    //if (previousNode)
    //{
    //    NSRect previousFrame = [previousNode boundingBox];            
    //    if (previousFrame.size.height <= 0.0f || NSMinY(frame) < NSMidY(previousFrame))
    //    {
    //        // Move the element
    //        [graphicController moveUp];
    //    }
    //}
}

- (NSPoint)snapController:(SVDOMController *)controller toFit:(NSPoint)result;
{
    CGPoint staticPosition = [controller positionIgnoringRelativePosition];
    
    SVGraphic *graphic = [controller graphic];
    if (!graphic)
    {
        // Assume non-graphics only move vertically
        result.x = staticPosition.x;
        return result;
    }
    
    
    SVTextAttachment *attachment = [graphic textAttachment];
    SVGraphicWrap wrap = [[attachment wrap] intValue];
    
    NSRect snapRect = [[self textHTMLElement] boundingBox];
    
    
    // Leave be if reasonable
    if (result.x > staticPosition.x - 10.0f &&
        result.x < staticPosition.x + 10.0f)
    {
        result.x = staticPosition.x;
    }
    else
    {
        // Where is the controller being asked to move to?
        NSRect frame = [controller frame];
        CGPoint currentPosition = [controller position];
        frame.origin.x += result.x - currentPosition.x;
        frame.origin.y += result.y - currentPosition.y;
        
        
        // Set wrap to match
        if (NSMidX(frame) <= NSMidX(snapRect))
        {
            if (wrap >= SVGraphicWrapLeft || wrap <= SVGraphicWrapFloat_1_0)    // is it floated?
            {
                wrap = SVGraphicWrapRight;
            }
            else
            {
                if (NSMinX(frame) - NSMinX(snapRect) < NSMidX(snapRect) - NSMidX(frame)) // closer to left?
                {
                    wrap = SVGraphicWrapRightSplit;
                }
                else
                {
                    wrap = SVGraphicWrapCenterSplit;
                }
            }
        }
        else
        {
            if (wrap >= SVGraphicWrapLeft || wrap <= SVGraphicWrapFloat_1_0)    // is it floated?
            {
                wrap = SVGraphicWrapLeft;
            }
            else
            {
                if (NSMaxX(snapRect) - NSMaxX(frame) < NSMidX(frame) - NSMidX(snapRect)) // closer to right?
                {
                    wrap = SVGraphicWrapLeftSplit;
                }
                else
                {
                    wrap = SVGraphicWrapCenterSplit;
                }
            }
        }
        
        if ([[attachment wrap] intValue] != wrap)
        {
            [attachment setWrap:[NSNumber numberWithInt:wrap]];
            [controller updateIfNeeded]; // push through so position can be set accurately
        }
    }
    
    
    // Show guide for choice of wrap
    NSNumber *guide;
    switch (wrap)
    {
        case SVGraphicWrapRightSplit:
        case SVGraphicWrapRight:
            guide = [NSNumber numberWithFloat:NSMinX(snapRect)];
            break;
        case SVGraphicWrapCenterSplit:
            guide = [NSNumber numberWithFloat:NSMidX(snapRect)];
            break;
        case SVGraphicWrapLeftSplit:
        case SVGraphicWrapLeft:
            guide = [NSNumber numberWithFloat:NSMaxX(snapRect)];
            break;
        default:
            guide = nil;
    }
    [[self webEditor] setXGuide:guide yGuide:nil];
    
    
    return result;
}

- (BOOL)dragItem:(SVDOMController *)controller withEvent:(NSEvent *)event offset:(NSSize)mouseOffset slideBack:(BOOL)slideBack;
{
    while ([controller parentWebEditorItem] != self)
    {
        controller = (SVDOMController *)[controller parentWebEditorItem];
        if (!controller) return NO;
    }
    
    NSView *view = [[[[self webEditor] firstResponderItem] HTMLElement] documentView];
    
    NSPoint mouseDown = [view convertPoint:NSMakePoint([event locationInWindow].x - mouseOffset.width,
                                                       [event locationInWindow].y - mouseOffset.height)
                                  fromView:nil];
    
    // Set the item's anchor point such that -position is where mouse down was
    [controller setAnchorPoint:[controller anchorPointToGivePosition:NSPointToCGPoint(mouseDown)]];
    
    do
    {
        // Calculate change from event
        [view autoscroll:event];
        
        NSPoint target = [view convertPoint:[event locationInWindow] fromView:nil];
        
        
        
        
        // Snap to fit current wrap. #94884
        target = [self snapController:controller toFit:target];
        
        
        
        // Do any of siblings fit into the available space?
        CGFloat delta = [event deltaY];
        if (delta < 0.0f)
        {
            [self tryToMoveController:controller upToPosition:NSPointToCGPoint(target)];
        }
        else if (delta > 0.0f)
        {
            [self tryToMoveController:controller downToPosition:NSPointToCGPoint(target)];
        }    
        
        [controller moveToPosition:NSPointToCGPoint(target)];
        
        event = [[event window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
    }
    while ([event type] != NSLeftMouseUp);
    
    
    [controller moveEnded];
    return YES;
}

#pragma mark Insertion

- (DOMRange *)insertionRangeForGraphic:(SVGraphic *)graphic;
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    // Figure out where to insert
    DOMRange *result = [self selectedDOMRange];
    if (result)
    {
        // Tweak a little when at the start of a paragraph. #81909
        if ([result collapsed] &&
            [result startOffset] == 0 &&
            [[result startContainer] parentNode] == [self textHTMLElement])
        {
            [result setStartBefore:[result startContainer]];
        }
    }
    else
    {
        // Match the insertion's placement to the existing graphic. #82329
        // Need to seek out a suitable parent to insert into. #86448
        WEKWebEditorItem *selection = [webEditor selectedItem];
        if ([selection isDescendantOfWebEditorItem:self])
        {
            WEKWebEditorItem *parent = [selection parentWebEditorItem];
            while (![parent allowsPagelets])
            {
                selection = parent;
                parent = [selection parentWebEditorItem];
            }
            
            SVGraphic *selectedGraphic = [selection graphic];
            [[graphic textAttachment] setPlacement:[selectedGraphic placement]];
            
            result = [[[self HTMLElement] ownerDocument] createRange];
            [result setStartBefore:[selection HTMLElement]];
        }
        else
        {
            // Fallback to insertion at start of text
            result = [[webEditor HTMLDocument] createRange];
            [result setStart:[self textHTMLElement] offset:0];
        }
    }
    
    return result;
}

- (void)insertGraphic:(SVGraphic *)graphic range:(DOMRange *)insertionRange;
{
    OBPRECONDITION(insertionRange);
    
    WEKWebEditorView *webEditor = [self webEditor];
    if ([webEditor shouldChangeTextInDOMRange:insertionRange])
    {
        SVWebEditorHTMLContext *context = [self HTMLContext];
        
        
        // Create controller for graphic
        SVDOMController *controller = [graphic newDOMControllerWithElementIdName:nil ancestorNode:[self HTMLElement]];
        [controller setHTMLContext:context];
        [controller loadPlaceholderDOMElement];
        
        
        // Generate & insert DOM node
        [insertionRange insertNode:[controller HTMLElement]];
        
        // Insert controller – must do after node is inserted so descendant nodes can be located by ID
        WEKWebEditorItem *parentController = [self hitTestDOMNode:[controller HTMLElement]];
        [parentController addChildWebEditorItem:controller];
        
        
        // Finish the edit – had to wait until both node and controller were present
        [webEditor didChangeText];
        
        /*  STOP!!
         *  I've found that in some rare cases -didChangeText can trigger a reload of the page which throws away this controller. Thus, don't access self after this point.
         */
        
        // Tell the graphic what's happened. Wait until after -didChangeText so full model has been hooked up
        KTPage *page = [context page];        
        [graphic pageDidChange:page];
        
        // Push it through quickly
        // Callouts are weird. If this is an insert next to an existing callout, need a full reload to get that properly onscreen. It's easiest to assume that should always happen
        if ([graphic isCallout])
        {
            [self setNeedsUpdate];
            [self updateIfNeeded];
        }
        else
        {
            [controller setNeedsUpdate];
            [controller updateIfNeeded];
        }
    }
    
}

- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;
{
    // Create text attachment for the graphic
    SVTextAttachment *textAttachment = [SVTextAttachment textAttachmentWithGraphic:graphic];
    
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    
    [textAttachment setCausesWrap:[NSNumber numberWithBool:!placeInline]];
    [textAttachment setBody:[self richTextStorage]];
    
    
    // Insert, selecting it
    KSArrayController *selectionController =
    [[self webEditorViewController] graphicsController];
    [selectionController saveSelectionAttributes];
    [selectionController setSelectsInsertedObjects:YES];
    
    DOMRange *insertionRange = [self insertionRangeForGraphic:graphic];
    [self insertGraphic:graphic range:insertionRange];
    
    [selectionController restoreSelectionAttributes];
    
    
    
    // Select item.
    //NSArrayController *selectionController =
    //[[self webEditorViewController] graphicsController];
    //if ([selectionController setSelectedObjects:[NSArray arrayWithObject:graphic]])
    {
        /*
        // For non-inline graphics, need the WebView to resign first responder. #79189
        BOOL select = YES;
        if (!placeInline) select = [[webEditor window] makeFirstResponder:webEditor];
        
        if (select) [webEditor selectItems:[NSArray arrayWithObject:controller]
                      byExtendingSelection:NO];*/
    }
}

- (void)addGraphic:(SVGraphic *)graphic;
{
    [self addGraphic:graphic placeInline:YES];
}

- (IBAction)insertPagelet:(id)sender;
{
    BOOL insert = [self importsGraphics];
    if (insert)
    {
        if (![self allowsPagelets])
        {
            // Graphics, but not pagelets? Only allow Raw HTML. #108221
            SVGraphicFactory *factory = [SVGraphicFactory graphicFactoryForTag:[sender tag]];
            insert = [SVGraphicFactory rawHTMLFactory] == factory;
        }
    }
    
    
    // If we don't handle it, pass on
    if (!insert)
    {
        if (![[self nextResponder] tryToPerform:_cmd with:sender])
        {
            WEKWebEditorItem *articleController = [[self webEditorViewController] articleDOMController];
            if (![articleController tryToPerform:_cmd with:sender])
            {
                NSBeep();
            }
        }
        
        return;
    }
    
    
    
    SVGraphic *graphic = [SVGraphicFactory graphicWithActionSender:sender
                                    insertIntoManagedObjectContext:[self managedObjectContext]];
    
    [graphic awakeFromNew];
    
    
    // If graphic is small enough to go in sidebar, place there instead.
    [self addGraphic:graphic];
}

- (IBAction)insertFile:(id)sender;
{
    NSWindow *window = [[[self HTMLElement] documentView] window];
    NSOpenPanel *panel = [[[window windowController] document] makeChooseDialog];
    
    [panel beginSheetForDirectory:nil
                             file:nil
                            types:[SVMediaGraphic allowedTypes]
                   modalForWindow:window
                    modalDelegate:self
                   didEndSelector:@selector(chooseDialogDidEnd:returnCode:contextInfo:)
                      contextInfo:NULL];
}

- (void)chooseDialogDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    SVMedia *media = [[SVMedia alloc] initByReferencingURL:[sheet URL]];
    if (!media) return;
    
    
    SVMediaGraphic *graphic = [SVMediaGraphic insertNewGraphicInManagedObjectContext:[self managedObjectContext]];
    [graphic setSourceWithMedia:media];
    [graphic setShowsTitle:NO];
    [graphic setShowsCaption:NO];
    [graphic setShowsIntroduction:NO];
    
    [media release];
    
    [self addGraphic:graphic placeInline:YES];
}

#pragma mark Removal

- (NSArray *)selectedItems;
{
    NSArray *result = [[self webEditor] selectedItems];
    for (WEKWebEditorItem *anItem in result)
    {
        if (![anItem isDescendantOfWebEditorItem:self]) return nil;
    }
    
    return result;
}

- (void)clearStyles:(id)sender;
{
    DOMRange *selection = [self selectedDOMRange];
    
    if ([[self webEditor] shouldChangeTextInDOMRange:selection])
    {
        // Search upwards so we get start of range from UI perspective
        while ([selection startOffset] == 0)
        {
            DOMNode *parent = [selection startContainer];
            if (parent == [self innerTextHTMLElement]) break;
            
            [selection setStartBefore:parent];
        }
        
        
        // Walk through the selection, stripping out class and style attributes
        DOMNode *aNode = [selection ks_startNode:NULL];
        
        DOMTreeWalker *iterator = [[[self HTMLElement] ownerDocument]
                                   createTreeWalker:[selection commonAncestorContainer]
                                   whatToShow:DOM_SHOW_ALL
                                   filter:nil
                                   expandEntityReferences:NO];
        
        [iterator setCurrentNode:aNode];
        
        while (YES)
        {
            if ([aNode nodeType] == DOM_ELEMENT_NODE)
            {
                // Anything outside of this controller should be skipped over
                if ([self hitTestDOMNode:aNode] == self)
                {
                    [(DOMElement *)aNode removeAttribute:@"class"];
                    [(DOMElement *)aNode removeAttribute:@"style"];
                }
                else
                {
                    [iterator ks_nextNodeIgnoringChildren];
                    [iterator previousNode];    // to balance -nextNode followup
                }
            }
            
            if (aNode == [selection ks_endNode:NULL]) break;
            
            aNode = [iterator nextNode];
        }
        
        
        [[self webEditor] didChangeText];
    }
}

#pragma mark Delete

- (void)delete:(id)sender forwardingSelector:(SEL)action;
{
    NSArray *selection = [self selectedItems];
    if (![selection count])
    {
        return [super delete:sender forwardingSelector:action];
    }
    
    WEKWebEditorView *webEditor = [self webEditor];
    if ([webEditor shouldChangeText:self])
    {
        for (WEKWebEditorItem *anItem in selection)
        {
            [webEditor deselectItem:anItem];
            
            while ([anItem parentWebEditorItem] != self)
            {
                anItem = [anItem parentWebEditorItem];
            }
            
            DOMRange *range = [anItem DOMRange];
            [range deleteContents];
            [range detach];
        }
        
        [webEditor didChangeText];
    }
}

- (void)delete:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

- (void)deleteForward:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

- (void)deleteBackward:(id)sender;
{
    [self delete:sender forwardingSelector:_cmd];
}

#pragma mark Queries

- (DOMNode *)isDOMRangeStartOfParagraph:(DOMRange *)range;
{
    // To be the start of a paragraph, there must be no preceeding content other than the paragraph itself
    
    if ([range startOffset] == 0)
    {
        DOMNode *innerTextNode = [self innerTextHTMLElement];
        
        DOMNode *node = [range startContainer];
        do
        {
            DOMNode *parent = [node parentNode];
            if (parent == innerTextNode) return node;    // node's a paragraph!
            if ([node previousSibling]) return nil;      // can't be start of a paragraph
            
            // Move up the tree
            node = parent;
        } while (node);
    }
    
    return nil;
}

- (DOMNode *)isDOMRangeEndOfParagraph:(DOMRange *)range;
{
    // To be the end of a paragraph, there must be no following content other than the paragraph itself
    
    
    // Bail if not the end of the node
    DOMNode *node = [range endContainer];
    if ([node isKindOfClass:[DOMCharacterData class]])
    {
        if ([range endOffset] < [(DOMCharacterData *)node length]) return nil;
    }
    else
    {
        if ([range endOffset] < [[node childNodes] length]) return nil;
    }
    

    DOMNode *innerTextNode = [self innerTextHTMLElement];
    
    do
    {
        DOMNode *parent = [node parentNode];
        if (parent == innerTextNode) return node;    // node's a paragraph!
        if ([node nextSibling]) return nil;      // can't be start of a paragraph
        
        // Move up the tree
        node = parent;
    } while (node);
    
    return nil;
}

#pragma mark Pasteboard

- (void)webEditorTextDidSetSelectionTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    // No point writing custom HTML if there's no items selected. Besides, messes up for simple pastes like #103440
    if ([[self webEditor] selectedItem])
    {
        [pasteboard addTypes:[NSArray arrayWithObject:@"com.karelia.html+graphics"] owner:self];
    }
}

- (void)webEditorTextDidWriteSelectionToPasteboard:(NSPasteboard *)pasteboard;
{
    if ([[pasteboard types] containsObject:@"com.karelia.html+graphics"])
    {
        DOMRange *selection = [self selectedDOMRange];
        OBASSERT(selection);
        
        // It's possible that WebKit has adjusted the selection slightly to be smaller than the selected item. If so, correct by copying the item
        WEKWebEditorItem *item = [[self webEditor] selectedItem];
        if (![selection intersectsNode:[item HTMLElement]])
        {
            selection = [item selectableDOMRange];
            OBASSERT(selection);
        }
        
        [SVAttributedHTMLWriter writeDOMRange:selection
                                 toPasteboard:pasteboard
                           graphicControllers:[self childWebEditorItems]];
    }
}

- (NSObject *)hitTestDOMNode:(DOMNode *)node draggingPasteboard:(NSPasteboard *)pasteboard;
{
    // If the drop is targeted at us, let the webview handle instead. #103882
    
    NSObject *result = [super hitTestDOMNode:node draggingPasteboard:pasteboard];
    if (!result && [self hitTestDOMNode:node])
    {
        result = [[self webEditor] webView];
    }
    return result;
}

#pragma mark Dependencies

- (void)beginAttachmentsObservation;
{
    [_graphicsController bind:NSContentSetBinding
                     toObject:[self richTextStorage]
                  withKeyPath:@"attachments"
                      options:nil];
    
    [_graphicsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:sBodyTextObservationContext];
}

- (void)endAttachmentsObservation;
{
    [_graphicsController removeObserver:self forKeyPath:@"arrangedObjects"];
    [_graphicsController unbind:NSContentSetBinding];
    [_graphicsController setContent:nil];
}

- (void)startObservingDependencies;
{
    if (!_isObservingText)
    {
        // Keep an eye on model
        [self addObserver:self forKeyPath:@"richTextStorage.string" options:0 context:sBodyTextObservationContext];
        if ([self richTextStorage]) [self beginAttachmentsObservation];
        _isObservingText = YES;
    }
    
    [super startObservingDependencies];
    OBPOSTCONDITION([self isObservingDependencies]);
}

- (void)stopObservingDependencies;
{
    if (_isObservingText)    // should be able to test isObservingDependencies but that's lying for reasons I cannot figure
    {
        [self removeObserver:self forKeyPath:@"richTextStorage.string"];
        if ([self richTextStorage]) [self endAttachmentsObservation];
        _isObservingText = NO;
    }
    
    
    [super stopObservingDependencies];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sBodyTextObservationContext)
    {
        if (![self isUpdating])
        {
            [self setNeedsUpdate];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVRichText (SVDOMController)

- (SVTextDOMController *)newTextDOMControllerWithIdName:(NSString *)elementID ancestorNode:(DOMNode *)node
{
    SVTextDOMController *result = [[SVRichTextDOMController alloc] initWithIdName:elementID
                                                                     ancestorNode:node
                                                                         textStorage:self];
    
    [result setSelectable:YES];
    [result setRichText:YES];
    
    return result;
}

@end

