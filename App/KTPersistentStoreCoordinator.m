//
//  KTPersistentStoreCoordinator.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/16/07.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTPersistentStoreCoordinator.h"

#import "Debug.h"

@implementation KTPersistentStoreCoordinator

- (KTDocument *)document { return myDocument; }

- (void)setDocument:(KTDocument *)document { myDocument = document; }


#pragma mark -
#pragma mark Debug
/*
// in RELEASE, we want KTPersistentStoreCoordinator to poseAsClass:
// NSPersistentStoreCoordinator so that saveDocumentAs: works!
#ifndef DEBUG
+ (void)initialize		// Not +load; we have problems with that.  But then we need to get the class loaded right.
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	[self poseAsClass:[NSPersistentStoreCoordinator class]];
	[pool release];
}
#endif
*/

// we can only use myLock if we are DEBUGging
#ifdef DEBUG

- (void)lock
{
	[super lock];
	myLockCount++;
	OFF((@"PSC+++++ %p   lock, now = %d", self, myLockCount));	
}

- (void)unlock
{
	myLockCount--;
	OFF((@"PSC----- %p unlock, now = %d", self, myLockCount));
	if (myLockCount == 0)
	{
		OFF((@"PSC--------------------"));
	}
	if (myLockCount < 0)
	{
		LOG((@"unlock of KTPersistentStoreCoordinator -- Less than zero!"));
		myLockCount = 0;
	}
	[super unlock];
}

#endif

@end
