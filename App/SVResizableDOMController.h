//
//  SVResizableDOMController.h
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@interface SVResizableDOMController : SVDOMController
{
  @private
    NSSize              _delta;
    SVResizingOptions   _resizeOptions;
}

@property(nonatomic) NSSize sizeDelta;
@property(nonatomic) SVResizingOptions resizeOptions;

@end
