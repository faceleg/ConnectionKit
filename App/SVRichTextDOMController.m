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
#import "SVGraphicFactory.h"
#import "SVRichText.h"
#import "KTDocument.h"
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
    [_changeHTMLContext release];//OBASSERT(!_changeHTMLContext);
    
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
        for (WEKWebEditorItem *anItem in [_changeHTMLContext DOMControllers])
        {
            // Web Editor View Controller will pick up the insertion in its delegate method and handle the various side-effects.
            if (![anItem parentWebEditorItem]) [self addChildWebEditorItem:anItem];
        }
        
        [_changeHTMLContext release]; _changeHTMLContext = nil;
    }
        
        
    
    
    //  Write the whole out using a special stream
    
       
    NSMutableString *html = [[NSMutableString alloc] init];
    
    SVParagraphedHTMLWriter *writer = 
    [[SVParagraphedHTMLWriter alloc] initWithOutputWriter:html];
    
    [writer setDelegate:self];
    [writer setAllowsPagelets:[self allowsPagelets]];
    
    
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
    
    
    // Finish up
    [html release];
    [writer release];
    [super webEditorTextDidChange];
}

- (void)willWriteText:(SVParagraphedHTMLWriter *)writer; { }

- (BOOL)write:(SVParagraphedHTMLWriter *)writer selectableItem:(WEKWebEditorItem *)controller;
{
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *attachment = [graphic textAttachment];
    
    
    // Is it allowed?
    if ([graphic isPagelet])
    {
        if ([self allowsPagelets])
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
                                        SVGraphicPlacementInline :
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
    NSString *stream = [[writer valueForKeyPath:@"_writer._outputs"] objectAtIndex:0];  // HACK!
    NSRange range = NSMakeRange([stream length] - 1, 1);
    
    if (!NSEqualRanges([attachment range], range))
    {
        [attachment setRange:range];
    }
    
    
    
    
    
    return YES;
}

- (DOMNode *)write:(SVParagraphedHTMLWriter *)writer
        DOMElement:(DOMElement *)element
              item:(WEKWebEditorItem *)controller;
{
    DOMNode *result = [element nextSibling];    // must grab before any chance of editing DOM due to misplaced graphic
    
    
    // We have a matching controller. But is it in a valid location? Make sure it really is block-level/inline
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *attachment = [graphic textAttachment];
    
    DOMNode *parentNode = [element parentNode];
    
    if ([writer openElementsCount] &&
        [[attachment placement] integerValue] != SVGraphicPlacementInline)
    {
        // Push the element off up the tree; it will be written next time round
        [[parentNode parentNode] insertBefore:element refChild:[parentNode nextSibling]];
    }
    else
    {
        // Graphics are written as-is. Callouts write their contents
        if ([controller isSelectable])
        {
            if (![self write:writer selectableItem:controller]) result = element;
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
    }
    
    
    return result;
}

- (DOMNode *)HTMLWriter:(SVParagraphedHTMLWriter *)writer willWriteDOMElement:(DOMElement *)element;
{
    WEKWebEditorItem *item = [self hitTestDOMNode:element];
    if (item != self)
    {
        return [self write:writer DOMElement:element item:item];
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
    [textAttachment setPlacement:[NSNumber numberWithInteger:SVGraphicPlacementInline]];
    [textAttachment setBody:[self representedObject]];
    
    
    // Create controller for graphic
    SVDOMController *controller = [SVDOMController
                                   DOMControllerWithGraphic:graphic
                                   parentWebEditorItemToBe:self
                                   context:[self HTMLContext]];
    
    
    // Generate & insert DOM node
    DOMRange *selection = [webEditor selectedDOMRange];
    if ([webEditor shouldChangeTextInDOMRange:selection])
    {
        [selection insertNode:[controller HTMLElement]];
    
        // Insert controller – must do after node is inserted so descendant nodes can be located by ID
        [self addChildWebEditorItem:controller];
        
        // Finish the edit – had to wait until both node and controller were present
        [webEditor didChangeText];
    }
    
    
    
    // Select item.
    NSArrayController *selectionController =
    [[[self HTMLContext] webEditorViewController] graphicsController];
    if ([selectionController setSelectedObjects:[NSArray arrayWithObject:graphic]])
    {
        // For non-inline graphics, need the WebView to resign first responder. #79189
        BOOL select = YES;
        if (!placeInline) select = [[webEditor window] makeFirstResponder:webEditor];
        
        if (select) [webEditor selectItems:[NSArray arrayWithObject:controller]
                      byExtendingSelection:NO];
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
        [image setShowsTitle:NO];
        [image setShowsCaption:NO];
        [image setShowsIntroduction:NO];
        
        [image willInsertIntoPage:[[self HTMLContext] page]];
        [self addGraphic:image placeInline:YES];
    }
    else
    {
        NSBeep();
    }
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

- (SVDOMController *)newDOMController;
{
    SVTextDOMController *result = [[SVRichTextDOMController alloc] initWithContentObject:self];
    [result setRichText:YES];
    
    return result;
}

@end
