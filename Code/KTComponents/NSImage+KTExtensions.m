//
//  NSImage+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSImage+Karelia.h"

#import "CIImage+Karelia.h"
#import "KT.h"
#import "KTImageScalingSettings.h"
#import "KTPage.h"
#import "KTUtilities.h"
#import "NSBitmapImageRep+Karelia.h"
#import "NSData+Karelia.h"
#import <QuartzCore/QuartzCore.h>



@implementation NSImage ( KTExtensions )


// assumes NSImageAlignment of NSImageAlignCenter
- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight behavior:(CIScalingBehavior)aBehavior
{
	return [self imageWithMaxWidth:aWidth 
							height:aHeight 
						  behavior:aBehavior 
						 alignment:NSImageAlignCenter];
}

- (NSImage *)imageWithMaxWidth:(int)aWidth 
						height:(int)aHeight 
					  behavior:(CIScalingBehavior)aBehavior 
					 alignment:(NSImageAlignment)anAlignment
{
	if ([self size].width <= aWidth && [self size].height <= aHeight)
	{
		return self;	// Don't scale down.  FIXME: This might not be right for all CIScalingBehavior's!
	}
	CIImage *theCI			= [self toCIImage];
	CIImage *scaledCI		= [theCI scaleToWidth:aWidth height:aHeight behavior:aBehavior alignment:anAlignment opaqueEdges:YES];
	NSUserDefaults *defaults= [NSUserDefaults standardUserDefaults];
	float sharpenFactor		= [defaults floatForKey:@"KTSharpeningFactor"];
	CIImage *sharpenedCI	= [scaledCI sharpenLuminanceWithFactor:sharpenFactor];
	
	//NSImage *result = [sharpenedCI toNSImage];	// returns image with a CIImage backing
	// OR .... (which one makes more sense? Which is faster?)
	// NOTE: we were getting crashes with [sharpenedCI bitmap] but now it's better, I guess
	
	// TODO: Do I really NEED to get this as a bitmap?
	NSImage *result = [sharpenedCI toNSImageBitmap];
	return result;
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


