//
//  ClassThatSeemsToHaveUnfixableBindingBugPoser.m
//  Marvel
//
//  Created by Terrence Talbot on 4/22/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "ClassThatSeemsToHaveUnfixableBindingBugPoser.h"


static NSMutableDictionary *sBoundKeys = nil;
static NSMutableDictionary *sBoundObjects = nil;


@implementation ClassThatSeemsToHaveUnfixableBindingBugPoser

- (void)bind:(NSString *)binding toObject:(id)observable withKeyPath:(NSString *)keyPath options:(NSDictionary *)options
{
	[super bind:binding toObject:observable withKeyPath: keyPath options:options];
	
	id Self = [NSString stringWithFormat:@"%p", self];
	NSMutableArray *keys = [sBoundKeys objectForKey:Self];
	if ( nil != keys ) 
	{
		keys = [NSMutableArray array];
		[sBoundKeys setObject:keys forKey:Self];
	}
	[keys addObject:keyPath];
}

- (void)unbind:(NSString *)binding
{
	[super unbind:binding];
	
	id Self = [NSString stringWithFormat:@"%p", self];
	NSMutableArray *keys = [sBoundKeys objectForKey:Self];
	[keys removeObject:binding];
}


- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context
{
	[super addObserver:observer forKeyPath:keyPath options:options context:context];
	
	id Self = [NSString stringWithFormat:@"%p", self];
	NSMutableArray *bindings = [sBoundObjects objectForKey:Self];
	if ( nil == bindings )
	{
		bindings = [NSMutableArray array];
		[sBoundObjects setObject:bindings forKey:Self];
	}
	[bindings addObject:[NSArray arrayWithObjects:observer, keyPath, nil]];
}

- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath
{
	[super removeObserver:observer forKeyPath:keyPath];
	
	id Self = [NSString stringWithFormat:@"%p", self];
	NSMutableArray *bindings = [sBoundObjects objectForKey:Self];
	[bindings removeObject:[NSArray arrayWithObjects:observer, keyPath, nil]];
}

- (id)init 
{
	[super init];
	
	if ( nil != self )
	{
		// static initialization
		if (nil == sBoundKeys)
		{
			sBoundKeys = [[NSMutableDictionary alloc] init];
		}
		
		if (nil == sBoundObjects)
		{
			sBoundObjects = [[NSMutableDictionary alloc] init];
		}
	}
	
	return self;
}

- (void)dealloc
{
	id Self = [NSString stringWithFormat:@"%p", self];
	NSMutableArray *bindings = [sBoundObjects objectForKey:Self];
	if ( [bindings count] > 0 ) 
	{
		NSLog(@"%@ %@ but you still have some observers observing!\n%@", [self className], NSStringFromSelector(_cmd), bindings);
	}
	
	[super dealloc];
}

- (oneway void)release
{
	id Self = [NSString stringWithFormat:@"%x", self];
	[super release];
	Self = nil;
}

@end
