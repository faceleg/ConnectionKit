//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyTextHTMLController.h"
#import "SVBodyParagraphDOMAdapter.h"

#import "SVBodyParagraph.h"
#import "SVPagelet.h"
#import "SVBody.h"
#import "SVWebContentItem.h"

#import "NSDictionary+Karelia.h"
#import "DOMNode+Karelia.h"


static NSString *sBodyElementsObservationContext = @"SVBodyTextAreaElementsObservationContext";


@implementation SVBodyTextHTMLController

#pragma mark Init & Dealloc

- (id)initWithHTMLElement:(DOMHTMLElement *)element;
{
    return [self initWithHTMLElement:element content:nil];
}

- (id)initWithHTMLElement:(DOMHTMLElement *)element content:(NSArrayController *)elementsController;
{
    OBPRECONDITION(elementsController);
    
    
    self = [super initWithHTMLElement:element];
    
    
    // Get our content populated first so we don't have to teardown and restup the DOM
    _content = [elementsController retain];
    
    
    
    // Match each model element up with its DOM equivalent
    NSArray *bodyElements = [[self content] arrangedObjects];
    _elementControllers = [[NSMutableSet alloc] initWithCapacity:[bodyElements count]];
    
    DOMDocument *document = [element ownerDocument]; 
    
    for (SVBodyElement *aModelElement in bodyElements)
    {
        DOMHTMLElement *htmlElement = [aModelElement elementForEditingInDOMDocument:document];
        OBASSERT([htmlElement isKindOfClass:[DOMHTMLElement class]]);
        
        [self makeAndAddControllerForBodyElement:aModelElement HTMLElement:htmlElement];
        
        [htmlElement setIdName:nil]; // don't want it cluttering up the DOM any more
    }
    
    
    // Observe DOM changes. Each SVBodyParagraphDOMAdapter will take care of its own section of the DOM
    [[self HTMLElement] addEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self HTMLElement] addEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    
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
    [[self HTMLElement] removeEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self HTMLElement] removeEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    [[self content] removeObserver:self forKeyPath:@"arrangedObjects"];
    
    
    // Release ivars
    [_content release];
    
    [_elementControllers setValue:nil forKey:@"representedObject"];
    [_elementControllers setValue:nil forKey:@"HTMLElement"];
    [_elementControllers release];
    
    [super dealloc];
}

#pragma mark Content

@synthesize content = _content;

- (void)update
{
    [self willUpdate];
    
    // Walk the content array. Shuffle up DOM nodes to match if needed
    DOMHTMLElement *domNode = [[self HTMLElement] firstChildOfClass:[DOMHTMLElement class]];
    
    for (SVBodyElement *aModelElement in [[self content] arrangedObjects])
    {
        // Locate the matching controller
        SVHTMLElementController *controller = [self controllerForBodyElement:aModelElement];
        if (controller)
        {
            // Ensure the node is in the right place. Most of the time it already will be. If it isn't 
            if ([controller HTMLElement] != domNode)
            {
                [[self HTMLElement] insertBefore:[controller HTMLElement] refChild:domNode];
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
            
            [[self HTMLElement] insertBefore:[controller HTMLElement] refChild:domNode];
            
            [self addElementController:controller];
            [controller release];
        }
    }
    
    
    // All the nodes for deletion should have been pushed to the end, so we can delete them
    while (domNode)
    {
        DOMHTMLElement *nextNode = [domNode nextSiblingOfClass:[DOMHTMLElement class]];
        
        [self removeElementController:[self controllerForDOMNode:domNode]];
        [[domNode parentNode] removeChild:domNode];
        
        domNode = nextNode;
    }
    
    [self didUpdate];
}

- (BOOL)insertGraphic:(SVGraphic *)pagelet;
{
    BOOL result = NO;
    
    // First remove any selected text
    WebView *webView = [[[[self HTMLElement] ownerDocument] webFrame] webView];
    [webView delete:self];
    
    
    // Figure out the body element to insert next to
    DOMRange *selection = [webView selectedDOMRange];
    OBASSERT([selection collapsed]);    // calling -delete: should have collapsed it
    
    SVHTMLElementController *controller = [self controllerForDOMNode:[selection startContainer]];
    if (controller)
    {
        SVBodyElement *bodyElement = [controller representedObject];
        NSUInteger index = [[[self content] arrangedObjects] indexOfObject:bodyElement];
        if (index != NSNotFound)
        {
            [[self content] insertObject:pagelet atArrangedObjectIndex:index];
            result = YES;
        }
    }
    
    
    return result;
}

- (BOOL)insertPagelet:(SVPagelet *)pagelet
{
    return [self insertGraphic:pagelet];
}

#pragma mark Editability

- (void)setEditable:(BOOL)editable
{
    // TODO: Embedded graphics must NOT be selectable
    
    [super setEditable:editable];
}

#pragma mark Subcontrollers

- (void)addElementController:(SVHTMLElementController *)controller;
{
    [_elementControllers addObject:controller];
}

- (void)removeElementController:(SVHTMLElementController *)controller;
{
    [controller setRepresentedObject:nil];
    [controller setHTMLElement:nil];
    [controller setHTMLContext:nil];
    
    [_elementControllers removeObject:controller];
}

- (SVHTMLElementController *)makeAndAddControllerForBodyElement:(SVBodyElement *)bodyElement
                                                   HTMLElement:(DOMHTMLElement *)htmlElement;
{
    id result = [[[self controllerClassForBodyElement:bodyElement] alloc] initWithHTMLElement:htmlElement];
    [result setHTMLContext:[self HTMLContext]];
    [result setRepresentedObject:bodyElement];
    [self addElementController:result];
    [result release];
    
    
    return result;
}

- (SVHTMLElementController *)controllerForBodyElement:(SVBodyElement *)element;
{
    SVHTMLElementController * result = nil;
    for (result in _elementControllers)
    {
        if ([result representedObject] == element) break;
    }
    
    return result;
}

- (SVHTMLElementController *)controllerForDOMNode:(DOMNode *)node;
{
    SVHTMLElementController *result = nil;
    for (result in _elementControllers)
    {
        if ([node isDescendantOfNode:[result HTMLElement]]) break;
    }
             
    return result;
}

- (Class)controllerClassForBodyElement:(SVBodyElement *)element;
{
    Class result = ([element isKindOfClass:[SVBodyParagraph class]] ? 
                    [SVBodyParagraphDOMAdapter class] : [SVWebContentItem class]);
    
    return result;
}

- (NSArray *)graphicControllers;
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:[_elementControllers count]];
    
    for (SVHTMLElementController *aController in _elementControllers)
    {
        if ([aController conformsToProtocol:@protocol(SVWebEditorItem)])
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
    [_elementControllers makeObjectsPerformSelector:@selector(enclosingBodyControllerDidChangeText)];
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
    if ([event relatedNode] != [self HTMLElement]) return;
    
    
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
        [paragraph setHTMLStringFromElement:insertedNode];
        
        
        // Create a matching controller
        [self makeAndAddControllerForBodyElement:paragraph HTMLElement:insertedNode];
        [paragraph release];
        
        
        // Insert the paragraph into the model in the same spot as it is in the DOM
        [self willUpdate];
         
        DOMHTMLElement *nextNode = [insertedNode nextSiblingOfClass:[DOMHTMLElement class]];
        if (nextNode)
        {
            SVHTMLElementController * nextController = [self controllerForDOMNode:nextNode];
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
            SVHTMLElementController * controller = [self controllerForDOMNode:removedNode];
            if (controller)
            {
                SVBodyElement *element = [controller representedObject];
                
                [self willUpdate];
                [[self content] removeObject:element];
                [self didUpdate];
                
                [self removeElementController:controller];
            }
        }
    }
}

#pragma mark Undo

- (NSManagedObjectContext *)managedObjectContext; { return [[self content] managedObjectContext]; }

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

