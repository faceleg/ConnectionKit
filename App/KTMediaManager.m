//
//  KTMediaManager2.m
//  Marvel
//
//  Created by Mike on 28/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMediaManager.h"
#import "KTMediaManager.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTMediaFile.h"
#import "KTMediaContainer.h"
#import "KTSite.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSScanner+Karelia.h"
#import "NSURL+Karelia.h"

#import <Connection/KTLog.h>
#import "BDAlias.h"

#import "Debug.h"


NSString *KTMediaLogDomain = @"Media";


@interface KTMediaManager ()
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
	
	_document = document;	// Weak ref
	
    return self;
}

- (void)dealloc
{
    [myMediaContainerIdentifiersCache release];
	
	[super dealloc];
}

#pragma mark Accessors

- (KTDocument *)document { return _document; }

#pragma mark Missing media

- (NSSet *)missingMediaFiles
{
	NSMutableSet *result = [NSMutableSet set];
    return result;
    
    
    
    
	
	NSEnumerator *mediaFileEnumerator = [[self externalMediaFiles] objectEnumerator];
	KTMediaFile *aMediaFile;
	
	while (aMediaFile = [mediaFileEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if (!path ||
            [path isEqualToString:@""] ||
            [path isEqualToString:[[NSBundle mainBundle] pathForImageResource:@"qmark"]] ||
            ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			if ([(NSSet *)[aMediaFile valueForKey:@"containers"] count] > 0)
            {
                [result addObject:aMediaFile];
            }
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
	

	// Collect MediaContainers
	[self garbageCollectMediaContainers];
	    
    
	// Garbage collect AbstractMediaFiles
	NSArray *mediaFilesForDeletion = [self mediaFilesForDeletion];
	KTLog(KTMediaLogDomain, KTLogDebug, @"Deleting %u unwanted MediaFile(s)", [mediaFilesForDeletion count]);
	
	KTMediaFile *aMediaFile;
	for (aMediaFile in mediaFilesForDeletion)
	{
		[[self managedObjectContext] deleteObject:aMediaFile];
	}
}

- (void)garbageCollectMediaContainers
{
	KTLog(KTMediaLogDomain, KTLogDebug, @"Collecting unneeded MediaContainers...");
	
	NSSet *pageMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Page"];
	NSSet *pageletMediaIDs = [NSSet set];//[self mediaIdentifiersRequiredByEntity:@"OldPagelet"];
	NSSet *masterMediaIDs = [self mediaIdentifiersRequiredByEntity:@"Master"];
	
	NSMutableSet *requiredMediaIDs =
	[[NSMutableSet alloc] initWithCapacity:([pageMediaIDs count] + [masterMediaIDs count] + [pageletMediaIDs count])];
	[requiredMediaIDs unionSet:pageMediaIDs];
	[requiredMediaIDs unionSet:masterMediaIDs];
	[requiredMediaIDs unionSet:pageletMediaIDs];
	
	
	// Get the list of all MediaContainer entities and narrow it down to those that aren't required.
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"scaledImages.@count == 0"];
    NSError *error = nil;
	NSArray *allMedia = [[self managedObjectContext] fetchAllObjectsForEntityForName:@"MediaContainer" predicate:predicate error:&error];
	
	NSManagedObject *aMedia;
	NSMutableSet *unrequiredMedia = [[NSMutableSet alloc] init];
	for (aMedia in allMedia)
	{
		if (![requiredMediaIDs containsObject:[aMedia valueForKey:@"identifier"]])
		{
			[unrequiredMedia addObject:aMedia];
		}
	}
	
	// Delete those unrequired media IDs
	KTLog(KTMediaLogDomain, KTLogDebug, @"Removing %u unneeded MediaContainer(s)", [unrequiredMedia count]);
	for (aMedia in unrequiredMedia)
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
	
	KTLog(KTMediaLogDomain, KTLogDebug, @"Found %u unwanted MediaFile(s) for deletion", [deadMediaFiles count]);
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
	NSArray *allObjects = [docMOC fetchAllObjectsForEntityForName:entityName error:&error];
	if (error) {
		NSAlert *alert = [NSAlert alertWithError:error];
		[alert setIcon:[NSApp applicationIconImage]];
		[alert runModal];	
	}
	
	// Run through the objects asking for their media
	id anObject;
	for (anObject in allObjects)
	{
		[result unionSet:[anObject performSelector:selector]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\n%@", errorInfo]));
	return NO;
}

@end
