//
//  KTStoredDictionary.m
//  KTComponents
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

#import "KTStoredDictionary.h"

#import "Debug.h"
#import "KTDocument.h"
#import "KTManagedObjectContext.h"
#import "NSData+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+KTExtensions.h"


@interface KTStoredDictionary ( Private )
- (BOOL)canSave;
- (void)saveIfPossible;
- (NSArray *)entries;
- (void)setObject:(id)anObject forKey:(id)aKey saveIfPossible:(BOOL)shouldSave;
- (void)removeObjectForKey:(id)aKey saveIfPossible:(BOOL)shouldSave;
@end


@implementation KTStoredDictionary

+ (id)dictionaryInManagedObjectContext:(KTManagedObjectContext *)aContext 
							entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id dictionary = [NSEntityDescription insertNewObjectForEntityForName:anEntityName inManagedObjectContext:aContext];
	[aContext unlockPSCAndSelf];
	return dictionary;
}

+ (id)dictionaryWithDictionary:(id)aDictionary 
		inManagedObjectContext:(KTManagedObjectContext *)aContext 
					entityName:(NSString *)anEntityName
{
	[aContext lockPSCAndSelf];
	id dictionary = [self dictionaryInManagedObjectContext:aContext entityName:anEntityName];
	[dictionary addEntriesFromDictionary:aDictionary];
	[aContext unlockPSCAndSelf];
	return dictionary;
}

- (NSDictionary *)dictionary
{
	[self lockPSCAndMOC];
	
	NSMutableDictionary *result = [NSMutableDictionary dictionary];
	
	NSEnumerator *e = [self keyEnumerator];
	id key;
	while ( key = [e nextObject] )
	{
		[result setObject:[self objectForKey:key] forKey:key];
	}
	
	[self unlockPSCAndMOC];
	
	return [NSDictionary dictionaryWithDictionary:result];
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
	
	[self lockPSCAndMOC];
	result = [[self valueForKey:@"dataEntries"] count] + [[self valueForKey:@"stringsEntries"] count];
	[self unlockPSCAndMOC];

	return result;
}

- (id)objectForKey:(id)aKey
{
	id result = nil;
	
	[self lockPSCAndMOC];
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
	[self unlockPSCAndMOC];

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

#pragma mark NSMutableDictionary-like primitives

- (void)setObject:(id)anObject forKey:(id)aKey
{
	[self setObject:anObject forKey:aKey saveIfPossible:YES];
}

- (void)setObject:(id)anObject forKey:(id)aKey saveIfPossible:(BOOL)shouldSave
{
	[self lockPSCAndMOC];

	if ( nil != anObject )
	{
        // do we already have an object for aKey?
        id oldObject = [[[self objectForKey:aKey] retain] autorelease];
        
        // would it be a different storage type?
        if ( nil != oldObject )
        {
            BOOL oldIsString = [oldObject isKindOfClass:[NSString class]];
            BOOL newIsString = [anObject isKindOfClass:[NSString class]];
            if ( (oldIsString && !newIsString) 
                 || (!oldIsString && newIsString) )
            {
                [self removeObjectForKey:aKey];
            }
        }
        
		[self willChangeValueForKey:aKey];

		// see if we need to encode a value
		id value = nil;
		if ( [anObject isKindOfClass:[NSString class]] )
		{
			value = anObject;
		}
        else if ( [anObject respondsToSelector:@selector(stringValue)] )
        {
            // are we already storing this as a string?
            if ( (nil != oldObject) && [oldObject isKindOfClass:[NSString class]] )
            {
                // yes, keep storing as a string
                value = [anObject stringValue];
            }
            else
            {
                // no, store as encoded data
                value = [NSData dataFromFoundationObject:anObject];
            }
        }
		else
		{
            // anything not a string needs to be encoded as data
			value = [NSData dataFromFoundationObject:anObject];
		}
				
		NSManagedObject *entry = [self entryForKey:aKey];
		if ( nil != entry )
		{
			// we already have an entry with this key
			// just set the new value and we're done
			[entry setValue:value forKey:@"value"];
		}
		else
		{
			if ( [value isKindOfClass:[NSString class]] )
			{
				entry = [NSEntityDescription insertNewObjectForEntityForName:@"KeyValueAsString" 
													  inManagedObjectContext:[self managedObjectContext]];
			}
			else
			{
				entry = [NSEntityDescription insertNewObjectForEntityForName:@"KeyValueAsData" 
													  inManagedObjectContext:[self managedObjectContext]];
			}
			[entry setValue:aKey forKey:@"key"];
			[entry setValue:value forKey:@"value"];
			if ( [value isKindOfClass:[NSString class]] )
			{
				NSMutableSet *stringsEntries = [self mutableSetValueForKey:@"stringsEntries"];
				[stringsEntries addObject:entry];
			}
			else
			{
				NSMutableSet *dataEntries = [self mutableSetValueForKey:@"dataEntries"];
				[dataEntries addObject:entry];
			}
		}
		
		[self didChangeValueForKey:aKey];
	}
	else if ( nil != [self objectForKey:aKey] )
	{
        [self removeObjectForKey:aKey];
	}
	
	if ( shouldSave )
	{
		[self saveIfPossible];
	}
	
	[self unlockPSCAndMOC];
}

- (void)removeObjectForKey:(id)aKey
{
	[self removeObjectForKey:aKey saveIfPossible:YES];
}

- (void)removeObjectForKey:(id)aKey saveIfPossible:(BOOL)shouldSave
{
	BOOL keyFound = NO;
	
	KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
	[context lockPSCAndSelf];
	[self willChangeValueForKey:aKey];

	// we'll do an optimization guess by checking strings first
	NSEnumerator *e = [[self valueForKey:@"stringsEntries"] objectEnumerator];
	NSManagedObject *entry;
	while ( entry = [e nextObject] )
	{
		if ( [[entry valueForKey:@"key"] isEqual:aKey] )
		{
			keyFound = YES;
			NSMutableSet *stringsEntries = [self mutableSetValueForKey:@"stringsEntries"];
			[stringsEntries removeObject:entry];
			[context deleteObject:entry];
			break;
		}
	}
	
	if ( !keyFound )
	{
		e = [[self valueForKey:@"dataEntries"] objectEnumerator];
		while ( entry = [e nextObject] )
		{
			if ( [[entry valueForKey:@"key"] isEqual:aKey] )
			{
				keyFound = YES;
				NSMutableSet *dataEntries = [self mutableSetValueForKey:@"dataEntries"];
				[dataEntries removeObject:entry];
				[context deleteObject:entry];
				break;
			}
		}
	}
		
	[self didChangeValueForKey:aKey];

	if ( shouldSave )
	{
		[self saveIfPossible];
	}
	
	[context unlockPSCAndSelf];
}

- (void)removeObjectsForKeys:(NSArray *)aKeyArray
{
	NSEnumerator *e = [aKeyArray objectEnumerator];
	NSString *key;
	while ( key = [e nextObject] )
	{
		[self removeObjectForKey:key saveIfPossible:NO];
	}
	
	[self saveIfPossible];
}

-(void)removeAllObjects
{
	NSEnumerator *e = [self keyEnumerator];
	NSString *key;
	while ( key = [e nextObject] )
	{
		[self removeObjectForKey:key saveIfPossible:NO];
	}
	
	[self saveIfPossible];
}

- (void)addEntriesFromDictionary:(id)aDictionary
{
	// this should work for either NSDictionaries or KTStoredDictionaries
	// keeping in mind that all entries must be pointers to foundation objects only
	NSEnumerator *e = [aDictionary keyEnumerator];
	id key;
	while ( key = [e nextObject] )
	{
		id value = [aDictionary objectForKey:key];
		[self setObject:value forKey:key saveIfPossible:NO];
	}
	
	[self saveIfPossible];
}

- (void)replaceAllObjectsWithEntriesFromDictionary:(id)otherDictionary
{
	[self removeAllObjects];
	[self addEntriesFromDictionary:otherDictionary];
}

#pragma mark convenience

- (BOOL)boolForKey:(NSString *)aKey
{
	NSNumber *value = [self objectForKey:aKey];
	return [value boolValue];
}

- (void)setBool:(BOOL)value forKey:(NSString *)aKey
{
	NSNumber *object = [NSNumber numberWithBool:value];
	[self setObject:object forKey:aKey];
}

- (float)floatForKey:(NSString *)aKey
{
	NSNumber *value = [self objectForKey:aKey];
	return [value floatValue];
}
- (void)setFloat:(float)value forKey:(NSString *)aKey
{
	NSNumber *object = [NSNumber numberWithFloat:value];
	[self setObject:object forKey:aKey];
}

- (int)integerForKey:(NSString *)aKey
{
	NSNumber *value = [self objectForKey:aKey];
	return [value intValue];
}

- (void)setInteger:(int)value forKey:(NSString *)aKey
{
	NSNumber *object = [NSNumber numberWithInt:value];
	[self setObject:object forKey:aKey];
}

#pragma mark key-value trickery

- (id)valueForUndefinedKey:(NSString *)aKey
{
	return [self objectForKey:aKey];
}

- (void)setValue:(id)aValue forUndefinedKey:(NSString *)aKey
{
	[self setObject:aValue forKey:aKey];
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
	
	[self lockPSCAndMOC];
	
	NSEnumerator *e = [[self allKeys] objectEnumerator];
	NSString *key;
	while ( key = [e nextObject] )
	{
		id object = [self objectForKey:key];
		desc = [desc stringByAppendingFormat:@"\nkey = %@, value = %@", key, [object description]];
	}
	
	[self unlockPSCAndMOC];
	
	return desc;
}

@end
