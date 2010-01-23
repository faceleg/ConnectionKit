//
//  KTMediaManager+MediaFiles.m
//  Marvel
//
//  Created by Mike on 07/04/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTMediaManager+Internal.h"
#import "KTMediaFileEqualityTester.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTSite.h"

#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObjectModel+KTExtensions.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"

#import <Connection/KTLog.h>

#import "Debug.h"


@interface KTMediaManager (MediaFilesPrivate)

// New media files
- (KTMediaFile *)mediaFileWithPath:(NSString *)path external:(BOOL)isExternal;

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest;
- (KTMediaFile *)inDocumentMediaFileForPath:(NSString *)path;
- (KTMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path;

// Conversion
- (KTMediaFile *)inDocumentMediaFileToReplaceExternalMedia:(KTMediaFile *)original;

@end


#pragma mark -


@implementation KTMediaManager (MediaFiles)

#pragma mark -
#pragma mark Queries

/*	Searches for an external media file whose alias matches the supplied path.
 */
- (KTMediaFile *)anyExternalMediaFileMatchingPath:(NSString *)path
{
	KTMediaFile *result = nil;
	
	NSEnumerator *mediaEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTMediaFile *aMediaFile;
	while (aMediaFile = [mediaEnumerator nextObject])
	{
		BDAlias *anAlias = [aMediaFile alias];
		if ([[anAlias lastKnownPath] isEqualToString:path] &&
			[[anAlias fullPath] isEqualToString:path])
		{
			result = aMediaFile;
			break;
		}
	}
	
	return result;
}

- (NSArray *)externalMediaFiles
{
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] allObjectsWithEntityName:@"MediaFile" error:&error];
	if (error) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert setIcon:[NSApp applicationIconImage]];
		[alert runModal];	
	}
	
	return result;
}

/*	NSManagedObjectContext gives us a nice list of inserted (temporary) objects. We just have to narrow it down to those of
 *	the KTMediaFile class.
 */
- (NSSet *)temporaryMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *insertedObjectsEnumerator = [[[self managedObjectContext] insertedObjects] objectEnumerator];
	id anInsertedObject;
	while (anInsertedObject = [insertedObjectsEnumerator nextObject])
	{
		if ([anInsertedObject isKindOfClass:[KTMediaFile class]])	// Ignore external media
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
	[fetchRequest setEntity:[[KTDocument managedObjectModel] entityWithName:@"InDocumentMediaFile"]];
	[fetchRequest setFetchLimit:1];
	[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"filename LIKE[c] %@", result]];
	
	
	// Loop through, only ending when the file doesn't exist
	while ([[[self managedObjectContext] executeFetchRequest:fetchRequest error:NULL] count] > 0)
	{
		count++;
		NSString *aFileName = [NSString stringWithFormat:@"%@-%u", fileName, count];
		OBASSERT(extension);
		result = [aFileName stringByAppendingPathExtension:extension];
		[fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"filename LIKE[c] %@", result]];
	}
	
	
	// Tidy up
	[fetchRequest release];
	return result;
}

/*	Locates the KTMediaContainer object with the specified identifier. Returns nil if none is found.
 */
- (KTMediaFile *)mediaFileWithIdentifier:(NSString *)identifier
{
	OBPRECONDITION(identifier);
    
    
	// Fetch first possible match
    NSFetchRequest *fetchRequest =
    [[KTDocument managedObjectModel] fetchRequestFromTemplateWithName:@"MediaFileWithIdentifier"
                                                   substitutionVariable:identifier forKey:@"IDENTIFIER"];
    [fetchRequest setFetchLimit:1];
    
    NSError *error = nil;
    NSArray *matches = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
    if (!matches) {
        [[self document] presentError:error];
    }
    
    return [matches firstObjectKS];
}

#pragma mark -
#pragma mark Creating/Locating MediaFiles

/*	Used to add new media files to the DB.
 *	The media manager will automatically decide whether to add the file as external or temporary media.
 */
- (KTMediaFile *)mediaFileWithPath:(NSString *)path
{
	KTMediaFile *result = [self mediaFileWithPath:path external:[self mediaFileShouldBeExternal:path]];
	return result;
}

/*	Basically the same as the above method, but allows the expression of a preference as to where the underlying file is stored
 */
- (KTMediaFile *)mediaFileWithPath:(NSString *)path preferExternalFile:(BOOL)preferExternal
{
	// For the time being we shall always obey the preference
	KTMediaFile *result = [self mediaFileWithPath:path external:preferExternal];
	return result;
}

/*	Does the work for the above two methods. The storage type is ALWAYS obeyed.
 */
- (KTMediaFile *)mediaFileWithPath:(NSString *)path external:(BOOL)isExternal
{
	KTMediaFile *result = nil;
	
	if (isExternal)
	{
		result = [self anyExternalMediaFileMatchingPath:path];
		if (!result)
		{
			KTLog(KTMediaLogDomain, KTLogDebug, @"Creating external MediaFile for path:\n%@", path);
			result = [KTMediaFile insertNewMediaFileWithPath:path inManagedObjectContext:[self managedObjectContext]];
		}
	}
	else
	{
		result = [self inDocumentMediaFileForPath:path];
	}
	
	return result;
}

- (KTMediaFile *)mediaFileWithData:(NSData *)data preferredFilename:(NSString *)preferredFilename
{
	KTMediaFile *result = nil;
	
	/*/ See if there is already a MediaFile with the same data
	NSArray *similarMediaFiles = [self inDocumentMediaFilesWithDigest:[KTMediaFile mediaFileDigestFromData:data]];
	
	NSEnumerator *mediaFilesEnumerator = [similarMediaFiles objectEnumerator];
	KTMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		NSData *possibleMatch = [NSData dataWithContentsOfFile:[aMediaFile currentPath]];
		if ([possibleMatch isEqualToData:data])
		{
			result = aMediaFile;
			break;
		}
	}
	*/
    
	// No existing match was found so create a new MediaFile
	if (!result)
	{
		result = [KTMediaFile mediaWithContents:data
                                     entityName:[KTMediaFile entityName]
                 insertIntoManagedObjectContext:[self managedObjectContext]];
        
        [result setPreferredFilename:preferredFilename];
	}
	
	
	return result;
}

- (KTMediaFile *)mediaFileWithImage:(NSImage *)image
{
	OBPRECONDITION(image);
	OBPRECONDITION([[image representations] count] > 0);
	
	// Figure out the filename to use
	NSString *imageUTI = [image preferredFormatUTI];
	OBASSERT(imageUTI);
	NSString *extension = [NSString filenameExtensionForUTI:imageUTI];
	OBASSERT(extension);
	NSString *filename = [@"pastedImage" stringByAppendingPathExtension:extension];
	NSData *imageData = [image representationForUTI:imageUTI];
	
	KTMediaFile *result = [self mediaFileWithData:imageData preferredFilename:filename];
	return result;
}

- (KTMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal
{
	KTMediaFile *result = nil;
	
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObjectKS];
		if (path)
		{
			result = [self mediaFileWithPath:path preferExternalFile:preferExternal];
		}
	}
	// TODO: Support drag sources other than files
	
	return result;
}

#pragma mark -
#pragma mark In-document Media Files

- (NSArray *)inDocumentMediaFilesWithDigest:(NSString *)digest
{
	return nil;
    
    // Search the DB for matching digests
	NSFetchRequest *fetchRequest = [[KTDocument managedObjectModel]
									fetchRequestFromTemplateWithName:@"MediaFilesWithDigest"
									substitutionVariable:digest forKey:@"DIGEST"];
	
	NSError *error = nil;
	NSArray *result = [[self managedObjectContext] executeFetchRequest:fetchRequest error:&error];
	if (error) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert setIcon:[NSApp applicationIconImage]];
		[alert runModal];	
	}
	
	return result;
}

/*	Look to see if there is an existing equivalent media file. If so, return that. Otherwise create a new one.
 */
- (KTMediaFile *)inDocumentMediaFileForPath:(NSString *)path
{
	OBPRECONDITION(path);
    
    KTMediaFile *result = nil;
	
	
	// Search the DB for matching digests. This gives us a rough set of results.
	NSArray *similarMedia = [self inDocumentMediaFilesWithDigest:[KTMediaFile mediaFileDigestFromContentsOfFile:path]];
	if ([similarMedia count] > 0)
	{
		NSEnumerator *matchEnumerator = [similarMedia objectEnumerator];
		KTMediaFile *aMediaFile;
		while (aMediaFile = [matchEnumerator nextObject])
		{
			if ([[NSFileManager defaultManager] contentsEqualAtPath:path andPath:[aMediaFile currentPath]])
			{
				result = aMediaFile;
				break;
			}
		}
	}
	
	
	// No match was found so create a new MediaFile
	if (!result)
	{
		result = [self insertTemporaryMediaFileWithPath:path];
	}
	
	return result;
}

/*	Creates a brand new entry in the DB for the media at the path.
 *	The path itself is copied to app support as a temporary store; it is moved internally at save-time.
 */
- (KTMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path
{
	KTMediaFile *result = [KTMediaFile mediaWithURL:[NSURL fileURLWithPath:path]
                                         entityName:[KTMediaFile entityName]
                     insertIntoManagedObjectContext:[self managedObjectContext]
                                              error:NULL];
    
    return result;
}


#pragma mark -
#pragma mark Conversion

/*	Convert any external media files to internal if the document's settings recommend it.
 */
- (void)moveApplicableExternalMediaInDocument
{
	// Not doing that for now
    return;
    
    
    
    NSArray *externalMediaFiles = [self externalMediaFiles];
	NSEnumerator *mediaFileEnumerator = [externalMediaFiles objectEnumerator];
	KTMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		if (![self mediaFileShouldBeExternal:[aMediaFile currentPath]])
		{
			[self inDocumentMediaFileToReplaceExternalMedia:aMediaFile];
		}
	}
}

/*  Attempts to move a given file into the document. Returns nil if this fails (e.g. the file can't be located).
 */
- (KTMediaFile *)inDocumentMediaFileToReplaceExternalMedia:(KTMediaFile *)original
{
	OBPRECONDITION(original);
	
	KTMediaFile *result = nil;
    
    
	// Get the replacement file.
	NSString *path = [original currentPath];
    if (path)
    {
        result = [self inDocumentMediaFileForPath:path];
        OBASSERT(result);
        
        
        // Migrate relationships
        [[result mutableSetValueForKey:@"uploads"] unionSet:[original valueForKey:@"uploads"]];
        [[result mutableSetValueForKey:@"scaledImages"] unionSet:[original valueForKey:@"scaledImages"]];
        [[result mutableSetValueForKey:@"containers"] unionSet:[original valueForKey:@"containers"]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Support

/*	Look at where the media is currently located and decide (based on the user's preference) where it should be stored.
 */
- (BOOL)mediaFileShouldBeExternal:(NSString *)path
{
	BOOL result = NO;	// The safest option so we use it as a fall back
	
	// If the user has requested the "automatic" or "reference" option we must consider the matter further
	KTCopyMediaType copyingSetting = [[[self document] site] copyMediaOriginals];
	switch (copyingSetting)
	{
		case KTCopyMediaNone:
			result = YES;
			break;
			
		case KTCopyMediaAutomatic:
			// If it's a piece of iMedia reference rather than copy it
			if ([[self class] fileConstitutesIMedia:path])
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
+ (BOOL)fileConstitutesIMedia:(NSString *)path
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

@end
