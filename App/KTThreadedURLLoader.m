//
//  KTThreadedURLLoader.m
//  Marvel
//
//  Created by Greg Hulands on 31/07/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "KTThreadedURLLoader.h"

#import "Debug.h"

enum { CHECK_TASKS = 1 };

static int sKTMaxMediaLoaderThreads = 1;
static KTThreadedURLLoader *_default = nil;


@interface KTThreadedURLLoader (Private)
- (void)processTasks;
@end


@implementation KTThreadedURLLoader

+ (void)initialize	// +initialize is preferred over +load when possible
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	_default = [[KTThreadedURLLoader alloc] init];
	[pool release];
}

+ (id)sharedLoader 
{
	return _default;
}

- (id)init
{
	self = [super init];
	if ( nil != self )
	{
		myThreadCount = 0;
		myLock = [[NSLock alloc] init];
		myTasks = [[NSMutableArray alloc] init];
		myPort = [[NSPort port] retain];
		[myPort setDelegate:self];
		
		sKTMaxMediaLoaderThreads = [[NSUserDefaults standardUserDefaults] integerForKey:@"MediaLoaderMaxThreads"];
		if ( sKTMaxMediaLoaderThreads != 1 )
		{
			sKTMaxMediaLoaderThreads = 1;
			[[NSUserDefaults standardUserDefaults] setInteger:1 forKey:@"MediaLoaderMaxThreads"];
		}
		
		[NSThread detachNewThreadSelector:@selector(KTMediaURLLoader:) toTarget:self withObject:nil];
	}
	return self;
}

- (void)dealloc
{
	[myLock release];
	[myTasks release];
	[myPort release];
	
	[super dealloc];
}

- (void)KTMediaURLLoader:(id)unused
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	myThread = [NSThread currentThread];
	// NOTE: this may be leaking ... there are two retains going on here.  Apple bug report #2885852, still open after TWO YEARS!
	// But then again, we can't remove the thread, so it really doesn't mean much.	
	[[NSRunLoop currentRunLoop] addPort:myPort forMode:NSDefaultRunLoopMode];
	
	while ( 1 )
	{		
		[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
	}
	
	[pool release];
}

- (void)sendPortMessage:(int)aMessage
{
	if  (nil != myPort )
	{
		NSPortMessage *message = [[NSPortMessage alloc] initWithSendPort:myPort receivePort:myPort components:nil];
		[message setMsgid:aMessage];
		
		@try 
		{
			if ( [NSThread currentThread] != myThread )
			{
				BOOL sent = [message sendBeforeDate:[NSDate dateWithTimeIntervalSinceNow:15.0]];
				if ( !sent )
				{
					LOG((@"KTThreadedURLLoader couldn't send message %d", aMessage));
				}
			}
			else
			{
				[self handlePortMessage:message];
			}
		}
		@catch (NSException *e)
		{
			LOG((@"%@ %@", NSStringFromSelector(_cmd), e));
		}
		@finally
		{
			[message release];
		} 
	}
}

- (void)handlePortMessage:(NSPortMessage *)portMessage
{
    int message = [portMessage msgid];
	switch ( message )
	{
		case CHECK_TASKS:
		{
			[self processTasks];
			break;
		}
		default:
		{
			LOG((@"%@ %@ unknown message %u", [self className], NSStringFromSelector(_cmd), message));
		}
	}
}

- (void)threadedTaskInvocation:(NSInvocation *)anInvocation
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[anInvocation invoke];
	[[anInvocation target] release];
	
	[myLock lock];
	myThreadCount--;
	[myLock unlock];
	[self sendPortMessage:CHECK_TASKS];
	
	[pool release];
}

- (void)processTasks
{
	[myLock lock];
	
	NSRange range = NSMakeRange(0, sKTMaxMediaLoaderThreads - myThreadCount);
	if ( NSMaxRange(range) > [myTasks count] )
	{
		range.length = [myTasks count];
	}
	
	NSArray *tasks = [myTasks subarrayWithRange:range];
	[myTasks removeObjectsInRange:range];
	myThreadCount += [tasks count];
	
	[myLock unlock];
	
	NSEnumerator *e = [tasks objectEnumerator];
	NSInvocation *invocation;
	while ( invocation = [e nextObject] )
	{
		[NSThread detachNewThreadSelector:@selector(threadedTaskInvocation:) toTarget:self withObject:invocation];
	}
}

- (void)delayedPostMessage
{
	[self sendPortMessage:CHECK_TASKS];
}

- (void)scheduleInvocation:(NSInvocation *)anInvocation
{
	[myLock lock];
	[myTasks addObject:anInvocation];
	[myLock unlock];
	
	if ( [NSThread currentThread] != myThread )
	{
		[self performSelector:@selector(delayedPostMessage) withObject:nil afterDelay:0.0];
	}
	else
	{
		[self processTasks];
	}
}

- (id)prepareWithInvocationTarget:(id)target
{
	[myLock lock];
	
	[myTarget release];
	myTarget = [target retain];
	
	return self;
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
	NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
	if ( nil == signature )
	{
		signature = [myTarget methodSignatureForSelector:aSelector];
	}
	
	return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
	[anInvocation setTarget:myTarget];
	myTarget = nil;
	
	[myLock unlock];
	
	[self performSelector:@selector(scheduleInvocation:) withObject:anInvocation afterDelay:0.0];
}

@end
