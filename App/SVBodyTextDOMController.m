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
#import "SVBodyTextHTMLContext.h"
#import "SVCallout.h"
#import "KTAbstractPage.h"
#import "SVPagelet.h"
#import "SVBody.h"
#import "KTDocWindowController.h"
#import "SVImage.h"
#import "SVLinkManager.h"
#import "SVLink.h"
#import "SVMediaRecord.h"
#import "SVTextAttachment.h"
#import "SVWebContentObjectsController.h"

#import "NSDictionary+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"

#import "KSOrderedManagedObjectControllers.h"


static NSString *sBodyElementsObservationContext = @"SVBodyTextAreaElementsObservationContext";


@implementation SVBodyTextDOMController

#pragma mark Init & Dealloc

- (id)initWithContentObject:(SVContentObject *)body inDOMDocument:(DOMDocument *)document;
{
    // Super
    self = [super initWithContentObject:body inDOMDocument:document];
    
    
    // Create controller for each graphic/attachment
    NSSet *graphics = [[self representedObject] attachments];
    for (SVTextAttachment *anAttachment in graphics)
    {
        SVPagelet *graphic = [anAttachment pagelet];
        Class class = [graphic DOMControllerClass];
        SVDOMController *result = [[class alloc] initWithContentObject:graphic
                                                         inDOMDocument:document];
        
        [result setHTMLContext:[[self webEditorViewController] HTMLContext]];
        
        [self addChildWebEditorItem:result];
        [result release];
    }
    
    
    // Finish up
    return self;
}

- (void)dealloc
{
    // Release ivars
    
    [super dealloc];
}

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

#pragma mark Content

- (void)update
{
    [self willUpdate];
    
    // Walk the content array. Shuffle up DOM nodes to match if needed
    DOMHTMLElement *domNode = [[self textHTMLElement] firstChildOfClass:[DOMHTMLElement class]];
    
    for (SVBodyElement *aModelElement in [[self content] arrangedObjects])
    {
        // Locate the matching controller
        SVDOMController *controller = [self controllerForBodyElement:aModelElement];
        if (controller)
        {
            // Ensure the node is in the right place. Most of the time it already will be. If it isn't 
            if ([controller HTMLElement] != domNode)
            {
                [[self textHTMLElement] insertBefore:[controller HTMLElement] refChild:domNode];
                domNode = [controller HTMLElement];
            }
        
        
        
            domNode = [domNode nextSiblingOfClass:[DOMHTMLElement class]];
        }
        else
        {
            // It's a new object, create controller and node to match
            Class controllerClass = [aModelElement DOMControllerClass];
            controller = [[controllerClass alloc] initWithHTMLDocument:
                          (DOMHTMLDocument *)[[self HTMLElement] ownerDocument]];
            [controller setHTMLContext:[self HTMLContext]];
            [controller setRepresentedObject:aModelElement];
            
            [[self textHTMLElement] insertBefore:[controller HTMLElement] refChild:domNode];
            
            [self addChildWebEditorItem:controller];
            [controller release];
        }
    }
    
    
    // All the nodes for deletion should have been pushed to the end, so we can delete them
    while (domNode)
    {
        DOMHTMLElement *nextNode = [domNode nextSiblingOfClass:[DOMHTMLElement class]];
        
        [[self controllerForDOMNode:domNode] removeFromParentWebEditorItem];
        [[domNode parentNode] removeChild:domNode];
        
        domNode = nextNode;
    }
    
    [self didUpdate];
}

#pragma mark Insertion

- (void)insertGraphic:(SVPagelet *)graphic;
{
    SVWebEditorView *webEditor = [self webEditor];
    
    
    // Create text attachment for the graphic
    SVTextAttachment *textAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                                     inManagedObjectContext:[graphic managedObjectContext]];
    [textAttachment setPagelet:graphic];
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
    
    [[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeNotification
                                                        object:[webEditor webView]];
}

- (IBAction)insertPagelet:(id)sender;
{
    // TODO: Make the insertion
}

- (IBAction)insertFile:(id)sender;
{
    NSWindow *window = [[[self HTMLElement] documentView] window];
    NSOpenPanel *panel = [[window windowController] makeChooseDialog];
    
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

#pragma mark Editability

- (BOOL)isSelectable { return NO; }

- (void)setEditable:(BOOL)editable
{
    // TODO: Embedded graphics must NOT be selectable
    for (SVDOMController *aGraphicController in [self graphicControllers])
    {
        [[[aGraphicController HTMLElement] style] setProperty:@"-webkit-user-select"
                                                        value:@"none"
                                                     priority:@"!important"];
    }
    
    // Carry on
    [super setEditable:editable];
}

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
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[[self childWebEditorItems] count]];
    
    for (KSDOMController *aController in [self childWebEditorItems])
    {
        if (![aController isKindOfClass:[SVParagraphDOMController class]])
        {
            [result addObject:aController];
        }
    }
    
    return result;
}

#pragma mark Updates

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

#pragma mark Editing

- (void)didChangeText;
{
    //  Body Text Controller doesn't track indivdual text changes itself, leaving that up to the paragraphs. So use this point to pass a similar message onto those subcontrollers to handle.
    
    
    NSMutableString *html = [[NSMutableString alloc] init];
    SVBodyTextHTMLContext *context = [[SVBodyTextHTMLContext alloc] initWithStringStream:html];
    [context setBodyTextDOMController:self];
    
    [[self textHTMLElement] writeInnerHTMLToContext:context];
    [context release];
    
    
    SVBody *body = [self representedObject];
    if (![html isEqualToString:[body string]])
    {
        [super didChangeText];
        [body setString:html];
    }
    
    [html release];
}

- (void)writeGraphicController:(SVDOMController *)controller
                     toContext:(SVBodyTextHTMLContext *)context;
{
    SVPagelet *graphic = [controller representedObject];
    
    
    // Ensure graphic has TextAttachment
    SVTextAttachment *textAttachment = [graphic textAttachment];
    if (!textAttachment)
    {
        textAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"TextAttachment"
                                                       inManagedObjectContext:[graphic managedObjectContext]];
        [textAttachment setPagelet:graphic];
        [textAttachment setBody:[self representedObject]];
    }
    
    
    // Set attachment location
    NSMutableString *stream = (NSMutableString *)[context stringStream];
    [context writeString:[NSString stringWithUnichar:NSAttachmentCharacter]];
    
    [textAttachment setLocation:[NSNumber numberWithUnsignedInteger:([stream length] - 1)]];
    [textAttachment setLength:[NSNumber numberWithShort:1]];
}

#pragma mark Links

- (void)changeLinkDestinationTo:(NSString *)linkURLString;
{
    SVWebEditorView *webEditor = [self webEditor];
    DOMRange *selection = [webEditor selectedDOMRange];
    
    if (!linkURLString)
    {
        DOMHTMLAnchorElement *anchor = [selection editableAnchorElement];
        if (anchor)
        {
            // Figure out selection before editing the DOM
            DOMNode *remainder = [anchor unlink];
            [selection selectNode:remainder];
            [webEditor setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
        }
        else
        {
            // Fallback way
            [[webEditor selectedDOMRange] removeAnchorElements];
        }
    }
    else
    {
        DOMHTMLAnchorElement *link = (id)[[webEditor HTMLDocument] createElement:@"A"];
        [link setHref:linkURLString];
        
        // Changing link affects selection. But if the selection is collapsed the user almost certainly wants to affect surrounding word/link
        if ([selection collapsed])
        {
            [[webEditor webView] selectWord:self];
            selection = [webEditor selectedDOMRange];
        }
        
        [selection surroundContents:link];
        
        // Make the link the selected object
        [selection selectNode:link];
        [webEditor setSelectedDOMRange:selection affinity:NSSelectionAffinityDownstream];
    }
    
    // Need to let paragraph's controller know an actual editing change was made
    [self webViewDidChange];
}

- (void)changeLink:(SVLinkManager *)sender;
{
    [self changeLinkDestinationTo:[[sender selectedLink] URLString]];
}

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
            KTAbstractPage *target = [KTAbstractPage pageWithUniqueID:pageID
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
    
    [[SVLinkManager sharedLinkManager] setSelectedLink:link editable:(selection != nil)];
    [link release];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sBodyElementsObservationContext)
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

