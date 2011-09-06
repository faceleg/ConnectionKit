//
//  NSImage+KTApplication.m
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "NSImage+KTExtensions.h"

#import "KTImageScalingSettings.h"
#import "NSImage+Karelia.h"
#import "NSBitmapImageRep+Karelia.h"
#import "NSString+Karelia.h"
#import "Debug.h"
#import "ICOFamily.h"

@implementation NSImage ( KTApplication )

// This has a big flaw -- it only works for one image size.  Really we ought to be getting all of the NSImage's sizes, and
// doing the composite for each size of the badge.

- (NSImage *)imageWithCompositedAddBadge
{
	static NSImage *sBadgeAddImage = nil;
	if (nil == sBadgeAddImage)
	{
		sBadgeAddImage = [[NSImage imageNamed:@"toolbar_plus_badge"] retain];
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
	NSSize destinationSize = [settings scaledSizeForImageOfSize:[self size]];
	int integralWidth = destinationSize.width = roundf(destinationSize.width);
	int integralHeight = destinationSize.height = roundf(destinationSize.height);
	
	
	// Create the image rep
	NSBitmapImageRep *result = [[NSBitmapImageRep alloc]
		initWithBitmapDataPlanes:nil
					  pixelsWide:integralWidth
					  pixelsHigh:integralHeight
				   bitsPerSample:8
				 samplesPerPixel:4
					    hasAlpha:YES
                        isPlanar:NO
				  colorSpaceName:NSCalibratedRGBColorSpace
					bitmapFormat:0
					 bytesPerRow:(4 * integralWidth)
					bitsPerPixel:32];
	
	
	// Prepare for drawing
	NSImageInterpolation oldImageInterpolation = [[NSGraphicsContext currentContext] imageInterpolation];
	[NSGraphicsContext saveGraphicsState];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:result]];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	
	
	// Draw the scaled image
	NSRect scaledRect;
	scaledRect.origin = NSMakePoint(0.0, 0.0);
	scaledRect.size = destinationSize;
	
	NSRect sourceRect = [settings sourceRectForImageOfSize:[self size]];
	
	[self drawInRect:scaledRect fromRect:sourceRect operation:NSCompositeCopy fraction:1.0];
	
	
	// Tidy up
	[NSGraphicsContext restoreGraphicsState];
	[[NSGraphicsContext currentContext] setImageInterpolation:oldImageInterpolation];
	
	return [result autorelease];
}

#pragma mark -
#pragma mark Representations

- (NSData *)representationForMIMEType:(NSString *)aMimeType
{
	NSData *data = nil;
	
	// Image, convert based on mime type
	if ([aMimeType isEqualToString:@"image/vnd.microsoft.icon"])
	{
		data = [self faviconRepresentation];
	}
	else if ([aMimeType isEqualToString:@"image/png"])
	{
		data = [self PNGRepresentation];
	}
	else if ([aMimeType isEqualToString:@"image/jpeg"])
	{
		data = [self JPEGRepresentationWithCompressionFactor:0.7];
	}
	else if ([aMimeType isEqualToString:@"image/tiff"])
	{
		data = [self TIFFRepresentation];
	}
	
	return data;
}

- (NSData *)representationForUTI:(NSString *)aUTI
{
	NSData *data = nil;
	
	if ( [aUTI isEqualToString:(NSString *)kUTTypeICO] )
	{
		data = [self faviconRepresentation];
	}
	else if ( [aUTI isEqualToString:(NSString *)kUTTypeJPEG] )
	{
		data = [self JPEGRepresentationWithCompressionFactor:0.7];
	}
	else if ( [aUTI isEqualToString:(NSString *)kUTTypePNG] )
	{
		data = [self PNGRepresentation];
	}
	else if ( [aUTI isEqualToString:(NSString *)kUTTypeTIFF] )
	{
		data = [self TIFFRepresentation];
	}
	
	return data;
}


/*!	Get the data for a favicon.ico file.  Returns nil if unable.
 Note:  If the image is >= 32 pixels wide or high, a 32-pixel variant is created along with the 16,
 in case browsers want to use the higher-resolution variant.
 */
- (NSData *)faviconRepresentation
{
	NSData *result = nil;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	float faviconSharpenFactor = [defaults floatForKey:@"KTFaviconSharpeningFactor"];
	
	CIImage *theCI = [self toCIImage];
	CIImage *scaled32 = nil;
	CIImage *scaled16 = nil;	
	
	if ([self size].width >= 32 || [self size].height >= 32)
	{
		// Create 32 pixel image and 16 from same source (NOT from 32; doesn't seem to work!)
		scaled32 = [theCI scaleToWidth:32 height:32 behavior:kCropToRect alignment:NSImageAlignCenter opaqueEdges:YES];
		scaled16 = [theCI scaleToWidth:16 height:16 behavior:kCropToRect alignment:NSImageAlignCenter opaqueEdges:YES];
		
		scaled32 = [scaled32 sharpenLuminanceWithFactor:faviconSharpenFactor];
		scaled16 = [scaled16 sharpenLuminanceWithFactor:faviconSharpenFactor];
	}
	else
	{
		// Create 16 pixel image directly from source image (which is < 32 pixels, so no 32 version)
		scaled16 = [theCI scaleToWidth:16 height:16 behavior:kCropToRect alignment:NSImageAlignCenter opaqueEdges:YES];
		// Don't sharpen -- it may already be sharpened or optimized
	}
	
	ICOFamily *myFamily = [ICOFamily family]; // Returns an autoreleased instance

	NSBitmapImageRep *bitmap16	= [scaled16 bitmap];
	if (nil != bitmap16)
	{
		// Must have some 16x16 data in order to do anything!
		[myFamily setBitmapImageRep:bitmap16 forElement:kICOFamily16Element];
        
		if (nil != scaled32)
		{
			NSBitmapImageRep *bitmap32	= [scaled32 bitmap];
			[myFamily setBitmapImageRep:bitmap32 forElement:kICOFamily32Element];
		}
	}
	result = myFamily.data;

	return result;
}

// Possibly temporary way to do this
- (NSImage *)imageWithMaxPixels:(int)aPixels;
{
	return [self imageWithMaxWidth:aPixels 
							height:aPixels 
						  behavior:kFitWithinRect 
						 alignment:NSImageAlignCenter];
}

- (NSImage *)imageWithMaxWidth:(int)aWidth height:(int)aHeight
{
	return [self imageWithMaxWidth:aWidth 
							height:aHeight 
						  behavior:kFitWithinRect 
						 alignment:NSImageAlignCenter];
}

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
	if (aBehavior != kAnamorphic &&
        [self size].width <= aWidth &&
        [self size].height <= aHeight)
	{
		return self;	// Don't need to scale
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
	
#if 0
	NSString *dirPath = [NSString stringWithFormat:@"/tmp/%@-%d", [NSApplication applicationName], [[NSProcessInfo processInfo] processIdentifier] ];
	[[NSFileManager defaultManager] createDirectoryAtPath:dirPath attributes:nil];
	NSString *path = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%p-%@.tiff", self, [NSString UUIDString]]];
	[[result TIFFRepresentation] writeToFile:path atomically:NO];
	
	OFF((@"@Scaling image %@ down to %d %d -> %@", [[self description] condenseWhiteSpace], aWidth, aHeight, path));
#endif
	
	return result;
}

- (NSData *)PNGRepresentation
{
    // Set the PNG to be interlaced.
    NSMutableDictionary *props = [NSDictionary
                                  dictionaryWithObject:[NSNumber numberWithBool:YES]
                                  forKey:NSImageInterlaced];
	
	
	NSData *result = [[self bitmap] representationUsingType:NSPNGFileType
                                                 properties:props];
	
	return result;
}

- (NSData *)JPEGRepresentationWithCompressionFactor:(float)aQuality;
{
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	
	// Set our desired compression property, and make NOT progressive for the benefit of the flash-based viewer
	[props setObject:[NSNumber numberWithFloat:aQuality] forKey:NSImageCompressionFactor];
	[props setObject:[NSNumber numberWithBool:NO] forKey:NSImageProgressive];
	
	NSData *result = [[self bitmap] representationUsingType:NSJPEGFileType properties:props];
	
	return result;
}

@end
