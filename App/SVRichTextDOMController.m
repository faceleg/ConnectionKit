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
#import "KTPage.h"
#import "SVGraphic.h"
#import "SVRichText.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper+DataSourceRegistration.h"
#import "SVImage.h"
#import "SVLinkManager.h"
#import "SVLink.h"
#import "SVMediaRecord.h"
#import "SVParagraphedHTMLWriter.h"
#import "SVTextAttachment.h"
#import "SVWebContentObjectsController.h"
#import "SVWebEditorHTMLContext.h"
#import "WebEditingKit.h"
#import "SVWebEditorViewController.h"

#import "NSDictionary+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSOrderedManagedObjectControllers.h"


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
    
    // Finish up
    return self;
}

- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"representedObject.string"];
    
    // Release ivars
    OBASSERT(!_changeHTMLContext);
    
    [super dealloc];
}

#pragma mark Properties

- (BOOL)allowsBlockGraphics; { return NO; }

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

#pragma mark Updating

// Leave commented out until ready to implement
/*- (void)update
{
    [self willUpdate];
    
    [self didUpdate];
}*/

@synthesize updating = _isUpdating;

- (void)willUpdate
{
    OBPRECONDITION(!_isUpdating);
    _isUpdating = YES;
}

- (void)didUpdate
{
    OBPRECONDITION(_isUpdating);
    _isUpdating = NO;
}

#pragma mark Editability

- (BOOL)isSelectable { return NO; }

#pragma mark Subcontrollers

- (SVDOMController *)controllerForBodyElement:(SVBodyElement *)element;
{
    SVDOMController * result = nil;
    for (result in [self childWebEditorItems])
    {
        if ([result representedObject] == element) break;
    }
    
    return result;
}

- (SVDOMController *)controllerForDOMNode:(DOMNode *)node;
{
    SVDOMController *result = nil;
    for (result in [self childWebEditorItems])
    {
        if ([node isDescendantOfNode:[result HTMLElement]]) break;
    }
             
    return result;
}

#pragma mark Controlling Editing Behaviour

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    // When moving an inline element, want to actually do that move
    
    BOOL result = YES;
    
    
    WEKWebEditorView *webEditor = [self webEditor];
    NSPasteboard *pasteboard = [webEditor insertionPasteboard];
    if (pasteboard)
    {
        // Prepare to write HTML
        NSMutableString *editingHTML = [[NSMutableString alloc] init];
        OBASSERT(!_changeHTMLContext);
        _changeHTMLContext = [[SVWebEditorHTMLContext alloc] initWithStringWriter:editingHTML];
        [_changeHTMLContext copyPropertiesFromContext:[self HTMLContext]];
        
        
        // Try to de-archive custom HTML
        NSAttributedString *attributedHTML = [NSAttributedString
                                            attributedHTMLStringFromPasteboard:pasteboard
                                            insertAttachmentsIntoManagedObjectContext:[[self representedObject] managedObjectContext]];
        
        if (attributedHTML)
        {
            // Generate HTML for the DOM
            [_changeHTMLContext writeAttributedHTMLString:attributedHTML];
        }
        
        // Fallback to interpreting standard pboard data
        else
        {
            NSManagedObjectContext *moc = [[self representedObject] managedObjectContext];
            
            NSArray *graphics = [KTElementPlugInWrapper graphicsFomPasteboard:pasteboard
                                                                 insertIntoManagedObjectContext:moc];
            
            if (graphics)
            {
                [SVContentObject writeContentObjects:graphics inContext:_changeHTMLContext];
            }
        }
        
        
        
        
        // Insert HTML into the DOM
        if ([editingHTML length])
        {
            DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[node ownerDocument];
            
            DOMDocumentFragment *fragment = [domDoc
                                             createDocumentFragmentWithMarkupString:editingHTML
                                             baseURL:nil];
            [editingHTML release];
            
            [[node mutableChildDOMNodes] removeAllObjects];
            [node appendChildNodes:[fragment childNodes]];
            
            
            // Remove source dragged items if they came from us. No need to call -didChangeText as the insertion will do that
            [webEditor removeDraggedItems];
        }
    }
    
    
    // Pretend we Inserted nothing. MUST supply empty text node otherwise WebKit interprets as a paragraph break for some reason
    if (!result)
    {
        [[node mutableChildDOMNodes] removeAllObjects];
        [node appendChild:[[node ownerDocument] createTextNode:@""]];
        result = YES;
    }
    
    result = [super webEditorTextShouldInsertNode:node replacingDOMRange:range givenAction:action];
    return result;
}

- (BOOL)webEditorTextDoCommandBySelector:(SEL)action;
{
    // Bit of a bug in WebKit that means when you delete backwards in an empty text area, the empty paragraph object gets deleted. Fair enough, but WebKit doesn't send you a delegate message asking permission! #71489
    if (action == @selector(deleteBackward:))
    {
        if ([[[self textHTMLElement] innerText] length] <= 1) return YES;
    }
        
    return [super webEditorTextDoCommandBySelector:action];
}

- (void)webEditorTextDidBeginEditing;
{
    [super webEditorTextDidBeginEditing];
    
    // A bit crude, but we don't want WebKit's usual focus ring
    [[[self HTMLElement] style] setProperty:@"outline" value:@"none" priority:@""];
}

#pragma mark Responding to Changes

- (void)webEditorTextDidChange;
{    
    // Are there DOM Controllers from the change waiting to be inserted?
    if (_changeHTMLContext)
    {
        for (WEKWebEditorItem *anItem in [_changeHTMLContext webEditorItems])
        {
            // Web Editor View Controller will pick up the insertion in its delegate method and handle the various side-effects.
            if (![anItem parentWebEditorItem]) [self addChildWebEditorItem:anItem];
        }
        
        [_changeHTMLContext release]; _changeHTMLContext = nil;
    }
        
        
    
    
    //  Write the whole out using a special stream
    
       
    NSMutableString *html = [[NSMutableString alloc] init];
    
    SVParagraphedHTMLWriter *writer = 
    [[SVParagraphedHTMLWriter alloc] initWithStringWriter:html];
    
    [writer setDelegate:self];
    [writer setAllowsBlockGraphics:[self allowsBlockGraphics]];
    
    
    [self willWriteText:writer];
    
    
    // Top-level nodes can only be: paragraph, newline, or graphic. Custom DOMNode addition handles this
    DOMNode *aNode = [[self textHTMLElement] firstChild];
    while (aNode)
    {
        aNode = [aNode topLevelParagraphWriteToStream:writer];
    }
    
    
    SVRichText *textObject = [self representedObject];
    if (![html isEqualToString:[textObject string]])
    {
        _isUpdating = YES;
        [textObject setString:html
                  attachments:[writer textAttachments]];
        _isUpdating = NO;
    }
    
    
    // Tidy up
    [writer release];
}

- (void)willWriteText:(SVParagraphedHTMLWriter *)writer; { }

- (BOOL)write:(SVParagraphedHTMLWriter *)writer selectableItem:(WEKWebEditorItem *)controller;
{
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *attachment = [graphic textAttachment];
    
    
    // Is it allowed?
    if ([[attachment placement] integerValue] == SVGraphicPlacementBlock)
    {
        if ([self allowsBlockGraphics])
        {
            if ([writer openElementsCount] > 0)
            {
                return NO;
            }
        }
        else
        {
            NSLog(@"This text block does not support block graphics");
            return NO;
        }
    }
    
    
    
    
    // Go ahead and write    
    
    // Newly inserted graphics tend not to have a corresponding text attachment yet. If so, create one
    if (!attachment)
    {
        // Guess placement from controller hierarchy
        SVGraphicPlacement placement = ([controller parentWebEditorItem] == self ?
                                        SVGraphicPlacementBlock :
                                        SVGraphicPlacementCallout);
        
        attachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                       inManagedObjectContext:[graphic managedObjectContext]];
        [attachment setGraphic:graphic];
        [attachment setPlacement:[NSNumber numberWithInteger:placement]];
        //[attachment setWrap:[NSNumber numberWithInteger:SVGraphicWrapRightSplit]];
        [attachment setBody:[self representedObject]];
    }
    
    
    // Set attachment location
    [writer writeTextAttachment:attachment];
    
    [writer flush];
    NSString *stream = (NSMutableString *)[writer stringWriter];
    NSRange range = NSMakeRange([stream length] - 1, 1);
    
    if (!NSEqualRanges([attachment range], range))
    {
        [attachment setRange:range];
    }
    
    
    
    
    
    return YES;
}

- (BOOL)write:(SVParagraphedHTMLWriter *)writer item:(WEKWebEditorItem *)controller;
{
    // We have a matching controller. But is it in a valid location? Make sure it really is block-level/inline
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *attachment = [graphic textAttachment];
    
    DOMElement *element = [controller HTMLElement];
    DOMNode *parentNode = [element parentNode];
    
    if ([writer openElementsCount] &&
        [[attachment placement] integerValue] != SVGraphicPlacementInline)
    {
        // Push the element off up the tree
        [[parentNode parentNode] insertBefore:element refChild:[parentNode nextSibling]];
    }
    
    
    // Graphics are written as-is. Callouts write their contents
    if ([controller isSelectable])
    {
        return [self write:writer selectableItem:controller];
    }
    else
    {
        DOMNodeList *calloutContents = [element getElementsByClassName:@"callout-content"];
        for (unsigned i = 0; i < [calloutContents length]; i++)
        {
            DOMNode *aNode = [[calloutContents item:i] firstChild];
            while (aNode)
            {
                aNode = [aNode topLevelParagraphWriteToStream:writer];
            }
        }
    }
    
    return YES;
}

- (BOOL)HTMLWriter:(SVParagraphedHTMLWriter *)writer writeDOMElement:(DOMElement *)element;
{
    WEKWebEditorItem *item = [self hitTestDOMNode:element];
    if (item != self)
    {
        return [self write:writer item:item];
    }
    
    return NO;
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
            NSString *pageID = [linkURLString substringFromIndex:[kKTPageIDDesignator length]];
            KTPage *target = [KTPage pageWithUniqueID:pageID
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

- (void)addGraphic:(SVGraphic *)graphic placeInline:(BOOL)placeInline;
{
    WEKWebEditorView *webEditor = [self webEditor];
    
    
    // Create text attachment for the graphic
    SVTextAttachment *textAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                                     inManagedObjectContext:[graphic managedObjectContext]];
    [textAttachment setGraphic:graphic];
    [textAttachment setPlacement:
     [NSNumber numberWithInteger:(placeInline ? SVGraphicPlacementInline : SVGraphicPlacementBlock)]];
    [textAttachment setBody:[self representedObject]];
    
    
    // Create controller for graphic
    SVDOMController *controller = [[[graphic DOMControllerClass] alloc]
                                   initWithHTMLDocument:(DOMHTMLDocument *)[webEditor HTMLDocument]];
    [controller setHTMLContext:[self HTMLContext]];
    [controller setRepresentedObject:graphic];
    
    
    // Generate & insert DOM node
    DOMRange *selection = [webEditor selectedDOMRange];
    if ([webEditor shouldChangeTextInDOMRange:selection])
    {
        [selection insertNode:[controller HTMLElement]];
    
        // Insert controller – must do after node is inserted so descandant nodes can be located by ID
        [self addChildWebEditorItem:controller];
        [controller release];
        
        // Finish the edit – had to wait until both node and controller were present
        [webEditor didChangeText];
    }
    
    
    
    // Select item
    NSArrayController *selectionController =
    [[self webEditorViewController] selectedObjectsController];
    if ([selectionController setSelectedObjects:[NSArray arrayWithObject:graphic]])
    {
        [webEditor setSelectedItems:[NSArray arrayWithObject:controller]];
    }
}

- (IBAction)insertFile:(id)sender;
{
    NSWindow *window = [[[self HTMLElement] documentView] window];
    NSOpenPanel *panel = [[[window windowController] document] makeChooseDialog];
    
    [panel beginSheetForDirectory:nil file:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(chooseDialogDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)chooseDialogDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    NSManagedObjectContext *context = [[self representedObject] managedObjectContext];
    SVMediaRecord *media = [SVMediaRecord mediaWithURL:[sheet URL]
                                            entityName:@"GraphicMedia"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    if (media)
    {
        SVImage *image = [SVImage insertNewImageWithMedia:media];
        [self addGraphic:image placeInline:YES];
        
        [image awakeFromInsertIntoPage:[[self HTMLContext] page]];
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)placeBlockLevel:(id)sender;    // tells all selected graphics to become placed as block
{
    WEKWebEditorView *webEditor = [self webEditor];
    if (![webEditor shouldChangeText:self]) return;
    
    
    for (SVDOMController *aController in [webEditor selectedItems])
    {
        if ([aController parentWebEditorItem] != self) continue;
        
        
        // Seek out the paragraph nearest myself. Place my HTML element before/after there
        DOMNode *refNode = [aController HTMLElement];
        DOMNode *parentNode = [refNode parentNode];
        while (parentNode != [self HTMLElement])
        {
            refNode = parentNode;
            parentNode = [parentNode parentNode];
        }
        
        [parentNode insertBefore:[aController HTMLElement] refChild:refNode];
        
        
        // Make sure it's marked as block
        SVGraphic *graphic = [aController representedObject];
        [[graphic textAttachment] setPlacement:
         [NSNumber numberWithInteger:SVGraphicPlacementBlock]];
    }
    
    
    
    // Make Web Editor/Controller copy text to model
    [webEditor didChangeText];
}

#pragma mark Pasteboard

- (void)addSelectionTypesToPasteboard:(NSPasteboard *)pasteboard;
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

- (Class)DOMControllerClass;
{
    return [SVRichTextDOMController class];
}

@end
