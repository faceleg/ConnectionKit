//
//  KTImageScalingSettings.m
//  Marvel
//
//  Created by Mike on 09/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTImageScalingSettings.h"


@interface KTImageScalingSettings (Private)
- (void)setBehavior:(KTMediaScalingOperation)behaviour;
- (void)setSize:(NSSize)size;
- (void)setScaleFactor:(float)scale;
- (void)setAlignment:(NSImageAlignment)alignment;
- (void)setSharpeningFactor:(NSNumber *)sharpening;
- (void)setUTI:(NSString *)UTI;
- (void)setCompression:(NSNumber *)compression;
@end


#pragma mark -


@implementation KTImageScalingSettings

+ (id)settingsWithScaleFactor:(float)scaleFactor sharpening:(NSNumber *)sharpening
{
	KTImageScalingSettings *result = [[[self alloc] init] autorelease];
	
	[result setBehavior:KTScaleByFactor];
	[result setScaleFactor:scaleFactor];
	[result setSharpeningFactor:sharpening];
	
	return result;
}

+ (id)settingsWithBehavior:(KTMediaScalingOperation)behavior
					  size:(NSSize)size
				sharpening:(NSNumber *)sharpening;
{
	KTImageScalingSettings *result = [[[self alloc] init] autorelease];
	
	[result setBehavior:behavior];
	[result setSize:size];
	[result setSharpeningFactor:sharpening];
	
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
	mySize = NSZeroSize;
	myScaleFactor = 1.0;
	myImageAlignment = NSImageAlignCenter;
	mySharpeningFactor = nil;
	myCompression = nil;
	myUTI = nil;
	
	return self;
}

- (void)dealloc
{
	[mySharpeningFactor release];
	[myCompression release];
	[myUTI release];
	
	[super dealloc];
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
	[self setSharpeningFactor:[decoder decodeObjectForKey:@"sharpening"]];
	[self setUTI:[decoder decodeObjectForKey:@"UTI"]];
	[self setCompression:[decoder decodeObjectForKey:@"compression"]];
	
	return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder
{
	[encoder encodeInt:[self behavior] forKey:@"behavior"];
	[encoder encodeSize:[self size] forKey:@"size"];
	[encoder encodeFloat:[self scaleFactor] forKey:@"scale"];
	[encoder encodeInt:[self alignment] forKey:@"alignment"];
	[encoder encodeObject:[self sharpeningFactor] forKey:@"sharpening"];
	[encoder encodeObject:[self UTI] forKey:@"UTI"];
	[encoder encodeObject:[self compression] forKey:@"compression"];
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

- (NSSize)size { return mySize; }

- (void)setSize:(NSSize)size { mySize = size; }

- (float)scaleFactor { return myScaleFactor; }

- (void)setScaleFactor:(float)scale { myScaleFactor = scale; }

- (NSImageAlignment)alignment { return myImageAlignment; }

- (void)setAlignment:(NSImageAlignment)alignment { myImageAlignment = alignment; }

- (NSNumber *)sharpeningFactor { return mySharpeningFactor; }

- (void)setSharpeningFactor:(NSNumber *)sharpening
{
	[sharpening retain];
	[mySharpeningFactor release];
	mySharpeningFactor = sharpening;
}

- (NSString *)UTI { return myUTI; }

- (void)setUTI:(NSString *)UTI
{
	UTI = [UTI copy];
	[myUTI release];
	myUTI = UTI;
}

- (NSNumber *)compression { return myCompression; }

- (void)setCompression:(NSNumber *)compression
{
	[compression retain];
	[myCompression release];
	myCompression = compression;
}

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
		 [settings sharpeningFactor] == [self sharpeningFactor] &&
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
- (float)_fitToSizeScaleFactor:(NSSize)size
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

- (float)_cropToSizeScaleFactor:(NSSize)size
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

- (float)scaleFactorForImageOfSize:(NSSize)sourceSize
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
			result = [self size].width / sourceSize.width;
			break;
	}
	
	return result;
}

- (float)aspectRatioForImageOfSize:(NSSize)sourceSize
{
	return 1.0;
	// TODO: Properly handle stretchToFit
}

- (NSSize)sizeForImageOfSize:(NSSize)sourceSize
{
	NSSize result;
	
	switch ([self behavior])
	{
		case KTStretchToSize:	// Dead easy
			result = [self size];
			break;
		
		default:
		{
			float scale = [self scaleFactorForImageOfSize:sourceSize];
			result = NSMakeSize(scale * sourceSize.width, scale * sourceSize.height);
			break;
		}	
	}
	
	return result;
}

@end
