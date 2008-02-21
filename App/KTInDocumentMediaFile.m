//
//  KTInDocumentMediaFile.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTInDocumentMediaFile.h"

#import "Debug.h"
#import "KTDocument.h"
#import "KTMediaManager.h"
#import "MediaFiles+Internal.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import "BDAlias.h"


@implementation KTInDocumentMediaFile

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
		KTDocument *doc = [moc document];
		if (doc)	// Safety check for handling store migration
		{
			NSString *sourcePath = [[doc temporaryMediaPath] stringByAppendingPathComponent:filename];
			NSString *destinationPath = [[doc mediaPath] stringByAppendingPathComponent:filename];
			
			LOG((@"Moving temporary MediaFile %@ into the document", filename));
			if (![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:nil]) {
				[NSException raise:NSInternalInconsistencyException
							format:@"Unable to move temporary MediaFile %@ into the document", filename];
			}
		}
	}
	
	
	// If we have been deleted from the context, move our underlying file back out to the temp dir
	if ([self isDeleted])
	{
		NSString *filename = [self committedValueForKey:@"filename"];
		NSString *sourcePath = [[[moc document] mediaPath] stringByAppendingPathComponent:filename];
		NSString *destinationPath = [[[moc document] temporaryMediaPath] stringByAppendingPathComponent:filename];
		
		LOG((@"The in-document MediaFile %@ has been deleted. Moving it to the temp media directory", filename));
		if (![[NSFileManager defaultManager] movePath:sourcePath toPath:destinationPath handler:nil]) {
			[NSException raise:NSInternalInconsistencyException
						format:@"Unable to move deleted MediaFile %@ to the temp media directory", filename];
		}
	}
}

- (NSString *)currentPath
{
	NSString *result = nil;
	
	KTDocument *document = [[self managedObjectContext] document];
	
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

@end
