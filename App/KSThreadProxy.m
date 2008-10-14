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
    [anInvocation performSelectorOnMainThread:@selector(invokeWithTarget:)
                                   withObject:_target
                                waitUntilDone:YES];
}

@end
