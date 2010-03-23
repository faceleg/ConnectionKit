//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyTextDOMController.h"
#import "SVParagraphDOMController.h"

#import "KT.h"
#import "SVAttributedHTML.h"
#import "SVAttributedHTMLWriter.h"
#import "KTPage.h"
#import "SVGraphic.h"
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
#import "SVWebEditorView.h"

#import "NSDictionary+Karelia.h"
#import "NSString+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSOrderedManagedObjectControllers.h"


static NSString *sBodyTextObservationContext = @"SVBodyTextObservationContext";


@implementation SVBodyTextDOMController

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
    
    [super dealloc];
}

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

#pragma mark Updating

- (void)update
{
    [self willUpdate];
    
    [self didUpdate];
}

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

- (NSArray *)graphicControllers;
{
    return [self childWebEditorItems];
}

#pragma mark Controlling Editing Behaviour

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    // When moving an inline element, want to actually do that move
    
    SVWebEditorView *webEditor = [self webEditor];
    NSPasteboard *pasteboard = [webEditor insertionPasteboard];
    if (pasteboard)
    {
            
        // De-archive custom HTML
        SVAttributedHTML *attributedHTML = [SVAttributedHTML
                                            attributedHTMLFromPasteboard:pasteboard
                                            managedObjectContext:[[self representedObject] managedObjectContext]];
        
        if (attributedHTML)
        {
            // Generate HTML for the DOM
            NSMutableString *editingHTML = [[NSMutableString alloc] init];
            SVWebEditorHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithStringWriter:editingHTML];
            [context copyPropertiesFromContext:[self HTMLContext]];
            
            [attributedHTML writeHTMLToContext:context];
            
            
            // Insert HTML into the DOM
            DOMHTMLDocument *domDoc = (DOMHTMLDocument *)[node ownerDocument];
            DOMDocumentFragment *fragment = [domDoc
                                             createDocumentFragmentWithMarkupString:editingHTML
                                             baseURL:nil];
            [range insertNode:fragment];
            
            
            // Insert DOM controllers
            // TODO: This duplicates -[SVWebEditorViewController webEditorViewDidFinishLoading:] somewhat
            for (SVWebEditorItem *anItem in [context webEditorItems])
            {
                if (![anItem isHTMLElementCreated]) [anItem loadHTMLElementFromDocument:domDoc];
                OBASSERT([anItem HTMLElement]);
                
                if (![anItem parentWebEditorItem]) [self addChildWebEditorItem:anItem];
            }
            
            
            // FInish up. Pretend we Inserted nothing. MUST supply empty text node otherwise WebKit interprets as a paragraph break for some reason
            [context release];
            [editingHTML release];
            
            [[node mutableChildNodesArray] removeAllObjects];
            [node appendChild:[[node ownerDocument] createTextNode:@""]];
        }
    }
    
    
    
    return [super webEditorTextShouldInsertNode:node replacingDOMRange:range givenAction:action];
}

#pragma mark Responding to Changes

- (void)webEditorTextDidBeginEditing;
{
    [super webEditorTextDidBeginEditing];
    
    // A bit crude, but we don't want WebKit's usual focus ring
    [[[self HTMLElement] style] setProperty:@"outline" value:@"none" priority:@""];
}

- (void)webViewDidChange;
{    
    //  Write the whole out using a special stream
    
       
    NSMutableString *html = [[NSMutableString alloc] init];
    
    SVParagraphedHTMLWriter *context = 
    [[SVParagraphedHTMLWriter alloc] initWithStringWriter:html];
    
    [context setBodyTextDOMController:self];
    
    
    // Top-level nodes can only be: paragraph, newline, or graphic. Custom DOMNode addition handles this
    DOMNode *aNode = [[self textHTMLElement] firstChild];
    while (aNode)
    {
        aNode = [aNode topLevelBodyTextNodeWriteToStream:context];
    }
    
    
    SVRichText *textObject = [self representedObject];
    if (![html isEqualToString:[textObject string]])
    {
        _isUpdating = YES;
        [textObject setString:html
                  attachments:[context textAttachments]];
        _isUpdating = NO;
    }
    
    
    // Tidy up
    [context release];
}

- (void)writeGraphicController:(SVDOMController *)controller
                withHTMLWriter:(SVParagraphedHTMLWriter *)context;
{
    SVGraphic *graphic = [controller representedObject];
    SVTextAttachment *textAttachment = [graphic textAttachment];
    
    
    
    // Set attachment location
    NSMutableString *stream = (NSMutableString *)[context stringWriter];
    [context writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
    
    NSUInteger location = [stream length] - 1;
    if ([textAttachment range].location != location)
    {
        [textAttachment setLocation:[NSNumber numberWithUnsignedInteger:location]];
        [textAttachment setLength:[NSNumber numberWithShort:1]];
    }
}

#pragma mark Links

@synthesize selectedLink = _selectedLink;

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification
{
    [super webEditorTextDidChangeSelection:notification];
    
    
    // Does the selection contain a link? If so, make it the selected object
    SVWebEditorView *webEditor = [self webEditor];
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

- (void)insertGraphic:(SVGraphic *)graphic;
{
    SVWebEditorView *webEditor = [self webEditor];
    
    
    // Create text attachment for the graphic
    SVTextAttachment *textAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                                     inManagedObjectContext:[graphic managedObjectContext]];
    [textAttachment setGraphic:graphic];
    [textAttachment setBody:[self representedObject]];
    
    
    // Create controller for graphic
    SVDOMController *controller = [[[graphic DOMControllerClass] alloc]
                                   initWithHTMLDocument:(DOMHTMLDocument *)[webEditor HTMLDocument]];
    [controller setHTMLContext:[self HTMLContext]];
    [controller setRepresentedObject:graphic];
    
    [self addChildWebEditorItem:controller];
    [controller release];
    
    
    // Generate DOM node
    [webEditor willChange];
    
    DOMRange *selection = [webEditor selectedDOMRange];
    [selection insertNode:[controller HTMLElement]];
    
    [webEditor didChange];
}

- (IBAction)insertPagelet:(id)sender;
{
    // TODO: Make the insertion
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
                                            entityName:@"ImageMedia"
                        insertIntoManagedObjectContext:context
                                                 error:NULL];
    
    if (media)
    {
        SVImage *image = [SVImage insertNewImageWithMedia:media];
        [self insertGraphic:image];
    }
    else
    {
        NSBeep();
    }
}

- (IBAction)placeBlockLevel:(id)sender;    // tells all selected graphics to become placed as block
{
    SVWebEditorView *webEditor = [self webEditor];
    [webEditor willChange];
    
    
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
    [webEditor didChange];
}

#pragma mark Pasteboard

- (void)addSelectionTypesToPasteboard:(NSPasteboard *)pasteboard;
{
    [pasteboard addTypes:[NSArray arrayWithObject:@"com.karelia.html+graphics"] owner:self];
    
    [SVAttributedHTMLWriter writeDOMRange:[[self webEditor] selectedDOMRange]
                             toPasteboard:pasteboard
                       graphicControllers:[self graphicControllers]];
}

#pragma mark Dragging

- (BOOL)webEditorTextValidateDrop:(id <NSDraggingInfo>)info
                proposedOperation:(NSDragOperation *)proposedOperation;
{
    // When dragging graphics within the Web Editor, want to move them rather than do a copy
    SVWebEditorView *webEditor = [self webEditor];
    if ([info draggingSource] == webEditor)
    {
        *proposedOperation = NSDragOperationMove;
        
        return NO;
    }
    else
    {
        return [super webEditorTextValidateDrop:info proposedOperation:proposedOperation];
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sBodyTextObservationContext)
    {
        if (![self isUpdating])
        {
            [[self webEditorViewController] setNeedsUpdate];
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
    return [SVBodyTextDOMController class];
}

@end
