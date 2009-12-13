//
//  SVWebEditorMainDOMController.m
//  Sandvox
//
//  Created by Mike on 12/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorMainDOMController.h"


@implementation SVWebEditorMainDOMController

- (DOMHTMLElement *)HTMLElement { return nil; }

@synthesize webEditorViewController = _webEditorController;

- (void)setDescendantNeedsUpdate:(SVDOMController *)controller
{
    // We are the top of the tree and need to hand off responsibility for the update to the Web Editor View Controller
    [[self webEditorViewController] performSelector:@selector(setDOMControllersNeedUpdate)];
}

@end
