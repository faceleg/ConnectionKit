//
//  NSObject+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/16/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSObject+KTExtensions.h"

#import "KT.h"
#import "NSManagedObject+KTExtensions.h"


@implementation NSObject ( KTExtensions )

// enforcing intentions
+ (void)subclassResponsibility:(SEL)aSelector
{
	[NSException raise:kKTGenericObjectException format:[NSString stringWithFormat:[NSString stringWithFormat:@"%@ is a subclass responsibility of %@", NSStringFromSelector(aSelector), [self className]]]];
}

- (void)subclassResponsibility:(SEL)aSelector
{
	[self raiseExceptionWithName:kKTGenericObjectException reason:[NSString stringWithFormat:@"%@ is a subclass responsibility of %@", NSStringFromSelector(aSelector), [self className]]];
}

- (void)notImplemented:(SEL)aSelector
{
	[self raiseExceptionWithName:kKTGenericObjectException reason:[NSString stringWithFormat:@"%@ does not implement %@", [self className], NSStringFromSelector(aSelector)]];
}

- (void)shouldNotImplement:(SEL)aSelector
{
	[self raiseExceptionWithName:kKTGenericObjectException reason:[NSString stringWithFormat:@"%@ should not implement %@", [self className], NSStringFromSelector(aSelector)]];
}

// deprecation
- (void)deprecated:(SEL)aSelector
{
	NSLog(@"%@, %@ has been deprecated", [self className], NSStringFromSelector(aSelector));
}

// exceptions and errors
- (void)raiseExceptionWithName:(NSString *)name reason:(NSString *)reason userInfo:(NSDictionary *)userInfo
{
	[[NSException exceptionWithName:name reason:reason userInfo:userInfo] raise];
}

- (void)raiseExceptionWithName:(NSString *)name reason:(NSString *)reason
{
	[self raiseExceptionWithName:name reason:reason userInfo:nil];
}

- (void)raiseExceptionWithName:(NSString *)name
{
	[self raiseExceptionWithName:name reason:nil userInfo:nil];
}

// encodable?
- (BOOL)isFoundationObject
{
	if ( [self isKindOfClass:[NSData class]] )
	{
		return YES;
	}
	if ( [self isKindOfClass:[NSString class]] )
	{
		return YES;
	}
	if ( [self isKindOfClass:[NSNumber class]] )
	{
		return YES;
	}
	if ( [self isKindOfClass:[NSDate class]] )
	{
		return YES;
	}
	if ( [self isKindOfClass:[NSArray class]] )
	{
		return YES;
	}
	if ( [self isKindOfClass:[NSDictionary class]] )
	{
		return YES;
	}
	
	// default
	return NO;
}

// managed by a context?
- (BOOL)isManagedObject
{
    if ( [self isKindOfClass:[NSManagedObject class]] )
    {
        return YES;
    }
    
    // otherwise
    return NO;
}

- (id)wrappedValueForKeyWithFallback:(NSString *)aKey
{
	id value = nil;
	
	if ( [self respondsToSelector:@selector(wrappedValueForKey:)] )
	{
		value = [(NSManagedObject *)self wrappedValueForKey:aKey];
	}
	else
	{
		value = [self valueForKey:aKey];
	}
	
	return value;
}

- (void)setWrappedValueWithFallback:(id)aValue forKey:(NSString *)aKey
{
	if  ( [self respondsToSelector:@selector(wrappedValueForKey:)] )
	{
		[(NSManagedObject *)self setWrappedValue:aValue forKey:aKey];
	}
	else
	{
		[self setValue:aValue forKey:aKey];
	}
}

#pragma mark -
#pragma mark KVC

/*	Makes our life easier by not having to mess around directly with NSNumber
 */

- (BOOL)boolForKey:(NSString *)aKey
{
	NSNumber *value = [self valueForKey:aKey];
	return [value boolValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)aKey
{
	NSNumber *object = [NSNumber numberWithBool:value];
	[self setValue:object forKey:aKey];
}

- (float)floatForKey:(NSString *)aKey
{
	NSNumber *value = [self valueForKey:aKey];
	return [value floatValue];
}
- (void)setFloat:(float)value forKey:(NSString *)aKey
{
	NSNumber *object = [NSNumber numberWithFloat:value];
	[self setValue:object forKey:aKey];
}

- (int)integerForKey:(NSString *)aKey
{
	NSNumber *value = [self valueForKey:aKey];
	return [value intValue];
}

- (void)setInteger:(int)value forKey:(NSString *)aKey
{
	NSNumber *object = [NSNumber numberWithInt:value];
	[self setValue:object forKey:aKey];
}

/*	Convenient means for batch sending KVO notifications on a bunch of keys
 */

- (void)willChangeValuesForKeys:(NSSet *)keys;
{
	NSEnumerator *enumerator = [keys objectEnumerator];
	NSString *aKey;
	while (aKey = [enumerator nextObject])
	{
		[self willChangeValueForKey:aKey];
	}
}

- (void)didChangeValuesForKeys:(NSSet *)keys;
{
	NSEnumerator *enumerator = [keys objectEnumerator];
	NSString *aKey;
	while (aKey = [enumerator nextObject])
	{
		[self didChangeValueForKey:aKey];
	}
}

/*	Convenience methods for adding and removing an object as an observer for multiple key paths at once
 */
- (void)addObserver:(NSObject *)anObserver forKeyPaths:(NSSet *)keyPaths options:(NSKeyValueObservingOptions)options context:(void *)context
{
	NSEnumerator *enumerator = [keyPaths objectEnumerator];
	NSString *aKeyPath;
	while (aKeyPath = [enumerator nextObject])
	{
		[self addObserver:anObserver forKeyPath:aKeyPath options:options context:context];
	}
}

- (void)removeObserver:(NSObject *)observer forKeyPaths:(NSSet *)keyPaths
{
	NSEnumerator *enumerator = [keyPaths objectEnumerator];
	NSString *aKeyPath;
	while (aKeyPath = [enumerator nextObject])
	{
		[self removeObserver:observer forKeyPath:aKeyPath];
	}
}

@end
