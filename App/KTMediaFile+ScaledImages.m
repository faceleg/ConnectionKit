//
//  KTMediaFile+ScaledImages.m
//  Marvel
//
//  Created by Mike on 22/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTMediaFile+ScaledImages.h"
#import "KTMediaFile+Internal.h"

#import "KTImageScalingSettings.h"
#import "KTMediaManager+Internal.h"
#import "KTScaledImageProperties.h"

#import "CIImage+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSString+Karelia.h"

#import <QuartzCore/QuartzCore.h>
#import <QTKit/QTKit.h>
#import <Connection/KTLog.h>

#import "Debug.h"


@interface QTMovie (iMediaHack)
- (NSImage *)betterPosterImage;
@end


@interface KTMediaFile (ScaledImagesPrivate)

- (NSString *)UTIForImage:(NSImage *)image scalingProperties:(NSDictionary *)properties;
- (NSString *)filenameExtensionForScaledImageOfType:(NSString *)UTI;

// Generation
- (KTScaledImageProperties *)generateImageUsingCoreImageWithProperties:(NSDictionary *)properties;

- (KTScaledImageProperties *)generateImageUsingQTKitWithProperties:(NSDictionary *)properties;
- (NSImage *)moviePosterImage;

- (KTScaledImageProperties *)generateImageFromFileIconWithProperties:(NSDictionary *)properties;


// Canonical
- (KTImageScalingSettings *)canonicalScalingSettingsForSettings:(KTImageScalingSettings *)settings;


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
		NSDictionary *canonicalProperties = [self canonicalImagePropertiesForProperties:properties];
		
		// Search for an existing match
		result = [self anyScaledImageWithProperties:canonicalProperties];
		if (!result)
		{
			result = [self generateImageUsingCoreImageWithProperties:canonicalProperties];
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
	OBPRECONDITION(image);
    OBPRECONDITION(properties);
    
    
    // Scale the image
	KTImageScalingSettings *scalingBehavior = [properties objectForKey:@"scalingBehavior"];
	[image normalizeSize];
	NSBitmapImageRep *scaledImage = [image bitmapByScalingWithBehavior:scalingBehavior];
    OBASSERT(scaledImage);
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
    OBASSERT(finalImage);
	
	
	// Figure out the UTI
	NSString *UTI = [self UTIForImage:finalImage scalingProperties:properties];
	NSString *extension = [self filenameExtensionForScaledImageOfType:UTI];
	
	
	// Create the MediaFile
	KTMediaManager *mediaManager = [self mediaManager];
	NSString *preferredFilename = [[self preferredFileName] stringByAppendingPathExtension:extension];
	NSData *imageData = [finalImage representationForUTI:UTI];
	KTInDocumentMediaFile *mediaFile = [mediaManager mediaFileWithData:imageData preferredFilename:preferredFilename];
	
	
	// Connect the MediaFile up to ourself to record how it was created
	KTScaledImageProperties *result = [KTScaledImageProperties connectSourceFile:self
																		  toFile:mediaFile
																  withProperties:properties];
	
	
	return result;
}

- (NSString *)UTIForImage:(NSImage *)image scalingProperties:(NSDictionary *)properties
{
	OBPRECONDITION(image);
	OBPRECONDITION(properties);
	
	
	// If the properties specify a UTI, use that. Otherwise, go by the user's prefs.
	NSString *result = [properties objectForKey:@"fileType"];
	if (!result)
	{
		result = [image preferredFormatUTI];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

/*	For a scaled image of the specified type, what filename extension should be used?
 *	When the original matches, use its extension, otherwise, use the default for the type.
 */
- (NSString *)filenameExtensionForScaledImageOfType:(NSString *)UTI
{
	OBPRECONDITION(UTI);
	
	NSString *result;
	if ([UTI isEqualToUTI:[self fileType]])
	{
		result = [[self currentPath] pathExtension];
	}
	else
	{
		result = [NSString filenameExtensionForUTI:UTI];
	}
	
	OBPOSTCONDITION(result);
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
		NSString *message = [NSString stringWithFormat:@"%@\rThe image could not be read into memory for scaling",
													   [imagePath stringByAbbreviatingWithTildeInPath]];
		KTLog(KTMediaLogDomain, KTLogError, message);
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
		NSString *message = [NSString stringWithFormat:@"error: unable to read movie for a thumbnail from %@: %@", 
													   [self currentPath],
													   [error localizedDescription]];
		KTLog(KTMediaLogDomain, KTLogError, message);
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

	OBASSERTSTRING(result, @"Could not generate movie thumbnail");
	
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
#pragma mark Canonical Scaling Properties

/*	Takes some properties and makes them suitable for the media system to search and generate images with.
 *  Returns scaleFactor = 1.0 if the settings will result in no change to the image.
 */ 
- (NSDictionary *)canonicalImagePropertiesForProperties:(NSDictionary *)properties
{
	NSMutableDictionary *buffer = [[NSMutableDictionary alloc] initWithDictionary:properties];
	
	
	// Figure the canonical scaling specification
	KTImageScalingSettings *specifiedScalingSettings = [properties objectForKey:@"scalingBehavior"];
    KTImageScalingSettings *canonicalScalingSettings = [self canonicalScalingSettingsForSettings:specifiedScalingSettings];
    [buffer setObject:canonicalScalingSettings forKey:@"scalingBehavior"];
    
    
    // Unless the requested scaling will result in no change, figure out what to apply for the other settings
    if ([canonicalScalingSettings behavior] == KTScaleByFactor && [canonicalScalingSettings scaleFactor] == 1.0)
    {
        // For GIF images, when no scaling is required, we logically want to maintain the file format
        if ([[self fileType] conformsToUTI:(NSString *)kUTTypeGIF])
        {
            [buffer setObject:(NSString *)kUTTypeGIF forKey:@"fileType"];
        }
    }
    else
    {
        // It's OK to leave fileType as nil
        
        
        // Ensure there is a compression setting
        NSNumber *compression = [properties objectForKey:@"compression"];
        if (!compression || (id)compression == [NSNull null])
        {
            compression = [[NSUserDefaults standardUserDefaults] objectForKey:@"KTPreferredJPEGQuality"];
            [buffer setObject:compression forKey:@"compression"];
        }
        
        
        // Ensure there is a sharpening factor
        NSNumber *sharpening = [properties objectForKey:@"sharpeningFactor"];
        if (!sharpening || (id)sharpening == [NSNull null])
        {
            sharpening = [[NSUserDefaults standardUserDefaults] objectForKey:@"KTSharpeningFactor"];
            [buffer setObject:sharpening forKey:@"sharpeningFactor"];
        }
    }
	
	
	// Tidy up
	NSDictionary *result = [[buffer copy] autorelease];
    [buffer release];
	return result;
}

/*  Support method to handle the scaling aspect of the previous method.
 */
- (KTImageScalingSettings *)canonicalScalingSettingsForSettings:(KTImageScalingSettings *)settings
{
    OBPRECONDITION(settings);
    
    
    // CropToSize operations are already sorted
    KTMediaScalingOperation behavior = [settings behavior];
    if (behavior == KTCropToSize)
    {
        return settings;
    }
    
    
    // Scale by a factor of 1.0 is already sorted
    if (behavior == KTScaleByFactor && [settings scaleFactor] == 1.0)
    {
        return settings;
    }
    
    
    // Convert wishy washy behaviours (scaleByFactor, scaleToSize) to a definite stretch operation
    if (behavior != KTStretchToSize)
    {
        NSSize suggestedSize = [settings scaledSizeForImageOfSize:[self dimensions]];
        NSSize roundedSize = NSMakeSize(roundf(suggestedSize.width), roundf(suggestedSize.height));
        
        settings = [KTImageScalingSettings settingsWithBehavior:KTStretchToSize
                                                           size:roundedSize
                                                     sharpening:nil];
    }
	
    
    // We should now have a simple stretchToFit operation.
    // Double-check that it is not equivalent to a scale by 1.0 operation
    OBASSERT([settings behavior] == KTStretchToSize);
    if (NSEqualSizes([settings size], [self dimensions]))
    {
        settings = [KTImageScalingSettings settingsWithScaleFactor:1.0 sharpening:nil];
    }
    
	
    OBPOSTCONDITION(settings);
	return settings;
}

#pragma mark -
#pragma mark Queries

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
