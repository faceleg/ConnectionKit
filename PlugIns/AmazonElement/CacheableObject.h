//
//  MACacheableObject.h
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	Computating or retrieving values for a key can be slow. For an object whose values will
//	not change after initial loading, the results can be cached for better performance.
//	This class provides methods for easily maintaining such a cache.
//	Use -cachedValueForKey:  If nothing has been cached, the method -myKeyUncached is
//	called, where "myKey" is the key originally passed.


#import <Foundation/Foundation.h>


@interface CacheableObject : NSObject
{
	NSMutableDictionary	*_cachedValues;
}

- (BOOL)valueForKeyIsCached:(NSString *)key;
- (id)cachedValueForKey:(NSString *)key;
- (id)cacheValueForKey:(NSString *)key;
- (void)cacheValue:(id)value forKey:(NSString *)key;

@end
