//
//  KTHTMLParserCache.m
//  Marvel
//
//  Created by Mike on 11/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTHTMLParserCache.h"


@interface KTHTMLParserCache ()
// Cache
- (id)cachedValueForKeyPath:(NSString *)keyPath;
- (void)cacheValue:(id)value forKeyPath:(NSString *)keyPath;
- (BOOL)valueForKeyPathIsCached:(NSString *)keyPath;
@end


@implementation KTHTMLParserCache

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithProxyObject:(NSObject *)proxyObject
{
	[super init];
	
	myProxyObject = [proxyObject retain];
	myCachedValues = [[NSMutableDictionary alloc] init];
	
	return self;
}

- (void)dealloc
{
	[myProxyObject release];
	[myCachedValues release];
	
	[super dealloc];
}	

#pragma mark -
#pragma mark Accessors

- (NSObject *)proxyObject { return myProxyObject; }

#pragma mark -
#pragma mark KVC

- (id)valueForKey:(NSString *)key
{
	id result = nil;
	
	if ([self valueForKeyPathIsCached:key])
	{
		result = [self cachedValueForKeyPath:key];
	}
	else
	{
		result = [[self proxyObject] valueForKey:key];
		[self cacheValue:result forKeyPath:key];
	}
	
	return result;
}

/*	Fetches the value for the key path from either the proxy object or cache as approrpriate.
 *	Will then cache the value as well if required.
 */
- (id)valueForKeyPath:(NSString *)keyPath
{
	id result = nil;
	
	if ([self valueForKeyPathIsCached:keyPath])
	{
		result = [self cachedValueForKeyPath:keyPath];
	}
	else
	{
		result = [super valueForKeyPath:keyPath];
		[self cacheValue:result forKeyPath:keyPath];
	}
	
	return result;
}

#pragma mark -
#pragma mark Cache

- (id)cachedValueForKeyPath:(NSString *)keyPath
{
	id result = [myCachedValues objectForKey:keyPath];
	
	// Convert NSNull back to nil
	if (result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (void)cacheValue:(id)value forKeyPath:(NSString *)keyPath
{
	// Convert nil to NSNull
	if (!value)
	{
		value = [NSNull null];
	}
	
	[myCachedValues setObject:value forKey:keyPath];
}

- (BOOL)valueForKeyPathIsCached:(NSString *)keyPath
{
	BOOL result = ([myCachedValues objectForKey:keyPath] != nil);
	return result;
}

@end
