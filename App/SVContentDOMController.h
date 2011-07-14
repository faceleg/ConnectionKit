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

// Creates a full tree of controllers from the context contents
- (id)initWithWebEditorHTMLContext:(SVWebEditorHTMLContext *)context document:(DOMHTMLDocument *)document;

@property(nonatomic, assign) SVWebEditorViewController *webEditorViewController;

@end
