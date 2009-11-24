//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyTextArea.h"
#import "SVBodyParagraphDOMAdapter.h"

#import "SVBodyParagraph.h"
#import "SVContentObject.h"
#import "SVPageletBody.h"
#import "SVWebContentItem.h"

#import "NSDictionary+Karelia.h"
#import "DOMNode+Karelia.h"


static NSString *sBodyElementsObservationContext = @"SVBodyTextAreaElementsObservationContext";


@implementation SVBodyTextArea

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
        DOMHTMLElement *htmlElement = (id)[document getElementById:[aModelElement editingElementID]];
        OBASSERT([htmlElement isKindOfClass:[DOMHTMLElement class]]);
        
        if ([aModelElement isKindOfClass:[SVBodyParagraph class]])
        {
            SVBodyParagraphDOMAdapter *controller = [[SVBodyParagraphDOMAdapter alloc]
                                                 initWithHTMLElement:htmlElement
                                                 paragraph:(SVBodyParagraph *)aModelElement];
            
            [self addElementController:controller];
            [controller release];
        }
        else
        {
            SVWebContentItem *controller = [[SVWebContentItem alloc] initWithHTMLElement:htmlElement];
            [controller setRepresentedObject:aModelElement];
            [self addElementController:controller];
            [controller release];
        }
        
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
    
    [_elementControllers makeObjectsPerformSelector:@selector(stop)];
    [_elementControllers release];
    
    [super dealloc];
}

#pragma mark Content

@synthesize content = _content;

- (void)contentElementsDidChange
{
    [self willUpdate];
    
    // Walk the content array. Shuffle up DOM nodes to match if needed
    DOMHTMLElement *domNode = [[self HTMLElement] firstChildOfClass:[DOMHTMLElement class]];
    
    for (SVBodyElement *aModelElement in [[self content] arrangedObjects])
    {
        // Locate the matching controller
        id <SVElementController> controller = [self controllerForBodyElement:aModelElement];
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
            
            id <SVElementController> controller = [[controllerClass alloc]
                                                   initWithBodyElement:aModelElement
                                                   DOMDocument:[[self HTMLElement] ownerDocument]];
            
            [[self HTMLElement] insertBefore:[controller HTMLElement] refChild:domNode];
            
            [self addElementController:controller];
            [controller release];
        }
    }
    
    
    // All the nodes for deletion should have been pushed to the end, so we can delete them
    while (domNode)
    {
        DOMHTMLElement *nextNode = [domNode nextSiblingOfClass:[DOMHTMLElement class]];
        
        [self removeElementController:[self controllerForHTMLElement:domNode]];
        [[domNode parentNode] removeChild:domNode];
        
        domNode = nextNode;
    }
    
    [self didUpdate];
}

#pragma mark Subcontrollers

- (void)addElementController:(id <SVElementController>)controller;
{
    [_elementControllers addObject:controller];
}

- (void)removeElementController:(id <SVElementController>)controller;
{
    if ([controller isKindOfClass:[SVBodyParagraphDOMAdapter class]])
    {
        [(SVBodyParagraphDOMAdapter *)controller stop];
    }
    
    [_elementControllers removeObject:controller];
}

- (id <SVElementController>)makeAndAddControllerForBodyElement:(SVBodyElement *)bodyElement
                                                   HTMLElement:(DOMHTMLElement *)htmlElement;
{
    id result;
    
    if ([bodyElement isKindOfClass:[SVBodyParagraph class]])
    {
        result = [[SVBodyParagraphDOMAdapter alloc] initWithHTMLElement:htmlElement
                                                              paragraph:(SVBodyParagraph *)bodyElement];
        
        [self addElementController:result];
        [result release];
    }
    else
    {
        result = [[SVWebContentItem alloc] initWithHTMLElement:htmlElement];
        [result setRepresentedObject:bodyElement];
        [self addElementController:result];
        [result release];
    }
    
    
    return result;
}

- (id <SVElementController>)controllerForBodyElement:(SVBodyElement *)element;
{
    id <SVElementController> result = nil;
    for (result in _elementControllers)
    {
        if ([result bodyElement] == element) break;
    }
    
    return result;
}

- (id <SVElementController>)controllerForHTMLElement:(DOMHTMLElement *)element;
{
    id <SVElementController> result = nil;
    for (result in _elementControllers)
    {
        if ([result HTMLElement] == element) break;
    }
             
    return result;
}

- (Class <SVElementController>)controllerClassForBodyElement:(SVBodyElement *)element;
{
    Class result = ([element isKindOfClass:[SVBodyParagraph class]] ? 
                    [SVBodyParagraphDOMAdapter class] : [SVWebContentItem class]);
    
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
            id <SVElementController> nextController = [self controllerForHTMLElement:nextNode];
            OBASSERT(nextController);
            
            NSArrayController *content = [self content];
            NSUInteger index = [[content arrangedObjects] indexOfObject:[nextController bodyElement]];
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
            id <SVElementController> controller = [self controllerForHTMLElement:removedNode];
            if (controller)
            {
                SVBodyElement *element = [controller bodyElement];
                
                [self willUpdate];
                [[self content] removeObject:element];
                [self didUpdate];
                
                [self removeElementController:controller];
            }
        }
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sBodyElementsObservationContext)
    {
        if (![self isUpdating])
        {
            [self contentElementsDidChange];
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVHTMLElementController (SVElementController)

- (id)initWithBodyElement:(SVPlugInContentObject *)element DOMDocument:(DOMDocument *)document;
{
    // Create DOM node
    DOMHTMLElement *domElement = (DOMHTMLElement *)[document createElement:@"div"];
    
    self = [self initWithHTMLElement:domElement];
    [self setRepresentedObject:element];
    return self;
}

- (SVBodyElement *)bodyElement
{
    SVBodyElement *result = [self representedObject];
    if (![result isKindOfClass:[SVBodyElement class]]) result = nil;
    return result;
}

- (void)stop
{    
}

@end

