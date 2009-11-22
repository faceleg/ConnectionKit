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
    return [self initWithHTMLElement:element body:nil];
}

- (id)initWithHTMLElement:(DOMHTMLElement *)element body:(SVPageletBody *)pageletBody;
{
    OBASSERT(pageletBody);
    
    
    self = [super initWithHTMLElement:element];
    
    
    _pageletBody = [pageletBody retain];
    
    
    // Match each model element up with its DOM equivalent
    _elementControllers = [[NSMutableArray alloc] initWithCapacity:[[pageletBody elements] count]];
    DOMDocument *document = [element ownerDocument]; 
    
    for (SVBodyElement *aModelElement in [pageletBody elements])
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
            SVWebContentItem *controller = [[SVWebContentItem alloc] initWithDOMElement:htmlElement];
            [controller setRepresentedObject:aModelElement];
            [self addElementController:controller];
            [controller release];
        }
        
        [htmlElement setIdName:nil]; // don't want it cluttering up the DOM any more
    }
    
    
    // Observe DOM changes. Each SVBodyParagraphDOMAdapter will take care of its own section of the DOM
    [[self HTMLElement] addEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self HTMLElement] addEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    
    // Observe model changes
    [[self body] addObserver:self
                  forKeyPath:@"elements"
                     options:(NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld)
                     context:sBodyElementsObservationContext];
    
    
    // Finish up
    return self;
}

- (void)dealloc
{
    // Stop observation
    [[self HTMLElement] removeEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self HTMLElement] removeEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    
    
    [_pageletBody release];
    
    [_elementControllers makeObjectsPerformSelector:@selector(stop)];
    [_elementControllers release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize body = _pageletBody;

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
        DOMHTMLElement *insertedNode = (DOMHTMLElement *)[event target];
        
        if (![self controllerForHTMLElement:insertedNode])   // for some reason, get told a node is inserted twice
        {
            // Create paragraph
            [self willUpdate];
            
            SVBodyParagraph *paragraph = [NSEntityDescription insertNewObjectForEntityForName:@"BodyParagraph" inManagedObjectContext:[[self body] managedObjectContext]];
            
            [paragraph setHTMLStringFromElement:insertedNode];
            [[self body] addElement:paragraph];
            
            
            // Figure out where it should be placed
            DOMHTMLElement *previousElement = [insertedNode previousSiblingOfClass:[DOMHTMLElement class]];
            if (previousElement)
            {
                id <SVElementController> controller = [self controllerForHTMLElement:previousElement];
                OBASSERT(controller);
                [paragraph insertAfterElement:[controller bodyElement]];
            }
            else
            {
                DOMHTMLElement *nextElement = [insertedNode nextSiblingOfClass:[DOMHTMLElement class]];
                if (nextElement)
                {
                    id <SVElementController> controller = [self controllerForHTMLElement:nextElement];
                    OBASSERT(controller);
                    [paragraph insertBeforeElement:[controller bodyElement]];
                }
            }                
            
            [self didUpdate];
            
            
            // Create a controller
            SVBodyParagraphDOMAdapter *controller = [[SVBodyParagraphDOMAdapter alloc] initWithHTMLElement:insertedNode
                                                                                         paragraph:paragraph];
            [self addElementController:controller];
            [controller release];
        }
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
                [self willUpdate];
                
                SVBodyElement *element = [controller bodyElement];
                [element removeFromElementsList];
                [element setBody:nil];
                [[element managedObjectContext] deleteObject:element];
                
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
            // For each element removed from the model, reflect it by removing the matching element in the DOM
            NSSet *removedElements = [change KVOChange_removedObjects];
            for (SVBodyElement *aRemovedElement in removedElements)
            {
                id <SVElementController> controller = [self controllerForBodyElement:aRemovedElement];
                OBASSERT(controller);
                
                DOMHTMLElement *htmlElement = [controller HTMLElement];
                [self willUpdate];
                [[htmlElement parentNode] removeChild:htmlElement];
                [self didUpdate];
                
                [self removeElementController:controller];
            }
        }
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

@end


#pragma mark -


@implementation SVWebContentItem (SVElementController)

- (DOMHTMLElement *)HTMLElement;
{
    DOMHTMLElement *result = (id)[self DOMElement];
    if (![result isKindOfClass:[DOMHTMLElement class]]) result = nil;
        
    return result;
}

- (SVBodyElement *)bodyElement
{
    SVBodyElement *result = [self representedObject];
    if (![result isKindOfClass:[SVBodyElement class]]) result = nil;
    return result;
}

@end

