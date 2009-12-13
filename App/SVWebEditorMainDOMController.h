//
//  SVWebEditorMainDOMController.h
//  Sandvox
//
//  Created by Mike on 12/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSDOMController.h"


@class SVWebEditorViewController;


@interface SVWebEditorMainDOMController : KSDOMController
{
  @private
    SVWebEditorViewController   *_webEditorController;
}

@property(nonatomic, assign) SVWebEditorViewController *webEditorViewController;

@end
