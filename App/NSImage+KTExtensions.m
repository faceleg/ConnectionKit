//
//  NSImage+KTApplication.m
//  Marvel
//
//  Created by Dan Wood on 5/10/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "NSImage+KTExtensions.h"

#import "KTImageScalingSettings.h"
#import "NSImage+Karelia.h"
#import "NSBitmapImageRep+Karelia.h"
#import "NSString+Karelia.h"
#import "Debug.h"

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
		data = [self JPEGRepresentationWithQuality:[NSImage preferredJPEGQuality]];
	}
	else if ([aMimeType isEqualToString:@"image/tiff"])
	{
		data = [self TIFFRepresentation];
	}
	else
	{
		data = [self preferredRepresentation];
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
		data = [self JPEGRepresentationWithQuality:[NSImage preferredJPEGQuality]];
	}
	else if ( [aUTI isEqualToString:(NSString *)kUTTypePNG] )
	{
		data = [self PNGRepresentation];
	}
	else if ( [aUTI isEqualToString:(NSString *)kUTTypeTIFF] )
	{
		data = [self TIFFRepresentation];
	}
	else
	{
		data = [self preferredRepresentation];
	}
	
	return data;
}


/*!	Return UTI of preferred format type
 */
- (NSString *)preferredFormatUTI	// return user defaults preferred file format, good for extensions!
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *result;
	if ( [defaults boolForKey:@"KTPrefersPNGFormat"] || [self hasAlphaComponent])
	{
		result = (NSString *)kUTTypePNG;	// png if that's our preference, or if there is alpha in the image
	}
	else
	{
		result = (NSString *)kUTTypeJPEG;
	}
	return result;
}

+ (float)preferredJPEGQuality
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	float quality = [defaults floatForKey:@"KTPreferredJPEGQuality"];
	if (quality > 1.0)
	{
		quality = 1.0;
	}
	if (quality <= 0.0)
	{
		quality = 0.7;		// default value if not specified
	}
	return quality;
}

/*!	Return data in preferred representation.
 */
- (NSData *)preferredRepresentation
{
	NSData *result = nil;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if ( [defaults boolForKey:@"KTPrefersPNGFormat"]  || [self hasAlphaComponent] )
	{
		result = [self PNGRepresentation];
	}
	else
	{
		result = [self JPEGRepresentationWithQuality:[NSImage preferredJPEGQuality]];
	}
	return result;
}

- (NSData *)preferredRepresentationWithOriginalMedia:(KTMedia *)aParentMedia
{
	NSData *result = nil;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if ( [defaults boolForKey:@"KTPrefersPNGFormat"]  || [self hasAlphaComponent])
	{
		result = [self PNGRepresentationWithOriginalMedia:aParentMedia];
	}
	else
	{
		result = [self JPEGRepresentationWithQuality:[NSImage preferredJPEGQuality] originalMedia:aParentMedia];
	}
	return result;
}

/*!	Get the data for a favicon.ico file.  Returns nil if unable.
 Note:  If the image is >= 32 pixels wide or high, a 32-pixel variant is created along with the 16,
 in case browsers want to use the higher-resolution variant.
 */
- (NSData *)faviconRepresentation
{
	NSData *result = nil;
	NSString *path16 = nil;
	NSString *path32 = nil;
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
	
	NSBitmapImageRep *bitmap16	= [scaled16 bitmap];
	NSData *pngData16			= [bitmap16 representationUsingType:NSPNGFileType properties:nil];
	if (nil != pngData16)
	{
		// Must have some 16x16 data in order to do anything!
		
		path16 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"source16.png"];
		[pngData16 writeToFile:path16 atomically:NO];
        
        
		if (nil != scaled32)
		{
			NSBitmapImageRep *bitmap32	= [scaled32 bitmap];
			NSData *pngData32			= [bitmap32 representationUsingType:NSPNGFileType properties:nil];
			if (nil != pngData32)
			{
				path32 = [NSTemporaryDirectory() stringByAppendingPathComponent:@"source32.png"];
				[pngData32 writeToFile:path32 atomically:NO];
			}
		}
		
		// Now build up the task
		NSString *png2IcoPath = [[NSBundle mainBundle] pathForAuxiliaryExecutable:@"png2ico"];
		OBASSERT(png2IcoPath);
		NSString *outputPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"favicon.ico"];
        
		// Argument array.  If there is no 32-pixel image, then array will end with path to 16.
		NSArray *arguments = [NSArray arrayWithObjects:outputPath, @"--colors", @"16", path16, path32, nil];
		
		NSTask *task // = [NSTask launchedTaskWithLaunchPath:png2IcoPath arguments:arguments];
		= [[[NSTask alloc] init] autorelease];
        
		
		[task setLaunchPath:png2IcoPath];
		[task setArguments:arguments];
		
		// Don't let this task clutter stderr if we're running the real app
#ifndef DEBUG
		[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
#endif
		[task launch];
		while ([task isRunning])
		{
			[NSThread sleepUntilDate:[NSDate distantPast]];
		}
		//[task waitUntilExit];
		int status = [task terminationStatus];
		
		if (0 == status)
		{
			result = [NSData dataWithContentsOfFile:outputPath];
		}
		
		// Clean up so we don't leave recovered files.  Ignore errors.
		NSFileManager *fm = [NSFileManager defaultManager];
		[fm removeFileAtPath:outputPath handler:nil];
		[fm removeFileAtPath:path16 handler:nil];
		[fm removeFileAtPath:path32 handler:nil];
	}
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
	
#if 0
	NSString *dirPath = [NSString stringWithFormat:@"/tmp/%@-%d", [NSApplication applicationName], [[NSProcessInfo processInfo] processIdentifier] ];
	[[NSFileManager defaultManager] createDirectoryAtPath:dirPath attributes:nil];
	NSString *path = [dirPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%p-%@.tiff", self, [NSString UUIDString]]];
	[[result TIFFRepresentation] writeToFile:path atomically:NO];
	
	DJW((@"@Scaling image %@ down to %d %d -> %@", [[self description] condenseWhiteSpace], aWidth, aHeight, path));
#endif
	
	return result;
}

- (NSData *)PNGRepresentationWithOriginalMedia:(KTMedia *)parentMedia;
{
	NSMutableDictionary *props;
	if (nil != parentMedia)
	{
		// Extract the colorSync data from the original image
		NSBitmapImageRep *otherBitmap = [NSBitmapImageRep imageRepWithData:[parentMedia data]];
		NSSet *propsToExtract = [NSSet setWithObjects: NSImageColorSyncProfileData, nil];
		props = [otherBitmap dictionaryOfPropertiesWithSetOfKeys:propsToExtract];
	}
	else
	{
		props = [NSMutableDictionary dictionary];
	}
	
	// Also, set the PNG to be interlaced.
	[props setObject:[NSNumber numberWithBool:YES] forKey:NSImageInterlaced];
	
	NSData *result = [[self bitmap] representationUsingType:NSPNGFileType properties:props];
	
	return result;
}

- (NSData *)PNGRepresentation
{
	return [self PNGRepresentationWithOriginalMedia:nil];
}

- (NSData *)JPEGRepresentationWithQuality:(float)aQuality originalMedia:(KTMedia *)parentMedia;
{
	NSMutableDictionary *props;
	if (nil != parentMedia)
	{
		// Extract the EXIF data (if we have a jpeg), and colorSync data from the original image
		NSBitmapImageRep *otherBitmap = [NSBitmapImageRep imageRepWithData:[parentMedia data]];
		NSSet *propsToExtract = [NSSet setWithObjects: NSImageEXIFData, NSImageColorSyncProfileData, nil];
		props = [otherBitmap dictionaryOfPropertiesWithSetOfKeys:propsToExtract];
		
		// Fix up dictionary to take out ISOSpeedRatings since that doesn't appear to be settable
		NSDictionary *exifDict = [props objectForKey:NSImageEXIFData];
		if (nil != exifDict)
		{
			NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:exifDict];
			[dict removeObjectForKey:@"ISOSpeedRatings"];
			[props setObject:dict forKey:NSImageEXIFData];
		}
	}
	else
	{
		props = [NSMutableDictionary dictionary];
	}
	
	// Also set our desired compression property, and make NOT progressive for the benefit of the flash-based viewer
	[props setObject:[NSNumber numberWithFloat:aQuality] forKey:NSImageCompressionFactor];
	[props setObject:[NSNumber numberWithBool:NO] forKey:NSImageProgressive];
	
	NSData *result = [[self bitmap] representationUsingType:NSJPEGFileType properties:props];
	
	return result;
}

- (NSData *)JPEGRepresentationWithQuality:(float)aQuality;
{
	return [self JPEGRepresentationWithQuality:aQuality originalMedia:nil];
}



@end
