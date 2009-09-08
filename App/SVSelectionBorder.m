//
//  SVSelectionBorder.m
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSelectionBorder.h"
#import "SVSelectionHandleLayer.h"

#import "NSColor+Karelia.h"


@interface SVSelectionBorder ()
//@property(nonatomic, readonly) CALayer *layer;
@end


#pragma mark -


@implementation SVSelectionBorder

- (CALayer *)newSelectionHandle
{
    CALayer *result = [[SVSelectionHandleLayer alloc] init];
    [self addSublayer:result];
    
    return result;
}

- (id)init
{
    self = [super init];
    
    [self setLayoutManager:[CAConstraintLayoutManager layoutManager]];
    
    // Add selection handles
    CAConstraint *minXConstraint = [CAConstraint constraintWithAttribute:kCAConstraintMidX 
                                                              relativeTo:@"superlayer"
                                                               attribute:kCAConstraintMinX];
    
    CAConstraint *midXConstraint = [CAConstraint constraintWithAttribute:kCAConstraintMidX 
                                                              relativeTo:@"superlayer"
                                                               attribute:kCAConstraintMidX];
    
    CAConstraint *maxXConstraint = [CAConstraint constraintWithAttribute:kCAConstraintMidX 
                                                              relativeTo:@"superlayer"
                                                               attribute:kCAConstraintMaxX
                                                                  offset:-1.0];
    
    CAConstraint *minYConstraint = [CAConstraint constraintWithAttribute:kCAConstraintMidY 
                                                              relativeTo:@"superlayer"
                                                               attribute:kCAConstraintMinY];
    
    CAConstraint *midYConstraint = [CAConstraint constraintWithAttribute:kCAConstraintMidY 
                                                              relativeTo:@"superlayer"
                                                               attribute:kCAConstraintMidY];
    
    CAConstraint *maxYConstraint = [CAConstraint constraintWithAttribute:kCAConstraintMidY 
                                                              relativeTo:@"superlayer"
                                                               attribute:kCAConstraintMaxY
                                                                  offset:-1.0];
    
    
    _bottomLeftSelectionHandle = [self newSelectionHandle];
    [_bottomLeftSelectionHandle addConstraint:minXConstraint];
    [_bottomLeftSelectionHandle addConstraint:minYConstraint];
    
    _leftSelectionHandle = [self newSelectionHandle];
    [_leftSelectionHandle addConstraint:minXConstraint];
    [_leftSelectionHandle addConstraint:midYConstraint];
    
    _topLeftSelectionHandle = [self newSelectionHandle];
    [_topLeftSelectionHandle addConstraint:minXConstraint];
    [_topLeftSelectionHandle addConstraint:maxYConstraint];

    _bottomRightSelectionHandle = [self newSelectionHandle];
    [_bottomRightSelectionHandle addConstraint:maxXConstraint];
    [_bottomRightSelectionHandle addConstraint:minYConstraint];

    _rightSelectionHandle = [self newSelectionHandle];
    [_rightSelectionHandle addConstraint:maxXConstraint];
    [_rightSelectionHandle addConstraint:midYConstraint];

    _topRightSelectionHandle = [self newSelectionHandle];
    [_topRightSelectionHandle addConstraint:maxXConstraint];
    [_topRightSelectionHandle addConstraint:maxYConstraint];

    _bottomSelectionHandle = [self newSelectionHandle];
    [_bottomSelectionHandle addConstraint:midXConstraint];
    [_bottomSelectionHandle addConstraint:minYConstraint];

    _topSelectionHandle = [self newSelectionHandle];
    [_topSelectionHandle addConstraint:midXConstraint];
    [_topSelectionHandle addConstraint:maxYConstraint];

    
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

- (CALayer *)hitTest:(CGPoint)thePoint
{
    CALayer *result = nil;
    
    // The default implementation assumes all sublayers are within our bounds. We know that all selection handles are at least partially outside.
    CGPoint localPoint = [self convertPoint:thePoint fromLayer:[self superlayer]];
    for (CALayer *aSublayer in [self sublayers])
    {
        result = [aSublayer hitTest:localPoint];
        if (result) break;
    }
    
    if (!result)
    {
        if ([self containsPoint:localPoint]) result = self;
    }
    
    return result;
}

@end


#pragma mark -


@implementation CALayer (SVTrackingAreas)

- (NSCursor *)webEditingOverlayCursor;
{
    return nil;
}

- (void)updateTrackingAreasInView:(NSView *)view
{
    [[self sublayers] makeObjectsPerformSelector:@selector(updateTrackingAreasInView:)
                                      withObject:view];
}

@end


