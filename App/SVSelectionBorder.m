//
//  SVSelectionBorder.m
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSelectionBorder.h"


@implementation SVSelectionBorder

- (id)init
{
    self = [super init];
    
    [self setNeedsDisplay];
    
    CGColorRef color = CGColorCreateGenericRGB(1.0, 0.0, 0.0, 0.5);
    [self setBackgroundColor:color];
    CGColorRelease(color);
    
    return self;
}

@end
