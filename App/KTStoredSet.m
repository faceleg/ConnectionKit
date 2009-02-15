//
//  KTStoredSet.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KTStoredSet.h"

#import "Debug.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

@implementation KTStoredSet

#pragma mark value accessors

- (NSMutableSet *)set
{
	return [NSMutableSet setWithArray:[self allObjects]];
}

#pragma mark NSSet primitives

- (unsigned)count
{
    return [super count];
}

- (id)member:(id)anObject
{
	id result = nil;
	
	NSEnumerator *e = [[self allValues] objectEnumerator];
	id value;
	while ( value = [e nextObject] )
	{
		if ( [value isKindOfClass:[NSString class]]
			 && [anObject isKindOfClass:[NSString class]] )
		{
			if ( [value isEqualToString:anObject] )
			{
				result = value;
			}
		}
		else if ( [value isEqual:anObject] )
		{
			result = value;
		}
	}
	
	return result;
}

- (NSEnumerator *)objectEnumerator
{
	return [[self allObjects] objectEnumerator];
}

#pragma mark NSSet-like methods

- (NSArray *)allObjects
{
	return [self allValues];
}

- (BOOL)containsObject:(id)anObject
{
	return (nil != [self member:anObject]) ? YES : NO;
}

@end
