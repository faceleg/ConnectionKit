//
//  SVBlogEntryBorderView.m
//  Sandvox
//
//  Created by Dan Wood on 1/29/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVBlogEntryBorderView.h"
#import "NSBezierPath+Karelia.h"
#import "NSColor+Karelia.h"

#define TABWIDTH 20.0
#define TABHEIGHT 20.0
#define TABRADIUS	4.0

@implementation SVBlogEntryBorderView







- (NSRect)frameRectForGraphicBounds:(NSRect)frameRect;
{
	frameRect.origin.x -= TABWIDTH;		// this extends TABWIDTH pixels to the left of the contents
	frameRect.size.width += TABWIDTH;
    
    return frameRect;
}


- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;
{
	
	NSRect ULTabRect = [view centerScanRect:NSMakeRect(NSMinX(frameRect), NSMinY(frameRect), TABWIDTH, TABHEIGHT)];
	NSBezierPath *path = [NSBezierPath bezierPathWithLeftRoundRectInRect:ULTabRect radius:TABRADIUS];
	[[NSColor aquaColor] set];
	[path fill];
}

- (void)drawWithGraphicBounds:(NSRect)frameRect inView:(NSView *)view;
{
    [self drawWithFrame:[self frameRectForGraphicBounds:frameRect] inView:view];
}

- (NSRect)drawingRectForGraphicBounds:(NSRect)frameRect;	// called by client
{
    // First, make sure the frame meets the requirements of -minFrame.
	frameRect = [self frameRectForGraphicBounds:frameRect];
	return frameRect;
}








@end
