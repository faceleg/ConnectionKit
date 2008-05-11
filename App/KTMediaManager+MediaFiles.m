//
//  KTMediaManager+MediaFiles.m
//  Marvel
//
//  Created by Mike on 07/04/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTMediaManager+Internal.h"
#import "MediaFiles+Internal.h"

#import "KTDocument.h"

#import "NSArray+Karelia.h"
#import "NSData+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"

#import "BDAlias.h"

#import <Connection/KTLog.h>

#import "Debug.h"


@interface KTMediaManager (MediaFilesPrivate)

// New media files
- (KTMediaFile *)mediaFileWithPath:(NSString *)path external:(BOOL)isExternal;

- (KTInDocumentMediaFile *)temporaryMediaFileWithPath:(NSString *)path;
- (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path;

@end


#pragma mark -


@implementation KTMediaManager (MediaFiles)

#pragma mark -
#pragma mark Queries

/*	Searches for an external media file whose alias matches the supplied path.
 */
- (KTExternalMediaFile *)anyExternalMediaFileMatchingPath:(NSString *)path
{
	KTExternalMediaFile *result = nil;
	
	NSEnumerator *mediaEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTExternalMediaFile *aMediaFile;
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
	NSArray *result = [[self managedObjectContext] allObjectsWithEntityName:@"ExternalMediaFile" error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
	}
	
	return result;
}

#pragma mark -
#pragma mark MediaFile creation/re-use

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
			KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Creating external MediaFile for path:\r%@", path]));
			result = [KTExternalMediaFile insertNewMediaFileWithPath:path inManagedObjectContext:[self managedObjectContext]];
		}
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
		
		KTLog(KTMediaLogDomain, KTLogDebug,
					([NSString stringWithFormat:@"Creating temporary in-document MediaFile from data named '%@'", filename]));
		
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
	OBASSERT(extension);
	NSString *filename = [@"pastedImage" stringByAppendingPathExtension:extension];
	NSData *imageData = [image representationForUTI:imageUTI];
	
	KTInDocumentMediaFile *result = [self mediaFileWithData:imageData preferredFilename:filename];
	return result;
}

- (KTMediaFile *)mediaFileWithDraggingInfo:(id <NSDraggingInfo>)info preferExternalFile:(BOOL)preferExternal
{
	KTMediaFile *result = nil;
	
	if ([[[info draggingPasteboard] types] containsObject:NSFilenamesPboardType])
	{
		NSString *path = [[[info draggingPasteboard] propertyListForType:NSFilenamesPboardType] firstObjectOrNilIfEmpty];
		if (path)
		{
			result = [self mediaFileWithPath:path preferExternalFile:preferExternal];
		}
	}
	// TODO: Support drag sources other than files
	
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

/*	Support method that ensures the temporary media directory does not already contain a file with the same name
 */
- (BOOL)prepareTemporaryMediaDirectoryForFileNamed:(NSString *)filename
{
	// See if there's already a file there
	NSString *proposedPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:filename];
	BOOL result = !([[NSFileManager defaultManager] fileExistsAtPath:proposedPath]);
	
	// If there is an existing file, try to delete it. Log the operation for debugging purposes
	if (!result)
	{
		int tag = 0;
		result = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation
															  source:[proposedPath stringByDeletingLastPathComponent]
														 destination:@""
															   files:[NSArray arrayWithObject:filename]
															     tag:&tag]; 
		
		NSString *message = [NSString stringWithFormat:@"Preparing for temporary media file at\n%@\nbut one already exists. %@",
								proposedPath,
								(result) ? @"It was moved to the trash." : @"It could not be deleted."];
		KTLog(KTMediaLogDomain, (result) ? KTLogWarn : KTLogError, message);
	}
	
	return result;
}

/*	Creates a brand new entry in the DB for the media at the path.
 *	The path itself is copied to app support as a temporary store; it is moved internally at save-time.
 */
- (KTInDocumentMediaFile *)insertTemporaryMediaFileWithPath:(NSString *)path;
{
	KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Creating temporary in-document MediaFile from path:\r%@", path]));
	
	// Figure out the filename and copy the file there
	NSString *sourceFilename = [path lastPathComponent];
	NSString *destinationFilename = [self uniqueInDocumentFilename:sourceFilename];
	NSString *destinationPath = [[[self document] temporaryMediaPath] stringByAppendingPathComponent:destinationFilename];
	
	[self prepareTemporaryMediaDirectoryForFileNamed:destinationFilename];
	if (![[NSFileManager defaultManager] copyPath:path toPath:destinationPath handler:self]) {
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

@end
