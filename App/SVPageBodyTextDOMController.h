//
//  SVPageBodyTextDOMController.h
//  Sandvox
//
//  Created by Mike on 28/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVRichTextDOMController.h"

#import "SVPageBody.h"


@interface SVPageBodyTextDOMController : SVRichTextDOMController
{
  @private
    DOMElement  *_dragCaret;
}

- (IBAction)insertPagelet:(id)sender;


#pragma mark Drag Caret
- (void)removeDragCaret;
- (void)moveDragCaretToBeforeDOMNode:(DOMNode *)node draggingInfo:(id <NSDraggingInfo>)dragInfo;


@end
