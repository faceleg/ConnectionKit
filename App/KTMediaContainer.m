//
//  KTMedia2.m
//  Marvel
//
//  Created by Mike on 10/10/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaContainer.h"

#import "KTScaledImageContainer.h"
#import "KTSimpleScaledImageContainer.h"
#import "KTNamedSettingsScaledImageContainer.h"

#import "KTMediaManager.h"
#import "MediaFiles+Internal.h"

#import "KTImageScalingSettings.h"
#import "BDAlias.h"
#import "KTDocument.h"
#import "NSString+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

@interface KTMediaContainer (Private)

- (KTSimpleScaledImageContainer *)existingImageWithProperties:(NSDictionary *)properties;
- (KTSimpleScaledImageContainer *)_imageWithProperties:(NSDictionary *)properties;

- (KTNamedSettingsScaledImageContainer *)existingImageWithName:(NSString *)name pluginID:(NSString *)ID;
- (KTNamedSettingsScaledImageContainer *)_imageWithScalingSettingsNamed:(NSString *)settingsName
															  forPlugin:(KTAbstractElement *)plugin;

@end


@implementation KTMediaContainer

+ (KTMediaContainer *)mediaContainerForURI:(NSURL *)mediaURI
{
	KTMediaContainer *result = nil;
	
	if ([[mediaURI scheme] isEqualToString:@"svxmedia"])
	{
		NSString *docID = [mediaURI host];
		
		NSArray *docs = [[NSDocumentController sharedDocumentController] documents];
		NSEnumerator *docsEnumerator = [docs objectEnumerator];
		KTDocument *aDoc;
		while (aDoc = [docsEnumerator nextObject])
		{
			if ([aDoc isKindOfClass:[KTDocument class]] && [[aDoc documentID] isEqualToString:docID])
			{
				KTMediaManager *mediaManager = [aDoc mediaManager];
				NSArray *pathComponents = [[mediaURI path] pathComponents];
				result = [mediaManager mediaContainerWithIdentifier:[pathComponents objectAtIndex:1]];
				break;
			}
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Core Data

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setValue:[NSString GUIDString] forKey:@"identifier"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	// Unarchive our alias
	NSData *aliasData = [self wrappedValueForKey:@"sourceAliasData"];
	if (aliasData)
	{
		[self setPrimitiveValue:[BDAlias aliasWithData:aliasData] forKey:@"sourceAlias"];
	}
}

- (void)willSave
{
    // We must store the alias's data back into the store
	[self setPrimitiveValue:[[self sourceAlias] aliasData] forKey:@"sourceAliasData"];
    
	[super willSave];
}

+ (id)objectWithArchivedIdentifier:(NSString *)identifier inDocument:(KTDocument *)document
{
	id result = [[document mediaManager] mediaContainerWithIdentifier:identifier];
	return result;
}

- (NSString *)archiveIdentifier { return [self identifier]; }

#pragma mark -
#pragma mark Accessors

- (KTMediaManager *)mediaManager { return [[[self managedObjectContext] document] mediaManager]; }

- (NSString *)identifier { return [self wrappedValueForKey:@"identifier"]; }

/*	Ensure that once it has been set the identifier cannot be changed.
 */
- (void)setIdentifier:(NSString *)identifier
{
	if ([self identifier])
	{
		[NSException raise:NSInvalidArgumentException
					format:@"-[KTMediaContainer identifier] is immutable"];
	}
	else
	{
		[self setWrappedValue:identifier forKey:@"identifier"];
	}
}

/*	A URI representation of the receiver than can be used to refer to the receiver later. Of the form:
 *
 *		svxmedia://document-id/media-identifer
 */
- (NSURL *)URIRepresentation
{
	KTDocument *document = [[self managedObjectContext] document];
	
	NSString *URLString = [NSString stringWithFormat:@"svxmedia://%@/%@",	
													 [document documentID],
													 [self identifier]];
	
	NSURL *result = [NSURL URLWithString:URLString];
	return result;
}

- (BDAlias *)sourceAlias
{
	return [self wrappedValueForKey:@"sourceAlias"];
}

- (void)setSourceAlias:(BDAlias *)alias
{
	[self setWrappedValue:alias forKey:@"sourceAlias"];
}

- (KTAbstractMediaFile *)file { return [self wrappedValueForKey:@"file"]; }

#pragma mark -
#pragma mark Scaled Images

- (KTMediaContainer *)scaledImageWithProperties:(NSDictionary *)properties;
{
	// Look for an existing scaled image
	KTMediaContainer *result = [self existingImageWithProperties:properties];
	
	// If none is found, create a new one
	if (!result)
	{
		result = [self _imageWithProperties:properties];
	}
	
	
	return result;
}

- (KTMediaContainer *)imageWithScalingSettings:(KTImageScalingSettings *)settings
{
	NSDictionary *properties = [NSDictionary dictionaryWithObject:settings forKey:@"scalingBehavior"];
	KTMediaContainer *result = [self scaledImageWithProperties:properties];
	return result;
}

- (KTMediaContainer *)imageWithScaleFactor:(float)scaleFactor
{
	KTImageScalingSettings *settings = [KTImageScalingSettings settingsWithScaleFactor:scaleFactor
																			sharpening:nil];
	
	KTMediaContainer *result = [self imageWithScalingSettings:settings];
													
	return result;
}

- (KTMediaContainer *)imageToFitSize:(NSSize)size
{
	KTImageScalingSettings *settings =
		[KTImageScalingSettings settingsWithBehavior:KTScaleToSize size:size sharpening:nil];
	
	KTMediaContainer *result = [self imageWithScalingSettings:settings];
													
	return result;
}

- (KTMediaContainer *)imageCroppedToSize:(NSSize)size alignment:(NSImageAlignment)alignment
{
	KTImageScalingSettings *settings = [KTImageScalingSettings cropToSize:size alignment:alignment];
	
	KTMediaContainer *result = [self imageWithScalingSettings:settings];
	return result;
}

- (KTMediaContainer *)imageStretchedToSize:(NSSize)size
{
	KTImageScalingSettings *settings =
		[KTImageScalingSettings settingsWithBehavior:KTStretchToSize size:size sharpening:nil];
	
	KTMediaContainer *result = [self imageWithScalingSettings:settings];
													
	return result;
}

#pragma mark support

- (KTSimpleScaledImageContainer *)existingImageWithProperties:(NSDictionary *)properties
{
	NSParameterAssert(properties);
	
	KTSimpleScaledImageContainer *result = nil;
	
	NSSet *existingScaledImages = [self valueForKey:@"scaledImages"];
	NSEnumerator *scaledImagesEnumerator = [existingScaledImages objectEnumerator];
	KTScaledImageContainer *aScaledImage;
	while (aScaledImage = [scaledImagesEnumerator nextObject])
	{
		if ([aScaledImage isKindOfClass:[KTSimpleScaledImageContainer class]] &&
			[properties isEqualToDictionary:[aScaledImage latestProperties]])
		{
			result = (KTSimpleScaledImageContainer *)aScaledImage;
			break;
		}
	}
	
	return result;
}

/*	Does the hard work of creating new media containers.
 *	The result is a MediaContainer paired with an appropriate MediaFile.
 */
- (KTSimpleScaledImageContainer *)_imageWithProperties:(NSDictionary *)properties
{
	// Create the media container first
	KTSimpleScaledImageContainer *result =
		[NSEntityDescription insertNewObjectForEntityForName:@"SimpleScaledImageContainer"
									  inManagedObjectContext:[self managedObjectContext]];
	
	[result setValue:self forKey:@"sourceMedia"];
	[result setValuesForKeysWithDictionary:properties];
	
	// Finish
	return result;
}

#pragma mark -
#pragma mark Named Settings

- (KTMediaContainer *)imageWithScalingSettingsNamed:(NSString *)settingsName
										  forPlugin:(KTAbstractElement *)plugin;
{
	// Look for an existing scaled image of the name
	KTMediaContainer *result = [self existingImageWithName:settingsName pluginID:[plugin uniqueID]];
	if (!result)
	{
		result = [KTNamedSettingsScaledImageContainer imageWithScalingSettingsNamed:settingsName
																		  forPlugin:plugin
																		sourceMedia:self];
	}
	
	return result;
}

- (KTNamedSettingsScaledImageContainer *)existingImageWithName:(NSString *)name pluginID:(NSString *)ID;
{
	KTNamedSettingsScaledImageContainer *result = nil;
	
	NSSet *existingScaledImages = [self valueForKey:@"scaledImages"];
	NSEnumerator *scaledImagesEnumerator = [existingScaledImages objectEnumerator];
	KTScaledImageContainer *aScaledImage;
	while (aScaledImage = [scaledImagesEnumerator nextObject])
	{
		if ([aScaledImage isKindOfClass:[KTSimpleScaledImageContainer class]] &&
			[[aScaledImage valueForKey:@"pluginID"] isEqualToString:ID] &&
			[[aScaledImage valueForKey:@"scalingSettingsName"] isEqualToString:name])
		{
			result = (KTNamedSettingsScaledImageContainer *)aScaledImage;
			break;
		}
	}
	
	return result;
}

@end
