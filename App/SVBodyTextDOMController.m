//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyTextDOMController.h"
#import "SVBodyParagraphDOMAdapter.h"

#import "SVBodyParagraph.h"
#import "SVCallout.h"
#import "SVPagelet.h"
#import "SVBody.h"
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
    // Make an object controller
    KSSetController *elementsController = [[KSSetController alloc] init];
    [elementsController setOrderingSortKey:@"sortKey"];
    [elementsController setManagedObjectContext:[body managedObjectContext]];
    [elementsController setEntityName:@"BodyParagraph"];
    [elementsController setAutomaticallyRearrangesObjects:YES];
    [elementsController bind:NSContentSetBinding toObject:body withKeyPath:@"elements" options:nil];
    
    
    // Super
    self = [super initWithContentObject:body inDOMDocument:document];
    
    
    // Get our content populated first so we don't have to teardown and restup the DOM
    _content = elementsController;
    
    
    
    // Match each model element up with its DOM equivalent
    NSArray *bodyElements = [[self content] arrangedObjects];
    for (SVBodyElement *aModelElement in bodyElements)
    {
        Class class = [self controllerClassForBodyElement:aModelElement];
        SVDOMController *result = [[class alloc] initWithContentObject:aModelElement
                                                         inDOMDocument:[[self HTMLElement] ownerDocument]];
        
        [result setHTMLContext:[self HTMLContext]];
        
        [self addChildWebEditorItem:result];
        [result release];
    }
    
    
    // Observe DOM changes. Each SVBodyParagraphDOMAdapter will take care of its own section of the DOM
    [[self textHTMLElement] addEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self textHTMLElement] addEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    
    // Observe content changes
    [[self content] addObserver:self
                     forKeyPath:@"arrangedObjects"
                        options:0
                        context:sBodyElementsObservationContext];
    
    
    // Finish up
    return self;
}

- (void)dealloc
{
    // Stop observation
    [[self textHTMLElement] removeEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self textHTMLElement] removeEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    [[self content] removeObserver:self forKeyPath:@"arrangedObjects"];
    
    
    // Release ivars
    [_content release];
    
    [super dealloc];
}

#pragma mark DOM Node

- (void)setHTMLElement:(DOMHTMLElement *)element
{
    [super setHTMLElement:element];
    [self setTextHTMLElement:element];
}

#pragma mark Content

@synthesize content = _content;

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
            Class controllerClass = [self controllerClassForBodyElement:aModelElement];
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

- (BOOL)insertElement:(SVBodyElement *)element;
{
    BOOL result = NO;
    
    // First remove any selected text
    WebView *webView = [[[[self HTMLElement] ownerDocument] webFrame] webView];
    [webView delete:self];
    
    
    // Figure out the body element to insert next to
    DOMRange *selection = [webView selectedDOMRange];
    OBASSERT([selection collapsed]);    // calling -delete: should have collapsed it
    
    KSDOMController *controller = [self controllerForDOMNode:[selection startContainer]];
    if (controller)
    {
        SVBodyElement *bodyElement = [controller representedObject];
        NSUInteger index = [[[self content] arrangedObjects] indexOfObject:bodyElement];
        if (index != NSNotFound)
        {
            [[self content] insertObject:element atArrangedObjectIndex:index];
            result = YES;
        }
    }
    
    
    return result;
}

- (BOOL)insertPagelet:(SVPagelet *)pagelet
{
    // Create a callout
    SVCallout *callout = [NSEntityDescription insertNewObjectForEntityForName:@"Callout"
                                                       inManagedObjectContext:[pagelet managedObjectContext]];
    
    [pagelet setSortKey:[NSNumber numberWithInteger:0]];
    [callout setPagelets:[NSSet setWithObject:pagelet]];
    
    return [self insertElement:callout];
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

- (Class)controllerClassForBodyElement:(SVBodyElement *)element;
{
    Class result = [element DOMControllerClass];
    
    return result;
}

- (NSArray *)graphicControllers;
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[[self childWebEditorItems] count]];
    
    for (KSDOMController *aController in [self childWebEditorItems])
    {
        if (![aController isKindOfClass:[SVBodyParagraphDOMAdapter class]])
        {
            [result addObject:aController];
        }
    }
    
    return result;
}

#pragma mark Updates

- (void)didChangeText
{
    [super didChangeText];
    
    // Let subcontrollers know the change took place
    [[self childWebEditorItems] makeObjectsPerformSelector:@selector(enclosingBodyControllerDidChangeText)];
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

#pragma mark Editing

- (void)handleEvent:(DOMMutationEvent *)event
{
    // We're only interested in nodes being added or removed from our own node
    if ([event relatedNode] != [self textHTMLElement]) return;
    
    
    // Nor do we care mid-update
    if ([self isUpdating]) return;
    
    
    // Add or remove controllers for the new element
    if ([[event type] isEqualToString:@"DOMNodeInserted"])
    {
        // WebKit sometimes likes to keep the HTML neat by inserting both a newline character and HTML element at the same time. Ignore the former
        DOMHTMLElement *insertedNode = (DOMHTMLElement *)[event target];
        if (![insertedNode isKindOfClass:[DOMHTMLElement class]])
        {
            return;
        }
        
        
        // Create paragraph
        SVBodyParagraph *paragraph = [[self content] newObject];
        [paragraph readHTMLFromElement:insertedNode];
        
        
        // Create a matching controller
        Class class = [self controllerClassForBodyElement:paragraph];
        SVDOMController *controller = [[class alloc] initWithHTMLElement:insertedNode];
        
        [controller setRepresentedObject:paragraph];
        [paragraph release];
        [controller setHTMLContext:[self HTMLContext]];
        
        [self addChildWebEditorItem:controller];
        [controller release];
        
        
        // Insert the paragraph into the model in the same spot as it is in the DOM
        [self willUpdate];
         
        DOMHTMLElement *nextNode = [insertedNode nextSiblingOfClass:[DOMHTMLElement class]];
        if (nextNode)
        {
            KSDOMController * nextController = [self controllerForDOMNode:nextNode];
            OBASSERT(nextController);
            
            NSArrayController *content = [self content];
            NSUInteger index = [[content arrangedObjects] indexOfObject:[nextController representedObject]];
            [content insertObject:paragraph atArrangedObjectIndex:index];
        }
        else
        {
            // shortcut, know we're inserting at the end
            [[self content] addObject:paragraph];
        }
        
        [self didUpdate];
    }
    else if ([[event type] isEqualToString:@"DOMNodeRemoved"])
    {
        // Remove paragraph
        DOMHTMLElement *removedNode = (DOMHTMLElement *)[event target];
        if ([removedNode isKindOfClass:[DOMHTMLElement class]])
        {
            SVWebEditorItem *controller = [self controllerForDOMNode:removedNode];
            if (controller)
            {
                SVBodyElement *element = [controller representedObject];
                
                [self willUpdate];
                [[self content] removeObject:element];
                [self didUpdate];
                
                [controller removeFromParentWebEditorItem];
            }
        }
    }
}

- (BOOL)doCommandBySelector:(SEL)selector
{
    BOOL result = [super doCommandBySelector:selector];
    
    if (selector == @selector(orderFrontLinkPanel:) ||
        selector == @selector(clearLinkDestination:))
    {
        [self performSelector:selector withObject:nil];
        result = YES;
    }
    
    
    return result;
}

#pragma mark Links

- (IBAction)orderFrontLinkPanel:(id)sender;
{
    SVWebEditorView *webEditor = [self webEditor];
    
    DOMHTMLAnchorElement *link = (id)[[webEditor HTMLDocument] createElement:@"A"];
    [link setHref:@"http://example.com"];
    
    DOMRange *selection = [webEditor selectedDOMRange];
    [selection surroundContents:link];
    
    // Need to let paragraph's controller know an actual editing change was made
    [self didChangeText];
}

- (IBAction)clearLinkDestination:(id)sender;
{
    SVWebEditorView *webEditor = [self webEditor];
    
    [[webEditor selectedDOMRange] removeAnchorElements];
}

- (BOOL)canMakeLink;
{
    return YES;
}

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification
{
    [super webEditorTextDidChangeSelection:notification];
    
    
    // Does the selection contain a link? If so, make it the selected object
    SVWebEditorView *webEditor = [self webEditor];
    DOMHTMLAnchorElement *link = [[webEditor selectedDOMRange] editableAnchorElement];
    if (link)
    {
        SVWebContentObjectsController *controller = [[webEditor dataSource] performSelector:@selector(primitiveSelectedObjectsController)];
        [controller selectObjectByInsertingIfNeeded:link];
    }
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

