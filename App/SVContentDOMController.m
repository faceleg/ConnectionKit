//
//  SVContentDOMController.m
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVContentDOMController.h"

#import "SVResizableDOMController.h"
#import "SVWebEditorHTMLContext.h"


@interface SVElementInfo (SVContentDOMController)
- (SVDOMController *)newDOMControllerWithDocument:(DOMHTMLDocument *)document;
@end


@implementation SVContentDOMController

- (void)populateDOMController:(SVDOMController *)controller
                  fromElement:(SVElementInfo *)element
                      context:(SVWebEditorHTMLContext *)context
                     document:(DOMHTMLDocument *)document;
{
    SVDOMController *aController = [element newDOMControllerWithDocument:document];
    if (aController)
    {
        [aController setShouldIncludeElementIdNameWhenPublishing:![element elementIdNameWasInvented]];
        [aController awakeFromHTMLContext:context];
        
        [controller addChildWebEditorItem:aController];
        controller = aController;
        [aController release];
    }
    
    
    // Step on down to child elements
    for (SVElementInfo *anElement in [element subelements])
    {
        [self populateDOMController:controller fromElement:anElement context:context document:document];
    }
}

- (id)initWithWebEditorHTMLContext:(SVWebEditorHTMLContext *)context document:(DOMHTMLDocument *)document;
{
    OBPRECONDITION(context);
    OBPRECONDITION(document);
    
    self = [self init];
    
    [self populateDOMController:self fromElement:[context rootElement] context:context document:document];
    
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

- (SVDOMController *)newDOMControllerWithDocument:(DOMHTMLDocument *)document;
{
    id <SVGraphicContainer> container = [self graphicContainer];
    if (container)
    {
        NSString *elementID = [[self attributes] objectForKey:@"id"];
        if (elementID)
        {
            if ([self isHorizontallyResizable] || [self isVerticallyResizable])
            {
                SVResizableDOMController *result = [[SVResizableDOMController alloc] initWithElementIdName:elementID document:document];
                [result setRepresentedObject:container];
                
                [result setHorizontallyResizable:[self isHorizontallyResizable]];
                [result setVerticallyResizable:[self isVerticallyResizable]];
                [result bind:NSWidthBinding toObject:container withKeyPath:@"width" options:nil];
                [result bind:@"height" toObject:container withKeyPath:@"height" options:nil];
                
                return result;
            }
            else
            {
                return [container newDOMControllerWithElementIdName:elementID document:document];
            }
        }
    }
    
    return nil;
}

@end
