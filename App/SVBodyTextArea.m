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
    _elementControllers = [[NSMutableArray alloc] initWithCapacity:[bodyElements count]];
    
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
    // For each element removed from the model, reflect it by removing the matching element in the DOM
    NSSet *removedElements = nil;
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
    
    
    // For each element added to the model, reflect it by creating matching nodes and inserting into the DOM
    NSSet *addedElements = nil;
    for (SVBodyElement *anAddedElement in addedElements)
    {
        // Create DOM Node
        DOMDocument *document = [[self HTMLElement] ownerDocument];
        DOMHTMLElement *htmlElement = (id)[document createElement:[(id)anAddedElement tagName]];
        [htmlElement setInnerHTML:[(SVBodyParagraph *)anAddedElement innerHTMLString]];
        
        [self willUpdate];
        [[self HTMLElement] appendChild:htmlElement];
        [self didUpdate];
        
        
        [self makeAndAddControllerForBodyElement:anAddedElement HTMLElement:htmlElement];
    }
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
        result = [[SVWebContentItem alloc] initWithDOMElement:htmlElement];
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
        SVBodyParagraphDOMAdapter *controller = [[SVBodyParagraphDOMAdapter alloc]
                                                 initWithHTMLElement:insertedNode
                                                 paragraph:paragraph];
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
        
        
        // Insert the controller into our array
        [self addElementController:controller];
        [controller release];
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

