//
//  MACacheableObject.m
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "CacheableObject.h"

@implementation CacheableObject

- (id)init
{
	[super init];

	_cachedValues = [[NSMutableDictionary alloc] init];

	return self;
}

- (void)dealloc
{
	[_cachedValues release];

	[super dealloc];
}

- (BOOL)valueForKeyIsCached:(NSString *)key
{
	BOOL isCached = ([_cachedValues objectForKey: key] != nil);
	return isCached;
}

- (id)cachedValueForKey:(NSString *)key
{
	id result = nil;

	if ([self valueForKeyIsCached: key])
	{
		result = [self cacheValueForKey: key];
	}
	else
	{
		NSString *uncachedKey = [key stringByAppendingString: @"Uncached"];
		result = [self valueForKey: uncachedKey];
		[self cacheValue: result forKey: key];
	}

	return result;
}

- (id)cacheValueForKey:(NSString *)key
{
	id cachedValue = [_cachedValues objectForKey: key];

	// Convert NSNull objects back to nil
	if (cachedValue == [NSNull null])
		cachedValue = nil;

	return cachedValue;
}

- (void)cacheValue:(id)value forKey:(NSString *)key
{
	// If the value is nil, use NSNull instead to avoid an NSMutableDictionary exception
	if (!value)
		value = [NSNull null];

	[_cachedValues setObject: value forKey: key];
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@%@",
		[super description],
		([_cachedValues count] ?  [NSString stringWithFormat:@" Cache:%@", _cachedValues] : @"")
		];
}

@end
