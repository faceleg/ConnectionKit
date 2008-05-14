//
//  KTInDocumentMediaFile.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTInDocumentMediaFile.h"
#import "KTMediaFile+Internal.h"

#import "KTDocument.h"
#import "KTMediaManager.h"
#import "KTMediaManager+Internal.h"

#import "NSData+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import "BDAlias.h"
#import <Connection/KTLog.h>

#import "Debug.h"


@implementation KTInDocumentMediaFile

#pragma mark -
#pragma mark Init

+ (id)insertNewMediaFileWithPath:(NSString *)path inManagedObjectContext:(NSManagedObjectContext *)moc
{
	id result = [super insertNewMediaFileWithPath:path inManagedObjectContext:moc];
	
	[result setValue:[path lastPathComponent] forKey:@"filename"];
	[result setValue:[NSData partiallyDigestStringFromContentsOfFile:path] forKey:@"digest"];
	
	return result;
}

#pragma mark -
#pragma mark Core Data

+ (NSString *)entityName { return @"InDocumentMediaFile"; }

- (void)willSave
{
	NSManagedObjectContext *moc = [self managedObjectContext];
	
	
	// If we have just been saved then move our underlying file into the document
	if ([[moc insertedObjects] containsObject:self])
	{
		NSString *filename = [self valueForKey:@"filename"];
		KTDocument *doc = [[self mediaManager] document];
		if (doc)	// Safety check for handling store migration
		{
			NSString *sourcePath = [[doc temporaryMediaPath] stringByAppendingPathComponent:filename];
			NSString *destinationPath = [[doc mediaPath] stringByAppendingPathComponent:filename];
			
			KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Moving temporary MediaFile %@ into the document", filename]));
			
			if (![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:self]) {
				[NSException raise:NSInternalInconsistencyException
							format:@"Unable to move temporary MediaFile %@ into the document", filename];
			}
		}
	}
	
	
	// If we have been deleted from the context, move our underlying file back out to the temp dir
	if ([self isDeleted])
	{
		NSString *filename = [self committedValueForKey:@"filename"];
		NSString *sourcePath = [[[[self mediaManager] document] mediaPath] stringByAppendingPathComponent:filename];
		NSString *destinationPath = [[[[self mediaManager] document] temporaryMediaPath] stringByAppendingPathComponent:filename];
		
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
			NSString *message = [NSString stringWithFormat:@"No file could be found at\r%@\rDeleting the MediaFile object it anyway",
				[sourcePath stringByAbbreviatingWithTildeInPath]];
			KTLog(KTMediaLogDomain, KTLogWarn, message);
		}
	}
}

- (NSString *)currentPath
{
	NSString *result = nil;
	
	KTDocument *document = [[self mediaManager] document];
	
	// Figure out proper values for these two
	if ([self isTemporaryObject])
	{
		result = [[document temporaryMediaPath] stringByAppendingPathComponent:[self filename]];
	}
	else
	{
		result = [[document mediaPath] stringByAppendingPathComponent:[self filename]];
	}
	
	return result;
}

- (NSString *)filename
{
	NSString *result = [self wrappedValueForKey:@"filename"];
	return result;
}

- (void)setFilename:(NSString *)filename
{
	if ([self filename])
	{
		[NSException raise:NSInvalidArgumentException format:@"-[KTInDocumentMediaFile filename] is immutable"];
	}
	else
	{
		[self setWrappedValue:filename forKey:@"filename"];
	}
}

- (NSString *)quickLookPseudoTag
{
	NSString *result = [NSString stringWithFormat:@"<!svxdata indocumentmedia:%@>",
												  [self filename]];
	return result;
}

- (NSString *)preferredFileName
{
	NSString *result = [[[self valueForKey:@"sourceFilename"] lastPathComponent] stringByDeletingPathExtension];
	return result;
}

#pragma mark -
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\r%@", errorInfo]));
	return NO;
}

@end
