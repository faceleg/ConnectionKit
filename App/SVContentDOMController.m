//
//  SVContentDOMController.m
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVContentDOMController.h"

#import "SVWebEditorHTMLContext.h"


@implementation SVContentDOMController

- (void)populateDOMController:(SVDOMController *)controller
                  fromElement:(SVElementInfo *)element
                      context:(SVWebEditorHTMLContext *)context;
{
    id <SVGraphicContainer> container = [element graphicContainer];
    if (container)
    {
        NSString *elementID = [[element attributes] objectForKey:@"id"];
        if (elementID)
        {
            SVDOMController *aController = [container newDOMControllerWithElementIdName:elementID];
            [aController awakeFromHTMLContext:context];
            
            [controller addChildWebEditorItem:aController];
            controller = aController;
            [aController release];
        }
    }
    
    // Step on down to child elements
    for (SVElementInfo *anElement in [element subelements])
    {
        [self populateDOMController:controller fromElement:anElement context:context];
    }
}

- (id)initWithWebEditorHTMLContext:(SVWebEditorHTMLContext *)context;
{
    self = [self init];
    
    [self populateDOMController:self fromElement:[context rootElement] context:context];
    
    return self;
}

@synthesize webEditorViewController = _viewController;

- (void)setNeedsUpdate;
{
    [[self webEditorViewController] setNeedsUpdate];
}

// Never want to be hooked up
- (NSString *) elementIdName; { return nil; }

@end
