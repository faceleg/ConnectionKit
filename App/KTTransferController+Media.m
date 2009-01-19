//
//  KTTransferController+Media.m
//  Marvel
//
//  Created by Mike on 09/12/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTTransferController+Internal.h"
#import "KTMediaFileUpload.h"

#import "KSThreadProxy.h"

#import "NSObject+Karelia.h"
#import "NSThread+Karelia.h"


@interface KTTransferController (MediaPrivate)
- (NSDictionary *)publishingInfoForMediaFile:(KTMediaFileUpload *)mediaFileUpload;
@end


#pragma mark -


@implementation KTTransferController (Media)

#pragma mark -
#pragma mark Publishing

- (NSSet *)mediaFileUploads { return [NSSet setWithSet:myMediaFileUploads]; }

- (void)removeAllMediaFileUploads { [myMediaFileUploads removeAllObjects]; }

- (void)threadedUploadMediaFile:(KTMediaFileUpload *)mediaFileUpload
{
	NSDictionary *publishingInfo = [[self proxyForMainThread] publishingInfoForMediaFile:mediaFileUpload];
    
    
    if (publishingInfo)
    {
        // Create the directory for the file
        NSString *uploadPath = [[self storagePath] stringByAppendingPathComponent:[publishingInfo objectForKey:@"uploadPath"]];
        [self recursivelyCreateDirectoriesFromPath:[uploadPath stringByDeletingLastPathComponent] setPermissionsOnAllFolders:YES];
        
        // Upload the file
        NSString *sourcePath = [publishingInfo objectForKey:@"sourcePath"];
        if (sourcePath && ![sourcePath isEqualToString:@""])
        {
            [self uploadFile:sourcePath toFile:uploadPath];
			
			if ([[[NSUserDefaults standardUserDefaults] objectForKey:@"ConnectionSetsPermissions"] boolValue])
			{
				[myController setPermissions:myPagePermissions forFile:uploadPath];
			}
        }
        
        // Add the file to the upload list
        OBASSERT(mediaFileUpload);
        [myMediaFileUploads addObject:mediaFileUpload];
    }
}

/*	Takes a set of MediaFileUploads and publishes them
 */
- (void)threadedUploadMediaFiles:(NSSet *)mediaFileUploads
{
	// Run through and publish each file
	NSEnumerator *uploadsEnumerator = [mediaFileUploads objectEnumerator];
	KTMediaFileUpload *aMediaFileUpload;
	while (aMediaFileUpload = [uploadsEnumerator nextObject])
	{
		[self threadedUploadMediaFile:aMediaFileUpload];
	}
}


/*	Support method for -threadedUploadMediaFile: that is called on the MAIN THREAD.
 *	
 *	Returns a dictionary with the following keys:
 *		sourcePath			-	The path to upload from
 *		uploadPath			-	The media's path relative to   docRoot/subFolder/
 */
- (NSDictionary *)publishingInfoForMediaFile:(KTMediaFileUpload *)mediaFileUpload
{
    // This MUST be called from the main thread
	if (![NSThread isMainThread]) {
		[NSException raise:NSObjectInaccessibleException format:@"-[KTTransferController uploadMediaFile:] is not thread-safe"];
	}
    
    
    NSDictionary *result = nil;
	
	
    NSString *sourcePath = [mediaFileUpload valueForKeyPath:@"file.currentPath"];
    if (sourcePath)
    {
        NSString *uploadPath = [mediaFileUpload pathRelativeToSite];
        result = [NSDictionary dictionaryWithObjectsAndKeys:sourcePath, @"sourcePath", uploadPath, @"uploadPath", nil];
    }
    
    
    return result;
}

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
