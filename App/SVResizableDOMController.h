//
//  SVResizableDOMController.h
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


#define MIN_GRAPHIC_LIVE_RESIZE 16.0f


@interface SVResizableDOMController : SVDOMController
{
  @private
    BOOL    _horizontallyResizable;
    BOOL    _verticallyResizable;
    
    NSSize              _delta;
}

@property(nonatomic, getter=isHorizontallyResizable) BOOL horizontallyResizable;
@property(nonatomic, getter=isVerticallyResizable) BOOL verticallyResizable;
@property(nonatomic) NSSize sizeDelta;

@end
