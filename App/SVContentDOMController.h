//
//  SVContentDOMController.h
//  Sandvox
//
//  Created by Mike on 30/07/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@interface SVContentDOMController : SVDOMController
{
  @private
    SVWebEditorViewController   *_viewController; // weak ref
}

@property(nonatomic, assign) SVWebEditorViewController *webEditorViewController;

@end
