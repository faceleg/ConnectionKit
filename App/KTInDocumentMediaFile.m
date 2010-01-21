//
//  KTInDocumentMediaFile.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTInDocumentMediaFile.h"

#import "KTDocument.h"
#import "KTMediaManager.h"
#import "KTMediaManager+Internal.h"
#import "KTMediaPersistentStoreCoordinator.h"

#import "NSData+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSURL+Karelia.h"

#import "BDAlias.h"
#import <Connection/KTLog.h>

#import "Debug.h"


@interface KTInDocumentMediaFile ()
- (void)moveIntoDocument;
@end


#pragma mark -


@implementation KTInDocumentMediaFile

#pragma mark -
#pragma mark Init

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc
{
	id result = [super insertNewMediaFileWithPath:path inManagedObjectContext:moc];
	
	[result setValue:[path lastPathComponent] forKey:@"filename"];
	
	return result;
}

#pragma mark -
#pragma mark Core Data

+ (NSString *)entityName { return @"InDocumentMediaFile"; }

#pragma mark -
#pragma mark File Management

- (void)didSave
{
    [super didSave];
    
    
	// Both -insertedObjects and KTLog seems to be pretty memory intensive during data migration, so give them a local pool
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	
	// If we have just been saved then move our underlying file into the document
	if ([self isInserted])
	{
		// During Save As operations, the files on disk are handled for us, so don't do this
        if ([[[self managedObjectContext] persistentStoreCoordinator] isKindOfClass:[KTMediaPersistentStoreCoordinator class]])
        {
            [self moveIntoDocument];
        }
	}
	
	
	// If we have been deleted from the context, move our underlying file back out to the temp dir
	if ([self isDeleted])
	{
		NSString *filename = [self committedValueForKey:@"filename"];
		NSString *sourcePath = [[[self mediaManager] mediaPath] stringByAppendingPathComponent:filename];
		NSString *destinationPath = [[[self mediaManager] temporaryMediaPath] stringByAppendingPathComponent:filename];
		
		KTLog(KTMediaLogDomain, KTLogDebug,
			  ([NSString stringWithFormat:@"The in-document MediaFile %@ has been deleted. Moving it to the temp media directory", filename]));
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:sourcePath])
		{
			[[self mediaManager] prepareTemporaryMediaDirectoryForFileNamed:filename];
			if (![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:self]) {
				[NSException raise:NSInternalInconsistencyException
							format:@"Unable to move deleted MediaFile %@ to the temp media directory", filename];
			}
		}
		else
		{
			NSString *message = [NSString stringWithFormat:@"No file could be found at\n%@\nDeleting the MediaFile object it anyway",
				[sourcePath stringByAbbreviatingWithTildeInPath]];
			KTLog(KTMediaLogDomain, KTLogWarn, message);
		}
	}
	
	
	[pool release];
}

/*	Called when a MediaFile is saved for the first time. i.e. it becomes peristent and the underlying file needs to move into the doc.
 */
- (void)moveIntoDocument
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	KTDocument *doc = [[self mediaManager] document];
	if (!doc) return;	// Safety check for handling store migration
	
	
	// Simple debug log of what's about to go down		(see, I'm streetwise. No, really!)
	NSString *filename = [self filename];
	KTLog(KTMediaLogDomain,
		  KTLogDebug,
		  ([NSString stringWithFormat:@"Moving temporary MediaFile %@ into the document", filename]));
	
	
	// Only bother if there is actually a file to move
	NSString *sourcePath = [[[self mediaManager] temporaryMediaPath] stringByAppendingPathComponent:filename];
	if (![fileManager fileExistsAtPath:sourcePath])
	{
		KTLog(KTMediaLogDomain,
			  KTLogInfo,
			  ([NSString stringWithFormat:@"No file to move at:\n%@", [sourcePath stringByAbbreviatingWithTildeInPath]]));
			   
		return;
	}
	
	
	// Make sure the destination is available
	NSString *destinationPath = [[[doc mediaDirectoryURL] path] stringByAppendingPathComponent:filename];
	if ([fileManager fileExistsAtPath:destinationPath])
	{
		KTLog(KTMediaLogDomain,
			  KTLogWarn,
			  ([NSString stringWithFormat:@"%@\nalready exists; overwriting it.", [destinationPath stringByAbbreviatingWithTildeInPath]]));
		
		[fileManager removeFileAtPath:destinationPath handler:self];
	}
	
			   
	// Make the move
	if (![fileManager movePath:sourcePath toPath:destinationPath handler:self])
	{
		KTLog(KTMediaLogDomain,
			  KTLogError,
			  @"-[%@ %@] failed moving from %@ to %@",
			  NSStringFromClass([self class]),
			  NSStringFromSelector(_cmd),
			  [sourcePath stringByAbbreviatingWithTildeInPath],
			  [destinationPath stringByAbbreviatingWithTildeInPath]);
	}
}

#pragma mark -
#pragma mark Accessors

- (NSURL *)fileURL;
{
	NSURL *result = nil;
		
	// Figure out proper values for these two
	if ([self isTemporaryObject])
	{
		result = [NSURL fileURLWithPath:[[[self mediaManager] temporaryMediaPath] stringByAppendingPathComponent:[self filename]]];
	}
	else
	{
		KTDocument *doc = [[self mediaManager] document];
        result = [[doc mediaDirectoryURL] URLByAppendingPathComponent:[self filename] isDirectory:NO];
	}
	
    return result;
}

@dynamic filename;

- (NSString *)quickLookPseudoTag
{
	NSString *result = [NSString stringWithFormat:@"<!svxdata indocumentmedia:%@>",
												  [self filename]];
	return result;
}

@dynamic preferredFilename;
- (BOOL)validatePreferredFilename:(NSString **)filename error:(NSError **)outError
{
    //  Make sure it really is just a filename and not a path
    BOOL result = [[*filename pathComponents] count] == 1;
    if (!result && outError)
    {
        NSDictionary *info = [NSDictionary dictionaryWithObject:[NSString stringWithFormat:@"perferredFilename \"%@\" is a path; not a filename", *filename]
                                                         forKey:NSLocalizedDescriptionKey];
        *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                        code:NSValidationStringPatternMatchingError
                                    userInfo:info];
    }
    
    return result;
}

/*  Little hack to make missing media sheet work
 */
- (id)alias { return nil; }

#pragma mark -
#pragma mark Digest

#define DIGESTDATALENGTH 8192

+ (NSData *)mediaFileDigestFromData:(NSData *)data
{
    unsigned int length = [data length];
	unsigned int lengthToDigest = MIN(length, (unsigned int)DIGESTDATALENGTH);
	NSData *firstPart = [data subdataWithRange:NSMakeRange(0,lengthToDigest)];
	NSData *result = [firstPart SHA1HashDigest];
	return result;
}

+ (NSData *)mediaFileDigestFromContentsOfFile:(NSString *)path
{
    NSData *result = nil;
	id fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
	if (fileHandle)
	{
		NSData *data = [fileHandle readDataOfLength:DIGESTDATALENGTH];
		result = [data SHA1HashDigest];
		
		[fileHandle closeFile];
	}
	return result;
}

@dynamic cachedDigest;

#pragma mark -
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\n%@", errorInfo]));
	return NO;
}

@end
