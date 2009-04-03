//
//  KTMedia2.m
//  Marvel
//
//  Created by Mike on 10/10/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaContainer.h"

#import "KTScaledImageContainer.h"
#import "KTSimpleScaledImageContainer.h"
#import "KTNamedSettingsScaledImageContainer.h"
#import "KTGraphicalTextMediaContainer.h"

#import "KTMediaManager.h"
#import "KTMediaPersistentStoreCoordinator.h"

#import "KTImageScalingSettings.h"
#import "BDAlias.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"

#import "NSString+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSSet+Karelia.h"


@interface KTMediaContainer (Private)

- (KTSimpleScaledImageContainer *)existingImageWithProperties:(NSDictionary *)properties;
- (KTSimpleScaledImageContainer *)_imageWithProperties:(NSDictionary *)properties;

- (KTNamedSettingsScaledImageContainer *)existingImageWithName:(NSString *)name pluginID:(NSString *)ID;
- (KTNamedSettingsScaledImageContainer *)_imageWithScalingSettingsNamed:(NSString *)settingsName
															  forPlugin:(KTAbstractElement *)plugin;

@end


#pragma mark -


@implementation KTMediaContainer

#pragma mark -
#pragma mark Class Methods

+ (KTMediaContainer *)mediaContainerForURI:(NSURL *)mediaURI
{
	KTMediaContainer *result = nil;
	
	if ([[mediaURI scheme] isEqualToString:@"svxmedia"])
	{
		NSString *docID = [mediaURI host];
		NSString *mediaIdentifier = [self mediaContainerIdentifierForURI:mediaURI];
		
		
		// Search for suitable documents
		NSArray *openDocuments = [[NSDocumentController sharedDocumentController] documents];
		NSMutableArray *matchingDocs = [NSMutableArray array];
		
		NSEnumerator *docsEnumerator = [openDocuments objectEnumerator];
		KTDocument *aDoc;
		while (aDoc = [docsEnumerator nextObject])
		{
			if ([aDoc isKindOfClass:[KTDocument class]] && [[[aDoc documentInfo] siteID] isEqualToString:docID])
			{
				[matchingDocs addObject:aDoc];
			}
		}
		
		
		// In the event that no docs with that ID were found, fallback to searching all of them
		if ([matchingDocs count] == 0)
		{
			[matchingDocs setArray:openDocuments];
		}
		
		
		// Search each matching doc for the media
		docsEnumerator = [matchingDocs objectEnumerator];
		while (aDoc = [docsEnumerator nextObject])
		{
			if ([aDoc isKindOfClass:[KTDocument class]])
			{
				KTMediaManager *mediaManager = [aDoc mediaManager];
				result = [mediaManager mediaContainerWithIdentifier:mediaIdentifier];
				if (result) break;
			}
		}
	}
	
	return result;
}

+ (NSSet *)mediaContainerIdentifiersInHTML:(NSString *)HTML
{
    NSMutableSet *buffer = [[NSMutableSet alloc] init];
    if (HTML)
	{
		NSScanner *imageScanner = [[NSScanner alloc] initWithString:HTML];
		while (![imageScanner isAtEnd])
		{
			// Look for an image tag
			[imageScanner scanUpToString:@"<img" intoString:NULL];
			if ([imageScanner isAtEnd]) break;
			
			
			// Locate the image's source attribute
			[imageScanner scanUpToString:@"src=\"" intoString:NULL];
			[imageScanner scanString:@"src=\"" intoString:NULL];
			
			NSString *aMediaURIString = nil;
			if ([imageScanner scanUpToString:@"\"" intoString:&aMediaURIString])
			{
				NSURL *aMediaURI = [[NSURL alloc] initWithString:aMediaURIString];
				[buffer addObjectIgnoringNil:[self mediaContainerIdentifierForURI:aMediaURI]];
				[aMediaURI release];
			}
		}    
		
		[imageScanner release];
	}
    
    NSSet *result = [[buffer copy] autorelease];
    [buffer release];
    return result;
}

+ (NSString *)mediaContainerIdentifierForURI:(NSURL *)mediaURI
{
    NSString *result = nil;
    
    if ([[mediaURI scheme] isEqualToString:@"svxmedia"])
	{
        NSArray *pathComponents = [[mediaURI path] pathComponents];
        if ([pathComponents count] == 2)
        {
            result = [pathComponents objectAtIndex:1];
        }
    }
    
    return result;
}

#pragma mark -
#pragma mark Core Data

- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	[self setValue:[NSString UUIDString] forKey:@"identifier"];
}

- (void)awakeFromFetch
{
	[super awakeFromFetch];
	
	// Unarchive our alias
	if (![self isKindOfClass:[KTGraphicalTextMediaContainer class]])
	{
		NSData *aliasData = [self wrappedValueForKey:@"sourceAliasData"];
		if (aliasData)
		{
			[self setPrimitiveValue:[BDAlias aliasWithData:aliasData] forKey:@"sourceAlias"];
		}
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

- (KTMediaManager *)mediaManager
{
	KTMediaManager *result = [(KTMediaPersistentStoreCoordinator *)[[self managedObjectContext] persistentStoreCoordinator] mediaManager];
	OBPOSTCONDITION(result);
	return result;
}

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
	KTDocument *document = [[self mediaManager] document];
	
	NSString *URLString = [NSString stringWithFormat:@"svxmedia://%@/%@",	
													 [[document documentInfo] siteID],
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

- (KTMediaFile *)file { return [self wrappedValueForKey:@"file"]; }

/*  Compatibility method for scaled image containers. We just return our file, but subclasses
 *  search up their hierarchy looking for the topmost file
 */
- (KTMediaFile *)sourceMediaFile
{
    KTMediaFile *result = [self file];
    return result;
}

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
	
    
	OBPOSTCONDITION(result);
    OBPOSTCONDITION([result managedObjectContext]);
    
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
	KTImageScalingSettings *settings = [KTImageScalingSettings settingsWithScaleFactor:scaleFactor];
	
	KTMediaContainer *result = [self imageWithScalingSettings:settings];
													
	return result;
}

- (KTMediaContainer *)imageToFitSize:(NSSize)size
{
	KTImageScalingSettings *settings =
		[KTImageScalingSettings settingsWithBehavior:KTScaleToSize size:size];
	
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
		[KTImageScalingSettings settingsWithBehavior:KTStretchToSize size:size];
	
	KTMediaContainer *result = [self imageWithScalingSettings:settings];
													
	return result;
}

#pragma mark support

- (KTSimpleScaledImageContainer *)existingImageWithProperties:(NSDictionary *)properties
{
	OBPRECONDITION(properties);
	
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
	OBPRECONDITION(properties);
    OBPRECONDITION([properties objectForKey:@"scalingBehavior"]);
    
    
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
