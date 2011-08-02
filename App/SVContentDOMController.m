//
//  SVContentDOMController.m
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVContentDOMController.h"

#import "SVPlugInDOMController.h"
#import "SVWebEditorHTMLContext.h"


@interface SVElementInfo (SVContentDOMController)
- (SVDOMController *)newDOMControllerWithNode:(DOMNode *)node;
@end


@implementation SVContentDOMController

- (void)populateDOMController:(SVDOMController *)controller
                  fromElement:(SVElementInfo *)element
                      context:(SVWebEditorHTMLContext *)context
                         node:(DOMNode *)node;
{
    SVDOMController *aController = [element newDOMControllerWithNode:node];
    if (aController)
    {
        [aController setShouldIncludeElementIdNameWhenPublishing:![element elementIdNameWasInvented]];
        
        [controller addChildWebEditorItem:aController];
        controller = aController;
        [aController release];
    }
    
    
    // Copy across dependencies
    for (KSObjectKeyPathPair *aDependency in [element dependencies])
    {
        [controller addDependency:aDependency];
    }
    
    
    // Step on down to child elements
    for (SVElementInfo *anElement in [element subelements])
    {
        [self populateDOMController:controller fromElement:anElement context:context node:node];
    }
    
    
    // Once all descendants are in place, time to awake
    [aController awakeFromHTMLContext:context];
}

- (id)initWithWebEditorHTMLContext:(SVWebEditorHTMLContext *)context node:(DOMNode *)node;
{
    OBPRECONDITION(context);
    OBPRECONDITION(node);
    
    self = [self init];
    
    [self populateDOMController:self fromElement:[context rootElement] context:context node:node];
    
    return self;
}

@synthesize webEditorViewController = _viewController;

- (void)setNeedsUpdate;
{
    [[self webEditorViewController] setNeedsUpdate];
}

// Never want to be hooked up
- (DOMHTMLElement *)HTMLElement { return nil; }
- (NSString *)elementIdName; { return nil; }

@end


#pragma mark -


@implementation SVElementInfo (SVContentDOMController)

- (SVDOMController *)newDOMControllerWithNode:(DOMNode *)node;
{
    id <SVComponent> container = [self graphicContainer];
    if (container)
    {
        NSString *elementID = [[self attributesAsDictionary] objectForKey:@"id"];
        if (elementID)
        {
            if ([self isHorizontallyResizable] || [self isVerticallyResizable])
            {
                SVPlugInDOMController *result = [[SVPlugInDOMController alloc] initWithElementIdName:elementID ancestorNode:node];
                [result setRepresentedObject:container];
                
                [result setHorizontallyResizable:[self isHorizontallyResizable]];
                [result setVerticallyResizable:[self isVerticallyResizable]];
                [result bind:NSWidthBinding toObject:container withKeyPath:@"width" options:nil];
                [result bind:@"height" toObject:container withKeyPath:@"height" options:nil];
                
                return result;
            }
            else
            {
                SVDOMController *result = [container newDOMControllerWithElementIdName:elementID node:node];
                [result setSelectable:[container conformsToProtocol:@protocol(SVGraphic)]];
                return result;
            }
        }
    }
    
    return nil;
}

@end
