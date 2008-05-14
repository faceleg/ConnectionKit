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

#import "NSManagedObjectModel+KTExtensions.h"

#import <Connection/KTLog.h>

#import "Debug.h"


NSString *KTMediaLogDomain = @"Media";


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
	
	KTMediaPersistentStoreCoordinator *mediaPSC =
		[[KTMediaPersistentStoreCoordinator alloc] initWithManagedObjectModel:mediaModel];
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
- (NSManagedObjectModel *)managedObjectModel
{
	NSManagedObjectModel *result = [[[self managedObjectContext] persistentStoreCoordinator] managedObjectModel];
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
#pragma mark Errors

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	KTLog(KTMediaLogDomain, KTLogError, ([NSString stringWithFormat:@"Caught file manager error:\r%@", errorInfo]));
	return NO;
}

@end
