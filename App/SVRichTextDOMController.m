//
//  SVRichTextDOMController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVRichTextDOMController.h"
#import "SVParagraphDOMController.h"

#import "KT.h"
#import "SVAttributedHTML.h"
#import "SVAttributedHTMLWriter.h"
#import "KTDocument.h"
#import "KTPage.h"
#import "SVGraphicDOMController.h"
#import "SVGraphicFactory.h"
#import "SVHTMLContext.h"
#import "SVImage.h"
#import "SVLinkManager.h"
#import "SVLink.h"
#import "SVMedia.h"
#import "SVMediaDOMController.h"
#import "SVParagraphedHTMLWriterDOMAdaptor.h"
#import "SVTextAttachment.h"
#import "SVTextBox.h"
#import "SVWebContentObjectsController.h"
#import "WebEditingKit.h"
#import "SVWebEditorViewController.h"

#import "NSDictionary+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSOrderedManagedObjectControllers.h"
#import "KSStringWriter.h"
#import "KSURLUtilities.h"


static NSString *sBodyTextObservationContext = @"SVBodyTextObservationContext";


@interface DOMElement (SVParagraphedHTMLWriter)
- (DOMNodeList *)getElementsByClassName:(NSString *)name;
@end


#pragma mark -


@implementation SVRichTextDOMController

#pragma mark Init & Dealloc

- (id)init;
{
    // Super
    self = [super init];
    
    
    // Keep an eye on model
    [self addObserver:self forKeyPath:@"representedObject.string" options:0 context:sBodyTextObservationContext];    
    
    _graphicsController = [[NSArrayController alloc] init];
    [_graphicsController setSortDescriptors:[SVRichText attachmentSortDescriptors]];
    [_graphicsController setAutomaticallyRearrangesObjects:YES];
    
    [_graphicsController bind:NSContentSetBinding
                     toObject:self
                  withKeyPath:@"representedObject.attachments"
                      options:nil];
    
    [_graphicsController addObserver:self forKeyPath:@"arrangedObjects" options:0 context:sBodyTextObservationContext];
    
    
    // Finish up
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"representedObject.string"];
    
    // Release ivars
    [_changeHTMLContext release];//OBASSERT(!_changeHTMLContext);
    [_graphicsController release];
    
    [super dealloc];
}

#pragma mark Properties

- (BOOL)allowsPagelets; { return NO; }

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

#pragma mark Hierarchy

- (WEKWebEditorItem *)orphanedWebEditorItemMatchingDOMNode:(DOMNode *)aNode;
{
    for (WEKWebEditorItem *anItem in [self childWebEditorItems])
    {
        DOMNode *node = [anItem HTMLElement];
        BOOL isOrphan = ![node isDescendantOfNode:[node ownerDocument]];
        if (isOrphan && [node isEqualNode:aNode]) return anItem;
    }
    
    return nil;
}

#pragma mark Updating

// Leave commented out until ready to implement
/*- (void)update
{
    [self willUpdate];
    
    [self didUpdate];
}*/

@synthesize updating = _isUpdating;

- (void)XwillUpdate
{
    OBPRECONDITION(!_isUpdating);
    _isUpdating = YES;
}

- (void)XdidUpdate
{
    OBPRECONDITION(_isUpdating);
    _isUpdating = NO;
}

#pragma mark Controlling Editing Behaviour

- (void)webEditorTextDidBeginEditing;
{
    [super webEditorTextDidBeginEditing];
    
    // A bit crude, but we don't want WebKit's usual focus ring
    [[[self textHTMLElement] style] setProperty:@"outline" value:@"none" priority:@""];
}

#pragma mark Responding to Changes

- (void)webEditorTextDidChange;
{    
    // Are there DOM Controllers from the change waiting to be inserted?
    if (_changeHTMLContext)
    {
        for (WEKWebEditorItem *anItem in [[_changeHTMLContext rootDOMController] childWebEditorItems])
        {
            // Web Editor View Controller will pick up the insertion in its delegate method and handle the various side-effects.
            [self addChildWebEditorItem:anItem];
        }
        
        [_changeHTMLContext release]; _changeHTMLContext = nil;
    }
        
        
    
    
    //  Write the whole out using a special stream
    
       
    KSStringWriter *stringWriter = [[KSStringWriter alloc] init];
    
    SVParagraphedHTMLWriterDOMAdaptor *writer = 
    [[SVParagraphedHTMLWriterDOMAdaptor alloc] initWithOutputStringWriter:stringWriter];
    
    [writer setDelegate:self];
    [writer setAllowsPagelets:[self allowsPagelets]];
    
    
    [self willWriteText:writer];
    _isUpdating = YES;
    
    
    // Top-level nodes can only be: paragraph, newline, or graphic. Custom DOMNode addition handles this
    DOMElement *textElement = [self textHTMLElement];
    DOMNode *aNode = [textElement firstChild];
    while (aNode)
    {
        aNode = [aNode writeTopLevelParagraph:writer];
    }
    
    
    // Push HTML into the model
    SVRichText *textObject = [self representedObject];
    NSString *html = [stringWriter string];
    
    [textObject setString:html
              attachments:[writer textAttachments]];
    
    // Wait, is the last thing an attachment? If so, should account for that…
    if ([textObject endsOnAttachment])
    {
        // …by adding a line break
        DOMElement *lineBreak = [[textElement ownerDocument] createElement:@"BR"];
        [textElement appendChild:lineBreak];
        
        // Continue writing from the line break…
        [lineBreak writeTopLevelParagraph:writer];
        
        // …and store the updated HTML
        [textObject setString:html
                  attachments:[writer textAttachments]];
        
    }
    
    _isUpdating = NO;
    
    
    // Finish up
    [writer release];
    [stringWriter release];
    
    [super webEditorTextDidChange];
}

- (void)willWriteText:(SVParagraphedHTMLWriterDOMAdaptor *)writer; { }

- (DOMNode *)write:(SVParagraphedHTMLWriterDOMAdaptor *)adaptor
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;
{
    DOMNode *result = [element nextSibling];    // must grab before any chance of editing DOM due to misplaced graphic
    
    
    // We have a matching controller. But is it in a valid location? Make sure it really is block-level/inline
    SVGraphic *graphic = [controller representedObject];
    
    DOMNode *parentNode = [element parentNode];
    
    if ([[adaptor XMLWriter] openElementsCount] &&
        ![graphic shouldWriteHTMLInline])
    {
        // Push the element off up the tree; it will be written next time round
        [[parentNode parentNode] insertBefore:element refChild:[parentNode nextSibling]];
    }
    else
    {
        // Graphics are written as-is. Callouts write their contents
        if (![controller writeAttributedHTML:adaptor])
        {
            result = element;
        }
    }
    
    
    return result;
}

- (DOMNode *)convertImageElementToGraphic:(DOMHTMLImageElement *)imageElement
                               HTMLWriter:(SVParagraphedHTMLWriterDOMAdaptor *)writer;
{
    // Is there an orphaned item we should reconnect to?
    WEKWebEditorItem *orphanedItem = [self orphanedWebEditorItemMatchingDOMNode:imageElement];
    if (orphanedItem)
    {
        [orphanedItem setHTMLElement:imageElement];
        [orphanedItem writeAttributedHTML:writer];
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
    SVRichText *text = [self representedObject];
    NSManagedObjectContext *context = [text managedObjectContext];
    
    SVMedia *media = nil;
    NSURL *URL = [imageElement absoluteImageURL];
    if ([URL isFileURL])
    {
        media = [[SVMedia alloc] initWithContentsOfURL:URL error:NULL];
        // FIXME: what if that failed?
    }
    else
    {
        WebResource *resource = [[[[imageElement ownerDocument] webFrame] dataSource] subresourceForURL:URL];
        if (resource)   // e.g. Chrome only provides the URL. #92311
        {
            media = [[SVMedia alloc] initWithWebResource:resource];
            
            // FIXME: Why not match the URL's filename?
            [media setPreferredFilename:[@"pastedImage" stringByAppendingPathExtension:[URL ks_pathExtension]]];
        }
    }
    
    SVMediaGraphic *image = [SVMediaGraphic insertNewGraphicInManagedObjectContext:context];
    if (media)
    {
        [image setSourceWithMedia:media];
        [media release];
    }
    else
    {
        [image setSourceWithExternalURL:URL];
    }
    
    
    // Try to divine image size
    int width = [imageElement width];
    int height = [imageElement height];
    
    if (width > 0 && height > 0)
    {
        [image setWidth:[NSNumber numberWithInt:width]];
        [image setHeight:[NSNumber numberWithInt:height]];
    }
    else
    {
        [image makeOriginalSize];
    }
    [image setConstrainProportions:YES];
    
    
    // Make corresponding text attachment
    SVTextAttachment *textAttachment = [SVTextAttachment insertNewTextAttachmentInManagedObjectContext:context];
    [textAttachment setGraphic:image];
    [textAttachment setBody:text];
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    
    
    // Match wrap settings if possible
    DOMCSSStyleDeclaration *style = [[[self webEditor] webView] computedStyleForElement:imageElement
                                                                          pseudoElement:nil];
    
    [textAttachment setCausesWrap:[NSNumber numberWithBool:
                                   ([[style display] isEqualToString:@"block"] ? YES : NO)]];
    
    NSString *floatProperty = [style getPropertyValue:@"float"];
    if ([floatProperty isEqualToString:@"left"])
    {
        [textAttachment setWrapRight:YES];  // believe it, this is the right call!
    }
    else if ([floatProperty isEqualToString:@"right"])
    {
        [textAttachment setWrapLeft:YES];  // believe it, this is the right call!
    }
    
    // Create controller for graphic and hook up to imported node
    SVMediaGraphicDOMController *controller = (SVMediaGraphicDOMController *)[image newDOMController];
    [controller awakeFromHTMLContext:[self HTMLContext]];
    [[controller imageDOMController] setHTMLElement:imageElement];
    [controller setHTMLElement:imageElement];
    
    [self addChildWebEditorItem:controller];
    
    
    // Generate new DOM node to match what model would normally generate
    [controller update];
    [controller release];
    
    
    // Write the replacement
    [controller writeAttributedHTML:writer];
    
    
    return [[controller HTMLElement] nextSibling];
}

- (DOMNode *)DOMAdaptor:(SVParagraphedHTMLWriterDOMAdaptor *)writer willWriteDOMElement:(DOMElement *)element;
{
    // If the element is inside an DOM controller, write that out instead…
    WEKWebEditorItem *item = [self itemForDOMNode:element];
    if (item)
    {
        // …If there are 2 controllers with the same node (e.g. plain image), hit-testing favours the inner one. We actually want to write the outer.
        return [self write:writer DOMElement:element item:item];
    }
    
    
    
    // Images need to create a corresponding model object & DOM controller
    else if ([writer importsGraphics] && [[element tagName] isEqualToString:@"IMG"])
    {
        return [self convertImageElementToGraphic:(DOMHTMLImageElement *)element
                                       HTMLWriter:writer];
    }
    
    
    return element;
}

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
                                 inManagedObjectContext:[[self representedObject] managedObjectContext]];
            
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
            
            SVGraphic *selectedGraphic = [selection representedObject];
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
        // Create controller for graphic
        SVGraphicDOMController *controller = [[graphic newDOMController] autorelease];
        [controller loadPlaceholderDOMElementInDocument:[[self HTMLElement] ownerDocument]];
        [controller setHTMLContext:[self HTMLContext]];
        
        // Generate & insert DOM node
        [insertionRange insertNode:[controller HTMLElement]];
        
        // Insert controller – must do after node is inserted so descendant nodes can be located by ID
        WEKWebEditorItem *parentController = [self hitTestDOMNode:[controller HTMLElement]];
        [parentController addChildWebEditorItem:controller];
        
        // Tell the graphic what's happened
        KTPage *page = [[self HTMLContext] page];
        [graphic didAddToPage:page];
        
        [controller update];	// push it through quickly
        
        // Finish the edit – had to wait until both node and controller were present
        [webEditor didChangeText];
    }
    
}

- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;
{
    // Create text attachment for the graphic
    SVTextAttachment *textAttachment = [SVTextAttachment insertNewTextAttachmentInManagedObjectContext:[graphic managedObjectContext]];
    [textAttachment setGraphic:graphic];
    
    SVGraphicPlacement placement = ([graphic isKindOfClass:[SVTextBox class]] ? // #93281
                                    SVGraphicPlacementCallout :
                                    SVGraphicPlacementInline);
    [textAttachment setPlacement:[NSNumber numberWithInteger:placement]];
    
    [textAttachment setCausesWrap:[NSNumber numberWithBool:!placeInline]];
    [textAttachment setBody:[self representedObject]];
    
    
    // Insert
    DOMRange *insertionRange = [self insertionRangeForGraphic:graphic];
    [self insertGraphic:graphic range:insertionRange];
    
    
    
    // Select item.
    NSArrayController *selectionController =
    [[self webEditorViewController] graphicsController];
    if ([selectionController setSelectedObjects:[NSArray arrayWithObject:graphic]])
    {
        /*
        // For non-inline graphics, need the WebView to resign first responder. #79189
        BOOL select = YES;
        if (!placeInline) select = [[webEditor window] makeFirstResponder:webEditor];
        
        if (select) [webEditor selectItems:[NSArray arrayWithObject:controller]
                      byExtendingSelection:NO];*/
    }
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
    
    
    // FIXME: Should reference non-image URLs
    SVMedia *media = [[SVMedia alloc] initWithContentsOfURL:[sheet URL] error:NULL];
    if (!media) return;
    
    
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    
    SVMediaGraphic *graphic = [SVMediaGraphic insertNewGraphicInManagedObjectContext:context];
    [graphic setSourceWithMedia:media];
    [graphic setShowsTitle:NO];
    [graphic setShowsCaption:NO];
    [graphic setShowsIntroduction:NO];
    
    [media release];
    
    [self addGraphic:graphic placeInline:YES];
}

#pragma mark Pasteboard

- (void)webEditorTextDidSetSelectionTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    [pasteboard addTypes:[NSArray arrayWithObject:@"com.karelia.html+graphics"] owner:self];
    
    [SVAttributedHTMLWriter writeDOMRange:[[self webEditor] selectedDOMRange]
                             toPasteboard:pasteboard
                       graphicControllers:[self childWebEditorItems]];
}

#pragma mark KVO

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

- (SVTextDOMController *)newTextDOMController;
{
    SVTextDOMController *result = [[SVRichTextDOMController alloc] initWithRepresentedObject:self];
    [result setRichText:YES];
    
    return result;
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVRichTextDOMController)

- (BOOL)allowsPagelets; { return NO; }

- (BOOL)writeAttributedHTML:(SVParagraphedHTMLWriterDOMAdaptor *)writer; { return NO; }

@end

