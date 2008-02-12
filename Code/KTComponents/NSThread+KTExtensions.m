//
//  NSThread+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/20/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

#import "NSThread+KTExtensions.h"


@interface NSObject ( KTThreadingPrivate )
- (NSThread *)mainThread;
@end


@implementation NSThread ( KTExtensions )

+(BOOL)isMainThread
{
	NSThread *mainThread = [[NSApp delegate] mainThread];
	// main thread is nil, it hasn't been initialized yet!
	return (nil == mainThread) || [mainThread isEqual:[self currentThread]];
}

@end
