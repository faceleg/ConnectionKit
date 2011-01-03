//
//  KTMissingMediaThumbnailCell.m
//  Marvel
//
//  Created by Mike on 12/11/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "KTMissingMediaThumbnailCell.h"


@implementation KTMissingMediaThumbnailCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if ([self objectValue])
	{
		[super drawWithFrame:cellFrame inView:controlView];
	}
	else
	{
		const int lineWidth = 4;
		const int margin = lineWidth / 2;
		NSRect boxRect = NSInsetRect(cellFrame, margin+3.0, margin+3.0);
		float boxSize = MIN(boxRect.size.width, boxRect.size.height);
		NSPoint boxOrigin = boxRect.origin;
		float size = MIN(cellFrame.size.width, cellFrame.size.height);
		float curveRadius = MIN(size * 0.3, 50.0);
		float curveBoxSize = boxSize - 2*curveRadius;
		
		NSBezierPath *p = [NSBezierPath bezierPath];
		
		[p moveToPoint:NSMakePoint(boxOrigin.x + curveRadius, boxOrigin.y)];
		[p relativeLineToPoint:NSMakePoint(curveBoxSize, 0.0)];
		[p relativeCurveToPoint:NSMakePoint(curveRadius, curveRadius) controlPoint1:NSMakePoint(curveRadius, 0.0) controlPoint2:NSMakePoint(curveRadius, 0.0)];
		[p relativeLineToPoint:NSMakePoint(0.0, curveBoxSize)];
		[p relativeCurveToPoint:NSMakePoint(-curveRadius, curveRadius) controlPoint1:NSMakePoint(0.0, curveRadius) controlPoint2:NSMakePoint(0.0, curveRadius)];
		[p relativeLineToPoint:NSMakePoint(-curveBoxSize, 0.0)];
		[p relativeCurveToPoint:NSMakePoint(-curveRadius, -curveRadius) controlPoint1:NSMakePoint(-curveRadius, 0.0) controlPoint2:NSMakePoint(-curveRadius, 0.0)];
		[p relativeLineToPoint:NSMakePoint(0.0, -curveBoxSize)];
		[p relativeCurveToPoint:NSMakePoint(curveRadius, -curveRadius) controlPoint1:NSMakePoint(0.0, -curveRadius) controlPoint2:NSMakePoint(0.0, -curveRadius)];
		[p closePath];
		
		[[NSColor colorWithCalibratedWhite:0.8 alpha:1.0] set];
		[p setLineWidth:lineWidth];
		[p stroke];
	}
}


@end
