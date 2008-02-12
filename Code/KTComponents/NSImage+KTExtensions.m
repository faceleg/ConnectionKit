//
//  NSImage+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "NSImage+KTExtensions.h"

#import "CIImage+KTExtensions.h"
#import "KT.h"
#import "KTImageScalingSettings.h"
#import "KTPage.h"
#import "KTUtilities.h"
#import "NSBitmapImageRep+KTExtensions.h"
#import "NSData+KTExtensions.h"
#import <QuartzCore/QuartzCore.h>



@implementation NSImage ( KTExtensions )

- (CIImage *)toCIImage
{
    NSBitmapImageRep *bitmapimagerep = [self bitmap];
    CIImage *im = [[CIImage alloc] initWithBitmapImageRep:bitmapimagerep];
	[im autorelease];
    return im;
}

+ (NSImage *)imageInBundleForClass:(Class)aClass named:(NSString *)imageName
{
    return [self imageInBundleForClass:aClass named:imageName inDirectory:nil];
}

+ (NSImage *)imageInBundleForClass:(Class)aClass named:(NSString *)imageName inDirectory:(NSString *)directory
{
    NSBundle *bundle = [NSBundle bundleForClass:aClass];
    return [self imageInBundle:bundle named:imageName inDirectory:directory];
}

+ (NSImage *)imageWithBitmap:(NSBitmapImageRep *)aBitmap
{
    NSImage *image;
    image = [[[NSImage alloc] initWithSize:
		NSMakeSize([aBitmap pixelsWide], [aBitmap pixelsHigh])] autorelease];
    [image addRepresentation:aBitmap];
    return image;
}

+ (NSImage *)imageInBundle:(NSBundle *)bundle named:(NSString *)imageName
{
    return [self imageInBundle:bundle named:imageName inDirectory:nil];
}

+ (NSImage *)imageInBundle:(NSBundle *)bundle named:(NSString *)imageName inDirectory:(NSString *)directory
{
    NSString *imagePath = [bundle pathForResource:imageName ofType:nil inDirectory:directory];
    NSImage *image = [[[NSImage allocWithZone:[self zone]] initWithContentsOfFile:imagePath] autorelease];
    
    if ( nil == image && ![imageName isEqualToString:@"broken.png"])	// prevent recursion
	{
		image = [NSImage brokenImage];
    }
    
    return [image normalizeSize];
}

#pragma mark -
#pragma mark CGImage utilities

- (id)initWithCGImageSourceRef:(CGImageSourceRef)aSource ofMaximumSize:(int)aSize;
{
	// image thumbnail options
	NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
		(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
		(id)kCFBooleanFalse, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
		(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageAlways,	// bug in rotation so let's use the full size always
		[NSNumber numberWithInt:aSize], (id)kCGImageSourceThumbnailMaxPixelSize, 
		nil];
	
	CGImageRef theCGImage = CGImageSourceCreateThumbnailAtIndex(aSource, 0, (CFDictionaryRef)thumbOpts);
	
	if (theCGImage)
	{
		// Now draw into an NSImage
		NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
		CGContextRef imageContext = nil;
		
		// Get the image dimensions.
		imageRect.size.height = CGImageGetHeight(theCGImage);
		imageRect.size.width = CGImageGetWidth(theCGImage);
		
		// Create a new image to receive the Quartz image data.
		self = [self initWithSize:imageRect.size];
		[self lockFocus];
		
		// Get the Quartz context and draw.
		imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
		CGContextDrawImage(imageContext, *(CGRect*)&imageRect, theCGImage);
		[self unlockFocus];			
		CFRelease(theCGImage);
		return self;
	}
	else	// Can't create CGImage
	{
		[self release];
		return nil;
	}
}

- (id)initWithData:(NSData *)data ofMaximumSize:(int)aSize;
{
	CGImageSourceRef source = CGImageSourceCreateWithData((CFDataRef)data, NULL);
	if (source)
	{
		self = [self initWithCGImageSourceRef:source ofMaximumSize:aSize];
		CFRelease(source);
		return self;
	}
	else
	{
		[self release];
		return nil;
	}
}

- (id)initWithContentsOfFile:(NSString *)fileName ofMaximumSize:(int)aSize;
{
	return [self initWithContentsOfURL:[NSURL fileURLWithPath:fileName] ofMaximumSize:aSize];
}

- (id)initWithContentsOfURL:(NSURL *)url ofMaximumSize:(int)aSize;
{
	CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
	if (source)
	{
		self = [self initWithCGImageSourceRef:source ofMaximumSize:aSize];
		CFRelease(source);
		return self;
	}
	else
	{
		[self release];
		return nil;
	}
}

#pragma mark -
#pragma mark Manipulation


// If it's a bitmap and there's an alpha channel, trim the image to include only the smallest rectangle possible
- (NSImage *)trimmedVertically
{
	NSBitmapImageRep *bitmap = [self bitmap];	// get (or make) a bitmap
    
	// get it into the right format
    if (![bitmap hasAlpha])
	{
		return self;	// no alpha channel -- or unknown format --  so return unaffected
	}

	unsigned int width = [bitmap pixelsWide];
	unsigned int height = [bitmap pixelsHigh];
	uint32_t bpr = [bitmap bytesPerRow];
	uint32_t row, col, topRow = 0, bottomRow = height;
	unsigned char *sr, *s;
	
	const unsigned char kAlphaThreshold = 0x10;		// treat almost-clear same as clear!
	
	// Look for first row with any opacity
	for (row = 0, sr = [bitmap bitmapData]; row < height; row++, sr += bpr)
	{
		for (col = 0, s = sr; col < width; col++, s += 4)
		{
			UInt8 alpha = s[3];
			if (alpha > kAlphaThreshold)
			{
				topRow = bottomRow = row;	// save top row, also assume bottom row is that too.
				goto doneTop;	// Yikes!  Well, I want to quickly get out of nested FOR
			}
		}
	}
doneTop:
		// Now start from the bottom up, to find the bottom row.
	for (row = height-1, sr = [bitmap bitmapData] + bpr * (height-1) ; row > topRow; row--, sr -= bpr)
	{
		for (col = 0, s = sr; col < width; col++, s += 4)
		{
			UInt8 alpha = s[3];
			if (alpha > kAlphaThreshold)
			{
				bottomRow = row;	// Row where non-alpha is first found
				goto doneBottom;	// Yikes!  Well, I want to quickly get out of nested FOR
			}
		}
	}
doneBottom:
	// NSLog(@"top row = %d, bot row = %d", topRow, bottomRow);
	if (topRow > 0 || bottomRow < height)
	{
		[self lockFocus];
		NSBitmapImageRep *newBitmap = [[[NSBitmapImageRep alloc]
			// have to deal with lower-left coordinates now
			initWithFocusedViewRect:NSMakeRect(0.0, height-bottomRow-1,width,bottomRow - topRow+1)] autorelease];
		[self unlockFocus];
		NSImage *newImage = [NSImage imageWithBitmap:newBitmap];
		return newImage;
	}
	else
	{
		return self;
	}
}

/*!	Scan through an image, one row at a time, one pixel at a time, looking for any pixel that is
	not opaque (or almost opaque).  Distinct from cocoa's hasAlpha, which just checks for an alpha channel 
	even if it's totally opaque.
	If an image has some transparency in the upper edges, this will exit pretty quickly.  Worst
	case is if an image is fully opaque except for a pixel in the bottom-most row.
*/
- (BOOL)hasAlphaComponent
{
	NSBitmapImageRep *bitmap = [self bitmap];	// get (or make) a bitmap
    
	// get it into the right format
    if (![bitmap hasAlpha])
	{
		return NO;
	}
	
	if (8 != [bitmap bitsPerSample])
	{
		return YES;			// this algorithm is not set up to parse images that aren't 8 bits/pixel, so assume alpha is real.
	}
	if ([bitmap isPlanar])
	{
		return YES;		// not supported for this kind of image
	}
//unused	BOOL isPlanar = [bitmap isPlanar];
	unsigned int width = [bitmap pixelsWide];
	unsigned int height = [bitmap pixelsHigh];
	uint32_t bpr = [bitmap bytesPerRow];
	BOOL alphaFirst = 0 != ([bitmap bitmapFormat] & NSAlphaFirstBitmapFormat);
	int bytesPerPixel = [bitmap bitsPerPixel] / 8;
	int alphaOffset = (alphaFirst ? 0 : bytesPerPixel - 1);
	unsigned char *sr;
	uint32_t row;
	
	const unsigned char kAlphaThreshold = (0xFF - 0x10);		// treat almost-clear same as clear!
	
	// Look for first row with any transparency
	for (row = 0, sr = [bitmap bitmapData]; row < height; sr += bpr)
	{
		unsigned char *s;
		uint32_t col;
		for (col = 0, s = sr; col < width; col++, s += bytesPerPixel)
		{
// FIXME: This Doesn't actualy seem to work!
			UInt8 alpha = s[alphaOffset];
			if (alpha < kAlphaThreshold)
			{
				return YES;
			}
		}
	}
	return NO;
}

/*!	Find or create a bitmap. */
- (NSBitmapImageRep *)bitmap	// returns bitmap, or creates one.
{
	NSBitmapImageRep *result = [self firstBitmap];
    
	if (nil == result)		// didn't have one, create it.
	{
		int width, height;
		NSSize sz = [self size];
		width = sz.width;
		height = sz.height;
		[self lockFocus];
		result = [[[NSBitmapImageRep alloc]
			initWithFocusedViewRect:NSMakeRect(0.0, 0.0, (float)width, (float)height)] autorelease];
		[self unlockFocus];
	}
	return result;
}

- (NSBitmapImageRep *)firstBitmap	// returns nil if no bitmap associated.
{
	NSBitmapImageRep *result = nil;
	NSArray *reps = [self representations];
	unsigned int i;
    
	for (i = 0 ; i < [reps count] ; i++ )
	{
		NSImageRep *theRep = [reps objectAtIndex:i];
		if ([theRep isKindOfClass:[NSBitmapImageRep class]])
		{
			result = (NSBitmapImageRep *)theRep;
			break;
		}
	}
	return result;
}

- (NSImage *)normalizeSize
{
	NSBitmapImageRep *theBitmap = [self firstBitmap];
    
	if (nil != theBitmap)
	{
		NSSize newSize;
        
		newSize.width = [theBitmap pixelsWide];
		newSize.height = [theBitmap pixelsHigh];
		[theBitmap setSize:newSize];
		[self setSize:newSize];
	}
	return self;
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

- (NSData *)JPEG2000RepresentationWithQuality:(float)aQuality
{
	NSMutableDictionary *props = [NSMutableDictionary dictionary];
	[props setObject:[NSNumber numberWithFloat:aQuality] forKey:NSImageCompressionFactor];
	
	NSData *result = [[self bitmap] representationUsingType:NSJPEG2000FileType properties:props];
	return result;
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

+ (NSImage *)brokenImage
{
	static NSImage *sBrokenPng = nil;
	if ( nil == sBrokenPng )
	{
		sBrokenPng = [[NSImage imageInBundle:[NSBundle bundleForClass:[KTUtilities class]] named:@"broken.png"] retain];
        [sBrokenPng normalizeSize];
	}
	
	return sBrokenPng;
}

//+ (NSImage *)noImageImage
//{
//	static NSImage *sNoImagePng = nil;
//	if ( nil == sNoImagePng )
//	{
//		sNoImagePng = [[NSImage imageInBundle:[NSBundle bundleForClass:[KTUtilities class]] named:@"no_image.png"] retain];
//        [sNoImagePng normalizeSize];
//	}
//	
//	return sNoImagePng;
//}
//
//+ (NSImage *)noneImage
//{
//	static NSImage *sNonePng = nil;
//	if ( nil == sNonePng )
//	{
//		sNonePng = [[NSImage imageInBundle:[NSBundle bundleForClass:[KTUtilities class]] named:@"none.png"] retain];
//        [sNonePng normalizeSize];
//	}
//	
//	return sNonePng;
//}

+ (NSImage *)qmarkImage
{
	static NSImage *sQMarkPng = nil;
	if ( nil == sQMarkPng )
	{
		sQMarkPng = [[NSImage imageInBundle:[NSBundle mainBundle] named:@"qmark.png"] retain];
        [sQMarkPng normalizeSize];
	}
	
	return sQMarkPng;
}

+ (NSImage *)movieImage
{
	static NSImage *sMoviePng = nil;
	if ( nil == sMoviePng )
	{
		sMoviePng = [[NSImage imageInBundle:[NSBundle mainBundle] named:@"movie.png"] retain];
        [sMoviePng normalizeSize];
	}
	
	return sMoviePng;
}

- (float)width
{
	return [self size].width;
}

- (float)height
{
	return [self size].height;
}

-(void)embossPlaceholder
{
	//[self normalizeSize];

	NSFont* font = [NSFont systemFontOfSize:([self size].width / 12.0)];
	NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
	[aShadow setShadowOffset:NSMakeSize(3.0, -5.0)];
	[aShadow setShadowBlurRadius:3.0];
	[aShadow setShadowColor:[NSColor colorWithCalibratedWhite:0.0 alpha:0.6]];

	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		font, NSFontAttributeName, 
		aShadow, NSShadowAttributeName, 
		[NSColor colorWithCalibratedWhite:1.0 alpha:0.5], NSForegroundColorAttributeName,
		nil];
	NSString *s = NSLocalizedString(@"Placeholder Image","Text embossed on placeholder photo");

	NSSize textSize = [s sizeWithAttributes:attributes];
	float left = ([self size].width - textSize.width) / 2.0;
	float bottom = [self size].height - textSize.height - 10.0;

	[self lockFocus];
	[s drawAtPoint:NSMakePoint(left, bottom) withAttributes:attributes];
	[self unlockFocus];
}

+ (BOOL)containsImageDataAtPath:(NSString *)path
{
	NSFileHandle *file = [NSFileHandle fileHandleForReadingAtPath:path];
	NSData *magic = [file readDataOfLength:256];			// This should be plenty!

	if (![magic containsJPEGImageData])
	{
		if (![magic containsTIFFImageData])
		{
			if (![magic containsPNGImageData])
			{
				if (![magic containsGIFImageData])
				{
					if (![magic containsFaviconImageData])
					{
						return NO;
					}
				}
			}
		}
	}
	return YES;
}

#pragma mark -
#pragma mark Standard Table Buttons

+ (NSImage *)addToTableButtonIcon
{
	static NSImage *image = nil;
	
	if (!image)
	{
		image = [[NSImage alloc] initWithSize:NSMakeSize(8.0, 8.0)];
		
		NSImageRep *imageRep = [[NSCustomImageRep alloc] initWithDrawSelector:@selector(drawTableAddButtonIcon:) delegate:image];
		[image addRepresentation:imageRep];
		[imageRep release];
	}
	
	return image;
}

- (void)drawTableAddButtonIcon:(id)imageRep
{
	// Create the path
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:2.0];
	
	[path moveToPoint:NSMakePoint(0.0, 4.0)];
	[path relativeLineToPoint:NSMakePoint(8.0, 0.0)];
	[path relativeMoveToPoint:NSMakePoint(-4.0, -4.0)];
	[path relativeLineToPoint:NSMakePoint(0.0, 8.0)];
	
	// Draw
	[[NSColor colorWithCalibratedWhite:0.3 alpha:1.0] set];
	[path stroke];
}

+ (NSImage *)removeFromTableButtonIcon
{
	static NSImage *image = nil;
	
	if (!image)
	{
		image = [[NSImage alloc] initWithSize:NSMakeSize(8.0, 8.0)];
		
		NSImageRep *imageRep = [[NSCustomImageRep alloc] initWithDrawSelector:@selector(drawTableRemoveButtonIcon:) delegate:image];
		[image addRepresentation:imageRep];
		[imageRep release];
	}
	
	return image;
}

- (void)drawTableRemoveButtonIcon:(id)imageRep
{
	// Create the path
	NSBezierPath *path = [NSBezierPath bezierPath];
	[path setLineWidth:2.0];
	
	[path moveToPoint:NSMakePoint(0.0, 4.0)];
	[path relativeLineToPoint:NSMakePoint(8.0, 0.0)];
	
	// Draw
	[[NSColor colorWithCalibratedWhite:0.3 alpha:1.0] set];
	[path stroke];
}

@end


