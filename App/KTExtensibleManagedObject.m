//
//  KTExtensibleManagedObject.m
//  Marvel
//
//  Created by Mike on 25/08/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTExtensibleManagedObject.h"


@interface KTExtensibleManagedObject (Private)
+ (NSSet *)modifiedKeysBetweenDictionary:(NSDictionary *)dict1 andDictionary:(NSDictionary *)dict2;
- (NSMutableDictionary *)storedValues;
- (void)storeValues;
@end


#pragma mark -


@implementation KTExtensibleManagedObject

#pragma mark -
#pragma mark Class Methods

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	return NO;
}

+ (NSString *)extensiblePropertiesDataKey
{
	return @"extensiblePropertiesData";
}

#pragma mark -
#pragma mark Accessors

- (NSDictionary *)extensiblePropertyValues
{
	// Force us not to be a fault first
	[self willAccessValueForKey:[[self class] extensiblePropertiesDataKey]];
	NSDictionary *result = [NSDictionary dictionaryWithDictionary:myValues];
	[self didAccessValueForKey:[[self class] extensiblePropertiesDataKey]];
	
	return result;
}

#pragma mark -
#pragma mark Core Data

/*	Prepare a blank new internal dictionary
 */
- (void)awakeFromInsert
{
	[super awakeFromInsert];
	
	myValues = [[NSMutableDictionary alloc] init];
	[self storeValues];
}

/*	Throw away our internal dictionary
 */
- (void)didTurnIntoFault
{
	[myValues release];	myValues = nil;
	[super didTurnIntoFault];
}

#pragma mark -
#pragma mark KVC

- (id)valueForUndefinedKey:(NSString *)key
{
	// It is possible that we are currently a fault, so reload the dictionary if required
	if (!myValues)
	{
		myValues = [[self storedValues] retain];
	}
	
	id result = [myValues valueForKey:key];
	return result;
}

- (void)setValue:(id)value forUndefinedKey:(NSString *)key
{
	[self willChangeValueForKey:key];
	
	[myValues setValue:value forKey:key];
	[self storeValues];
	
	[self didChangeValueForKey:key];
}

/*	Whenever a change to our dictionary data is made due to an undo or redo, match the changes to
 * our in-memory dictionary
 */
- (void)didChangeValueForKey:(NSString *)key
{
	if ([key isEqualToString:[[self class] extensiblePropertiesDataKey]])
	{
		NSUndoManager *undoManager = [[self managedObjectContext] undoManager];
		if ([undoManager isUndoing] || [undoManager isRedoing])
		{
			// Comparison of the old and new dictionaries in order to to send out approrpriate KVO notifications
			NSDictionary *currentDictionary = myValues;
			NSDictionary *replacementDictionary = [self storedValues];
			
			NSSet *modifiedKeys = [KTExtensibleManagedObject modifiedKeysBetweenDictionary:currentDictionary
																			 andDictionary:replacementDictionary];
			
			[self willChangeValuesForKeys:modifiedKeys];		
			
			// Change each of the modified keys in our in-memory dictionary
			NSEnumerator *keysEnumerator = [modifiedKeys objectEnumerator];
			NSString *aKey;
			while (aKey = [keysEnumerator nextObject])
			{
				[myValues setValue:[replacementDictionary valueForKey:aKey] forKey:aKey];
			}
			
			[self didChangeValuesForKeys:modifiedKeys];
		}
	}
	
	// Finally go ahead and do the default behavior. This is required to balance the earlier -willChange
	[super didChangeValueForKey:key];
}

#pragma mark -
#pragma mark Support

+ (NSSet *)modifiedKeysBetweenDictionary:(NSDictionary *)dict1 andDictionary:(NSDictionary *)dict2
{
	// Build the set containing all the keys that exist in either dictionary
	NSMutableSet *allKeys = [[NSMutableSet alloc] initWithArray:[dict1 allKeys]];
	[allKeys addObjectsFromArray:[dict2 allKeys]];
	
	// Then run through these building a list of keys which the two dictionaries have different values for
	NSEnumerator *enumerator = [allKeys objectEnumerator];
	NSString *aKey;
	NSMutableSet *result = [NSMutableSet set];
	
	while (aKey = [enumerator nextObject])
	{
		if (![[dict1 valueForKey:aKey] isEqual:[dict2 valueForKey:aKey]]) {
			[result addObject:aKey];
		}
	}
	
	// Tidy up
	[allKeys release];
	
	return result;
}

/*	Fetches all custom values from the persistent store rather than the in-memory representation.
 */
- (NSMutableDictionary *)storedValues
{
	NSData *data = [self wrappedValueForKey:[[self class] extensiblePropertiesDataKey]];
	NSMutableDictionary *result = [self unarchiveExtensiblePropertiesDictionary:data];
	return result;
}

/*	Writes our internal dictionary to the persistent store
 */
- (void)storeValues
{
	[self setWrappedValue:[self archiveExtensiblePropertiesDictionary:myValues]
				   forKey:[[self class] extensiblePropertiesDataKey]];
}

- (NSMutableDictionary *)unarchiveExtensiblePropertiesDictionary:(NSData *)propertiesData
{
	NSMutableDictionary *result = nil;
	
	if (propertiesData)
	{
		id unarchivedDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:propertiesData];
		if ([unarchivedDictionary isKindOfClass:[NSMutableDictionary class]])
		{
			result = unarchivedDictionary;
		}
	}
	
	// If we were unable to build a dictionary from the data, begin a new one
	if (!result)
	{
		result = [NSMutableDictionary dictionary];
	}
	
	return result;
}

- (NSData *)archiveExtensiblePropertiesDictionary:(NSDictionary *)properties;
{
	NSData *result = [NSKeyedArchiver archivedDataWithRootObject:properties];
	return result;
}

@end
