//
//  SVSelectionBorder.h
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>


enum SVSelectionResizeMask
{
    kSVSelectionResizeableLeft      = 1U << 0,
    kSVSelectionResizeableRight     = 1U << 1,
    kSVSelectionResizeableBottom    = 1U << 2,
    kSVSelectionResizeableTop       = 1U << 3,
};


@interface SVSelectionBorder : CALayer
{

}

@end
