//
//  KTMediaManager2.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaManager.h"
#import "KTMediaManager+Internal.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTMediaFile.h"
#import "KTMediaContainer.h"
#import "KTSite.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSURL+Karelia.h"

#import <Connection/KTLog.h>
#import "BDAlias.h"

#import "Debug.h"


NSString *KTMediaLogDomain = @"Media";


@interface KTMediaManager ()
// GC
- (void)garbageCollectMediaContainers;
- (NSArray *)mediaFilesForDeletion;
- (NSSet *)mediaIdentifiersRequiredByEntity:(NSString *)entityName;
- (NSSet *)_buildSetFromResultOfPerformSelector:(SEL)selector onAllObjectsOfEntityName:(NSString *)entityName;
@end


#pragma mark -


@implementation KTMediaManager

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithDocument:(KTDocument *)document
{
	[super init];
	
	_document = document;	// Weak ref
	_deletedMediaDirectoryName = [[[NSProcessInfo processInfo] globallyUniqueString] copy];
    
    
    // Reserve all the media filenames already in use
    NSArray *media = [self externalMediaFiles]; // FIXME: fetch the correct set of objects
    for (KTMediaFile *aMediaFile in media)
    {
        NSString *filename = [aMediaFile filename];
        if (filename) [document replaceObjectForFilename:filename withObject:aMediaFile];
    }
	
    return self;
    
	
    
    // We don't want to make undo/redo available to the user, but do want it to record the doc changed status
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(undoGroupWillClose:)
                                                 name:NSUndoManagerWillCloseUndoGroupNotification
                                               object:[[self managedObjectContext] undoManager]];
    
	
    return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [myMediaContainerIdentifiersCache release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

+ (NSString *)defaultMediaStoreType { return NSXMLStoreType; }

/*	Convenience method for accessing our MOC's associated MOM
 */
+ (NSManagedObjectModel *)managedObjectModel
{
	static NSManagedObjectModel *result;
	
	if (!result)
	{
		NSURL *mediaModelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Media" ofType:@"mom"]];
		result = [[NSManagedObjectModel alloc] initWithContentsOfURL:mediaModelURL];
	}
	
	return result;
}

- (KTDocument *)document { return _document; }

/*	The Media Manager has its own private managed object context
 */
- (NSManagedObjectContext *)managedObjectContext { return [[self document] managedObjectContext]; }

+ (NSURL *)mediaStoreURLForDocumentURL:(NSURL *)docURL
{
	OBASSERT(docURL);
	
	NSURL *result = [docURL URLByAppendingPathComponent:@"media.xml" isDirectory:NO];
	
	OBPOSTCONDITION(result);
	return result;
}

/*	Temporary media is stored in:
 *	
 *		Application Support -> Sandvox -> Temporary Media Files -> Document ID -> a file
 *
 *	This method returns the path to that directory, creating it if necessary.
 */
- (NSURL *)deletedMediaDirectory;
{	
    NSURL *sandvoxSupportDirectory = [NSURL fileURLWithPath:[NSApplication applicationSupportPath]
                                                isDirectory:YES];
    NSURL *allDeletedMediaDirectory = [sandvoxSupportDirectory URLByAppendingPathComponent:@"Deleted Media"
                                                                               isDirectory:YES];
	NSURL *result = [allDeletedMediaDirectory URLByAppendingPathComponent:_deletedMediaDirectoryName
                                                              isDirectory:YES];
	
	// Create the directory if needs be
	[[NSFileManager defaultManager] createDirectoryAtPath:[result path]
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:NULL];
    
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Document Change Status

- (void)undoGroupWillClose:(NSNotification *)notification
{
    NSUndoManager *undoManager = [notification object];
    if (undoManager == [[self managedObjectContext] undoManager])
    {
        if ([undoManager groupingLevel] == 1)
        {
            /*KTDocument *document = [self document];
            if (![document isClosing])
            {
                [document updateChangeCount:NSChangeDone];
            }*/
        }
    }
}

#pragma mark -
#pragma mark Missing media

- (NSSet *)missingMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
    return result;
    
    
    
    
	
	NSEnumerator *mediaFileEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if (!path ||
            [path isEqualToString:@""] ||
            [path isEqualToString:[[NSBundle mainBundle] pathForImageResource:@"qmark"]] ||
            ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			if ([(NSSet *)[aMediaFile valueForKey:@"containers"] count] > 0)
            {
                [result addObject:aMediaFile];
            }
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Garbage Collector

/*	Does something along these lines:
 *		0. Delete uneeded MediaContainers
 *		1. Gather up the AbstractMediaFiles to be deleted and remove them from the DB
 *		2. Move all deleted AbstractMediaFiles back to the temp media folder
 */
- (void)garbageCollect
{
	KTLog(KTMediaLogDomain, KTLogDebug, @"Beginning media garbage collection...");
	

	// Collect MediaContainers
	[self garbageCollectMediaContainers];
	    
    
	// Garbage collect AbstractMediaFiles
	NSArray *mediaFilesForDeletion = [self mediaFilesForDeletion];
	KTLog(KTMediaLogDomain, KTLogDebug, @"Deleting %u unwanted MediaFile(s)", [mediaFilesForDeletion count]);
	
	NSEnumerator *mediaFilesEnumerator = [mediaFilesForDeletion objectEnumerator];
	KTMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		[[self managedObjectContext] deleteObject:aMediaFile];
	}
}

- (void)garbageCollectMediaContainers
{
	KTLog(KTMediaLogDomain, KTLogDebug, @"Collecting unneeded MediaContainers...");
	
	NSSet *pageMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Page"];
	NSSet *pageletMediaIDs = [NSSet set];//[self mediaIdentifiersRequiredByEntity:@"OldPagelet"];
	NSSet *masterMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Master"];
	
	NSMutableSet *requiredMediaIDs =
	[[NSMutableSet alloc] initWithCapacity:([pageMediaIDs count] + [masterMediaIDs count] + [pageletMediaIDs count])];
	[requiredMediaIDs unionSet:pageMediaIDs];
	[requiredMediaIDs unionSet:masterMediaIDs];
	[requiredMediaIDs unionSet:pageletMediaIDs];
	
	
	// Get the list of all MediaContainer entities and narrow it down to those that aren't required.
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"scaledImages.@count == 0"];
    NSError *error = nil;
	NSArray *allMedia = [[self managedObjectContext] objectsWithEntityName:@"MediaContainer" predicate:predicate error:&error];
	
    NSEnumerator *mediaEnumerator = [allMedia objectEnumerator];
	NSManagedObject *aMedia;
	NSMutableSet *unrequiredMedia = [[NSMutableSet alloc] init];
	while (aMedia = [mediaEnumerator nextObject])
	{
		if (![requiredMediaIDs containsObject:[aMedia valueForKey:@"identifier"]])
		{
			[unrequiredMedia addObject:aMedia];
		}
	}
	
	// Delete those unrequired media IDs
	KTLog(KTMediaLogDomain, KTLogDebug, @"Removing %u unneeded MediaContainer(s)", [unrequiredMedia count]);
	NSEnumerator *unrequiredMediaEnumerator = [unrequiredMedia objectEnumerator];
	while (aMedia = [unrequiredMediaEnumerator nextObject])
	{
		[[self managedObjectContext] deleteObject:aMedia];
	}
	
	[unrequiredMedia release];
	[requiredMediaIDs release];
}

- (NSArray *)mediaFilesForDeletion
{
	NSFetchRequest *fetchRequest = [[[self class] managedObjectModel] fetchRequestTemplateForName:@"DeadMediaFiles"];
	
	NSError *error = nil;
	NSArray *deadMediaFiles = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	
	KTLog(KTMediaLogDomain, KTLogDebug, @"Found %u unwanted MediaFile(s) for deletion", [deadMediaFiles count]);
	return deadMediaFiles;
}

/*	Specify an entity (e.g. KTAbstractElement) and this will return all the KTMedia2 objects they require
 */
- (NSSet *)mediaIdentifiersRequiredByEntity:(NSString *)entityName
{
	NSSet *result = [self _buildSetFromResultOfPerformSelector:@selector(requiredMediaIdentifiers)
									  onAllObjectsOfEntityName:entityName];
	
	return result;
}

- (NSSet *)_buildSetFromResultOfPerformSelector:(SEL)selector onAllObjectsOfEntityName:(NSString *)entityName
{
	NSMutableSet *result = [NSMutableSet set];
	
	// Fetch all objects of that entity
	NSManagedObjectContext *docMOC = [[self document] managedObjectContext];
	NSError *error = nil;
	NSArray *allObjects = [docMOC allObjectsWithEntityName:entityName error:&error];
	if (error) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert setIcon:[NSApp applicationIconImage]];
		[alert runModal];	
	}
	
	// Run through the objects asking for their media
	NSEnumerator *enumerator = [allObjects objectEnumerator];
	id anObject;
	while (anObject = [enumerator nextObject])
	{
		[result unionSet:[anObject performSelector:selector]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Document close

/*	Simply deletes the temp media folder associated with our document
 */
- (void)deleteTemporaryMediaFiles
{
	KTLog(KTMediaLogDomain, KTLogDebug, @"Deleting the temporary media directory for the document at:\n%@", [[self document] fileURL]);
	NSString *tempMedia = [[self deletedMediaDirectory] path];
	[[NSFileManager defaultManager] removeFileAtPath:tempMedia handler:self];
}

#pragma mark -
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\n%@", errorInfo]));
	return NO;
}

@end


#pragma mark -


@interface KTMediaManager (MediaContainerSecretsIKnow)
- (KTMediaContainer *)insertNewMediaContainer;
@end


@implementation KTMediaManager (LegacySupport)

typedef enum {
    KTMediaCopyAliasStorage = 10, 
    KTMediaCopyContentsStorage, // default, stores a copy of the file in the datastore
    KTMediaCopyFileStorage,
	KTMediaPlaceholderStorage	// a singleton
} KTMediaStorageType;


- (KTMediaContainer *)mediaContainerWithMediaRefNamed:(NSString *)oldMediaRefName element:(NSManagedObject *)oldElement
{
    KTMediaContainer *result = nil;
    
    /// BUGSID:35057	Some 1.2 docs have a media ref with no corresponding media entry. This raises a Core Data
	///					exception. We handle it by replacing with empty media
	@try
	{
		// Locate the media ref for the name
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@ AND owner == %@", oldMediaRefName, oldElement];
		NSManagedObject *mediaRef = [[[oldElement managedObjectContext] objectsWithEntityName:@"MediaRef" predicate:predicate error:NULL] firstObjectKS];
        
		
		// Look up the media object
		if (mediaRef)
		{
			NSManagedObject *oldMedia = [mediaRef valueForKey:@"media"];
			
			// Import either data or a path
			NSData *oldMediaData = [oldMedia valueForKeyPath:@"mediaData.contents"];
			NSString *oldMediaUTI = [oldMedia valueForKey:@"mediaUTI"];
			if ([oldMedia integerForKey:@"storageType"] == KTMediaCopyAliasStorage)
			{
				BDAlias *alias = [BDAlias aliasWithData:oldMediaData];
				NSString *path = [alias fullPath];
				if (path)
				{
					result = [self mediaContainerWithPath:path];
				}
				else
				{
					// We'll construct the MediaFile ourself to account for missing media
					result = [self insertNewMediaContainer];
					[result setSourceAlias:alias];
					
					KTMediaFile *mediaFile = [KTMediaFile insertNewMediaFileWithAlias:alias
																	   inManagedObjectContext:[self managedObjectContext]];
					[result setValue:mediaFile forKey:@"file"];
				}
			}
			else
			{
				NSString *mediaFileName = [oldMedia valueForKey:@"name"];
				
				result = [self mediaContainerWithData:oldMediaData
											 filename:mediaFileName
												  UTI:oldMediaUTI];
				
				
				// This may fail fail as some UTIs do not have an associated file extension (namely com.pkware.zip-archive grrrrr).
				// If so, go back to the original path
				if (!result)
				{
					NSString *fileExtension = [[oldMedia valueForKey:@"originalPath"] pathExtension];
					if (!fileExtension || [fileExtension isEqualToString:@""])
					{
						fileExtension = [mediaFileName pathExtension];
						mediaFileName = [mediaFileName stringByDeletingPathExtension];
					}
					
					if (fileExtension && ![fileExtension isEqualToString:@""])
					{
						result = [self mediaContainerWithData:oldMediaData
													 filename:mediaFileName
												fileExtension:fileExtension];
					}
				}
			}
			
			
			// There is potentially some rather large chunks of memory tied up by the old media, so turn into a fault
			[[mediaRef managedObjectContext] refreshObject:oldMedia mergeChanges:NO];
			[[mediaRef managedObjectContext] refreshObject:mediaRef mergeChanges:NO];
		}
		
    }
	@catch (NSException *exception)
	{
		result = nil;
	}
	
	
    return result;
}

- (NSString *)importLegacyMediaFromString:(NSString *)oldText
                      scalingSettingsName:(NSString *)scalingSettings
                               oldElement:(NSManagedObject *)oldElement
                               newElement:(KTAbstractElement *)newElement
{
    NSMutableString *buffer = [[NSMutableString alloc] init];

	if (oldText)
	{
		NSScanner *imageScanner = [[NSScanner alloc] initWithString:oldText];
		
		while (![imageScanner isAtEnd])
		{
			// Look for an image tag
			NSString *someText = nil;
			[imageScanner scanUpToString:@"<img" intoString:&someText];
            if (someText) [buffer appendString:someText];
			if ([imageScanner isAtEnd]) break;
			
			
			// Locate the image's source attribute
			if (![imageScanner scanUpToString:@"src=\"" intoString:&someText]) break;
			[buffer appendString:someText];
			if (![imageScanner scanString:@"src=\"" intoString:&someText]) break;
			[buffer appendString:someText];
			
			NSString *imageURLString = nil;
			[imageScanner scanUpToString:@"\"" intoString:&imageURLString];
			
			if (imageURLString)
			{
				// Look for a media ref or media within the URI
				NSURL *imageURL = [NSURL URLWithString:imageURLString];
                
                NSArray *pathComponents = [[imageURL path] pathComponents];
                if ([pathComponents count] >= 3 && [[pathComponents objectAtIndex:1] isEqualToString:@"_Media"])
                {
                    NSString *mediaRef = [[imageURL queryDictionary] objectForKey:@"ref"];
                    if (!mediaRef)
                    {
                        // This is a REALLY old media URL. Fallback to filename
                        mediaRef = [[pathComponents objectAtIndex:2] stringByDeletingPathExtension];
                    }
                    
                    if (mediaRef)
                    {
                        KTMediaContainer *anImage = [self mediaContainerWithMediaRefNamed:mediaRef element:oldElement];
                        anImage = [anImage imageWithScalingSettingsNamed:scalingSettings forPlugin:newElement];
                        imageURLString = [[anImage URIRepresentation] absoluteString];
                    }
                }
                
               				
				// Store the new image URI. This could be:
				//	A) An external URL
				//	B) A svxmedia: URL
				//	C) In the event that a media container could not be created, nil.
				if (imageURLString) [buffer appendString:imageURLString];
			}
		}
		
		[imageScanner release];
    }
    
    NSString *result = [[buffer copy] autorelease];
    [buffer release];
    return result;
}

@end
