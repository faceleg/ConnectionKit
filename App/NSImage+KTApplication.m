//
//  NSImage+KTApplication.m
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

#import "NSImage+KTApplication.h"

#import "KTImageScalingSettings.h"


@implementation NSImage ( KTApplication )

- (NSImage *)imageWithCompositedAddBadge
{
	static NSImage *sBadgeAddImage = nil;
	if (nil == sBadgeAddImage)
	{
		sBadgeAddImage = [[NSImage imageNamed:@"BadgeAdd"] retain];
	}
	

	NSImage *newImage = [[[NSImage alloc] initWithSize:[self size]] autorelease];
        
    [newImage lockFocus];
    [self drawAtPoint:NSZeroPoint
			 fromRect:NSMakeRect(0,0,[self size].width, [self size].height)
			operation:NSCompositeSourceOver fraction:1.0];

	[sBadgeAddImage drawAtPoint:NSZeroPoint
					   fromRect:NSMakeRect(0,0,[sBadgeAddImage size].width, [sBadgeAddImage size].height)
			operation:NSCompositeSourceOver fraction:1.0];
	
	[newImage unlockFocus];
	
	return newImage;
}

- (NSBitmapImageRep *)bitmapByScalingWithBehavior:(KTImageScalingSettings *)settings
{
	// Create the image rep
	NSBitmapImageRep *result = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:nil
					  pixelsWide:[settings size].width
					  pixelsHigh:[settings size].height
				   bitsPerSample:8
				 samplesPerPixel:4
					    hasAlpha:YES
                        isPlanar:NO
				  colorSpaceName:NSCalibratedRGBColorSpace
					bitmapFormat:0
					 bytesPerRow:(4 *[settings size].width)
					bitsPerPixel:32];
	
	
	// Prepare for drawing
	NSImageInterpolation oldImageInterpolation = [[NSGraphicsContext currentContext] imageInterpolation];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:result]];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	
	// Draw the scaled image
	NSRect scaledRect;
	scaledRect.origin = NSMakePoint(0.0, 0.0);
	scaledRect.size = [settings size];
	
	[self drawInRect:scaledRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	// TODO: handle all behaviors
	
	
	// Tidy up
	[NSGraphicsContext restoreGraphicsState];
	[[NSGraphicsContext currentContext] setImageInterpolation:oldImageInterpolation];
	
	return [result autorelease];
}

@end
