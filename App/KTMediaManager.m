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
#import "KTDesign.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTExternalMediaFile.h"
#import "KTInDocumentMediaFile.h"
#import "KTMediaContainer.h"
#import "KTMediaManager.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"

#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"


@interface KTMediaManager ()
// MediaContainer Creation
- (KTMediaContainer *)insertMediaContainer;
@end


#pragma mark -


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
	
	KTMediaFile *mediaFile = [self mediaFileWithPath:path];
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
	// Figure out a full filename
	NSString *fileExtension = [NSString filenameExtensionForUTI:UTI];
	NSAssert1(fileExtension && ![fileExtension isEqualToString:@""], @"UTI %@ has no corresponding file extension", UTI);
	NSString *preferredFilename = [filename stringByAppendingPathExtension:fileExtension];
	
	// Create media container & file
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithData:data preferredFilename:preferredFilename];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithImage:(NSImage *)image;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithImage:image];
	[result setValue:mediaFile forKey:@"file"];
	
	return result;
}

- (KTMediaContainer *)mediaContainerWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)external;
{
	KTMediaContainer *result = [self insertMediaContainer];
	
	KTMediaFile *mediaFile = [self mediaFileWithDraggingInfo:info preferExternalFile:external];
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
#pragma mark Graphical Text

/*	Returns an existing graphical text MediaContainer or creates a new one.
 */
- (KTGraphicalTextMediaContainer *)graphicalTextWithString:(NSString *)string
													design:(KTDesign *)design
									  imageReplacementCode:(NSString *)imageReplacementCode
													  size:(float)size
{
	NSPredicate *predicate = [NSPredicate predicateWithFormat:
		@"text == %@ AND designIdentifier == %@ AND imageReplacementCode == %@ AND textSize BETWEEN { %f , %f }",
		string,
		[[design bundle] bundleIdentifier],
		imageReplacementCode,
		size - 0.01, size + 0.01];
	
	NSArray *objects = [[self managedObjectContext] objectsWithEntityName:@"GraphicalText" predicate:predicate error:NULL];
	KTGraphicalTextMediaContainer *result = [objects firstObjectOrNilIfEmpty];
	
	if (!result)
	{
		// Create the container
		result = [NSEntityDescription insertNewObjectForEntityForName:@"GraphicalText"
											   inManagedObjectContext:[self managedObjectContext]];
		
		[result setValue:string forKey:@"text"];
		[result setValue:[[design bundle] bundleIdentifier] forKey:@"designIdentifier"];
		[result setValue:imageReplacementCode forKey:@"imageReplacementCode"];
		[result setFloat:size forKey:@"textSize"];
		
		
		// Create the actual graphic
		NSImage *image = [design replacementImageForCode:imageReplacementCode
												  string:string
													size:[NSNumber numberWithFloat:size]];
		
		KTMediaFile *mediaFile = [self mediaFileWithImage:image];
		[result setValue:mediaFile forKey:@"file"];
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
