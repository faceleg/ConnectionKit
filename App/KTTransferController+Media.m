//
//  KTTransferController+Media.m
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTTransferController+Internal.h"
#import "KTMediaFileUpload.h"

#import "NSObject+Karelia.h"
#import "NSThread+Karelia.h"

@implementation KTTransferController (Media)

#pragma mark -
#pragma mark Publishing

/*	Takes a set of MediaFileUploads and publishes them
 */
- (void)threadedUploadMediaFiles:(NSSet *)mediaFileUploads
{
	[self performSelectorOnMainThread:@selector(uploadMediaFiles:) withObject:mediaFileUploads waitUntilDone:YES];
}

- (void)uploadMediaFile:(KTMediaFileUpload *)mediaFileUpload
{
	// This MUST be called from the main thread
	if (![NSThread isMainThread]) {
		[NSException raise:NSObjectInaccessibleException format:@"-[KTTransferController uploadMediaFile:] is not thread-safe"];
	}
	
	// Create the directory for the file
	NSString *uploadPath = [[self storagePath] stringByAppendingPathComponent:[mediaFileUpload pathRelativeToSite]];
	[self recursivelyCreateDirectoriesFromPath:[uploadPath stringByDeletingLastPathComponent] setPermissionsOnAllFolders:YES];
	
	// Upload the file
	NSString *sourcePath = [mediaFileUpload valueForKeyPath:@"file.currentPath"];
	if ( (nil != sourcePath) && ![sourcePath isEqualToString:@""] )
	{
		[self uploadFile:sourcePath toFile:uploadPath];
	}
	else
	{
		NSLog(@"upload error: no local path for %@, skipping...", [mediaFileUpload valueForKeyPath:@"file.uniqueID"]);
	}
	
	// Add the file to the upload list
    OBASSERT(mediaFileUpload);
	[myMediaFileUploads addObject:mediaFileUpload];
}

- (void)uploadMediaFiles:(NSSet *)mediaFileUploads
{
	// Run through and publish each file
	NSEnumerator *uploadsEnumerator = [mediaFileUploads objectEnumerator];
	KTMediaFileUpload *aMediaFileUpload;
	while (aMediaFileUpload = [uploadsEnumerator nextObject])
	{
		[self uploadMediaFile:aMediaFileUpload];
	}
}

- (NSSet *)mediaFileUploads { return [NSSet setWithSet:myMediaFileUploads]; }

- (void)removeAllMediaFileUploads { [myMediaFileUploads removeAllObjects]; }

#pragma mark -
#pragma mark Parsed Media

- (NSSet *)parsedMediaFileUploads { return [NSSet setWithSet:myParsedMediaFileUploads]; }

- (NSSet *)staleParsedMediaFileUploads
{
	// This MUST be called from the main thread
	if (![NSThread isMainThread]) {
		[NSException raise:NSObjectInaccessibleException format:@"-[KTTransferController staleParsedMediaFileUploads] is not thread-safe"];
	}
	
	// Enumerate through our parsed media files and return those which are stale
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *mediaFileUploadsEnumerator = [[self parsedMediaFileUploads] objectEnumerator];
	KTMediaFileUpload *aMediaFileUpload;
	while (aMediaFileUpload = [mediaFileUploadsEnumerator nextObject])
	{
		if ([aMediaFileUpload boolForKey:@"isStale"])
		{
			[result addObject:aMediaFileUpload];
		}
	}
	
	return result;
}

- (void)addParsedMediaFileUpload:(KTMediaFileUpload *)mediaFileUpload
{
    OBPRECONDITION(mediaFileUpload);
    [myParsedMediaFileUploads addObject:mediaFileUpload];
}

- (void)removeAllParsedMediaFileUploads { [myParsedMediaFileUploads removeAllObjects]; }

@end
