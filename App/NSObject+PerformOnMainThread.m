//
//  NSObject+PerformOnMainThread.m
//  Marvel
//
//  Created by Mike on 04/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "NSObject+PerformOnMainThread.h"


@implementation NSObject (PerformOnMainThread)

- (id)performInvocationOnMainThreadAndReturnResult:(NSInvocation *)invocation
{
	[self performSelectorOnMainThread:@selector(mainThreadInvokeInvocation:)
						   withObject:invocation
						waitUntilDone:YES];
	
	id result = nil;
	if ([[invocation methodSignature] methodReturnLength] > 0)
	{
		[invocation getReturnValue:&result];
	}
	
	return [result autorelease];	// It was retained on the main thread
}

- (id)performSelectorOnMainThreadAndReturnResult:(SEL)selector
{
	NSInvocation *invocation = [NSInvocation invocationWithSelector:selector target:self arguments:nil];
	id result = [self performInvocationOnMainThreadAndReturnResult:invocation];
	return result;
}

- (id)performSelectorOnMainThreadAndReturnResult:(SEL)selector withObject:(id)argument
{
	NSInvocation *invocation = [NSInvocation invocationWithSelector:selector
															 target:self
														  arguments:[NSArray arrayWithObject:argument]];
														  
	id result = [self performInvocationOnMainThreadAndReturnResult:invocation];
	return result;
}

- (id)performSelectorOnMainThreadAndReturnResult:(SEL)selector withObject:(id)argument1 withObject:(id)argument2
{
	NSArray *arguments = [NSArray arrayWithObjects:argument1, argument2, nil];
	
	NSInvocation *invocation = [NSInvocation invocationWithSelector:selector
															 target:self
														  arguments:arguments];
														  
	id result = [self performInvocationOnMainThreadAndReturnResult:invocation];
	return result;
}

- (void)mainThreadInvokeInvocation:(NSInvocation *)invocation
{
	[invocation invoke];
	
	if ([[invocation methodSignature] methodReturnLength] > 0)
	{
		id result;
		[invocation getReturnValue:&result];
		[result retain];	// It will be released in the background thread later
	}
}

@end
