//
//  CIImage+KTExtensions.m
//  Marvel
//
//  Created by Mike on 13/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "CIImage+KTExtensions.h"

#import "KTImageScalingSettings.h"
#import <QuartzCore/QuartzCore.h>


@interface CIImage (KTExtensionsPrivate)
- (void)getScaleFactor:(float *)scaleFactor
           aspectRatio:(float *)aspectRatio
		      cropRect:(CGRect *)cropRect
	forScalingSettings:(KTImageScalingSettings *)settings;
@end


@implementation CIImage (KTExtensions)

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

@end
