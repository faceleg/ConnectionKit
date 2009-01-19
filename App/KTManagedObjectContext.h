//
//  KTManagedObjectContext.h
//  KTComponents
//
//  Created by Terrence Talbot on 11/14/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// this class exists to facilitate (and debug) multi-threaded Core Data access

@interface KTManagedObjectContext : NSManagedObjectContext
{
#ifdef DEBUG
	int myLockCount; // in RELEASE, we poseAsClass: which can't have any ivars
#endif
}

#ifdef DEBUG
// lock context if context wouldBeAccessedInOtherThanCreationThread
- (BOOL)lockIfNeeded;
- (void)unlockIfNeeded:(BOOL)didLock;

// returns %p of thread in which this context was created
- (NSString *)threadID;

// returns %p of self
- (NSString *)threadKey;

// puts a lockIfNeeded around deleteObject:
- (void)threadSafeDeleteObject:(NSManagedObject *)object;

// compares current thread against original thread
- (BOOL)wouldBeAccessedInOtherThanCreationThread;
#endif

#ifdef DEBUG
- (int)lockCount;
#endif

@end
