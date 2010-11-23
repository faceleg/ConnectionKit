//
//  SVGraphicContainerDOMController.h
//  Sandvox
//
//  Created by Mike on 23/11/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVGraphicDOMController.h"


@protocol SVGraphicContainerDOMController <NSObject>

- (void)moveGraphicWithDOMController:(SVGraphicDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;

@end


@interface SVGraphicDOMController (SVGraphicContainerDOMController)
- (id <SVGraphicContainerDOMController>)graphicContainerDOMController;
@end