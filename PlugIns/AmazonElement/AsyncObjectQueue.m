//
//  AsyncObjectQueue.m
//  Amazon List
//
//  Created by Mike on 17/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AsyncObjectQueue.h"


@interface AsyncObjectQueue (Private)

- (NSMutableArray *)queue;

- (void)scheduleFirstQueuedObjectForNextAvailableDate;
- (void)loadFirstQueuedObject;

- (void)setLastObjectLoadDate:(NSDate *)date;

@end


@implementation AsyncObjectQueue

# pragma mark *** Dealloc ***

- (void)dealloc
{
	[self removeAllObjectsFromQueue];
	
	[myQueue release];
	[myLastLoadDate release];
	
	[super dealloc];
}

# pragma mark *** Queue Objects ***

- (NSMutableArray *)queue
{
	if (!myQueue) {
		myQueue = [[NSMutableArray alloc] initWithCapacity: 1];
	}
	
	return myQueue;
}

- (NSArray *)queuedObjects { return [self queue]; }

- (void)addObjectToQueue:(AsyncObject *)anObject
{
	NSMutableArray *queue = [self queue];
	
	// Add it to the end of the queue array
	[queue addObject: anObject];
	
	// If the only item in the queue, schedule it ourself
	if ([queue count] == 1) {
		[self scheduleFirstQueuedObjectForNextAvailableDate];
	}
}

- (void)removeObjectFromQueue:(AsyncObject *)anObject;
{
	NSMutableArray *queue = [self queue];
	
	// Bail if the object is not actually in the queue
	NSUInteger index = [queue indexOfObjectIdenticalTo: anObject];
	if (index == NSNotFound) { 
		return;
	}
		
	
	[[self queue] removeObjectIdenticalTo: anObject];
	
	// If the queue is now empty,  cancel the request to load the next object
	if ([queue count] == 0) {
		[NSObject cancelPreviousPerformRequestsWithTarget: self
												 selector: @selector(loadFirstQueuedObject)
												   object: nil];
	}
}

// Cancels loading the first object and removes all others
- (void)removeAllObjectsFromQueue
{
	[NSObject cancelPreviousPerformRequestsWithTarget: self
											 selector: @selector(loadFirstQueuedObject)
											   object: nil];
	
	[[self queue] removeAllObjects];
}

# pragma mark *** Queue Mnagement ***

- (void)scheduleFirstQueuedObjectForNextAvailableDate
{
	NSMutableArray *queue = [self queue];
	
	// Bail if there's nothing the queue
	if ([queue count] == 0) {
		return;
	}
	
	
	// Use the later of the two possible dates for the object
	NSDate *currentDate = [NSDate date];
	NSDate *nextAvailableDate = [self nextAvailableObjectLoadDate];

	NSDate *requestDate = [nextAvailableDate laterDate: currentDate];
	NSTimeInterval timeInterval = [requestDate timeIntervalSinceDate: currentDate];
	
	
	// Ask the operation to start loading after the delay
	[self performSelector: @selector(loadFirstQueuedObject)
			   withObject: nil
			   afterDelay: timeInterval];
}

- (void)loadFirstQueuedObject
{
	NSMutableArray *queue = [self queue];
	if ([queue count] == 0) {
		return;
	}
	
	
	AsyncObject *object = [[queue objectAtIndex: 0] retain];
	
	// Remove the object from the queue
	[self setLastObjectLoadDate: [NSDate date]];
	[self removeObjectFromQueue: object];
	
	// Load it
	[object _load];
	[object release];
	
	// Schedule the next operation
	[self scheduleFirstQueuedObjectForNextAvailableDate];
}

# pragma mark *** Dates ***

- (NSDate *)lastObjectLoadDate { return myLastLoadDate; }

// The date the last object in the queue was loaded
// If no objects have been loaded yet, returns nil
- (void)setLastObjectLoadDate:(NSDate *)date
{
	[date retain];
	[myLastLoadDate release];
	myLastLoadDate = date;
}

// As it says on the tin. If nothing has been loaded yet, returns the current date
- (NSDate *)nextAvailableObjectLoadDate
{
	NSDate *lastLoadDate = [self lastObjectLoadDate];
	
	NSDate *nextAvailableDate = nil;
	if (lastLoadDate) {
		nextAvailableDate = [lastLoadDate addTimeInterval: 1.0];
	}
	else {
		nextAvailableDate = [NSDate date];
	}

	return nextAvailableDate;
}

@end
