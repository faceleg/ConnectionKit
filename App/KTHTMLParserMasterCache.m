//
//  KTHTMLParserMasterCache.m
//  Marvel
//
//  Created by Mike on 13/09/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTHTMLParserMasterCache.h"

#import "KTTemplateParser.h"
#import "SVHTMLContext.h"


@interface KTHTMLParserMasterCache ()
// Requested key paths
- (void)registerRequestedKeyPath:(NSString *)keyPath forObject:(NSObject *)object;
@end


@implementation KTHTMLParserMasterCache

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithProxyObject:(NSObject *)proxyObject parser:(KTTemplateParser *)parser
{
	OBASSERTSTRING(proxyObject, @"-[KTHTMLParserMasterCahce initWithProxyObject:parser:] Attempt with nil proxy object");
	
	[super initWithProxyObject:proxyObject];
	
	myOverrides = [[NSMutableDictionary alloc] init];
	myParser = parser;		// Weak ref
	
	return self;
}

- (void)dealloc
{
	[myOverrides release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTTemplateParser *)parser { return myParser; }

#pragma mark -
#pragma mark KVC

- (id)valueForKey:(NSString *)key
{
	// First see if this particular key has been overriden. If so, return the value for that
	id result = [[myOverrides objectForKey:key] proxyObject];
	
	// If there was no override, use the default implementation
	if (!result)
	{
		result = [super valueForKey:key];
		[self registerRequestedKeyPath:key forObject:[self proxyObject]];
	}
	
	return result;
}

/*	Convenience method for -valueForKeyPath:informDelegate:
 */
- (id)valueForKeyPath:(NSString *)keyPath
{
	return [self valueForKeyPath:keyPath informDelegate:YES];
}

/*	Supplement to the default behaviour of -valueForKeyPath to handle overriden keys.
 *	
 *	I am working on the principal that there are four types of keypath to be considered here:
 *		some.keyPath
 *		keyPath
 *		anObject.keyPath
 *		anObject
 *	
 *	The code is commented where it relates to a specific case.
 */
- (id)valueForKeyPath:(NSString *)keyPath informDelegate:(BOOL)informDelegate;
{
	id result = nil;
	
	KTHTMLParserCache *cache;
	NSString *trueKeyPath = keyPath;
	
	// Special case to handle "anObject"
	cache = [myOverrides objectForKey:keyPath];
	if (cache)
	{
		result = [cache proxyObject];
		return result;
	}
	
	// Is this "anObject.keyPath" ? If so, set object and trueKeyPath appropriately.
	NSRange firstSeparatorRange = [keyPath rangeOfString:@"."];
	if (firstSeparatorRange.location != NSNotFound)
	{
		NSString *firstKey = [keyPath substringToIndex:(firstSeparatorRange.location)];
		cache = [myOverrides objectForKey:firstKey];
		if (cache)
		{
			// Pull the rest of the key path from the overriden object's cache
			trueKeyPath = [keyPath substringFromIndex:(firstSeparatorRange.location + firstSeparatorRange.length)];
			result = [cache valueForKeyPath:trueKeyPath];
		}
	}
	
	// It's not an overriden key, so do the standard implementation
	if (trueKeyPath == keyPath)
	{
		cache = self;
		result = [super valueForKeyPath:trueKeyPath];
	}
	
	// Register the request
	if (informDelegate)
	{
		[self registerRequestedKeyPath:trueKeyPath forObject:[cache proxyObject]];
	}
	
	return result;
}

#pragma mark -
#pragma mark KVC Overriding

- (id)overridingValueForKey:(NSString *)key;
{
	KTHTMLParserCache *subCache = [myOverrides objectForKey:key];
	id result = [subCache proxyObject];
	return result;
}

/*	Overrides the default behaviour for any further -valueForKey: or -valueForKeyPath: calls
 *	to the specified key. Instead of using our cache, the value is fetched from a new cache
 *	specific to the overriding value.
 */
- (void)overrideKey:(NSString *)key withValue:(id)override
{
	OBASSERTSTRING(key, @"Attempt to override a nil key in the parser cache");
	OBASSERTSTRING(override, @"Attempt to override parser cache key with nil value");
	NSAssert1([key rangeOfString:@"."].location == NSNotFound, @"“%@” is not a valid parser cache override key", key);  // Clang, already asserted key is non-nil
	NSAssert1(![myOverrides objectForKey:key], @"The key “%@” is already in overidden", key);
	
	KTHTMLParserCache *overrideCache = [[KTHTMLParserCache alloc] initWithProxyObject:override];
	[myOverrides setObject:overrideCache forKey:key];
	[overrideCache release];
}

- (void)removeOverrideForKey:(NSString *)key
{
	[myOverrides removeObjectForKey:key];
}

#pragma mark -
#pragma mark Requested Key Paths

- (void)registerRequestedKeyPath:(NSString *)keyPath forObject:(NSObject *)object
{
	// Alert the context
	[[SVHTMLContext currentContext] addDependencyOnObject:object keyPath:keyPath];
}

@end

