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
- (void)drawSelectionHandleAtPoint:(NSPoint)point inView:(NSView *)view enabled:(BOOL)enabled;
@end


#pragma mark -


@implementation SVSelectionBorder

#pragma mark Init

- (id)init
{
    self = [super init];
    _resizingMask = /*kCALayerLeftEdge | */kCALayerRightEdge | kCALayerBottomEdge/* | kCALayerTopEdge*/;
    return self;
}

#pragma mark Properties

@synthesize editing = _isEditing;
@synthesize minSize = _minSize;
@synthesize resizingMask = _resizingMask;

#pragma mark Layout

- (NSRect)frameRectForGraphicBounds:(NSRect)frameRect;
{
    // Make sure the frame meets the requirements of -minFrame.
    NSSize frameSize = frameRect.size;
    NSSize minSize = [self minSize];
    
    if (frameSize.width < minSize.width || frameSize.height < minSize.height)
    {
        CGFloat dX = 0.5 * (MAX(frameSize.width, minSize.width) - frameSize.width);
        CGFloat dY = 0.5 * (MAX(frameSize.height, minSize.height) - frameSize.height);
        frameRect = NSInsetRect(frameRect, dX, dY);
    }
    
    return frameRect;
}

- (NSRect)drawingRectForGraphicBounds:(NSRect)frameRect;
{
    // First, make sure the frame meets the requirements of -minFrame.
    frameRect = [self frameRectForGraphicBounds:frameRect];
    
    // Then enlarge to accomodate selection handles
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

#pragma mark Drawing

- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;
{
    // First draw overall frame. enlarge by 1 pixel to avoid drawing directly over the graphic
    [[NSColor grayColor] setFill];
    NSFrameRectWithWidthUsingOperation([view centerScanRect:NSInsetRect(frameRect, -1.0, -1.0)],
                                       1.0,
                                       NSCompositeSourceOver);
    
    
    // Then draw handles. Pixels are weird, need to draw using a slightly smaller rectangle otherwise edges get cut off
    if (![self isEditing])
    {
        NSRect editingHandlesRect = frameRect;
        editingHandlesRect.size.width -= 1.0f;
        editingHandlesRect.size.height -= 1.0f;
        
        
        CGFloat minX = NSMinX(editingHandlesRect);
        CGFloat midX = NSMidX(editingHandlesRect);
        CGFloat maxX = NSMaxX(editingHandlesRect);
        CGFloat minY = NSMinY(editingHandlesRect);
        CGFloat midY = NSMidY(editingHandlesRect);
        CGFloat maxY = NSMaxY(editingHandlesRect);
        
        
        unsigned int mask = [self resizingMask];
        BOOL canResizeLeft = (mask & kCALayerLeftEdge);
        BOOL canResizeTop = (mask & kCALayerTopEdge);
        BOOL canResizeRight = (mask & kCALayerRightEdge);
        BOOL canResizeBottom = (mask & kCALayerBottomEdge);
        
        if (canResizeTop || canResizeBottom)
        {
            if (mask & kCALayerLeftEdge || mask & kCALayerRightEdge)
            {
                [self drawSelectionHandleAtPoint:NSMakePoint(minX, minY)
                                          inView:view
                                         enabled:(canResizeTop && canResizeLeft)];
                
                [self drawSelectionHandleAtPoint:NSMakePoint(maxX, minY)
                                          inView:view
                                         enabled:(canResizeTop && canResizeRight)];
                
                [self drawSelectionHandleAtPoint:NSMakePoint(minX, maxY)
                                          inView:view
                                         enabled:(canResizeBottom && canResizeLeft)];
                
                [self drawSelectionHandleAtPoint:NSMakePoint(maxX, maxY)
                                          inView:view
                                         enabled:(canResizeBottom && canResizeRight)];
            }
            
            [self drawSelectionHandleAtPoint:NSMakePoint(midX, minY) inView:view enabled:canResizeTop];
            [self drawSelectionHandleAtPoint:NSMakePoint(midX, maxY) inView:view enabled:canResizeBottom];
        }
        
        [self drawSelectionHandleAtPoint:NSMakePoint(minX, midY) inView:view enabled:canResizeLeft];
        [self drawSelectionHandleAtPoint:NSMakePoint(maxX, midY) inView:view enabled:canResizeRight];
    }
}

- (void)drawWithGraphicBounds:(NSRect)frameRect inView:(NSView *)view;
{
    [self drawWithFrame:[self frameRectForGraphicBounds:frameRect] inView:view];
}

- (void)drawSelectionHandleAtPoint:(NSPoint)point inView:(NSView *)view enabled:(BOOL)enabled;
{
    NSRect rect = [view centerScanRect:NSMakeRect(point.x - 3.0,
                                                  point.y - 3.0,
                                                  7.0,
                                                  7.0)];
    
    // Draw middle
    [[NSColor colorWithCalibratedWhite:1.0 alpha:(enabled ? 1.0 : 0.5)] setFill];
    NSRectFillUsingOperation(NSInsetRect(rect, 1.0f, 1.0f), NSCompositeSourceOver);
    
    // Draw border
    if (enabled)
    {
        [[NSColor blackColor] setFill];
        NSFrameRect(rect);
    }
    else
    {
        [[[NSColor aquaColor] colorWithAlphaComponent:0.5] setFill];
        NSFrameRectWithWidthUsingOperation(rect, 1.0, NSCompositeSourceOver);
    }
}

@end