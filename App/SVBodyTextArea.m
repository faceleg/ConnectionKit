//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyTextArea.h"
#import "SVParagraphController.h"

#import "SVBodyParagraph.h"
#import "SVContentObject.h"
#import "SVPageletBody.h"
#import "SVWebContentItem.h"

#import "DOMNode+Karelia.h"


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
    
    
    // Match paragraphs up to the model
    _elementControllers = [[NSMutableArray alloc] initWithCapacity:[[pageletBody elements] count]];
    DOMNode *aDOMNode = [[self HTMLElement] firstChild];
    SVBodyElement *aModelElement = [pageletBody firstElement];
    
    while (aModelElement)
    {
        if ([aDOMNode isKindOfClass:[DOMHTMLElement class]])
        {
            DOMHTMLElement *htmlElement = (DOMHTMLElement *)aDOMNode;
            if ([[htmlElement idName] isEqualToString:[aModelElement editingElementID]])
            {
                if ([aModelElement isKindOfClass:[SVBodyParagraph class]])
                {
                    SVParagraphController *controller = [[SVParagraphController alloc]
                                                         initWithHTMLElement:htmlElement
                                                         paragraph:(SVBodyParagraph *)aModelElement];
                    
                    [_elementControllers addObject:controller];
                    [controller release];
                }
                else
                {
                    SVWebContentItem *controller = [[SVWebContentItem alloc] initWithDOMElement:htmlElement];
                    [controller setRepresentedObject:aModelElement];
                    [_elementControllers addObject:controller];
                    [controller release];
                }
                
                aModelElement = [aModelElement nextElement];
            }
        }
        
        aDOMNode = [aDOMNode nextSibling];
    }
    
    
    // Observe elements being added or removed
    [[self HTMLElement] addEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self HTMLElement] addEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    
    
    return self;
}

- (void)dealloc
{
    // Stop observation
    [[self HTMLElement] removeEventListener:@"DOMNodeInserted" listener:self useCapture:NO];
    [[self HTMLElement] removeEventListener:@"DOMNodeRemoved" listener:self useCapture:NO];
    
    
    
    [_pageletBody release];
    [_elementControllers release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize body = _pageletBody;

- (id <SVElementController>)controllerForHTMLElement:(DOMHTMLElement *)element;
{
    id <SVElementController> result = nil;
    for (result in _elementControllers)
    {
        if ([result HTMLElement] == element) break;
    }
             
    return result;
}

#pragma mark Editing

- (void)handleEvent:(DOMMutationEvent *)event
{
    // We're only interested in nodes being added or removed from our own node
    if ([event relatedNode] != [self HTMLElement]) return;
    
    
    // Add or remove controllers for the new element
    if ([[event type] isEqualToString:@"DOMNodeInserted"])
    {
        DOMHTMLElement *insertedNode = (DOMHTMLElement *)[event target];
        
        if (![self controllerForHTMLElement:insertedNode])   // for some reason, get told a node is inserted twice
        {
            // Create paragraph
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
            
            
            // Create a controller
            SVParagraphController *controller = [[SVParagraphController alloc] initWithHTMLElement:insertedNode
                                                                                         paragraph:paragraph];
            [_elementControllers insertObject:controller atIndex:0];
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
                SVBodyElement *element = [controller bodyElement];
                [element removeFromElementsList];
                [element setBody:nil];
                [[element managedObjectContext] deleteObject:element];
                
                [_elementControllers removeObject:controller];
            }
        }
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
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

