//
//  NSManagedObject+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 3/10/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "NSManagedObject+KTExtensions.h"

#import "NSEntityDescription+KTExtensions.h"
#import "NSString+KTExtensions.h"

#import "NSString+Karelia.h"

#import "Debug.h"


@interface NSManagedObject (KTExtensionsPrivate)
- (void)setTransientValue:(id)value forKey:(NSString *)key andPersistentData:(NSData *)data forKey:(NSString *)dataKey;
@end


@interface NSManagedObject ( DelegateHack )
- (id)delegate;
@end


@implementation NSManagedObject ( KTExtensions )

- (BOOL)hasAttributeNamed:(NSString *)anAttributeName
{
	// TJT rewrote this to use for loop with extra bulletproofing
	BOOL result = NO;
	
	NSEntityDescription *entity = [self entity];
	if ( nil != entity )
	{
		NSDictionary *attributes = [entity attributesByName]; // key = attribute name
		NSArray *attributeNames = [[attributes allKeys] copy];
		
		for ( NSString *name in attributeNames )
		{
			if ( [name isEqualToString:anAttributeName] )
			{
				result = YES;
				break;
			}
		}
		
		[attributeNames release];
	}
	
	return result;		// this had been just returning NO, no matter what
}

- (BOOL)hasRelationshipNamed:(NSString *)aRelationshipName
{
	// TJT rewrote this to use for loop with extra bulletproofing
	BOOL result = NO;
	
	NSEntityDescription *entity = [self entity];
	if ( nil != entity )
	{
		NSDictionary *relationships = [entity relationshipsByName]; // key = relationship name
		NSArray *relationshipNames = [[relationships allKeys] copy];
		
		for ( NSString *name in relationshipNames )
		{
			if ( [name isEqualToString:aRelationshipName] )
			{
				result = YES;
				break;
			}
		}
		
		[relationshipNames release];
	}
	
	return result;	
}

- (BOOL)isValidForKey:(NSString *)aKey
{
	OBASSERTSTRING([self hasAttributeNamed:aKey],@"object has no attribute with that name!");

	BOOL result = NO;
	@try
	{
		NSString *value = [self wrappedValueForKey:aKey];
		if ( nil != value )
		{
			result = YES;
		}
	}
	@catch (NSException *fetchException)
	{
		// if anything goes wrong, assume it's a bad object
		result = NO;
		if ( [[fetchException name] isEqualToString:@"NSObjectInaccessibleException"] )
		{
			LOG((@"CoreData could not fulfill a fault. %@ is not/no longer a valid managed object.", [self managedObjectDescription]));
		}
	}
	
	return result;
}


// thread-safe description method, nothing here should cause a fetch
- (NSString *)managedObjectDescription
{
	NSString *result = nil;
	
	result = [NSString stringWithFormat:@"%@:%@", [[self entity] name], [[[self objectID] URIRepresentation] absoluteString]];

	if ( [self isDeleted] )
	{
		result = [result stringByAppendingString:@" isDeleted"];
	}
	else if ( [self hasChanges] )
	{
		result = [result stringByAppendingString:@" hasChanges"];
	}
	
	// add thread
	
	return result;
}

- (NSString *)URIRepresentationString
{
	return [[[self objectID] URIRepresentation] absoluteString];
}

- (BOOL)hasTemporaryObjectID
{
	return [[self objectID] isTemporaryID];
}

- (BOOL)hasTemporaryURIRepresentation
{
	return [self hasTemporaryObjectID];
}

- (BOOL)isNewlyCreatedObject
{
    return [self hasTemporaryObjectID];
}

- (BOOL)hasChanges
{
	// changedValues, according to docs, doesn't fire faults
	// so we shouldn't need to lockPSCAndMOC here
	BOOL result = ([[self changedValues] count] > 0);
	
	return result;
}

- (NSUndoManager *)undoManager { return [[self managedObjectContext] undoManager]; }

#pragma mark -
#pragma mark KVC

/*	We're overriding the default NSObject implementations here to use -wrapppedValues
 */
- (BOOL)wrappedBoolForKey:(NSString *)aKey
{
	BOOL result = NO;
	
	result = [[self wrappedValueForKey:aKey] boolValue];
	
	return result;
}

- (void)setWrappedBool:(BOOL)value forKey:(NSString *)aKey
{
	[self setWrappedValue:[NSNumber numberWithBool:value] forKey:aKey];
}

- (float)wrappedFloatForKey:(NSString *)aKey
{
	float result = 0.0;
	
	result = [[self wrappedValueForKey:aKey] floatValue];
	
	return result;
}

- (void)setWrappedFloat:(float)value forKey:(NSString *)aKey
{
	[self setWrappedValue:[NSNumber numberWithFloat:value] forKey:aKey];
}

- (int)wrappedIntegerForKey:(NSString *)aKey
{
	int result = 0;
	
	result = [[self wrappedValueForKey:aKey] intValue];
	
	return result;
}

- (void)setWrappedInteger:(int)value forKey:(NSString *)aKey
{
	[self setWrappedValue:[NSNumber numberWithInt:value] forKey:aKey];
}

/*	Convenient wrapper for -committedValuesForKeys: when only a single key is required.
 *	Automatically converts NSNull objects back into nil.
 */
- (id)committedValueForKey:(NSString *)aKey
{
	NSDictionary *values = [self committedValuesForKeys:[NSArray arrayWithObject:aKey]];
	
	id result = [values valueForKey:aKey];
	if (result == [NSNull null])
	{
		result = nil;
	}
	
	return result;
}

- (id)persistentValueForKey:(NSString *)aKey
{
	id result = nil;
		
	// first check changedValues, then comittedValues
	NSDictionary *values = [self changedValues];
	if ( nil != [values valueForKey:aKey] )
	{
		result = [values valueForKey:aKey];
	}
	else
	{
		result = [self committedValueForKey:aKey];
	}
	
	
	return result;
}

/*	Convenience method for doing the -willAccess -primitiveValue -didAccess set of methods.
 */
- (id)wrappedValueForKey:(NSString *)aKey
{
	[self willAccessValueForKey:aKey];
	id result = [self primitiveValueForKey:aKey];
	[self didAccessValueForKey:aKey];
	return result;
}

// setWrappedValue:forKey: SHOULD NOT BE USED TO SET A RELATIONSHIP (IT WILL DIE DOWNSTREAM)
// setWrappedValue:forKey: ALSO WILL NOT SET BOTH SIDES OF A RELATIONSHIP
- (void)setWrappedValue:(id)aValue forKey:(NSString *)aKey
{
	[self willChangeValueForKey:aKey];
    [self setPrimitiveValue:aValue forKey:aKey];
    [self didChangeValueForKey:aKey];
}

- (id)delegableWrappedValueForKey:(NSString *)aKey
{
	id result = nil;
	
	// does the delegate respond?
	if ( [self respondsToSelector:@selector(delegate)] )
	{
		id delegate = [self delegate];
		if ( nil != delegate )
		{
			SEL selector = NSSelectorFromString(aKey);
			if ( [delegate respondsToSelector:selector] )
			{
				result = [delegate performSelector:selector];
			}
		}		
	}
	
	// if not, let's do it ourselves
	if ( nil == result )
	{
		result = [self wrappedValueForKey:aKey];
	}
	
	return result;
}

- (void)setDelegableWrappedValue:(id)aValue forKey:(NSString *)aKey
{
	if ( [self respondsToSelector:@selector(delegate)] )
	{
		id delegate = [self delegate];
		if ( nil != delegate )
		{
			NSString *selectorAsString = [NSString stringWithFormat:@"set%@:", [aKey firstLetterCapitalizedString]];
			SEL selector = NSSelectorFromString(selectorAsString);
		
			// does delegate implement "set"+aKey?
			if ( [delegate respondsToSelector:selector] )
			{
				[delegate performSelector:selector withObject:aValue];
				return;
			}
		}
	}
	
	[self setWrappedValue:aValue forKey:aKey];	
}

- (id)threadSafeWrappedValueForKey:(NSString *)aKey
{
	//[self lockPSCAndMOC];
    [self willAccessValueForKey:aKey];
    id result = [self primitiveValueForKey:aKey];
    [self didAccessValueForKey:aKey];
	//[self unlockPSCAndMOC];
    return result;
}

- (void)threadSafeSetWrappedValue:(id)aValue forKey:(NSString *)aKey
{
	//[self lockPSCAndMOC];
    [self willChangeValueForKey:aKey];
    [self setPrimitiveValue:aValue forKey:aKey];
    [self didChangeValueForKey:aKey];
	//[self unlockPSCAndMOC];
}

- (id)threadSafeValueForKey:(NSString *)aKey
{
	//[self lockPSCAndMOC];
	id result = [self valueForKey:aKey];
	//[self unlockPSCAndMOC];
	
	return result;
}

- (void)threadSafeSetValue:(id)aValue forKey:(NSString *)aKey
{
	//[self lockPSCAndMOC];
	[self setValue:aValue forKey:aKey];
	//[self unlockPSCAndMOC];
}

- (id)threadSafeValueForKeyPath:(NSString *)aKeyPath
{
	id result = nil;
	
	//[self lockPSCAndMOC];
	result = [self valueForKeyPath:aKeyPath];
	//[self unlockPSCAndMOC];
	
	return result;
}

- (void)threadSafeSetValue:(id)aValue forKeyPath:(NSString *)aKeyPath
{
	//[self lockPSCAndMOC];
	[self setValue:aValue forKeyPath:aKeyPath];
	//[self unlockPSCAndMOC];
}

- (NSDictionary *)currentValues
{
    NSArray *propertyKeys = [[[self entity] propertiesByName] allKeys];
	NSDictionary *result = [self dictionaryWithValuesForKeys:propertyKeys];
    return result;
}

#pragma mark -
#pragma mark Locking

- (void)lockContext
{
	//[[self managedObjectContext] lock];
}

- (void)unlockContext
{
	//[[self managedObjectContext] unlock];
}

- (BOOL)lockContextIfNeeded
{
	//[[self managedObjectContext] lock];
	return YES;
}

- (void)unlockContextIfNeeded:(BOOL)didLock
{
	//[[self managedObjectContext] unlock];
}

// these two methods should be paired
- (void)lockPSCAndMOC
{
	LOG((@"lockPSCAndMOC is deprecated -- who's calling me?"));
	//[[self managedObjectContext] checkPublishingModeAndThread];
	
	// lock PSC first
	//[[[self managedObjectContext] persistentStoreCoordinator] lock];
	//[[self managedObjectContext] lock];
}

- (void)unlockPSCAndMOC
{
	LOG((@"unlockPSCAndMOC is deprecated -- who's calling me?"));
	//[[self managedObjectContext] checkPublishingModeAndThread];

	// unlock MOC first
	//[[self managedObjectContext] unlock];
	//[[[self managedObjectContext] persistentStoreCoordinator] unlock];
}

#pragma mark -
#pragma mark Non-standard Transient Attributes

/*	Performs a standard -valueForKey: But if no value is found, it is reconstructed from the persistant property list specified
 */
- (id)transientValueForKey:(NSString *)key persistentPropertyListKey:(NSString *)plistKey
{
	//[self lockPSCAndMOC];
	
	[self willAccessValueForKey:key];
	id result = [self primitiveValueForKey:key];
	[self didAccessValueForKey:key];
	
	if (!result)
	{
        NSData *data = [self valueForKey:plistKey];
        
		if (data)
		{
            NSString *error = nil;
			result = [NSPropertyListSerialization propertyListFromData:data
													  mutabilityOption:NSPropertyListImmutable
															    format:NULL
													  errorDescription:&error];
													  
			if (error) {
				[NSException raise:NSInternalInconsistencyException
							format:@"The persistant property list data for key “%@” is invalid", key];
			}
													  
            [self setPrimitiveValue:result forKey:key];
        }
	}
    
	//[self unlockPSCAndMOC];
	
	return result;
}

/*	When setting a transient attribute we also want to store a data representation that is persistant.
 *	This is a convenience method to do just that.
 */
- (void)setTransientValue:(id)value forKey:(NSString *)key persistentPropertyListKey:(NSString *)plistKey
{
	NSString *error = nil;
	NSData *data = nil;
	if (value)
	{
		data = [NSPropertyListSerialization dataFromPropertyList:value
														  format:NSPropertyListBinaryFormat_v1_0
												errorDescription:&error];
	}
	
	if (error) {
		[NSException raise:NSInvalidArgumentException format:@"The value for key “%@” is not a valid property list", key];
	}
													
	[self setTransientValue:value forKey:key andPersistentData:data forKey:plistKey];
}

/*	Similar to the above two methods but uses NSKeyedArchiver and NSKeyedUnarchiver instead of a plist
 *	Handy for non-plist compatible classes such as NSSet.
 */
- (id)transientValueForKey:(NSString *)key persistentArchivedDataKey:(NSString *)dataKey
{
	//[self lockPSCAndMOC];
	
	[self willAccessValueForKey:key];
	id result = [self primitiveValueForKey:key];
	[self didAccessValueForKey:key];
	
	if (!result)
	{
        NSData *data = [self valueForKey:dataKey];
        
		if (data)
		{
            result = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			[self setPrimitiveValue:result forKey:key];
        }
	}
    
	//[self unlockPSCAndMOC];
	
	return result;
}

- (void)setTransientValue:(id)value forKey:(NSString *)key persistentArchivedDataKey:(NSString *)dataKey
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:value];
	[self setTransientValue:value forKey:key andPersistentData:data forKey:dataKey];
}

/*	Support for the two transient setter methods
 */
- (void)setTransientValue:(id)value forKey:(NSString *)key andPersistentData:(NSData *)data forKey:(NSString *)dataKey
{
	//[self lockPSCAndMOC];
	
	[self willChangeValueForKey:key];
    [self setPrimitiveValue:value forKey:key];
    [self didChangeValueForKey:key];
    
	[self setValue:data forKey:dataKey];
	
	//[self unlockPSCAndMOC];
}

#pragma mark Serialization

- (id)serializedProperties;               // calls [self serializedValueForKey:] with each non-transient attribute
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    [self populateSerializedProperties:result];    
    return result;
}

- (void)populateSerializedProperties:(NSMutableDictionary *)propertyList;
{
    NSDictionary *attributes = [[self entity] propertiesByNameOfClass:[NSAttributeDescription class]
                                           includeTransientProperties:NO];
    
    for (NSString *aKey in attributes)
    {
        id serializedValue = [self serializedValueForKey:aKey];
        if (serializedValue) [propertyList setObject:serializedValue forKey:aKey];
    }
}

- (id)serializedValueForKey:(NSString *)key
{
    return [self valueForKey:key];
}

- (void)setSerializedValue:(id)serializedValue forKey:(NSString*)key;
{
    [self setValue:serializedValue forKey:key];
}

- (void)awakeFromPropertyList:(id)propertyList;
{
    for (NSString *aKey in [[self entity] attributesByName])
    {
        [self setSerializedValue:[propertyList objectForKey:aKey] forKey:aKey];
    }
}

@end
