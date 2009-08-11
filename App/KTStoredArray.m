//
//  KTStoredArray.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KTStoredArray.h"

#import "Debug.h"
#import "NSData+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSSet+KTExtensions.h"
#import "NSSortDescriptor+Karelia.h"


@interface KTStoredArray ()
- (NSArray *)items;
@end


@implementation KTStoredArray

#pragma mark core data to-many relationships
	
- (NSArray *)items
{
	NSMutableArray *array = [NSMutableArray array];
	
	//[self lockPSCAndMOC];
	[array addObjectsFromArray:[[self valueForKey:@"dataItems"] allObjects]];
	[array addObjectsFromArray:[[self valueForKey:@"stringsItems"] allObjects]];
	NSArray *result = [array sortedArrayUsingDescriptors:[NSSortDescriptor orderingSortDescriptors]];
	//[self unlockPSCAndMOC];
	
	return result;
}

#pragma mark NSArray primitives

- (unsigned)count
{
	return [[self items] count];
}

- (id)objectAtIndex:(unsigned)anIndex
{
	id value = [[self items] objectAtIndex:anIndex];
	if ( [value isMemberOfClass:[NSData class]] )
	{
		value = [NSData mutableFoundationObjectFromData:value];
	}
    return value;
}

- (NSArray *)allValues
{
	//[self lockPSCAndMOC];
	
	NSMutableArray *array = [NSMutableArray array];
	
	NSArray *items = [self items]; // get them ordered
	unsigned int i;
	for ( i=0; i<[items count]; i++)
	{
		id item = [items objectAtIndex:i];
		id value = [item valueForKey:@"value"];
		if ( [value isMemberOfClass:[NSData class]] )
		{
			value = [NSData mutableFoundationObjectFromData:value];
		}
		[array addObject:value];
	}
	
	//[self unlockPSCAndMOC];
	
	return [NSArray arrayWithArray:array];
}

#pragma mark other array methods

// Probably not the most efficient.  Perhaps we could make our own enum class.
- (NSEnumerator *)objectEnumerator;
{
	return [[self allValues] objectEnumerator];
}

- (NSString *)verboseDescription
{
	//[self lockPSCAndMOC];
	NSString *result =  [[self allValues] description];
	//[self unlockPSCAndMOC];
	return result;
}

@end
