//
//  SVSelectionHandleLayer.m
//  Sandvox
//
//  Created by Mike on 07/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSelectionHandleLayer.h"


@implementation SVSelectionHandleLayer

- (id)init
{
    self = [super init];
    
    [self setValue:[NSValue valueWithSize:NSMakeSize(7.0, 7.0)]
          forKeyPath:@"bounds.size"];
    
    [self setBackgroundColor:CGColorGetConstantColor(kCGColorWhite)];
    [self setBorderColor:CGColorGetConstantColor(kCGColorBlack)];
    [self setBorderWidth:1.0];
    
    return self;
}

- (void)dealloc
{
    [_trackingArea release];
    
    [super dealloc];
}

@synthesize trackingArea = _trackingArea;

- (void)updateTrackingAreasInView:(NSView *)view;
{
    // If our tracking area is no longer in the right place, replace it
    NSTrackingArea *trackingArea = [self trackingArea];
    
    NSRect trackingRect = NSRectFromCGRect([self convertRect:[self bounds]
                                                     toLayer:[view layer]]);
    
    if (trackingArea && !NSEqualRects(trackingRect, [trackingArea rect]))
    {
        [view removeTrackingArea:trackingArea];
        
        trackingArea = [[NSTrackingArea alloc] initWithRect:trackingRect
                                                    options:[trackingArea options]
                                                      owner:view
                                                   userInfo:nil];
        
        [view addTrackingArea:trackingArea];
        [self setTrackingArea:trackingArea];
        [trackingArea release];
    }
    else if (!trackingArea)
    {
        NSTrackingAreaOptions options = (NSTrackingCursorUpdate | NSTrackingActiveInKeyWindow);
        trackingArea = [[NSTrackingArea alloc] initWithRect:trackingRect
                                                    options:options
                                                      owner:view
                                                   userInfo:nil];
        
        [view addTrackingArea:trackingArea];
        [self setTrackingArea:trackingArea];
        [trackingArea release];
    }
}

- (void)removeFromSuperlayer
{
    // This makes the tracking area invalid, so remove it
    NSTrackingArea *trackingArea = [self trackingArea];
    [(NSView *)[trackingArea owner] removeTrackingArea:trackingArea];
    [self setTrackingArea:nil];
}

@end
