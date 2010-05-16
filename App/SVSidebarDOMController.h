//
//  SVSidebarDOMController.h
//  Sandvox
//
//  Created by Mike on 07/05/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVDOMController.h"

#import "SVSidebarPageletsController.h"


@interface SVSidebarDOMController : SVDOMController
{
  @private
    DOMElement                  *_sidebarDiv;
    SVSidebarPageletsController *_pageletsController;
    
    // Drag & Drop
    DOMElement          *_dragCaret;
}

- (id)initWithPageletsController:(SVSidebarPageletsController *)pageletsController;

@property(nonatomic, retain) DOMElement *sidebarDivElement;

@property(nonatomic, retain, readonly) SVSidebarPageletsController *pageletsController;


#pragma mark Drop
- (NSUInteger)indexOfDrop:(id <NSDraggingInfo>)dragInfo;

- (void)removeDragCaret;
- (void)moveDragCaretToAfterDOMNode:(DOMNode *)node;


@end