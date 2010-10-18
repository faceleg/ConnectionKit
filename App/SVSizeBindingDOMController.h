//
//  SVSizeBindingDOMController.h
//  Sandvox
//
//  Created by Mike on 12/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@interface SVSizeBindingDOMController : SVDOMController
{
  @private
    NSSize  _delta;
}

@property(nonatomic) NSSize sizeDelta;

@end
