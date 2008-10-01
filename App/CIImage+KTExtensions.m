//
//  CIImage+KTExtensions.m
//  Marvel
//
//  Created by Mike on 13/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

// REQUIRES Quartz.framework

#import "CIImage+KTExtensions.h"

#import "CIImage+Karelia.h"
#import "KTImageScalingSettings.h"
#import <QuartzCore/QuartzCore.h>


@implementation CIImage (KTExtensions)

- (CIImage *)imageByApplyingScalingSettings:(KTImageScalingSettings *)settings opaqueEdges:(BOOL)opaqueEdges
{
    CIFilter *filter;
	CIImage *result = self;	// the working image that we keep modifying
	CGSize originalSize = [self extent].size;
    
    float inW = [settings size].width;
    float inH = [settings size].height;
	float finalW = inW;	// initially copied from input, may be set to zero (auto)
	float finalH = inH;
	float dX = 0.0, dY = 0.0;		// offset of cropping from Lower Left
	float h=finalH, w=finalW;	// actual size that image will be scaled to.
    
	
    
    // For some behaviors, mark the width or height as needing to be calculated
	//
	switch ([settings behavior])
	{
		case KTScaleByFactor:
            OBASSERT_NOT_REACHED("KTScaleByFactor not implemented");
            break;
        
        case KTStretchToSize:
			// keep specified dimensions as specified .... NOT FULLY IMPLEMENTED!
            break;
            
		case KTScaleToSize:
			if (originalSize.width / originalSize.height > finalW/finalH)
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
		
        case KTCropToSize:
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
	
    
    
	// Now calculate any missing dimension based on original size.
	//
	if (0 == inW)		// specified height, calculate width
	{
		h = inH;
		inW = w = roundf(inH * (originalSize.width / originalSize.height));
		if (0 == finalW || [settings behavior] == KTScaleToSize)
		{
			finalW = w;
		}
	}
	else if (0 == inH)	// specified width, calculate height
	{
		w = inW;
		inH = h = roundf(inW * (originalSize.height / originalSize.width));
		if (0 == finalH || [settings behavior] == KTScaleToSize)
		{
			finalH = h;
		}
	}
	
    
    
	// Before scaling, make the edges stretch to infinity so that the edges don't have any alpha
	//
	if (opaqueEdges)
	{
		filter = [CIFilter filterWithName:@"CIAffineClamp"];
		[filter setValue:[NSAffineTransform transform] forKey:@"inputTransform"];
		[filter setValue:result forKey:@"inputImage"];
		result = [filter valueForKey:@"outputImage"];
	}
	
	
    // Scale
	float xscale = w / originalSize.width;
	float yscale = h / originalSize.height;
    float aspectRatio = ([settings behavior] == KTStretchToSize) ? (yscale / xscale) : 1.0;
    
    result = [result imageByScalingByFactor:yscale aspectRatio:aspectRatio];
    
	
    
	// Calculate cropping offset, dX and dY, if applicable
	//
	if ([settings behavior] == KTCropToSize)
	{
		switch ([settings alignment])
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
	CIVector *cropRect = [CIVector vectorWithX:dX Y:dY Z:finalW W:finalH];
	filter = [CIFilter filterWithName:@"CICrop"];
	[filter setValue:result forKey:@"inputImage"];
	[filter setValue:cropRect forKey:@"inputRectangle"];
	result = [filter valueForKey:@"outputImage"];
	// NSLog(@"Extent of cropped (to %.3f %.3f %.3f %.3f) image:%.3f %.3f %.3f %.3f", dX,dY,finalW,finalH, [im extent].origin.x, [im extent].origin.y, [im extent].size.width, [im extent].size.height);
    
	
	// Transform the image back to the origin, if necessary
	//
	if (dX > 0.0 || dY > 0.0)
	{
		// Transform it down to the origin, to make NSImage happy
		NSAffineTransform *t = [NSAffineTransform transform];
		[t translateXBy:-dX yBy:-dY];
		filter = [CIFilter filterWithName:@"CIAffineTransform"];
		[filter setValue:t forKey:@"inputTransform"];
		[filter setValue:result forKey:@"inputImage"];
		result = [filter valueForKey:@"outputImage"];
		// NSLog(@"Extent of translated (by %.3f %.3f) image:%.3f %.3f %.3f %.3f", -dX, -dY, [im extent].origin.x, [im extent].origin.y, [im extent].size.width, [im extent].size.height);
	}
    
    
	return result;
}

@end
