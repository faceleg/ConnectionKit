//
//  KSThreadProxy.m
//  Marvel
//
//  Created by Mike on 14/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KSThreadProxy.h"


@implementation KSThreadProxy

- (id)initWithTarget:(id)target
{
    return [self initWithTarget:target thread:nil];
}

- (id)initWithTarget:(id)target thread:(NSThread *)thread;
{
    OBPRECONDITION(target);
    //OBPRECONDITION(thread);   We don't actually support arbitrary threads yet, so ignore for now
    
    _target = [target retain];
    _thread = [thread retain];
    
    return self;
}

- (void)dealloc
{
    [_target release];
    [_thread release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Method forwarding

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *result = [_target methodSignatureForSelector:aSelector];
    return result;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    [anInvocation retainArguments];
    
    [anInvocation performSelectorOnMainThread:@selector(invokeWithTargetAndReportExceptions:)
                                    withObject:_target
                                 waitUntilDone:YES];
}

@end


@implementation NSInvocation (KSThreadProxyAdditions)

/*  We perform our own exception handling as by default -performSelectorOnMainThread:
 *  does nothing more than log exceptions.
 */
- (void)invokeWithTargetAndReportExceptions:(id)target
{
	@try
    {
        [self invokeWithTarget:target];
        [self retainArguments];
    }
    @catch (NSException *exception)
    {
        [NSApp reportException:exception];
    }
}

@end


#pragma mark -


@implementation NSObject (KSThreadProxy)

- (id)proxyForThread:(NSThread *)thread
{
    KSThreadProxy *result = [[KSThreadProxy alloc] initWithTarget:self thread:thread];
    return [result autorelease];
}

- (id)proxyForMainThread
{
    return [self proxyForThread:nil];
}

@end


