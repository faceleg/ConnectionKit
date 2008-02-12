//
//  KTStoredSet.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTStoredSet.h"

#import "Debug.h"
#import "KTManagedObjectContext.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

@implementation KTStoredSet

#pragma mark constructors

+ (id)setInManagedObjectContext:(KTManagedObjectContext *)aContext entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id set = [NSEntityDescription insertNewObjectForEntityForName:anEntityName inManagedObjectContext:aContext];
	[aContext unlockPSCAndSelf];
	return set;
}

+ (id)setWithArray:(NSArray *)anArray inManagedObjectContext:(KTManagedObjectContext *)aContext entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id set = [self setInManagedObjectContext:aContext entityName:anEntityName];
	[set copyObjectsFromArray:anArray];
	[aContext unlockPSCAndSelf];
	return set;
}

+ (id)setWithSet:(id)aSet inManagedObjectContext:(KTManagedObjectContext *)aContext entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id set = [self setInManagedObjectContext:aContext entityName:anEntityName];
	[set copyObjectsFromArray:[aSet allObjects]];
	[aContext unlockPSCAndSelf];
	return set;
}

#pragma mark value accessors

- (NSMutableSet *)set
{
	return [NSMutableSet setWithArray:[self allObjects]];
}

- (void)setSet:(id)aSet
{
	[self removeAllObjects];
	[self copyObjectsFromArray:[aSet allObjects]];
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

#pragma mark KTStoredArray overrides

- (void)addObject:(id)anObject
{
	if ( ![self member:anObject] )
	{
		[super addObject:anObject];
	}
}

@end
