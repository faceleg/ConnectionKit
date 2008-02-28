//
//  KTMediaManager2.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaManager+Internal.h"

#import "Debug.h"
#import "KT.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTExternalMediaFile.h"
#import "KTInDocumentMediaFile.h"
#import "KTMediaContainer.h"
#import "KTMediaManager.h"
#import "MediaFiles+Internal.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"

#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"


@interface KTMediaManager (Private)

// MediaContainer Creation
- (KTMediaContainer *)insertMediaContainer;

// New media files
- (KTAbstractMediaFile *)mediaFileWithPath:(NSString *)path keepExternal:(BOOL)isExternal;

- (KTInDocumentMediaFile *)temporaryMediaFileWithPath:(NSString *)path;
- (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path;

- (KTExternalMediaFile *)externalMediaFileWithPath:(NSString *)path;

@end


@implementation KTMediaManager

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithDocument:(KTDocument *)document
{
	[super init];
	
	myDocument = document;	// Weak ref
	
	
	// Set up our MOC
	myMOC = [[NSManagedObjectContext alloc] init];
	[myMOC setUndoManager:nil];	// You can't auto-undo media stuff
	
	NSString *mediaModelPath = [[NSBundle mainBundle] pathForResource:@"Media" ofType:@"mom"];
	NSManagedObjectModel *mediaModel = [NSManagedObjectModel modelWithPath:mediaModelPath];
	
	NSPersistentStoreCoordinator *mediaPSC =
		[[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mediaModel];
	[myMOC setPersistentStoreCoordinator:mediaPSC];
	[mediaPSC release];
	
	
	return self;
}

- (void)dealloc
{
	[myMOC release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTDocument *)document { return myDocument; }

/*	The Media Manager has its own prviate managed object context
 */
- (NSManagedObjectContext *)managedObjectContext { return myMOC; }

/*	Convenience method for accessing our MOC's associated MOM
 */
- (NSManagedObjectModel *)managedObjectModel
{
	NSManagedObjectModel *result = [[[self managedObjectContext] persistentStoreCoordinator] managedObjectModel];
	return result;
}

#pragma mark -
#pragma mark MediaContainer Creation

/*	Locates the KTMediaContainer object with the specified identifier. Returns nil if none is found.
 */
- (KTMediaContainer *)mediaContainerWithIdentifier:(NSString *)identifier
{
	KTMediaContainer *result = nil;
	
	if (identifier)
	{
		// Fetch first possible match
		NSFetchRequest *fetchRequest =
			[[self managedObjectModel] fetchRequestFromTemplateWithName:@"MediaWithIdentifier"
												   substitutionVariable:identifier forKey:@"IDENTIFIER"];
		
		[fetchRequest setFetchLimit:1];
		
		NSError *error = nil;
		NSArray *mediaFiles = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
		if (error) {
			[[NSAlert alertWithError:error] runModal];
		}
		
		result = [mediaFiles firstObjectOrNilIfEmpty];
	}
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithPath:(NSString *)path
{
	KTMediaContainer *result = [self insertMediaContainer];
	[result setSourceAlias:[BDAlias aliasWithPath:path]];
	
	KTAbstractMediaFile *mediaFile = [self mediaFileWithPath:path];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithURL:(NSURL *)aURL
{
	KTMediaContainer *result = nil;
	
	if ( [aURL isFileURL] )
	{
		NSString *path = [aURL path];
		result = [self mediaContainerWithPath:path];
	}
	
	// TODO: in theory, we might be able to create a container
	// from the net using NSURLRequest/NSURLConnection or similar
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithData:(NSData *)data filename:(NSString *)filename UTI:(NSString *)UTI;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	NSString *preferredFilename = [filename stringByAppendingPathExtension:[NSString filenameExtensionForUTI:UTI]];
	KTAbstractMediaFile *mediaFile = [self mediaFileWithData:data preferredFilename:preferredFilename];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTAbstractMediaFile *mediaFile = [self mediaFileWithImage:image];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)external;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTAbstractMediaFile *mediaFile = [self mediaFileWithDraggingInfo:info preferExternalFile:external];
	[result setValue:mediaFile forKey:@"file"];
	
	// If the drag was a file, store the source alias
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObjectOrNilIfEmpty];
		if (path)
		{
			[result setSourceAlias:[BDAlias aliasWithPath:path]];
		}
	}
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithDataSourceDictionary:(NSDictionary *)dataSource;
{
	KTMediaContainer *result = nil;
	
	// File has highest priority
	if ([dataSource objectForKey:kKTDataSourceFilePath] )
	{
		NSString *path = [dataSource objectForKey:kKTDataSourceFilePath];
		result = [self mediaContainerWithPath:path];
	}
	// data has next highest priority
	else if ([dataSource objectForKey:kKTDataSourceData])
	{
		NSData *data = [dataSource objectForKey:kKTDataSourceData];
		NSString *fileName = [[dataSource objectForKey:kKTDataSourceFileName] stringByDeletingPathExtension];
		NSString *UTI = [dataSource objectForKey:kKTDataSourceUTI];
		result = [self mediaContainerWithData:data filename:fileName UTI:UTI];
	}
	// last priority, since it has no intrinsic image type
	else if ([dataSource objectForKey:kKTDataSourceImage])
	{
		NSImage *image = [dataSource objectForKey:kKTDataSourceImage];
		result = [self mediaContainerWithImage:image];
	}
	
	return result;
}

- (KTMediaContainer *)insertMediaContainer
{
	KTMediaContainer *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaContainer"
															 inManagedObjectContext:[self managedObjectContext]];
	
	return result;
}

#pragma mark -
#pragma mark Queries

- (NSArray *)mediaFilesFromTemplate:(NSString *)templateName
{
	NSFetchRequest *fetchRequest = [[self managedObjectModel] fetchRequestTemplateForName:templateName];
	
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	
	return result;
}

/*	Performs a simple fetch of all appropriate media files.
 */
- (NSArray *)externalMediaFiles
{
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] allObjectsWithEntityName:@"ExternalMediaFile" error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	
	return result;
}

/*	NSManagedObjectContext gives us a nice list of inserted (temporary) objects. We just have to narrow it down to those of
 *	the KTExternalMediaFile class.
 */
- (NSSet *)temporaryMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *insertedObjectsEnumerator = [[[self managedObjectContext] insertedObjects] objectEnumerator];
	id anInsertedObject;
	while (anInsertedObject = [insertedObjectsEnumerator nextObject])
	{
		if ([anInsertedObject isKindOfClass:[KTInDocumentMediaFile class]])	// Ignore external media
		{
			[result addObject:anInsertedObject];
		}
	}
	
	return result;
}

/*	Returns the first available unique filename
 */
- (NSString *)uniqueInDocumentFilename:(NSString *)preferredFilename;
{
	NSString *result = preferredFilename;
	
	NSString *fileName = [preferredFilename stringByDeletingPathExtension];
	NSString *extension = [preferredFilename pathExtension];
	unsigned count = 1;
	
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	[fetchRequest setEntity:[[self managedObjectModel] entityWithName:@"InDocumentMediaFile"]];
	[fetchRequest setFetchLimit:1];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"filename LIKE[c] %@", result]];
	
	
	// Loop through, only ending when the file doesn't exist
	while ([[[self managedObjectContext] executeFetchRequest:fetchRequest error:NULL] count] > 0)
	{
		count++;
		NSString *aFileName = [NSString stringWithFormat:@"%@-%u", fileName, count];
		result = [aFileName stringByAppendingPathExtension:extension];
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"filename LIKE[c] %@", result]];
	}
	
	
	// Tidy up
	[fetchRequest release];
	return result;
}

#pragma mark -
#pragma mark MediaFile Creation

/*	Used to add new media files to the DB.
 *	The media manager will automatically decide whether to add the file as external or temporary media.
 */
- (KTAbstractMediaFile *)mediaFileWithPath:(NSString *)path
{
	KTAbstractMediaFile *result = [self mediaFileWithPath:path keepExternal:[self mediaFileShouldBeExternal:path]];
	return result;
}

/*	Basically the same as the above method, but allows the expression of a preference as to where the underlying file is stored
 */
- (KTAbstractMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal
{
	// For the time being we shall always obey the preference
	KTAbstractMediaFile *result = [self mediaFileWithPath:path keepExternal:preferExternal];
	return result;
}

/*	Does the work for the above two methods. The storage type is ALWAYS obeyed.
 */
- (KTAbstractMediaFile *)mediaFileWithPath:(NSString *)path keepExternal:(BOOL)isExternal
{
	KTAbstractMediaFile *result = nil;
	
	if (isExternal)
	{
		result = [self externalMediaFileWithPath:path];
	}
	else
	{
		result = [self temporaryMediaFileWithPath:path];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

- (KTInDocumentMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)preferredFilename
{
	KTInDocumentMediaFile *result = nil;
	
	// See if there is already a MediaFile with the same data
	NSArray *similarMediaFiles = [self inDocumentMediaFilesWithDigest:[data partiallyDigestString]];
	
	NSEnumerator *mediaFilesEnumerator = [similarMediaFiles objectEnumerator];
	KTInDocumentMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		NSData *possibleMatch = [[NSData alloc] initWithContentsOfFile:[aMediaFile currentPath]];
		if ([possibleMatch isEqualToData:data])
		{
			result = aMediaFile;
			break;
		}
		
		[possibleMatch release];
	}
	
	
	// No existing match was found so create a new MediaFile
	if (!result)
	{
		// Write out the file
		NSString *filename = [self uniqueInDocumentFilename:preferredFilename];
		NSString *destinationPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:filename];
		
		LOG((@"Creating temporary in-document MediaFile from data named '%@'", filename));
		
		NSError *error = nil;
		[data writeToFile:destinationPath options:0 error:&error];
		if (error) {
			[[NSAlert alertWithError:error] runModal];
		}
		
		// Then add the object to the DB
		result = [KTInDocumentMediaFile insertTemporaryMediaFileWithPath:destinationPath
													 inManagedObjectContext:[self managedObjectContext]];
		
		[result setValue:preferredFilename forKey:@"sourceFilename"];
	}
	
	
	return result;
}

- (KTInDocumentMediaFile *)mediaFileWithImage:(NSImage *)image
{
	// Figure out the filename to use
	NSString *imageUTI = [image preferredFormatUTI];
	NSString *extension = [NSString filenameExtensionForUTI:imageUTI];
	NSString *filename = [@"pastedImage" stringByAppendingPathExtension:extension];
	NSData *imageData = [image representationForUTI:imageUTI];
	
	KTInDocumentMediaFile *result = [self mediaFileWithData:imageData preferredFilename:filename];
	return result;
}

- (KTAbstractMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal
{
	KTAbstractMediaFile *result = nil;
	
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObjectOrNilIfEmpty];
		if (path)
		{
			result = [self mediaFileWithPath:path preferExternalFile:preferExternal];
		}
	}
	// TODO: Support stuff other than files
	
	return result;
}

#pragma mark support

/*	Look to see if there is an existing equivalent media file. If so, return that. Otherwise create a new one.
 */
- (KTInDocumentMediaFile *)temporaryMediaFileWithPath:(NSString *)path
{
	KTInDocumentMediaFile *result = nil;
	
	result = [self anyInDocumentMediaFileEqualToFile:path];
	
	if (!result)
	{
		result = [self insertTemporaryMediaFileWithPath:path];
	}
	
	return result;
}

/*	Creates a brand new entry in the DB for the media at the path.
 *	The path itself is copied to app support as a temporary store; it is moved internally at save-time.
 */
- (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path;
{
	LOG((@"Creating temporary in-document MediaFile from path:\r%@", path));
	
	// Figure out the filename and copy the file there
	NSString *sourceFilename = [path lastPathComponent];
	NSString *destinationFilename = [self uniqueInDocumentFilename:sourceFilename];
	NSString *destinationPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:destinationFilename];
	
	if (![[NSFileManager defaultManager] copyPath:path toPath:destinationPath handler:nil]) {
		[NSException raise:NSInternalInconsistencyException
					format:@"Unable to copy file:\r%@\r to %@ in the temporary media folder", path, destinationFilename];
	}	
	
	// Add the file to the DB.
	KTInDocumentMediaFile *result = [KTInDocumentMediaFile insertTemporaryMediaFileWithPath:destinationPath
												inManagedObjectContext:[self managedObjectContext]];
	
	// Store the file's source filename
	[result setValue:sourceFilename forKey:@"sourceFilename"];
	
	return result;

}

/*	Returns a MediaFile that is set to only reference the specified path.
 *	This may be an existing media file from the same source or a new one.
 */
- (KTExternalMediaFile *)externalMediaFileWithPath:(NSString *)path
{
	KTExternalMediaFile *result = nil;
	
	// Have a look for files that have the same lastKnownPath and fullPath
	NSArray *existingMedia = [self externalMediaFiles];
	NSEnumerator *mediaEnumerator = [existingMedia objectEnumerator];
	KTExternalMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaEnumerator nextObject])
	{
		if ([[[aMediaFile alias] lastKnownPath] isEqualToString:path] &&
			[[[aMediaFile alias] fullPath] isEqualToString:path])
		{
			result = aMediaFile;
			break;
		}
	}
	
	// If no suitable existing match was found create a new one
	if (!result)
	{
		LOG((@"Creating external MediaFile from path:\r%@", path));
		result = [KTExternalMediaFile insertExternalMediaFileWithPath:path inManagedObjectContext:[self managedObjectContext]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Other

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest
{
	// Search the DB for matching digests
	NSFetchRequest *fetchRequest = [[self managedObjectModel]
		fetchRequestFromTemplateWithName:@"MediaFilesWithDigest"
					substitutionVariable:digest forKey:@"DIGEST"];
	
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	
	return result;
}

- (KTInDocumentMediaFile *)anyInDocumentMediaFileEqualToFile:(NSString *)path
{
	KTInDocumentMediaFile *result = nil;
	
	// Search the DB for matching digests
	NSArray *similarMedia = [self inDocumentMediaFilesWithDigest:[NSData partiallyDigestStringFromContentsOfFile:path]];
	
	if ([similarMedia count] > 0)
	{
		// Run through each possible match to see if it actually is identical
		NSData *mediaData = [NSData dataWithContentsOfFile:path];
		
		NSEnumerator *similarMediaEnumerator = [similarMedia objectEnumerator];
		KTInDocumentMediaFile *anInternalMediaFile;
		while (anInternalMediaFile = [similarMediaEnumerator nextObject])
		{
			NSString *internalMediaPath = [anInternalMediaFile currentPath];
			NSData *internalMediaData = [NSData dataWithContentsOfFile:internalMediaPath];
			
			if ([internalMediaData isEqualToData:mediaData])
			{
				result = anInternalMediaFile;
				break;
			}
		}
	}
	
	return result;
}

/*	Look at where the media is currently located and decide (based on the user's preference) where it should be stored.
 */
- (BOOL)mediaFileShouldBeExternal:(NSString *)path
{
	BOOL result = NO;	// The safest option so we use it as a fall back
	
	// If the user has requested the "automatic" or "reference" option we must consider the matter further
	KTCopyMediaType copyingSetting = [[[self document] documentInfo] copyMediaOriginals];
	switch (copyingSetting)
	{
		case KTCopyMediaNone:
			result = YES;
			break;
		
		case KTCopyMediaAutomatic:
			// If it's a piece of iMedia reference rather than copy it
			if ([[self class] fileConstituesIMedia:path])
			{
				result = YES;
			}
			else
			{
				result = NO;
			}
			break;
		
		case KTCopyMediaAll:
			result = NO;
			break;
	}
	
	return result;
}

/*	Determines if the file is considered to be "iMedia"
 */
+ (BOOL)fileConstituesIMedia:(NSString *)path
{
	//  anything in ~/Movies, ~/Music, or ~/Pictures is considered iMedia.
    //  NB: there appear to be no standard library functions for finding these
	//  but supposedly these names are constant and .localized files
	//  change what name appears in Finder
	
	// We resolve symbolic links so that the path of the arbitrary file added will match the actual path
	// of the home directory
	NSString *homeDirectory = NSHomeDirectory();
    NSString *moviesDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Movies"] stringByResolvingSymlinksInPath];
    NSString *musicDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Music"] stringByResolvingSymlinksInPath];
    NSString *picturesDirectory	= [[homeDirectory stringByAppendingPathComponent:@"Pictures"] stringByResolvingSymlinksInPath];
    
    if ( [path hasPrefix:moviesDirectory] || [path hasPrefix:musicDirectory] || [path hasPrefix:picturesDirectory] )
    {
        return YES;
    }
	
	
	//  anything in iPhoto (using defaults) is iMedia
	NSDictionary *iPhotoDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.iPhoto"];
	NSString *iPhotoRoot = [iPhotoDefaults valueForKey:@"RootDirectory"];	
	if (iPhotoRoot && [path hasPrefix:iPhotoRoot])
	{
		return YES;
	}
    
    
	//  anything in iTunes (using defaults) is iMedia
    static NSString *sITunesRoot = nil;
	if (!sITunesRoot)
	{
// FIXME: the defaults key used here was determined empirically and could break!
// FIXME: This could be very slow to resolve if this points who-knows-where.  And it doesn't save the alias back if it's changed. 
		NSDictionary *iTunesDefaults = [[NSUserDefaults standardUserDefaults] persistentDomainForName:@"com.apple.iTunes"];
		NSString *musicFolderLocationKey = @"alis:11345:Music Folder Location";
		NSData *aliasData = [iTunesDefaults valueForKey:musicFolderLocationKey];
		BDAlias *alias = [[[BDAlias alloc] initWithData:aliasData] autorelease];
		sITunesRoot = [[alias fullPath] retain];
//			}
	}
	if (sITunesRoot && [path hasPrefix:sITunesRoot] )
	{
			return YES;
	}
	
	
	return NO;
}

/*	Looks for all media files which can't be resolved
 */
#pragma mark -
#pragma mark Missing media

- (NSSet *)missingMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *mediaFileEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTExternalMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if (!path || [path isEqualToString:@""] || ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			[result addObject:aMediaFile];
		}
	}
	
	return result;
}

@end
