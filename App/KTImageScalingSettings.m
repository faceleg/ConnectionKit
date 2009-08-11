//
//  KTImageScalingSettings.m
//  Marvel
//
//  Created by Mike on 09/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTImageScalingSettings.h"


@interface KTImageScalingSettings ()
- (void)setBehavior:(KTMediaScalingOperation)behaviour;
- (void)setSize:(NSSize)size;
- (void)setScaleFactor:(float)scale;
- (void)setAlignment:(NSImageAlignment)alignment;
@end


#pragma mark -


@implementation KTImageScalingSettings

+ (id)settingsWithScaleFactor:(float)scaleFactor
{
	KTImageScalingSettings *result = [[[self alloc] init] autorelease];
	
	[result setBehavior:KTScaleByFactor];
	[result setScaleFactor:scaleFactor];
	
	return result;
}

+ (id)settingsWithBehavior:(KTMediaScalingOperation)behavior size:(NSSize)size;
{
	KTImageScalingSettings *result = [[[self alloc] init] autorelease];
	
	[result setBehavior:behavior];
	[result setSize:size];
	
	return result;
}

+ (id)cropToSize:(NSSize)size alignment:(NSImageAlignment)alignment
{
	KTImageScalingSettings *result = [self settingsWithBehavior:KTCropToSize size:size];
	[result setAlignment:alignment];
	//[result setScaleFactor:0.0];	// By default -cropToFit items are infinitely scalable
	return result;
}

+ (id)scalingSettingsWithDictionaryRepresentation:(NSDictionary *)dictionary
{
	// Set up the default object
	KTImageScalingSettings *result = [[[self alloc] init] autorelease];
	
	
	// Search for size information
	NSSize size = NSZeroSize;
	id aValue = [dictionary objectForKey:@"maxPixels"];
	if (aValue && [aValue isKindOfClass:[NSNumber class]])
	{
		size.width = size.height = [aValue floatValue];
	}
	else
	{
		aValue = [dictionary objectForKey:@"width"];
		if (aValue && [aValue isKindOfClass:[NSNumber class]])
		{
			size.width = [aValue floatValue];
		}
		else
		{
			aValue = [dictionary objectForKey:@"maxWidth"];
			if (aValue && [aValue isKindOfClass:[NSNumber class]])
			{
				size.width = [aValue floatValue];
			}	
		}
		
		aValue = [dictionary objectForKey:@"height"];
		if (aValue && [aValue isKindOfClass:[NSNumber class]])
		{
			size.height = [aValue floatValue];
		}
		else
		{
			aValue = [dictionary objectForKey:@"maxHeight"];
			if (aValue && [aValue isKindOfClass:[NSNumber class]])
			{
				size.height = [aValue floatValue];
			}	
		}
	}
	[result setSize:size];
	
	
	// Scaling behavior
	if (!NSEqualSizes([result size], NSZeroSize))	// Whenever possible, default to scaleToSize
	{
		[result setBehavior:KTScaleToSize];
	}
	
	NSString *behaviorDescription = [dictionary objectForKey:@"behavior"];
	if (behaviorDescription && [behaviorDescription isKindOfClass:[NSString class]])
	{
		if ([behaviorDescription isEqualToString:@"CropToRect"] ||
			[behaviorDescription isEqualToString:@"cropToSize"])
		{
			[result setBehavior:KTCropToSize];
			
			// Alignment	// TODO: Refactor and handle all cases
			NSString *alignment = [dictionary objectForKey:@"alignment"];
			if (alignment && [alignment isKindOfClass:[NSString class]])
			{
				if ([alignment isEqualToString:@"top"])
				{
					[result setAlignment:NSImageAlignTop];
				}
			}
		}
	}
	
	
	return result;
}

- (id)init
{
	[super init];
	
	// Init with default parameters
	myBehaviour = KTScaleByFactor;
	_size = NSZeroSize;
	myScaleFactor = 1.0;
	myImageAlignment = NSImageAlignCenter;
	
	return self;
}

#pragma mark -
#pragma mark NSCoding

- (id)initWithCoder:(NSCoder *)decoder
{
	[self init];
	
	[self setBehavior:[decoder decodeIntForKey:@"behavior"]];
	[self setSize:[decoder decodeSizeForKey:@"size"]];
	[self setScaleFactor:[decoder decodeFloatForKey:@"scale"]];
	[self setAlignment:[decoder decodeIntForKey:@"alignment"]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:[self behavior] forKey:@"behavior"];
	[encoder encodeSize:[self size] forKey:@"size"];
	[encoder encodeFloat:[self scaleFactor] forKey:@"scale"];
	[encoder encodeInt:[self alignment] forKey:@"alignment"];
}

#pragma mark -
#pragma mark Description

/*	All good Cocoa objects should have a decent description :)
 */
- (NSString *)description
{
	NSString *result = [super description];
	
	switch ([self behavior])
	{
		case KTScaleByFactor:
			result = [result stringByAppendingFormat:@" scaleFactor:%f", [self scaleFactor]];
			break;
		
		case KTScaleToSize:
			result = [result stringByAppendingFormat:@" scaleToSize:%@", NSStringFromSize([self size])];
			break;
			
		case KTCropToSize:
			result = [result stringByAppendingFormat:@" cropToSize:%@, alignment:%i",
													 NSStringFromSize([self size]),
													 [self alignment]];
			break;
			
		case KTStretchToSize:
			result = [result stringByAppendingFormat:@" stretchToSize:%@", NSStringFromSize([self size])];
			break;
	}
	
	return result;
}

#pragma mark -
#pragma mark Accessors

- (KTMediaScalingOperation)behavior { return myBehaviour; }

- (void)setBehavior:(KTMediaScalingOperation)behaviour { myBehaviour = behaviour; }

- (NSSize)size { return _size; }

- (void)setSize:(NSSize)size { _size = size; }

- (float)scaleFactor { return myScaleFactor; }

- (void)setScaleFactor:(float)scale { myScaleFactor = scale; }

- (NSImageAlignment)alignment { return myImageAlignment; }

- (void)setAlignment:(NSImageAlignment)alignment { myImageAlignment = alignment; }

#pragma mark -
#pragma mark Equality

- (BOOL)isEqual:(id)anObject
{
	BOOL result = NO;
	
	if ([anObject isKindOfClass:[KTImageScalingSettings class]])
	{
		result = [self isEqualToImageScalingSettings:anObject];
	}
	
	return result;
}

- (BOOL)isEqualToImageScalingSettings:(KTImageScalingSettings *)settings
{
	BOOL result =
		(NSEqualSizes([settings size], [self size]) &&
		 [settings behavior] == [self behavior] &&
		 [settings alignment] == [self alignment]);
	
	return result;
	// TODO: Be more forgiving when a setting is not appropriate to the behavior
}

- (unsigned)hash
{
	return 0;	// TODO: Return something more sensible!
}

#pragma mark -
#pragma mark Resizing

#pragma mark source

/*	Returns NSZeroRect if the entirety of the source image should be used
 */
- (NSRect)sourceRectForImageOfSize:(NSSize)sourceSize
{
	NSRect result = NSZeroRect;
	
	// Cropping requires using a smaller source area
	if ([self behavior] == KTCropToSize)
	{
		// The source size must be the destination size scaled back down
        CGSize CGSourceSize = CGSizeMake(sourceSize.width, sourceSize.height);
		float scaleFactor = [self scaleFactorForImageOfSize:CGSourceSize];
		result.size = NSMakeSize(roundf([self size].width / scaleFactor), roundf([self size].height / scaleFactor));
		
		// The origin depends on the chosen alignment
		switch ([self alignment])
		{
			case NSImageAlignTopLeft:
			case NSImageAlignLeft:
			case NSImageAlignBottomLeft:
				result.origin.x = 0.0;
				break;
			case NSImageAlignTop:
			case NSImageAlignCenter:
			case NSImageAlignBottom:
				result.origin.x = (sourceSize.width - result.size.width) / 2;
				break;
			case NSImageAlignTopRight:
			case NSImageAlignRight:
			case NSImageAlignBottomRight:
				result.origin.x = sourceSize.width - result.size.width;
				break;
		}
		
		switch ([self alignment])
		{
			case NSImageAlignTopLeft:
			case NSImageAlignTop:
			case NSImageAlignTopRight:
				result.origin.y = sourceSize.height - result.size.height;
				break;
			case NSImageAlignLeft:
			case NSImageAlignCenter:
			case NSImageAlignRight:
				result.origin.y = (sourceSize.height - result.size.height) / 2;
				break;
			case NSImageAlignBottomLeft:
			case NSImageAlignBottom:
			case NSImageAlignBottomRight:
				result.origin.y = 0.0;
				break;
		}
	}
	
	return result;
}

#pragma mark destination

/*	If we were to scale purely by image width, what is the required factor?
 */
- (float)_scaleFactorToFitWidth:(float)sourceWidth
{
	float result = ([self size].width / sourceWidth);
	return result;
}

/*	As above, but for height.
 */
- (float)_scaleFactorToFitHeight:(float)sourceHeight;
{
	float result = ([self size].height / sourceHeight);
	return result;
}

/*	Assumes we are in fitToSize mode
 */
- (float)_fitToSizeScaleFactor:(CGSize)size
{
	float result;
	
	// If the user specified 0 for either dimension, base the result purely on that
	if ([self size].width <= 0.0)
	{
		result = [self _scaleFactorToFitHeight:size.height];
	}
	else if ([self size].height <= 0.0)
	{
		result = [self _scaleFactorToFitWidth:size.width];
	}
	else
	{
		result = MIN([self _scaleFactorToFitWidth:size.width], [self _scaleFactorToFitHeight:size.height]);
	}
	
	// Respect any limit that may have been placed
	float scaleLimit = [self scaleFactor];
	if (scaleLimit > 0.0)
	{
		result = MIN(result, scaleLimit);
	}
	
	return result;
}

- (float)_cropToSizeScaleFactor:(CGSize)size
{
	float result = MAX([self _scaleFactorToFitWidth:size.width], [self _scaleFactorToFitHeight:size.height]);
	
	// Respect any limit that may have been placed
	float scaleLimit = [self scaleFactor];
	if (scaleLimit > 0.0)
	{
		result = MIN(result, scaleLimit);
	}
	
	return result;
}

- (float)scaleFactorForImageOfSize:(CGSize)sourceSize
{
	float result = 1.0;
	
	switch ([self behavior])
	{
		case KTScaleByFactor:
			result = [self scaleFactor];
			break;
		
		case KTScaleToSize:
			result = [self _fitToSizeScaleFactor:sourceSize];
			break;
		
		case KTCropToSize:
			result = [self _cropToSizeScaleFactor:sourceSize];
			break;
		
		case KTStretchToSize:
			// Fairly simple conversion between size & scale
			result = [self size].height / sourceSize.height;
			break;
	}
	
	return result;
}

- (float)aspectRatioForImageOfSize:(CGSize)sourceSize
{
	float result = 1.0;
    
    if ([self behavior] == KTStretchToSize)
    {
        result = [self scaleFactorForImageOfSize:sourceSize] / ([self size].width / sourceSize.width);
    }
    
    return result;
}

- (NSSize)scaledSizeForImageOfSize:(NSSize)sourceSize
{
	NSSize result;
	NSSize mySize = [self size];
	
	switch ([self behavior])
	{
		case KTStretchToSize:	// Dead easy
		case KTCropToSize:		// The image will fill the frame unless the image is undersized
			result = mySize;
			break;
		
		/*case KTCropToSize:		// The image will fill the frame unless the image is undersized
			result = NSMakeSize(MIN(mySize.width, sourceSize.width), MIN(mySize.height, sourceSize.height));
			break;
		*/	
		default:
		{
			CGSize CGSourceSize = CGSizeMake(sourceSize.width, sourceSize.height);
            float scale = [self scaleFactorForImageOfSize:CGSourceSize];
			result = NSMakeSize(roundf(scale * sourceSize.width), roundf(scale * sourceSize.height));
			break;
		}	
	}
	
	return result;
}

- (CGSize)scaledCGSizeForImageOfSize:(CGSize)sourceSize
{
    NSSize result = [self scaledSizeForImageOfSize:(*(NSSize *)&(sourceSize))];
    return (*(CGSize *)&(result));
}

@end
