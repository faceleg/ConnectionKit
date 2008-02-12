//
//  KTPersistentStoreCoordinator.h
//  KTComponents
//
//  Created by Terrence Talbot on 3/16/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

// this class exists to facilitate (and debug) multi-threaded Core Data access

@interface KTPersistentStoreCoordinator : NSPersistentStoreCoordinator 
{
#ifdef DEBUG
	int myLockCount; // in RELEASE, we poseAsClass: which can't have any ivars
#endif
}

@end
