//
//  KTMediaManager2.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTMediaManager.h"
#import "KTMediaManager+Internal.h"

#import "KTDocument.h"
#import "KTExternalMediaFile.h"
#import "KTMediaPersistentStoreCoordinator.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import <Connection/KTLog.h>
#import "BDAlias.h"

#import "Debug.h"


NSString *KTMediaLogDomain = @"Media";


@interface KTMediaManager (Private)
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
	
	myDocument = document;	// Weak ref
	
	
	// Set up our MOC
	myMOC = [[NSManagedObjectContext alloc] init];
	[myMOC setUndoManager:nil];	// You can't auto-undo media stuff
	
	
	KTMediaPersistentStoreCoordinator *mediaPSC = [[KTMediaPersistentStoreCoordinator alloc] initWithManagedObjectModel:
												   [[self class] managedObjectModel]];
	
	[mediaPSC setMediaManager:self];
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
	
#ifdef DEBUG
	NSDate *startDate = [NSDate date];	// We're currently logging how long it takes since this is quite performance intensive
#endif
	
	
	// Collect MediaContainers
	[self garbageCollectMediaContainers];
	
	
	// Garbage collect AbstractMediaFiles
	NSArray *mediaFilesForDeletion = [self mediaFilesForDeletion];
	KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Deleting %u unwanted AbstractMediaFile(s)", [mediaFilesForDeletion count]]));
	
	NSEnumerator *mediaFilesEnumerator = [mediaFilesForDeletion objectEnumerator];
	KTMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		[[self managedObjectContext] deleteObject:aMediaFile];
	}
	
	
#ifdef DEBUG
	NSDate *finishDate = [NSDate date];
	NSTimeInterval timeTaken = [finishDate timeIntervalSinceDate:startDate];
	NSString *message = [NSString stringWithFormat:@"Media garbage collection took %fs", timeTaken];
	KTLog(KTMediaLogDomain, KTLogInfo, message);
#endif
}

- (void)garbageCollectMediaContainers
{
	KTLog(KTMediaLogDomain, KTLogDebug, @"Collecting unneeded MediaContainers...");
	
	NSSet *pageMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Page"];
	NSSet *pageletMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Pagelet"];
	NSSet *masterMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Master"];
	
	NSMutableSet *requiredMediaIDs =
	[[NSMutableSet alloc] initWithCapacity:([pageMediaIDs count] + [masterMediaIDs count] + [pageletMediaIDs count])];
	[requiredMediaIDs unionSet:pageMediaIDs];
	[requiredMediaIDs unionSet:masterMediaIDs];
	[requiredMediaIDs unionSet:pageletMediaIDs];
	
	
	// Get the list of all MediaContainer entities and narrow it down to those that aren't required.
	NSError *error = nil;
	NSArray *allMedia = [[self managedObjectContext] allObjectsWithEntityName:@"MediaContainer" error:&error];
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
	KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Removing %u unneeded MediaContainer(s)", [unrequiredMedia count]]));
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
	
	KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Found %u unwanted MediaFile(s) for deletion", [deadMediaFiles count]]));
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
		[[NSAlert alertWithError:error] runModal];
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
	KTLog(KTMediaLogDomain, KTLogDebug, ([NSString stringWithFormat:@"Deleting the temporary media directory for the document at:\r%@", [[self document] fileURL]]));
	NSString *tempMedia = [[self document] temporaryMediaPath];
	[[NSFileManager defaultManager] removeFileAtPath:tempMedia handler:self];
}

#pragma mark -
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\r%@", errorInfo]));
	return NO;
}

@end
