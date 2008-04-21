//
//  KTMediaFile+ScaledImages.m
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTMediaFile+ScaledImages.h"
#import "MediaFiles+Internal.h"

#import "KTImageScalingSettings.h"
#import "KTMediaManager+Internal.h"
#import "KTScaledImageProperties.h"

#import "CIImage+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSString+Karelia.h"

#import <QuartzCore/QuartzCore.h>
#import <QTKit/QTKit.h>


@interface QTMovie (iMediaHack)
- (NSImage *)betterPosterImage;
@end


@interface KTMediaFile (ScaledImagesPrivate)

// Generation
- (KTScaledImageProperties *)generateImageUsingCoreImageWithProperties:(NSDictionary *)properties;

- (KTScaledImageProperties *)generateImageUsingQTKitWithProperties:(NSDictionary *)properties;
- (NSImage *)moviePosterImage;

- (KTScaledImageProperties *)generateImageFromFileIconWithProperties:(NSDictionary *)properties;

// Queries
- (KTScaledImageProperties *)anyScaledImageWithProperties:(NSDictionary *)properties;

@end


#pragma mark -


@implementation KTMediaFile (ScaledImages)

/*	Settings, compression & UTI are all validated against the current environment.
 *	e.g. if you specify a nil UTI, the returned object will have a UTI for JPEG or PNG; whichever suits the image.
 */
- (KTScaledImageProperties *)scaledImageWithProperties:(NSDictionary *)properties
{
	KTScaledImageProperties *result;
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// We can only generate a scaled image directly from an image file.
	// If not an image, create a full-size image and then scale from that
	NSString *sourceUTI = [self fileType];
	if ([[CIImage imageTypes] containsObject:sourceUTI] && ![sourceUTI isEqualToString:(NSString *)kUTTypePDF])
	{
		// Build the canonical version of the settings
		properties = [self canonicalImagePropertiesForProperties:properties];
		
		// Search for an existing match
		result = [self anyScaledImageWithProperties:properties];
		if (!result)
		{
			result = [self generateImageUsingCoreImageWithProperties:properties];
		}
	}
	else
	{
		// Go for a super-simple unscaled image from the source media
		NSMutableDictionary *unscaledImageProperties = [NSMutableDictionary dictionary];
		[unscaledImageProperties setObject:[KTImageScalingSettings settingsWithScaleFactor:1.0 sharpening:nil] forKey:@"scalingBehavior"];
		[unscaledImageProperties setObject:[NSNumber numberWithFloat:0.0] forKey:@"compression"];
		[unscaledImageProperties setObject:[NSNumber numberWithFloat:0.0] forKey:@"sharpeningFactor"];
		
		
		KTMediaFile *unscaledImage;
		if ([NSString UTI:sourceUTI conformsToUTI:(NSString *)kUTTypeAudiovisualContent])
		{
			unscaledImage = [[self generateImageUsingQTKitWithProperties:unscaledImageProperties] valueForKey:@"destinationFile"];
		}
		else
		{
			unscaledImage = [[self generateImageFromFileIconWithProperties:unscaledImageProperties] valueForKey:@"destinationFile"];
		}
		
		// And then scale it properly
		result = [unscaledImage scaledImageWithProperties:properties];
	}
	
	
	// Tidy up
	[result retain];
	[pool release];
	
	return [result autorelease];
}

#pragma mark -
#pragma mark Image Generation

- (KTScaledImageProperties *)scaleImage:(NSImage *)image withProperties:(NSDictionary *)properties
{
	// Scale the image
	KTImageScalingSettings *scalingBehavior = [properties objectForKey:@"scalingBehavior"];
	NSBitmapImageRep *scaledImage = [image bitmapByScalingWithBehavior:scalingBehavior];
	NSImage *finalImage = nil;
	
	
	// Sharpen if necessary
	NSNumber *sharpening = [properties objectForKey:@"sharpeningFactor"];
	if (sharpening && [sharpening floatValue] > 0.0)
	{
		CIImage *unsharpenedImage = [[CIImage alloc] initWithBitmapImageRep:scaledImage];
		CIImage *sharpenedImage = [unsharpenedImage sharpenLuminanceWithFactor:[sharpening floatValue]];
		finalImage = [sharpenedImage toNSImageBitmap];
		[unsharpenedImage release];
	}
	else
	{
		finalImage = [NSImage imageWithBitmap:scaledImage];
	}
	
	
	// Figure out the UTI
	NSString *UTI = [properties objectForKey:@"fileType"];
	if (!UTI)
	{
		UTI = [finalImage preferredFormatUTI];
	}
	
	
	// Create the MediaFile
	KTMediaManager *mediaManager = [self mediaManager];
	NSString *extension = [NSString filenameExtensionForUTI:UTI];
	OBASSERT(extension);
	NSString *preferredFilename = [[self preferredFileName] stringByAppendingPathExtension:extension];
	NSData *imageData = [finalImage representationForUTI:UTI];
	KTInDocumentMediaFile *mediaFile = [mediaManager mediaFileWithData:imageData preferredFilename:preferredFilename];
	
	
	// Connect the MediaFile up to ourself to record how it was created
	KTScaledImageProperties *result = [KTScaledImageProperties connectSourceFile:self
																		  toFile:mediaFile
																  withProperties:properties];
	
	
	return result;
}


/*	Called if the receiver holds an image.
 *	This method is responsible for checking that the image is actually suitable for scaling.
 */
- (KTScaledImageProperties *)generateImageUsingCoreImageWithProperties:(NSDictionary *)properties;
{
	KTScaledImageProperties *result = nil;
	
	NSString *imagePath = [self currentPath];
	NSImage *image = [[NSImage alloc] initByReferencingFile:imagePath];
	
	if (image && [[image representations] count] > 0)
	{
		result = [self scaleImage:image withProperties:properties];
	}
	else
	{
		NSLog(@"%@\rThe image could not be read into memory for scaling", [imagePath stringByAbbreviatingWithTildeInPath]);
	}
	
	// Tidy up
	[image release];
	return result;
}

- (KTScaledImageProperties *)generateImageUsingQTKitWithProperties:(NSDictionary *)properties
{
	NSImage *image = [self moviePosterImage];
	KTInDocumentMediaFile *mediaFile = [[self mediaManager] mediaFileWithImage:image];
	KTScaledImageProperties *result = [KTScaledImageProperties connectSourceFile:self toFile:mediaFile withProperties:properties];
	
	return result;
}

- (NSImage *)moviePosterImage
{	
	NSImage *result = nil;
	
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
		[self currentPath], QTMovieFileNameAttribute,
		[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
		nil];
	
	NSError *error = nil;
	QTMovie *movie = [[QTMovie alloc] initWithAttributes:attributes error:&error];
	
	if (movie)
	{
		result = [movie betterPosterImage]; 
	}
	else
	{
		// log to console so bug reports pick it up
		NSLog(@"error: unable to read movie for a thumbnail from %@: %@", 
			  [self currentPath],
			  [error localizedDescription]);
	}
	
	// Handle a missing thumbnail, like when we have a .wmv file
	if (!result || NSEqualSizes(NSZeroSize, [result size]) )
	{
		NSString *quickTimePath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.quicktimeplayer"];
		if (quickTimePath)
		{
			result = [[NSWorkspace sharedWorkspace] iconForFile:quickTimePath];
		}
		else
		{
			result = [NSImage imageNamed:@"NSDefaultApplicationIcon"];	// last resort!
		}
	}		

	NSAssert(result, @"Could not generate movie thumbnail");
	
	[movie release];
	return result;
}

- (KTScaledImageProperties *)generateImageFromFileIconWithProperties:(NSDictionary *)properties
{
	// Pick up the image from the workspace manager
	NSImage *image = [[NSWorkspace sharedWorkspace] iconForFile:[self currentPath]];
	KTInDocumentMediaFile *mediaFile = [[self mediaManager] mediaFileWithImage:image];
	KTScaledImageProperties *result = [KTScaledImageProperties connectSourceFile:self toFile:mediaFile withProperties:properties];
	
	return result;
}

#pragma mark -
#pragma mark Queries

/*	Takes some properties and makes them suitable for the media system to search and generate images with.
 */ 
- (NSDictionary *)canonicalImagePropertiesForProperties:(NSDictionary *)properties
{
	NSMutableDictionary *buffer = [NSMutableDictionary dictionaryWithDictionary:properties];
	
	
	// Ensure there is a compression setting
	id aValue = [properties objectForKey:@"compression"];
	if (!aValue || aValue == [NSNull null])
	{
		NSNumber *compression = [[NSUserDefaults standardUserDefaults] objectForKey:@"KTPreferredJPEGQuality"];
		[buffer setObject:compression forKey:@"compression"];
	}
	
	
	// Ensure there is a sharpening factor
	aValue = [properties objectForKey:@"sharpeningFactor"];
	if (!aValue || aValue == [NSNull null])
	{
		NSNumber *sharpening = [[NSUserDefaults standardUserDefaults] objectForKey:@"KTSharpeningFactor"];
		[buffer setObject:sharpening forKey:@"sharpeningFactor"];
	}
	
	
	// It's OK to leave fileType as nil
	
	
	// Make sure scaling behavior is stretchToSize or cropToSize
	KTImageScalingSettings *settings = [properties objectForKey:@"scalingBehavior"];
	switch ([settings behavior])
	{
		case KTScaleToSize:
		case KTScaleByFactor:
		{
			// Convert these wishy washy behaviours to a definite stretch operation
			NSSize suggestedSize = [settings scaledSizeForImageOfSize:[self dimensions]];
			NSSize roundedSize = NSMakeSize(roundf(suggestedSize.width), roundf(suggestedSize.height));
			
			KTImageScalingSettings *canonicalBehavior = [KTImageScalingSettings settingsWithBehavior:KTStretchToSize
																								size:roundedSize
																						  sharpening:nil];
			
			[buffer setObject:canonicalBehavior forKey:@"scalingBehavior"];
			break;
		}
			
		default:
			break;
	}
	
	
	// Tidy up
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:buffer];
	return result;
}

/*	Searches through our existing ScaledImageMediaFiles for one with the specified properties.
 *	The properties are interpreted EXACTLY. i.e. nil values are completely ignored. Use NSNull if you wish to search for a
 *	property being set to nil.
 *	Returns nil if no match is found.
 */
- (KTScaledImageProperties *)anyScaledImageWithProperties:(NSDictionary *)properties
{
	KTScaledImageProperties *result = nil;
	
	NSArray *propertyKeys = [properties allKeys];
	NSSet *imageProperties = [self valueForKey:@"scaledImages"];
	NSEnumerator *imagesEnumerator = [imageProperties objectEnumerator];
	KTScaledImageProperties *aPropertiesObject;
	
	while (aPropertiesObject = [imagesEnumerator nextObject])
	{
		NSDictionary *anImageProperties = [aPropertiesObject dictionaryWithValuesForKeys:propertyKeys];
		if ([properties isEqualToDictionary:anImageProperties])
		{
			result = aPropertiesObject;
			break;
		}
	}
	
	return result;
}

@end
