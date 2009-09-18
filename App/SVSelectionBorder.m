//
//  SVSelectionBorder.m
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSelectionBorder.h"


@interface SVSelectionBorder ()
- (void)drawSelectionHandleAtPoint:(NSPoint)point inView:(NSView *)view;
@end


#pragma mark -


@implementation SVSelectionBorder

@synthesize editing = _isEditing;

- (void)dealloc
{
    
    [super dealloc];
}


- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;
{
    // First draw overall frame
    [[NSColor grayColor] setFill];
    NSFrameRectWithWidthUsingOperation([view centerScanRect:NSInsetRect(frameRect, -1.0, -1.0)],
                                       1.0,
                                       NSCompositeSourceOver);
    
    // Then draw handles
    if (![self isEditing])
    {
        CGFloat minX = NSMinX(frameRect);
        CGFloat midX = NSMidX(frameRect);
        CGFloat maxX = NSMaxX(frameRect) - 1.0;
        CGFloat minY = NSMinY(frameRect);
        CGFloat midY = NSMidY(frameRect);
        CGFloat maxY = NSMaxY(frameRect) - 1.0;
        
        [self drawSelectionHandleAtPoint:NSMakePoint(minX, minY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(minX, maxY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(minX, midY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(maxX, minY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(maxX, maxY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(maxX, midY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(midX, minY) inView:view];
        [self drawSelectionHandleAtPoint:NSMakePoint(midX, maxY) inView:view];
    }
}

- (void)drawSelectionHandleAtPoint:(NSPoint)point inView:(NSView *)view
{
    NSRect rect = [view centerScanRect:NSMakeRect(point.x - 3.0,
                                                  point.y - 3.0,
                                                  7.0,
                                                  7.0)];
    
    [[NSColor blackColor] setFill];
    NSEraseRect(rect);
    NSFrameRect(rect);
}

/*  Enlarge by 3 pixels to accomodate selection handles
 */
- (NSRect)drawingRectForFrame:(NSRect)frameRect;
{
    NSRect result = NSInsetRect(frameRect, -3.0, -3.0);
    return result;
}

/*  Mostly a simple question of if frame contains point, but also return yes if the point is in one of our selection handles
 */
- (BOOL)mouse:(NSPoint)mousePoint isInFrame:(NSRect)frameRect inView:(NSView *)view
{
    BOOL result = [view mouse:mousePoint inRect:frameRect];
    return result;
}

@end