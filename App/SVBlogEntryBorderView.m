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
#import "NSString+Karelia.h"
#import "NSAttributedString+Karelia.h"

#define TABWIDTH 20.0
#define TABHEIGHT 20.0
#define TABRADIUS	5.0
#define TABMARGIN 4.0

@implementation SVBlogEntryBorderView







- (NSRect)frameRectForGraphicBounds:(NSRect)frameRect;
{
	frameRect.origin.x -= TABWIDTH;		// this extends TABWIDTH pixels to the left of the contents
	frameRect.size.width += TABWIDTH;
    
    return frameRect;
}


- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;
{
	NSFont *font = [NSFont systemFontOfSize:16.0];
	NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
						  font, NSFontAttributeName,
						  [NSColor whiteColor], NSForegroundColorAttributeName,
						  nil];
	NSGradient *g = [[[NSGradient alloc] initWithColorsAndLocations:
					  [NSColor colorWithCalibratedHue:0.583333f saturation:0.5f brightness:1.0f alpha:1.0f], 0.0,
					  [NSColor colorWithCalibratedHue:0.583333f saturation:1.0f brightness:1.0f alpha:1.0f], 0.1,
					  [NSColor colorWithCalibratedHue:0.583333f saturation:1.0f brightness:1.0f alpha:1.0f], 0.6,
					  [NSColor colorWithCalibratedHue:0.583333f saturation:0.7f brightness:1.0f alpha:1.0f], 0.6,
					  [NSColor colorWithCalibratedHue:0.583333f saturation:0.5f brightness:1.0f alpha:1.0f], 1.0, nil] autorelease];

	NSRect tabRect;
	NSBezierPath *path;
	
	tabRect = [view centerScanRect:NSMakeRect(NSMinX(frameRect), NSMinY(frameRect)+TABMARGIN, TABWIDTH, TABHEIGHT)];
	path = [NSBezierPath bezierPathWithLeftRoundRectInRect:tabRect radius:TABRADIUS];

	[g drawInBezierPath:path angle:-90.0];

	NSAttributedString *s = [NSAttributedString stringWithString:[NSString stringWithUnichar:0x270E] attributes:
							 attr ];
	NSSize sz = [s size];
	[s drawAtPoint:NSMakePoint(NSMinX(frameRect)+ ((TABWIDTH-sz.width)/2), NSMinY(frameRect)+TABMARGIN)];
	
	tabRect = [view centerScanRect:NSMakeRect(NSMinX(frameRect), NSMaxY(frameRect)-TABHEIGHT-TABMARGIN, TABWIDTH, TABHEIGHT)];
	path = [NSBezierPath bezierPathWithLeftRoundRectInRect:tabRect radius:TABRADIUS];	
	
	[g drawInBezierPath:path angle:-90.0];

	s = [NSAttributedString stringWithString:[NSString stringWithUnichar:0x2702] attributes:
							 attr ];
	sz = [s size];
	[s drawAtPoint:NSMakePoint(NSMinX(frameRect)+ ((TABWIDTH-sz.width)/2), NSMaxY(frameRect)-TABHEIGHT-TABMARGIN)];
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
