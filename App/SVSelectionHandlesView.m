//
//  SVSelectionHandlesView.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVSelectionHandlesView.h"


@interface SVSelectionHandlesView ()
- (void)drawHandleAtPoint:(NSPoint)point;
@end


@implementation SVSelectionHandlesView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    // Draw each selection handle. Need to find the rectangle inset from our bounds that ends up placing handles at edges
    NSRect handleCentresRect = NSInsetRect([self bounds], 3.0, 3.0);
    handleCentresRect.size.width--;
    handleCentresRect.size.height--;
    
    [self drawHandleAtPoint:NSMakePoint(NSMinX(handleCentresRect), NSMinY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMidX(handleCentresRect), NSMinY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMaxX(handleCentresRect), NSMinY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMinX(handleCentresRect), NSMidY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMaxX(handleCentresRect), NSMidY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMinX(handleCentresRect), NSMaxY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMidX(handleCentresRect), NSMaxY(handleCentresRect))];
    [self drawHandleAtPoint:NSMakePoint(NSMaxX(handleCentresRect), NSMaxY(handleCentresRect))];
}

- (void)drawHandleAtPoint:(NSPoint)point
{
    // Figure out a rectangle that's centered on the point but lined up with device pixels.
    NSRect handleBounds;
    handleBounds.origin.x = point.x - 3.0;
    handleBounds.origin.y = point.y - 3.0;
    handleBounds.size.width = 7.0;
    handleBounds.size.height = 7.0;
    handleBounds = [self centerScanRect:handleBounds];
    
    // Draw the rectangle
    [[NSColor blackColor] set];
    NSEraseRect(handleBounds);
    NSFrameRect(handleBounds);
}

@end
