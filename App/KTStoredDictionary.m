//
//  KTStoredDictionary.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KTStoredDictionary.h"

#import "Debug.h"
#import "KTDocument.h"
#import "NSData+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSObject+KTExtensions.h"


@interface KTStoredDictionary ()
- (NSArray *)entries;
@end


@implementation KTStoredDictionary

- (NSDictionary *)dictionary
{
	//[self lockPSCAndMOC];
	
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	NSEnumerator *e = [self keyEnumerator];
	id key;
	while ( key = [e nextObject] )
	{
		[result setObject:[self objectForKey:key] forKey:key];
	}
	
	//[self unlockPSCAndMOC];
	
	return [NSDictionary dictionaryWithDictionary:result];
}

#pragma mark core date to-many relationships

- (NSArray *)entries
{
	NSMutableArray *array = [NSMutableArray array];
	
	[array addObjectsFromArray:[[self wrappedValueForKey:@"dataEntries"] allObjects]];
	[array addObjectsFromArray:[[self wrappedValueForKey:@"stringsEntries"] allObjects]];
	
	return [NSArray arrayWithArray:array];
}

#pragma mark NSDictionary-like primitives

- (unsigned)count
{
	unsigned int result = 0;
	
	//[self lockPSCAndMOC];
	result = [[self valueForKey:@"dataEntries"] count] + [[self valueForKey:@"stringsEntries"] count];
	//[self unlockPSCAndMOC];

	return result;
}

- (id)objectForKey:(id)aKey
{
	id result = nil;
	
	//[self lockPSCAndMOC];
	[self willAccessValueForKey:aKey];

	NSEnumerator *e = [[self entries] objectEnumerator];
	NSManagedObject *entry;
	
	while ( entry = [e nextObject] )
	{
		if ( [[entry valueForKey:@"key"] isEqual:aKey] )
		{
			id value = [entry valueForKey:@"value"];
			if ( [value isKindOfClass:[NSData class]] )
			{
				result = [NSData mutableFoundationObjectFromData:value];
				break;
			}
			else
			{
				result = value;
				break;
			}
		}
	}
	
	[self didAccessValueForKey:aKey];
	//[self unlockPSCAndMOC];

	return result;
}

- (NSArray *)allKeys
{
	NSMutableArray *keys = [NSMutableArray array];
	
	NSEnumerator *e = [[self entries] objectEnumerator];
	id entry;
	while ( entry = [e nextObject] )
	{
		[keys addObject:[entry wrappedValueForKey:@"key"]];
	}
	
	return keys;
}

- (NSEnumerator *)keyEnumerator
{
	
	return [[self allKeys] objectEnumerator];
}

- (NSArray *)allObjects
{
	return [self allValues];
}

- (NSArray *)allValues
{
	NSMutableArray *values = [NSMutableArray array];
	
	NSEnumerator *e = [[self entries] objectEnumerator];
	id entry;
	while ( entry = [e nextObject] )
	{
		id value = [entry wrappedValueForKey:@"value"];
		if ( [value isKindOfClass:[NSData class]] )
		{
			[values addObject:[NSData mutableFoundationObjectFromData:value]];
		}
		else
		{
			[values addObject:value];
		}
	}
	
	return values;
}

#pragma mark key-value trickery

- (id)valueForUndefinedKey:(NSString *)aKey
{
	return [self objectForKey:aKey];
}

#pragma mark support

- (NSManagedObject *)entryForKey:(NSString *)aKey
{
	NSEnumerator *e = [[self entries] objectEnumerator];
	id entry;
	while ( entry = [e nextObject] )
	{
		if ( [[entry wrappedValueForKey:@"key"] isEqualToString:aKey] )
		{
			return entry;
		}
	}
	
	return nil;
}

- (NSString *)verboseDescription
{
	NSString *desc = @"";
	
	//[self lockPSCAndMOC];
	
	NSEnumerator *e = [[self allKeys] objectEnumerator];
	NSString *key;
	while ( key = [e nextObject] )
	{
		id object = [self objectForKey:key];
		desc = [desc stringByAppendingFormat:@"\nkey = %@, value = %@", key, [object description]];
	}
	
	//[self unlockPSCAndMOC];
	
	return desc;
}

@end
