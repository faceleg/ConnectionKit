//
//  AsyncObjectQueue.h
//  Amazon List
//
//  Created by Mike on 17/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Queues up AsyncObjects and loads them at one second intervals
//	(although this paramater should be specifiable in the future).

#import <Cocoa/Cocoa.h>
#import "AsyncObject.h"


@interface AsyncObjectQueue : NSObject
{
	NSMutableArray	*myQueue;
	NSDate			*myLastLoadDate;
}

// Queue
- (NSArray *)queuedObjects;

- (void)addObjectToQueue:(AsyncObject *)anObject;
- (void)removeObjectFromQueue:(AsyncObject *)anObject;
- (void)removeAllObjectsFromQueue;

// Dates
- (NSDate *)lastObjectLoadDate;
- (NSDate *)nextAvailableObjectLoadDate;

@end
