//
//  KTHost.m
//  Marvel
//
//  Created by Greg Hulands on 5/06/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTHost.h"
#include <netinet/in.h>     
#include <arpa/nameser.h> 
#include <netdb.h> 
#include <unistd.h>


@implementation KTHost

+ (id)currentHost
{
	return [[[KTHost alloc] initWithName:@"localhost"] autorelease];
}

+ (id)hostWithName:(NSString *)name
{
	return [[[KTHost alloc] initWithName:name] autorelease];
}

+ (id)hostWithAddress:(NSString *)address
{
	return [[[KTHost alloc] initWithAddress:address] autorelease];
}

- (id)initWithName:(NSString *)name
{
	if (self = [super init])
	{
		myTimeoutValue = 15;
		myHost = CFHostCreateWithName(kCFAllocatorDefault,(CFStringRef)name);
		myLock = [[NSLock alloc] init];
	}
	return self;
}

- (id)initWithAddress:(NSString *)address
{
	if (self = [super init])
	{
		struct sockaddr_in addr;
		addr.sin_addr.s_addr = inet_addr([address UTF8String]);
		myTimeoutValue = 15;
		myHost = CFHostCreateWithAddress(kCFAllocatorDefault,(CFDataRef)[NSData dataWithBytes:&addr length:sizeof(addr)]);
		myLock = [[NSLock alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[myTimeoutTimer invalidate];
	[myTimeoutTimer release];
	if (myHost) CFRelease(myHost);
	[myLock release];
	
	[super dealloc];
}

- (void)setTimeout:(NSTimeInterval)to
{
	myTimeoutValue = to;
}

- (NSTimeInterval)timeout
{
	return myTimeoutValue;
}

- (void)resolve
{
	[myLock lock];
	if (!hasResolved && !isResolving)
	{
		isResolving = YES;
		[NSThread detachNewThreadSelector:@selector(threadedResolve:) toTarget:self withObject:nil];
		[NSTimer scheduledTimerWithTimeInterval:myTimeoutValue
										 target:self
									   selector:@selector(resolveTimedOut:)
									   userInfo:nil
										repeats:NO];
	}
	BOOL check = !hasResolved;
	[myLock unlock];
	
	while (check)
	{
		[NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]];
		[myLock lock];
		check = !hasResolved;
		[myLock unlock];
	}
}

- (void)threadedResolve:(id)unused
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	//CFHostScheduleWithRunLoop(myHost,[[NSRunLoop currentRunLoop] getCFRunLoop],kCFRunLoopCommonModes);
	CFStreamError error;
	if (!CFHostStartInfoResolution(myHost,kCFHostReachability,&error))
	{
		//NSLog(@"Failed to reach host");
	}
	if (!CFHostStartInfoResolution(myHost,kCFHostAddresses,&error))
	{
		//NSLog(@"Failed to resolve addresses");
	}
	if (!CFHostStartInfoResolution(myHost,kCFHostNames,&error))
	{
		//NSLog(@"Failed to resolve host names");
	}
	[myLock lock];
	isResolving = NO;
	hasResolved = YES;
	[myLock unlock];
	
	[pool release];
}

- (void)resolveTimedOut:(NSTimer *)timer
{
	CFHostCancelInfoResolution(myHost,kCFHostAddresses);
	CFHostCancelInfoResolution(myHost,kCFHostNames);
	CFHostCancelInfoResolution(myHost,kCFHostReachability);
}

- (NSString *)address
{
	return [[self addresses] lastObject];
}

- (NSArray *)addresses
{
	[self resolve];
	CFArrayRef addresses = CFHostGetAddressing(myHost,NULL);
	NSMutableArray *addrs = [NSMutableArray array];
	
	struct sockaddr  *addr;
    char             ipAddress[INET6_ADDRSTRLEN];
    CFIndex          theIndex, count;
    int              err;
    
    
    count = CFArrayGetCount(addresses);
    for (theIndex = 0; theIndex < count; theIndex++) {
        addr = (struct sockaddr *)CFDataGetBytePtr(CFArrayGetValueAtIndex(addresses, theIndex));
        
        /* getnameinfo coverts an IPv4 or IPv6 address into a text string. */
        err = getnameinfo(addr, addr->sa_len, ipAddress, INET6_ADDRSTRLEN, NULL, 0, NI_NUMERICHOST);
        if (err == 0) {
            [addrs addObject:[NSString stringWithUTF8String:ipAddress]];
        } 
    }
	
	return addrs;
}

- (NSString *)name
{
	return [[self names] lastObject];
}

- (NSArray *)names
{
	[self resolve];
	NSArray *names = (NSArray *)CFHostGetNames(myHost,NULL);
	return names;
}

- (BOOL)isEqualToHost:(KTHost *)host
{
	return [[self name] isEqualToString:[host name]];
}

@end
