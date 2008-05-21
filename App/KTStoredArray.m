//
//  KTStoredArray.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTStoredArray.h"

#import "Debug.h"
#import "KTDocument.h"
#import "KTManagedObjectContext.h"
#import "NSData+Karelia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSSet+KTExtensions.h"


@interface KTStoredArray ( Private )
- (BOOL)canSave;
- (void)saveIfPossible;
- (NSArray *)items;
@end


@implementation KTStoredArray

+ (id)arrayInManagedObjectContext:(KTManagedObjectContext *)aContext entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id array = [NSEntityDescription insertNewObjectForEntityForName:anEntityName inManagedObjectContext:aContext];
	[aContext unlockPSCAndSelf];
	return array;
}

+ (id)arrayWithArray:(id)anArray inManagedObjectContext:(KTManagedObjectContext *)aContext entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id array = [self arrayInManagedObjectContext:aContext entityName:anEntityName];
	[array copyObjectsFromArray:anArray];
	[aContext unlockPSCAndSelf];
	return array;
}

#pragma mark core data to-many relationships
	
- (NSArray *)items
{
	NSMutableArray *array = [NSMutableArray array];
	
	[self lockPSCAndMOC];
	[array addObjectsFromArray:[[self valueForKey:@"dataItems"] allObjects]];
	[array addObjectsFromArray:[[self valueForKey:@"stringsItems"] allObjects]];
	NSArray *result = [array sortedArrayUsingDescriptors:[NSSortDescriptor orderingSortDescriptors]];
	[self unlockPSCAndMOC];
	
	return result;
}

# pragma mark helpers

- (BOOL)canSave
{
	BOOL result = YES; // by default we can save, unless we are expecting an owner and don't have one
	
	if ( [self hasRelationshipNamed:@"owner"] )
	{
		[self lockPSCAndMOC];
		result = (nil != [self valueForKey:@"owner"]);
		[self unlockPSCAndMOC];
	}
	
	return result;
}

- (void)saveIfPossible
{
	if ( [self canSave] )
	{
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		[[context document] saveContext:context onlyIfNecessary:YES];
	}
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

#pragma mark NSMutableArray primitives

- (void)addObject:(id)anObject
{
	if ( nil != anObject )
	{
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		[context lockPSCAndSelf];
		
		// create ordered value
		NSManagedObject *item = nil;
		if ( [anObject isKindOfClass:[NSString class]] )
		{
			item = [NSEntityDescription insertNewObjectForEntityForName:@"OrderedValueAsString" 
												 inManagedObjectContext:context];
			[item setValue:anObject forKey:@"value"];
		}
		else
		{
			item = [NSEntityDescription insertNewObjectForEntityForName:@"OrderedValueAsData" 
												 inManagedObjectContext:context];
			[item setValue:[NSData dataFromFoundationObject:anObject] forKey:@"value"];
		}
		[item setInteger:[[self items] count] forKey:@"ordering"];
		
		// set array relationship
		if ( [anObject isKindOfClass:[NSString class]] )
		{
			NSMutableSet *stringsItems = [self mutableSetValueForKey:@"stringsItems"];
			[stringsItems addObject:item];
		}
		else
		{
			NSMutableSet *dataItems = [self mutableSetValueForKey:@"dataItems"];
			[dataItems addObject:item];
		}
		
		[self saveIfPossible];
		[context unlockPSCAndSelf];
	}
}

- (void)copyObject:(NSManagedObject *)anObject
{
	if ( nil != anObject )
	{
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		[context lockPSCAndSelf];
		
		NSManagedObject *newItem = [NSEntityDescription insertNewObjectForEntityForName:[[anObject entity] name]
																 inManagedObjectContext:context];
		[newItem setValue:[anObject valueForKey:@"value"] forKey:@"value"];
		[newItem setValue:[anObject valueForKey:@"ordering"] forKey:@"ordering"];
		[newItem setValue:self forKey:@"array"];
		
		[self saveIfPossible];
		[context unlockPSCAndSelf];
	}
}

- (void)removeObject:(id)anObject
{
	KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
	[context lockPSCAndSelf];
	
	NSMutableSet *dataItemsSet = [self mutableSetValueForKey:@"dataItems"];
	NSMutableSet *stringsItemsSet = [self mutableSetValueForKey:@"stringsItems"];
	
	int removeIndex = [[anObject valueForKey:@"ordering"] intValue];
	
	// remove the item
	if ( [dataItemsSet containsObject:anObject] )
	{
		[dataItemsSet removeObject:anObject];
		[context deleteObject:anObject];
	}
	else if ( [stringsItemsSet containsObject:anObject] )
	{
		[stringsItemsSet removeObject:anObject];
		[context deleteObject:anObject];
	}
	else
	{
		NSLog(@"error: %@ removeObject:%@ unknown object!", [self className], anObject);
	}
	
	// remove ordering (non-intuitive)
	NSMutableSet *itemsSet = [NSMutableSet setWithSet:dataItemsSet];
	[itemsSet addObjectsFromArray:[stringsItemsSet allObjects]];
	[itemsSet removeOrderingAt:removeIndex];
	
	[self saveIfPossible];
	[context unlockPSCAndSelf];
}

- (void)insertObject:(id)anObject atIndex:(unsigned)anIndex
{
	[self lockPSCAndMOC];
	
	// this is the workhorse method
	// we need to update the ordering for any object that would now come after
	NSMutableSet *dataItemsSet = [self mutableSetValueForKey:@"dataItems"];
	NSMutableSet *stringsItemsSet = [self mutableSetValueForKey:@"stringsItems"];

	NSMutableSet *itemsSet = [NSMutableSet setWithSet:dataItemsSet];
	[itemsSet addObjectsFromArray:[stringsItemsSet allObjects]];
	
	// update orderings after anIndex
	[itemsSet insertOrderingAt:anIndex];
	
	// add anObject to the correct set
	NSManagedObject *item = nil;
	if ( [anObject isKindOfClass:[NSString class]] )
	{
		item = [NSEntityDescription insertNewObjectForEntityForName:@"OrderedValueAsString" 
											 inManagedObjectContext:[self managedObjectContext]];
		[item setValue:anObject forKey:@"value"];
	}
	else
	{
		item = [NSEntityDescription insertNewObjectForEntityForName:@"OrderedValueAsData" 
											 inManagedObjectContext:[self managedObjectContext]];
		[item setValue:[NSData dataFromFoundationObject:anObject] forKey:@"value"];
	}
	[item setInteger:anIndex forKey:@"ordering"];
	
	if ( [anObject isKindOfClass:[NSString class]] )
	{
		NSMutableSet *stringsItems = [self mutableSetValueForKey:@"stringsItems"];
		[stringsItems addObject:item];
	}
	else
	{
		NSMutableSet *dataItems = [self mutableSetValueForKey:@"dataItems"];
		[dataItems addObject:item];
	}
	
	[self saveIfPossible];
	[self unlockPSCAndMOC];
}

- (void)removeLastObject
{
	id lastItem = [self objectAtIndex:([[self items] count]-1)];
	[self removeObject:lastItem];
}

- (void)removeObjectAtIndex:(unsigned)anIndex
{
	id item = [self objectAtIndex:anIndex];
	[self removeObject:item];
}

- (void)replaceObjectAtIndex:(unsigned)anIndex withObject:(id)anObject;
{
	[self removeObjectAtIndex:anIndex];
	[self insertObject:anObject atIndex:anIndex];
}

- (void)removeAllObjects
{
	while ( [[self items] count] > 0 )
	{
		[self removeLastObject];
	}
}

- (void)addObjectsFromArray:(NSArray *)anArray
{
	// should work for both NSArrays and KTStoredArrays
	unsigned int i;
	for ( i=0; i<[anArray count]; i++ )
	{
		[self addObject:[anArray objectAtIndex:i]];
	}
}

- (void)copyObjectsFromArray:(NSArray *)anArray
{
	// should work for both NSArrays and KTStoredArrays
	unsigned int i;
	for ( i=0; i<[anArray count]; i++ )
	{
		id object = [anArray objectAtIndex:i];
		if ( [object isKindOfClass:[NSManagedObject class]] )
		{
			[self copyObject:object];
		}
		else
		{
			[self addObject:object];
		}
	}	
}

- (NSArray *)allValues
{
	[self lockPSCAndMOC];
	
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
	
	[self unlockPSCAndMOC];
	
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
	[self lockPSCAndMOC];
	NSString *result =  [[self allValues] description];
	[self unlockPSCAndMOC];
	return result;
}

@end
