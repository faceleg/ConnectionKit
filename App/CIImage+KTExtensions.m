//
//  CIImage+KTExtensions.m
//  Marvel
//
//  Created by Mike on 13/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

// REQUIRES Quartz.framework

#import "CIImage+KTExtensions.h"

#import "CIImage+Karelia.h"
#import "KTImageScalingSettings.h"
#import <QuartzCore/QuartzCore.h>


@implementation CIImage (KTExtensions)

- (CIImage *)processForThumbnailOfSize:(NSUInteger)maxSize
{
	CGFloat width = CGRectGetWidth([self extent]);
	CGFloat height = CGRectGetHeight([self extent]);
	CGFloat maxDimension = MAX(width,height);
	CGFloat shadowOffset = maxDimension / 32.0;
	CGFloat radius = maxDimension / 64.0;
	CGFloat shadowCrop = radius * 2.0;	// Relative to radius, how much to crop off the uninteresting part of the shadow
	
	NSLog(@"Image: %.0f x %.0f offset = %.1f radius = %.1f", width, height, shadowOffset, radius);
	
	CIFilter *filter = nil;
	NSAffineTransform *t = nil;
	
	// Create the main image: washed out slightly with a radial gradient, and up to make room for shadow
	CIImage *main = self;

	// Make a radial radient to composite onto the foreground image
	// Go from black in the middle to white in the outside.
	filter = [CIFilter filterWithName:@"CIRadialGradient"];
	[filter setValue:[CIVector vectorWithX:width/2.0 Y:height/2.0] forKey:@"inputCenter"];
	[filter setValue:[NSNumber numberWithFloat:maxDimension/2.0] forKey:@"inputRadius0"];		// make the edges start from the min dimension to the max one
	CGFloat radiusToCorner = sqrtf(powf(width/2.0, 2.0) + powf(height/2.0, 2.0));
	[filter setValue:[NSNumber numberWithFloat:radiusToCorner] forKey:@"inputRadius1"];
	[filter setValue:[CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.0] forKey:@"inputColor0"];
	[filter setValue:[CIColor colorWithRed:1.0 green:1.0 blue:1.0 alpha:0.2] forKey:@"inputColor1"];	// just slight lightness at edges
	CIImage *gradient = [filter valueForKey:@"outputImage"];
	
	
	// Use the gradient to lighten the image, to wash it out slightly
	filter = [CIFilter filterWithName:@"CISourceOverCompositing"];
	[filter setValue:gradient forKey:@"inputImage"];
	[filter setValue:main forKey:@"inputBackgroundImage"];		// act as mask
	CIImage *lightened = [filter valueForKey:@"outputImage"];
	
	// Now composite with the original so I have the original size.
	filter = [CIFilter filterWithName:@"CISourceInCompositing"];
	[filter setValue:lightened forKey:@"inputImage"];
	[filter setValue:self forKey:@"inputBackgroundImage"];		// act as mask
	main = [filter valueForKey:@"outputImage"];

//	[[main TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/main1.tiff" atomically:NO];
	
	// Move the main image up since shadow will go down below it.
	t = [NSAffineTransform transform];
	[t translateXBy:0 yBy:shadowOffset];
	filter = [CIFilter filterWithName:@"CIAffineTransform"];
	[filter setValue:t forKey:@"inputTransform"];
	[filter setValue:main forKey:@"inputImage"];
	main = [filter valueForKey:@"outputImage"];

	NSLog(@"Extent of main : %.2f, %.2f: %.2f x %.2f", [main extent].origin.x, [main extent].origin.y, [main extent].size.width, [main extent].size.height);

	// Create a shadow:
	CIImage *shadow = nil;
	
	// Start with solid black.
	filter = [CIFilter filterWithName:@"CIConstantColorGenerator"];
	[filter setValue:[CIColor colorWithRed:0.0 green:0.0 blue:0.0] forKey:@"inputColor"];
	CIImage *constantBlack = [filter valueForKey:@"outputImage"];
	
	// Mask to the size of the original image
	filter = [CIFilter filterWithName:@"CISourceInCompositing"];
	[filter setValue:constantBlack forKey:@"inputImage"];
	[filter setValue:self forKey:@"inputBackgroundImage"];		// act as mask
	shadow = [filter valueForKey:@"outputImage"];

//	[[shadow TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/shadow1.tiff" atomically:NO];

	NSLog(@"Extent of shadow : %.2f, %.2f: %.2f x %.2f", [shadow extent].origin.x, [shadow extent].origin.y, [shadow extent].size.width, [shadow extent].size.height);

	// Scale the shadow up slightly.  PROBLEM -- WE WOULD NEED TO SCALE UP FROM THE CURRENT CENTER, SO OFFSET IT TOO?
//	t = [NSAffineTransform transform];
//	[t scaleBy:1.25];
//	filter = [CIFilter filterWithName:@"CIAffineTransform"];
//	[filter setValue:t forKey:@"inputTransform"];
//	[filter setValue:shadow forKey:@"inputImage"];
//	shadow = [filter valueForKey:@"outputImage"];
	CGRect shadowExtent = [shadow extent];		// remember for later when we crop it

//	[[shadow TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/shadowScaled.tiff" atomically:NO];
	
	NSLog(@"Extent of shadow : %.2f, %.2f: %.2f x %.2f", [shadow extent].origin.x, [shadow extent].origin.y, [shadow extent].size.width, [shadow extent].size.height);
	
	
	// Blur the shadow.
	filter = [CIFilter filterWithName:@"CIGaussianBlur"];
	[filter setValue:shadow forKey:@"inputImage"];
	[filter setValue:[NSNumber numberWithInt:radius] forKey:@"inputRadius"];
	shadow = [filter valueForKey:@"outputImage"];

	NSLog(@"Extent of shadow : %.2f, %.2f: %.2f x %.2f", [shadow extent].origin.x, [shadow extent].origin.y, [shadow extent].size.width, [shadow extent].size.height);
//	[[shadow TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/shadow2.tiff" atomically:NO];

	// Crop shadow to the size of the original image plus the radius.
	CGRect newExtent = CGRectInset(shadowExtent, -shadowCrop, -shadowCrop);
	shadow = [shadow imageByCroppingToRect:newExtent];
	
	NSLog(@"Extent of shadow : %.2f, %.2f: %.2f x %.2f", [shadow extent].origin.x, [shadow extent].origin.y, [shadow extent].size.width, [shadow extent].size.height);
//	[[shadow TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/shadow3.tiff" atomically:NO];
	
	// Composite the main image over the shadow
	CIImage *result = nil;
	filter = [CIFilter filterWithName:@"CISourceOverCompositing"];
	[filter setValue:main forKey:@"inputImage"];
	[filter setValue:shadow forKey:@"inputBackgroundImage"];
	result = [filter valueForKey:@"outputImage"];

//	[[result TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/result1.tiff" atomically:NO];

	NSLog(@"Extent of result : %.2f, %.2f: %.2f x %.2f", [result extent].origin.x, [result extent].origin.y, [result extent].size.width, [result extent].size.height);



	// Now scale down to the appropriate size
	KTImageScalingSettings *thumbSettings = [KTImageScalingSettings settingsWithBehavior:KTScaleToSize size:NSMakeSize(maxSize,maxSize)];
	result = [result imageByApplyingScalingSettings:thumbSettings opaqueEdges:NO];
		
//	[[result TIFFRepresentation] writeToFile:@"/Volumes/dwood/Desktop/result2.tiff" atomically:NO];

	NSLog(@"Extent of result : %.2f, %.2f: %.2f x %.2f", [result extent].origin.x, [result extent].origin.y, [result extent].size.width, [result extent].size.height);

	return result;
	
}


- (CIImage *)imageByApplyingScalingSettings:(KTImageScalingSettings *)settings opaqueEdges:(BOOL)opaqueEdges
{
    CIFilter *filter;       // the working filter
	CIImage *result = self;	// the working image that we keep modifying
	CGSize originalSize = [self extent].size;
    
    
    
    // Calculate dimensions
	float scaleFactor = [settings scaleFactorForImageOfSize:originalSize];
    float aspectRatio = [settings aspectRatioForImageOfSize:originalSize];  // Will be 1.0 except for KTStretchToFit
    
    float finalH, finalW;
    if ([settings behavior] == KTStretchToSize)
    {
        finalW = [settings size].width;
        finalH = [settings size].height;
    }
    else    // Aspect ratio is 1 since we're not doing a stretch to fit
    {
        finalW = scaleFactor * originalSize.width;
        finalH = scaleFactor * originalSize.height;
    }
            
        
    // Scale only if needed
	if (scaleFactor != 1.0)
    {
        // Before scaling, make the edges stretch to infinity so that the edges don't have any alpha
        if (opaqueEdges)
        {
            filter = [CIFilter filterWithName:@"CIAffineClamp"];
            [filter setValue:[NSAffineTransform transform] forKey:@"inputTransform"];
            [filter setValue:result forKey:@"inputImage"];
            result = [filter valueForKey:@"outputImage"];
        }
        
        
        // Scale
        result = [result imageByScalingByFactor:scaleFactor aspectRatio:aspectRatio];
        
        // THIS DOESN'T SEEM TO BE WORKING -- CODE REVIEW ?
        result = [result imageByCroppingToRect:CGRectMake(0, 0, finalW, finalH)];
    }
	
    
	// Crop to size if requested
	if ([settings behavior] == KTCropToSize)
	{
		result = [result imageByCroppingToSize:CGSizeMake([settings size].width, [settings size].height)
                                     alignment:[settings alignment]];
	}
	 
	
	return result;
}

@end
