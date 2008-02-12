//
//  KTManagedObjectContext.m
//  KTComponents
//
//  Created by Terrence Talbot on 11/14/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTManagedObjectContext.h"

#import "Debug.h"
#import "Sandvox.h"
#import "KTDataMigrator.h"

static NSMutableDictionary *sAllMOCs = nil;	// key: %p of self, value: %p of thread
static NSString *sMainThreadID = nil;


#ifdef DEBUG
@interface KTManagedObjectContext ( Private )
- (void)checkThread:(SEL)aSel;
@end
#endif


//@interface KTDataMigrator ( PrivateHack )
//+ (void)crashKTDataMigrator;
//@end


@implementation KTManagedObjectContext

//+ (void)crashKTManagedObjectContext
//{
//	[KTDataMigrator crashKTDataMigrator];
//}

// in RELEASE, we want KTManagedObjectContext to poseAsClass: NSManagedObjectContext so that saveDocumentAs: works!
#ifndef DEBUG
+ (void)initialize		// Not +load; we have problems with that.  But then we need to get the class loaded right.
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self poseAsClass:[NSManagedObjectContext class]];
	[pool release];
}
#endif

- (id)init 
{
	[super init];
	
	if ( nil != self )
	{
		// static initialization
		if ( nil == sMainThreadID )
		{
			sMainThreadID = [[NSString stringWithFormat:@"%p", [[NSApp delegate] mainThread]] retain];
		}
		if (nil == sAllMOCs)
		{
			sAllMOCs = [[NSMutableDictionary alloc] init];
		}
		
		// add ourself to sAllMOCs
		@synchronized ( sAllMOCs )
		{
			[sAllMOCs setObject:[NSString stringWithFormat:@"%p", [NSThread currentThread]] forKey:[NSString stringWithFormat:@"%p", self]];
		}
		//LOG((@"MOC %p is associated with thread %p", self, [NSThread currentThread]));
	}
	
	return self;
}

- (void)dealloc
{
	//LOG((@"dealloc'ing MOC %p", self));
	@synchronized ( sAllMOCs )
	{
		[sAllMOCs removeObjectForKey:[self threadKey]];
	}
	[super dealloc];
}

- (NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error
{
#ifdef DEBUG
	[self checkThread:_cmd];
#endif
	
	NSArray *result = [super executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error];
	
	return result;
}


- (BOOL)lockIfNeeded
{
	if ( [self wouldBeAccessedInOtherThanCreationThread] )
	{
		[self lock];
		//LOG((@"needed to lock %@", self));
		return YES;
	}
	
	return NO;
}

- (void)unlockIfNeeded:(BOOL)didLock
{
	if ( didLock )
	{
		[self unlock];
		//LOG((@"needed to unlock %@", self));
	}
}

- (BOOL)wouldBeAccessedInOtherThanCreationThread
{
	return (![[self threadID] isEqualToString:[NSString stringWithFormat:@"%p", [NSThread currentThread]]]);
}

- (NSString *)threadID
{
	NSString *result = nil;
	
	@synchronized ( sAllMOCs )
	{
		result = [sAllMOCs objectForKey:[self threadKey]];
	}
	
	return result;
}

- (NSString *)threadKey
{
	return [NSString stringWithFormat:@"%p", self];
}

- (void)threadSafeDeleteObject:(NSManagedObject *)object
{
	[self lockPSCAndSelf];
	[self deleteObject:object];
	[self unlockPSCAndSelf];
}

#pragma mark -
#pragma mark DEBUG ONLY BELOW
	
#ifdef DEBUG

- (void)checkThread:(SEL)aSel
{
	if (myLockCount) return;
	
	if ([self wouldBeAccessedInOtherThanCreationThread])
	{
		NSString *expectedThreadID = [sAllMOCs objectForKey:[self threadKey]];		
		NSString *currentThreadID = [NSString stringWithFormat:@"%p", [NSThread currentThread]];
		
		if ( [currentThreadID isEqualToString:sMainThreadID] )
		{
			LOG((@":::::: %@ -- attempting to use MOC %p in main thread %p, expected %@", 
				 NSStringFromSelector(aSel), 
				 self, 
				 [NSThread currentThread],
				 expectedThreadID));
		}
		else 
		{
			LOG((@":::::: %@ -- attempting to use MOC %p in background thread %p, expected %@",
				 NSStringFromSelector(aSel),
				 self, 
				 [NSThread currentThread],
				 expectedThreadID));
		}
	}
}

- (int)lockCount
{
	return myLockCount;
}

- (void)setPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator
{
	[self checkThread:_cmd];
	return [super setPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator];
}

// KTDocument createPeerContext calls this ... OK?

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
//	[self checkThread:_cmd];
	return [super persistentStoreCoordinator];
}
- (void)setUndoManager:(NSUndoManager *)undoManager
{
	[self checkThread:_cmd];
	return [super setUndoManager:(NSUndoManager *)undoManager];
}
- (NSUndoManager *)undoManager
{
	NSUndoManager *result = [super undoManager];
	if ( nil != result )
	{
		[self checkThread:_cmd];
	}
	return result;
}
- (BOOL)hasChanges		// IS IT OK TO CALL THIS FROM ANOTHER THREAD, E.G. KTDocument saveContext ?  Stop complaining for now
{
//	[self checkThread:_cmd];
	return [super hasChanges];
}
- (NSManagedObject *)objectRegisteredForID:(NSManagedObjectID *)objectID
{
	[self checkThread:_cmd];
	return [super objectRegisteredForID:(NSManagedObjectID *)objectID];
}
- (NSManagedObject *)objectWithID:(NSManagedObjectID *)objectID
{
	[self checkThread:_cmd];
	return [super objectWithID:(NSManagedObjectID *)objectID];
}

// [NSManagedObjectContext(_NSInternalAdditions) lockObjectStore]
//
//- (void)lockObjectStore
//{
//	NSLog(@";;;;; lockObjectStore");
//	[super lockObjectStore];
//}
//
//- (NSArray *)unlockObjectStore
//{
//	NSLog(@";;;;; unlockObjectStore");
//	return [super unlockObjectStore];
//}


- (void)insertObject:(NSManagedObject *)object
{
	[self checkThread:_cmd];
	return [super insertObject:(NSManagedObject *)object];
}
- (void)deleteObject:(NSManagedObject *)object
{
	[self checkThread:_cmd];
	return [super deleteObject:(NSManagedObject *)object];
}
- (void)refreshObject:(NSManagedObject *)object mergeChanges:(BOOL)flag
{
	[self checkThread:_cmd];
	return [super refreshObject:(NSManagedObject *)object mergeChanges:(BOOL)flag];
}
- (void)detectConflictsForObject:(NSManagedObject *)object
{
	[self checkThread:_cmd];
	return [super detectConflictsForObject:(NSManagedObject *)object];
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	[self checkThread:_cmd];
	return [super observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context];
}
- (void)processPendingChanges
{
	[self checkThread:_cmd];
	return [super processPendingChanges];
}
- (void)assignObject:(id)object toPersistentStore:(id)store
{
	[self checkThread:_cmd];
	return [super assignObject:(id)object toPersistentStore:(id)store];
}
// are these three methods thread-safe???
- (NSSet *)insertedObjects
{
	//[self checkThread:_cmd];
	return [super insertedObjects];
}
- (NSSet *)updatedObjects
{
	//[self checkThread:_cmd];
	return [super updatedObjects];
}
- (NSSet *)deletedObjects
{
	//[self checkThread:_cmd];
	return [super deletedObjects];
}
- (NSSet *)registeredObjects
{
	[self checkThread:_cmd];
	return [super registeredObjects];
}
- (void)undo
{
	[self checkThread:_cmd];
	return [super undo];
}
- (void)redo
{
	[self checkThread:_cmd];
	return [super redo];
}
- (void)reset
{
	[self checkThread:_cmd];
	return [super reset];
}
- (void)rollback
{
	[self checkThread:_cmd];
	return [super rollback];
}
- (BOOL)save:(NSError **)error
{
	[self checkThread:_cmd];
	return [super save:(NSError **)error];
}
- (void)lock
{
	// no need to check thread; obviously we can lock from another thread
	myLockCount++;
	if ( [self isDocumentMOC] )
	{
		OFF((@"MOC+++++ %p   lock, now = %d", self, myLockCount));
	}
	return [super lock];
}
- (void)unlock
{
	// no need to check thread; obviously we can lock from another thread
	myLockCount--;
	if ( [self isDocumentMOC] )
	{
		OFF((@"MOC----- %p unlock, now = %d", self, myLockCount));
	}
	if (myLockCount == 0)
	{
		if ( [self isDocumentMOC] )
		{
			OFF((@"MOC-------------------- %p", self));
		}
	}
	if (myLockCount < 0)
	{
		if ( [self isDocumentMOC] )
		{
			LOG((@"unlock of KTManagedObjectContext -- Less than zero!"));
		}
		myLockCount = 0;
	}
	return [super unlock];
}
- (BOOL)tryLock
{
	// no need to check thread; obviously we can lock from another thread
	BOOL locked = [super tryLock];
	return locked;
}
- (BOOL)propagatesDeletesAtEndOfEvent
{
	[self checkThread:_cmd];
	return [super propagatesDeletesAtEndOfEvent];
}
- (void)setPropagatesDeletesAtEndOfEvent:(BOOL)flag
{
	[self checkThread:_cmd];
	return [super setPropagatesDeletesAtEndOfEvent:(BOOL)flag];
}
- (BOOL)retainsRegisteredObjects
{
	[self checkThread:_cmd];
	return [super retainsRegisteredObjects];
}
- (void)setRetainsRegisteredObjects:(BOOL)flag
{
	[self checkThread:_cmd];
	return [super setRetainsRegisteredObjects:(BOOL)flag];
}
- (NSTimeInterval)stalenessInterval
{
	[self checkThread:_cmd];
	return [super stalenessInterval];
}
- (void)setStalenessInterval:(NSTimeInterval)expiration
{
	[self checkThread:_cmd];
	return [super setStalenessInterval:(NSTimeInterval)expiration];
}
- (void)setMergePolicy:(id)mergePolicy
{
	[self checkThread:_cmd];
	return [super setMergePolicy:mergePolicy];
}
- (id)mergePolicy
{
	[self checkThread:_cmd];
	return [super mergePolicy];
}
#endif

@end
