//
//  CIImage+KTExtensions.m
//  KTComponents
//
//  Created by Dan Wood on 3/15/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "CIImage+KTExtensions.h"

#import "KTAbstractPlugin.h"		// for the benefit of L'izedStringInKTComponents macro
#import "KTImageScalingSettings.h"

#import "NSImage+KTExtensions.h"
#import "KT.h"
#import <QuartzCore/QuartzCore.h>
#import "assertions.h"
#import "Debug.h"


@interface CIImage (KTExtensionsPrivate)
- (void)getScaleFactor:(float *)scaleFactor
           aspectRatio:(float *)aspectRatio
		      cropRect:(CGRect *)cropRect
	forScalingSettings:(KTImageScalingSettings *)settings;
@end

/*
 
 I should scale full size to 'scaled' 640 and from there to 128 & 45; from 128 to 32; from 32 to 16.
 Don't scale from 128 to 45 since it will reduce image quality.
 
 Only sharpen the final image in each case.
 */

@implementation CIImage ( KTExtensions )

/*	Mimics +[NSImage imageTypes] by returning the UTIs supported by Core Image.
 */
+ (NSArray *)imageTypes
{
	static NSArray *sImageTypes;
	
	if (!sImageTypes)
	{
		sImageTypes = (NSArray *)CGImageSourceCopyTypeIdentifiers();
	}
	
	return sImageTypes;
}

- (NSImage *)toNSImage	// returns an NSImage with a CIImage representation
{
	CGRect extent = [self extent];
	return [self toNSImageFromRect:extent];
}

-(NSImage *)toNSImageBitmap	// like above, but forces a bitmap image rep, not NSCIImageRep
{
	CGRect extent = [self extent];
	float width = extent.size.width;
	float height = extent.size.height;
	BOOL ready = NO;
	NSImage *result = [[[NSImage alloc] initWithSize:NSMakeSize(width,height)] autorelease];
	
	// Try to use the technique that prevents leakage, if possible:
	// See comments here  http://inessential.com/?comments=1&postid=3390
	NSGraphicsContext *graphicsContext = [NSGraphicsContext currentContext];
	if (nil != graphicsContext)
	{
		CIContext *ciContext = [graphicsContext CIContext];
		
		// Need to make our own?
		if (nil == ciContext)
		{
			CGContextRef contextRef = [graphicsContext graphicsPort];
			ciContext = [CIContext contextWithCGContext:contextRef
												options:[NSDictionary dictionaryWithObject:
													  [NSNumber numberWithBool:YES] forKey:kCIContextUseSoftwareRenderer]];
		}
		
		CGImageRef cgImage = [ciContext createCGImage:self fromRect:extent];
		if (cgImage != NULL)
		{
			[result lockFocus];
			graphicsContext = [NSGraphicsContext currentContext];	// new context
			CGContextRef contextRef = [graphicsContext graphicsPort];
			CGContextDrawImage (contextRef, extent, cgImage);
			[result unlockFocus];
			CGImageRelease (cgImage);
			ready = YES;
		}
		else
		{
			LOG((@"No CGImageRef when trying to use leak-proof image technique"));
		}
	}
	else
	{
		LOG((@"Nil graphics context; must use the leaky way"));
	}
	
	if (!ready) // the leaky way, but it works -- we tried creating a NSGraphicsContext from a bitmap, but it didn't work?
	{
		NSCIImageRep *ciRep = [[NSCIImageRep alloc] initWithCIImage:self];
		[result addRepresentation:ciRep];	// temporarily put in this representation
		
		NSBitmapImageRep *bitmap = [result bitmap];		// force a bitmap to be drawn
		[result addRepresentation:bitmap];
		[result removeRepresentation:ciRep];	// Note: we also seem to have a cached image rep. Hopefully that won't be a problem!
		[ciRep release];
	}
	
//#if DEBUG
//		NSData *tiff = [result TIFFRepresentation];
//		[tiff writeToFile:[NSString stringWithFormat:@"/tmp/BITMAP_%p.tiff", tiff] atomically:NO];
//#endif
	
	return result;
}

// Return a bitmap from the rendered CIImage

-(NSBitmapImageRep *)bitmap
{
	CGRect extent = [self extent];
	float width = extent.size.width;
	float height = extent.size.height;
	NSCIImageRep *rep = [[NSCIImageRep alloc] initWithCIImage:self];
	NSImage *tempImage = [[NSImage alloc] initWithSize:NSMakeSize(width,height)];
	[tempImage addRepresentation:rep];
	
	NSBitmapImageRep *result = [tempImage bitmap];		// force a bitmap to be drawn
	
	[rep release];
	[tempImage release];

	return result;
}

- (NSImage *)toNSImageFromRect:(CGRect)r	// returns an ns image with a CIImage representation
{
    NSImage *image;
    NSCIImageRep *ir;
    
    ir = [NSCIImageRep imageRepWithCIImage:self];
    image = [[[NSImage alloc] initWithSize:NSMakeSize(r.size.width, r.size.height)] autorelease];
    [image addRepresentation:ir];
    return image;
}

/*!	General workhorse for scaling.  Behavior depends on "behavior" parameter...
	kAutomatic: If you pass in 0 for either dimension, the image will be scaled to the
	specified width/height, with the other dimension calculated automatically.

	kAnamorphic: Not implemented yet; may be handy later.

	kFitWithinRect: the image will be scaled so that it fits within the specified size, and may be
	narrower or shorter than the specified rectangle.
	For instance, passing in 128,128 will cause a portrait to be 128 tall and smaller width;
	a landscape to be 128 wide with a shorter height.  Think "Letterbox".

	kCoverRect:  the image will be scaled so that it fits along one specified dimension, but is
	wider/taller on the other dimension -- in other words, fully covering the rectangle.  In this
	case, passing in 128,128 would cause a portrait to be 128 *wide* and taller than that, and a
	landscape to be 128 tall and wider than 128.   Think "Pan & Scan".

	kCropToRect: Similar to above, except that the image is then cropped to fit the specified
	rectangle exactly.  Use the "alignment" parameter to specify how to crop it.
	For instance, if you pass in 128,128 with NSImageAlignTopLeft, then a portrait will be cropped
	so that the top square is visible; a landscape will be cropped so that the left square is.
	NSImageAlignTop, on the other hand, would show the *center* square of a landscape.

*/

- (CIImage *)scaleToWidth:(float)inW
				   height:(float)inH
				 behavior:(CIScalingBehavior)aBehavior	// if kAutomatic, above can be zero
				alignment:(NSImageAlignment)anAlignment	// applies for kCropToRect, 0 otherwise
			  opaqueEdges:(BOOL)anOpaqueEdges;			// makes sure edges are not transparent
{
	// NSLog(@"scaleToWidth:%f height:%f behavior:%d alignment:%d opaqueEdges:%d", inW,inH, aBehavior, anAlignment,anOpaqueEdges);

	if ( (aBehavior != kAutomatic && ( inW < 1.0 || inH < 1.0) )	// non-auto with 0 param
		|| (aBehavior == kAutomatic && inW > 0.0 && inH > 0.0)	// both non-zero for auto
		|| (inW < 1.0 && inH < 1.0)								// or both zero
		|| inW < 0.0 || inH < 0.0)								// either negative
	{
		NSException* exception = [NSException exceptionWithName:@"CIImage  Invalid Size"
			reason:NSLocalizedString(@"Invalid size passed to image scaling", @"Error: Core Image given Invalid Size.")
			userInfo:nil];
		[exception raise];                
	}
	CIFilter *f;
	CIImage *im = self;	// the working image that we keep modifying
	CGSize originalSize = [self extent].size;
	float finalW = inW;	// initially copied from input, may be set to zero (auto)
	float finalH = inH;
	float dX = 0.0, dY = 0.0;		// offset of cropping from Lower Left
	float h=0, w=0;	// actual size that image will be scaled to.

	//
	// For some behaviors, mark the width or height as needing to be calculated
	//
	switch (aBehavior)
	{
		case kAutomatic:
			// Nothing to do, we'll calculate needed dimension below
			break;
		case kAnamorphic:
			// keep specified dimensions as specified .... NOT FULLY IMPLEMENTED!
			break;
		case kFitWithinRect:
			if (originalSize.width / originalSize.height > inW/inH)
			{
				// wider original than will fit: "letterbox", make height automatic
				inH = 0;
			}
			else
			{
				// taller original than wil fit: "pillarbox" so make width automatic
				inW = 0;
			}
			break;
		case kCoverRect:
		case kCropToRect:
			if (originalSize.width / originalSize.height > inW/inH)
			{
				// wider original than will fit, use specified height and make width automatic
				inW = 0;
			}
			else
			{
				// taller original than wil fit: use specified width and make height automatic
				inH = 0;
			}
			break;
	}
	//
	// Now calculate any missing dimension based on original size.
	//
	if (0 == inW)		// specified height, calculate width
	{
		h = inH;
		inW = w = roundf(inH * (originalSize.width / originalSize.height));
		if (0 == finalW || kFitWithinRect == aBehavior)
		{
			finalW = w;
		}
		else if (kCoverRect == aBehavior)
		{
			finalW = inW;
		}
	}
	else if (0 == inH)	// specified width, calculate height
	{
		w = inW;
		inH = h = roundf(inW * (originalSize.height / originalSize.width));
		if (0 == finalH || kFitWithinRect == aBehavior)
		{
			finalH = h;
		}
		else if (kCoverRect == aBehavior)
		{
			finalH = inH;
		}
	}
	
	//
	// Before scaling,Make the edges stretch to infinity so that the edges don't have any alpha
	//
	if (anOpaqueEdges)
	{
		f = [CIFilter filterWithName:@"CIAffineClamp"];
		[f setValue:[NSAffineTransform transform] forKey:@"inputTransform"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
	}
	
	//
	// Transform image down to scale
	//
	// float xscale = w / originalSize.width;
	float yscale = h / originalSize.height;
	f = [CIFilter filterWithName:@"CILanczosScaleTransform"];
	[f setValue:[NSNumber numberWithFloat:yscale] forKey:@"inputScale"];
	[f setValue:[NSNumber numberWithFloat:1.0] forKey:@"inputAspectRatio"];
	[f setValue:im forKey:@"inputImage"];
	im = [f valueForKey:@"outputImage"];
	// NSLog(@"Extent of scaled image:%.3f %.3f %.3f %.3f", [im extent].origin.x, [im extent].origin.y, [im extent].size.width, [im extent].size.height);
	
	//
	// Calculate cropping offset, dX and dY, if applicable
	//
	if (aBehavior == kCropToRect)
	{
		switch (anAlignment)
		{
case NSImageAlignCenter:		dX = roundf((w-finalW)/2.0);	dY = roundf((h-finalH)/2.0);	break;
case NSImageAlignTop:			dX = roundf((w-finalW)/2.0);	dY = (h-finalH);				break;
case NSImageAlignTopLeft:		dX = 0.0;						dY = (h-finalH);				break;
case NSImageAlignTopRight:		dX = (w-finalW);				dY = (h-finalH);				break;
case NSImageAlignLeft:			dX = 0.0;						dY = roundf((h-finalH)/2.0);	break;
case NSImageAlignBottom:		dX = roundf((w-finalW)/2.0);	dY = 0.0;						break;
case NSImageAlignBottomLeft:	dX = 0.0;						dY = 0.0;						break;
case NSImageAlignBottomRight:	dX = (w-finalW);				dY = 0.0;						break;
case NSImageAlignRight:			dX = (w-finalW);				dY = roundf((h-finalH)/2.0);	break;
		}
	}
	
	//
	// Perform crop, now that we have scaled.  Since we did an affine clamp, it's currently infinite!
	//
	CIVector *cropRect =[CIVector vectorWithX:dX Y:dY Z: finalW W: finalH];
	f = [CIFilter filterWithName:@"CICrop"];
	[f setValue:im forKey:@"inputImage"];
	[f setValue:cropRect forKey:@"inputRectangle"];
	im = [f valueForKey:@"outputImage"];
	// NSLog(@"Extent of cropped (to %.3f %.3f %.3f %.3f) image:%.3f %.3f %.3f %.3f", dX,dY,finalW,finalH, [im extent].origin.x, [im extent].origin.y, [im extent].size.width, [im extent].size.height);

	//
	// Transform the image back to the origin, if necessary
	//
	if (dX > 0.0 || dY > 0.0)
	{
		// Transform it down to the origin, to make NSImage happy
		NSAffineTransform *t = [NSAffineTransform transform];
		[t translateXBy:-dX yBy:-dY];
		f = [CIFilter filterWithName:@"CIAffineTransform"];
		[f setValue:t forKey:@"inputTransform"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
		// NSLog(@"Extent of translated (by %.3f %.3f) image:%.3f %.3f %.3f %.3f", -dX, -dY, [im extent].origin.x, [im extent].origin.y, [im extent].size.width, [im extent].size.height);
	}
	return im;
}

- (CIImage *)imageByApplyingScalingSettings:(KTImageScalingSettings *)settings
{
	float scale;
	float aspectRatio;
	CGRect cropRect;
	[self getScaleFactor:&scale aspectRatio:&aspectRatio cropRect:&cropRect forScalingSettings:settings];
	
	
	// Clamp and scale the image
	CIFilter *affineClampFilter =
		[CIFilter filterWithName:@"CIAffineClamp"
				   keysAndValues:@"inputImage", self,
								 @"inputTransform", [NSAffineTransform transform], nil];
				   
	CIFilter *scaleFilter =
		[CIFilter filterWithName:@"CILanczosScaleTransform"
				   keysAndValues:@"inputImage", [affineClampFilter valueForKey:@"outputImage"],
								 @"inputScale", [NSNumber numberWithFloat:scale],
								 @"inputAspectRatio", [NSNumber numberWithFloat:aspectRatio],
								 nil];
	
	
	// Crop the image
	CIVector *scaledImageRect = [CIVector vectorWithX:cropRect.origin.x
													Y:cropRect.origin.y
													Z:cropRect.size.width
													W:cropRect.size.height];
	
	CIFilter *cropFilter =
		[CIFilter filterWithName:@"CICrop"
				   keysAndValues:@"inputImage", [scaleFilter valueForKey:@"outputImage"],
								 @"inputRectangle", scaledImageRect, nil];
	
	CIImage *result = [cropFilter valueForKey:@"outputImage"];
	
	
	// Transform the image back to the origin, if necessary
	if (cropRect.origin.x > 0.0 || cropRect.origin.y > 0.0)
	{
		NSAffineTransform *transform = [NSAffineTransform transform];
		[transform translateXBy:-cropRect.origin.x yBy:-cropRect.origin.y];
		
		CIFilter *realignFilter = [CIFilter filterWithName:@"CIAffineTransform"];
		[realignFilter setValue:transform forKey:@"inputTransform"];
		[realignFilter setValue:result forKey:@"inputImage"];
		result = [realignFilter valueForKey:@"outputImage"];
	}
	
	
	// Sharpen if requested
	NSNumber *sharpeningFactor = [settings sharpeningFactor];
	if (sharpeningFactor)
	{
		result = [result sharpenLuminanceWithFactor:(2.0 * [sharpeningFactor floatValue])];
	}
	
	
	return result;
}

/*	Converts arbitrary scaling settings so that they are more appropriate for Core Image to handle.
 */
- (void)getScaleFactor:(float *)scaleFactor
           aspectRatio:(float *)aspectRatio
		      cropRect:(CGRect *)cropRect
	forScalingSettings:(KTImageScalingSettings *)settings
{
	CGSize sourceSize = [self extent].size;
	
	
	// Figure out scaling & aspect ratio
	NSSize sourceImageSize = NSMakeSize(sourceSize.width, sourceSize.height);
	*scaleFactor = [settings scaleFactorForImageOfSize:sourceImageSize];
	*aspectRatio = [settings aspectRatioForImageOfSize:sourceImageSize];
	
	NSSize cropSize = [settings sizeForImageOfSize:sourceImageSize];
	float cropWidth = roundf(cropSize.width);
	float cropHeight = roundf(cropSize.height);
	
	if ([settings behavior] == KTCropToSize)
	{
		// TODO: Actually write this!
	}
	else
	{
		*cropRect = CGRectMake(0.0, 0.0, cropWidth, cropHeight);
	}
}

- (CIImage *)sharpenLuminanceWithFactor:(float)aSharpness	// range 0.0 to 2.0
{
	CIImage *im = self;
	if (aSharpness > 0.0)
	{
		CIFilter *f = [CIFilter filterWithName:@"CISharpenLuminance"];
		[f setValue:[NSNumber numberWithFloat:aSharpness] forKey:@"inputSharpness"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
	}
	return im;
}

- (CIImage *)rotateDegrees:(float)aDegrees	// range 0.0 to 360.0
{
	CIImage *im = self;
	if (aDegrees > 0.0 && aDegrees < 360.0)
	{
		CIFilter *f = [CIFilter filterWithName:@"CIAffineTransform"];
		NSAffineTransform *t = [NSAffineTransform transform];
		[t rotateByDegrees:aDegrees];
		[f setValue:t forKey:@"inputTransform"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
		
		// Now translate so that it doesn't dip below or to the left of the origin
		CGRect extent = [im extent];
		f = [CIFilter filterWithName:@"CIAffineTransform"];
		t = [NSAffineTransform transform];
		[t translateXBy:-extent.origin.x yBy:-extent.origin.y];
		[f setValue:t forKey:@"inputTransform"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
	}
	return im;
}

- (CIImage *)addWhiteBorder:(int)aPixels
{
	CIImage *im = self;
	if (aPixels > 0)
	{
		// Calculate geometry first
		CGRect extent = [im extent];
		float w  = extent.size.width  + 2 * aPixels;
		float h = extent.size.height + 2 * aPixels;

		// Create a white image
		CIFilter *f = [CIFilter filterWithName:@"CIConstantColorGenerator"];
		CIColor *white = [CIColor colorWithRed:1.0 green:1.0 blue:1.0];
		[f setValue:white forKey:@"inputColor"];
		CIImage *whiteImage = [f valueForKey:@"outputImage"];
		
		// Composite over the white
		f = [CIFilter filterWithName:@"CISourceOverCompositing"];
		[f setValue:whiteImage forKey:@"inputBackgroundImage"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];

		// Now crop to the size of the borders
		CIVector *cropRect =[CIVector vectorWithX:-aPixels Y:-aPixels Z:w W:h];
		f = [CIFilter filterWithName:@"CICrop"];
		[f setValue:im forKey:@"inputImage"];
		[f setValue:cropRect forKey:@"inputRectangle"];
		im = [f valueForKey:@"outputImage"];
		
		// Now move back to 0,0
		f = [CIFilter filterWithName:@"CIAffineTransform"];
		NSAffineTransform *t = [NSAffineTransform transform];
		[t translateXBy:aPixels yBy:aPixels];
		[f setValue:t forKey:@"inputTransform"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
	}
	return im;
}

- (CIImage *)addShadow:(int)aPixels	// pixels in blurriness and affects offset
{
	CIImage *im = self;
	if (aPixels > 0)
	{
		// Create a translucent black image
		CIFilter *f = [CIFilter filterWithName:@"CIConstantColorGenerator"];
		CIColor *black = [CIColor colorWithRed:0.0 green:0.0 blue:0.0 alpha:0.667];
		[f setValue:black forKey:@"inputColor"];
		CIImage *blackImage = [f valueForKey:@"outputImage"];
		
		// Make a new image filled with black, the shape of the original image
		f = [CIFilter filterWithName:@"CISourceInCompositing"];
		[f setValue:self forKey:@"inputBackgroundImage"];
		[f setValue:blackImage forKey:@"inputImage"];
		CIImage *shadowImage = [f valueForKey:@"outputImage"];
		
		// Blur the shadow
		f = [CIFilter filterWithName:@"CIGaussianBlur"];
		[f setValue:[NSNumber numberWithFloat:(float)aPixels] forKey:@"inputRadius"];
		[f setValue:shadowImage forKey:@"inputImage"];
		shadowImage = [f valueForKey:@"outputImage"];
		
		// Move the shadow below the image and slightly to the right
		f = [CIFilter filterWithName:@"CIAffineTransform"];
		NSAffineTransform *t = [NSAffineTransform transform];
		[t translateXBy:(float)aPixels/3.0 yBy:-aPixels];
		[f setValue:t forKey:@"inputTransform"];
		[f setValue:shadowImage forKey:@"inputImage"];
		shadowImage = [f valueForKey:@"outputImage"];
		
		// Composite image over the shadow
		f = [CIFilter filterWithName:@"CISourceOverCompositing"];
		[f setValue:shadowImage forKey:@"inputBackgroundImage"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];

		// Now move back to 0,0
		CGRect extent = [im extent];
		f = [CIFilter filterWithName:@"CIAffineTransform"];
		t = [NSAffineTransform transform];
		[t translateXBy:-extent.origin.x yBy:-extent.origin.y];
		[f setValue:t forKey:@"inputTransform"];
		[f setValue:im forKey:@"inputImage"];
		im = [f valueForKey:@"outputImage"];
	}
	return im;
}



@end
