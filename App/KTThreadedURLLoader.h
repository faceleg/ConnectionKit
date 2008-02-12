//
//  KTThreadedURLLoader.h
//  Marvel
//
//  Created by Greg Hulands on 31/07/06.
//  Copyright 2006 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTThreadedURLLoader : NSObject 
{
	NSLock			*myLock;
	NSMutableArray	*myTasks;
	
	NSPort			*myPort;
	NSThread		*myThread;
	id				myTarget;
	int				myThreadCount;
}

+ (id)sharedLoader;
- (id)prepareWithInvocationTarget:(id)target;


@end
