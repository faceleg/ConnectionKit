//
//  CIImage+KTExtensions.m
//  Marvel
//
//  Created by Mike on 13/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

// REQUIRES Quartz.framework

#import "CIImage+KTExtensions.h"

#import "CIImage+Karelia.h"
#import "KTImageScalingSettings.h"
#import <QuartzCore/QuartzCore.h>


@implementation CIImage (KTExtensions)

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
        
        
        // Remove the infinite edge pixels if needed
        if (opaqueEdges)
        {
            CIVector *cropRect = [CIVector vectorWithX:0.0 Y:0.0 Z:finalW W:finalH];
            result = [result imageByCroppingToRectangle:cropRect];
        }
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
