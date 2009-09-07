//
//  SVSelectionBorder.m
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSelectionBorder.h"

#import "NSColor+Karelia.h"


@interface SVSelectionBorder ()
//@property(nonatomic, readonly) CALayer *layer;
@end


#pragma mark -


@implementation SVSelectionBorder

- (CALayer *)newSelectionHandle
{
    CALayer *result = [[CALayer alloc] init];
    
    [result setValue:[NSValue valueWithSize:NSMakeSize(6.0, 6.0)]
          forKeyPath:@"bounds.size"];
    
    [result setBackgroundColor:CGColorGetConstantColor(kCGColorWhite)];
    [result setBorderColor:CGColorGetConstantColor(kCGColorBlack)];
    [result setBorderWidth:1.0];
    
    [self addSublayer:result];
    
    return result;
}

- (id)init
{
    self = [super init];
    
    // Add selection handles
    _bottomLeftSelectionHandle = [self newSelectionHandle];
    [_bottomSelectionHandle setAutoresizingMask:(kCALayerMaxXMargin | kCALayerMaxYMargin)];
    
    _leftSelectionHandle = [self newSelectionHandle];
    [_leftSelectionHandle setAutoresizingMask:(kCALayerMaxXMargin |
                                               kCALayerMinYMargin |
                                               kCALayerMaxYMargin)];
    
    _topLeftSelectionHandle = [self newSelectionHandle];
    [_topLeftSelectionHandle setAutoresizingMask:(kCALayerMaxXMargin | kCALayerMinYMargin)];
    
    _bottomRightSelectionHandle = [self newSelectionHandle];
    [_bottomRightSelectionHandle setAutoresizingMask:(kCALayerMinXMargin | kCALayerMaxYMargin)];
    
    _rightSelectionHandle = [self newSelectionHandle];
    [_rightSelectionHandle setAutoresizingMask:(kCALayerMinXMargin |
                                                kCALayerMinYMargin |
                                                kCALayerMaxYMargin)];
    
    _topRightSelectionHandle = [self newSelectionHandle];
    [_topRightSelectionHandle setAutoresizingMask:(kCALayerMinXMargin | kCALayerMinYMargin)];
    
    _bottomSelectionHandle = [self newSelectionHandle];
    [_bottomSelectionHandle setAutoresizingMask:(kCALayerMaxYMargin |
                                                 kCALayerMinXMargin |
                                                 kCALayerMaxXMargin)];
    
    _topSelectionHandle = [self newSelectionHandle];
    [_topSelectionHandle setAutoresizingMask:(kCALayerMinYMargin |
                                              kCALayerMinXMargin |
                                              kCALayerMaxXMargin)];
    
    
    // Add our border
    [self setBorderColor:[[NSColor selectedControlColor] CGColor]];
    [self setBorderWidth:1.0];
    
    return self;
}

- (void)dealloc
{
    [_bottomLeftSelectionHandle release];
    [_leftSelectionHandle release];
    [_topLeftSelectionHandle release];
    [_bottomRightSelectionHandle release];
    [_rightSelectionHandle release];
    [_topRightSelectionHandle release];
    [_bottomSelectionHandle release];
    [_topSelectionHandle release];
     
    [super dealloc];
}


@end
