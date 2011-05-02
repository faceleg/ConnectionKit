//
//  NSEntityDescription+KTExtensions.m
//  ModelTester
//
//  Created by Terrence Talbot on 3/2/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "NSEntityDescription+KTExtensions.h"


@implementation NSEntityDescription ( KTExtensions )

/*	A convenience method on top -propertiesByName etc. that allows you to easily specify which
 *	type to use (attributes, relationships, all) and whether to include transients.
 */
- (NSDictionary *)propertiesByNameOfClass:(Class)propertyClass
			   includeTransientProperties:(BOOL)includeTransient;
{
	OBPRECONDITION(propertyClass);
	OBPRECONDITION([propertyClass isSubclassOfClass:[NSPropertyDescription class]]);
	
	
	// Get the basic result from the right set of properties
	NSDictionary *result = nil;
	if (propertyClass == [NSPropertyDescription class])
	{
		result = [self propertiesByName];
	}
	else if (propertyClass == [NSAttributeDescription class])
	{
		result = [self attributesByName];
	}
	else if (propertyClass == [NSRelationshipDescription class])
	{
		result = [self relationshipsByName];
	}
	OBASSERT(result);
	
	
	// Remove transient properties if requested
	if (!includeTransient)
	{
		NSMutableDictionary *buffer = [result mutableCopy];
		
		NSEnumerator *keysEnumerator = [result keyEnumerator];
		NSString *aKey;		NSPropertyDescription *aProperty;
		while (aKey = [keysEnumerator nextObject])
		{
			aProperty = [result objectForKey:aKey];
			if ([aProperty isTransient]) [buffer removeObjectForKey:aKey];
		}
		
		result = [[buffer copy] autorelease];
		[buffer release];
	}
	
	
	// Finish up
	OBPOSTCONDITION(result);
	return result;
}

- (void)addPropertiesOfEntity:(NSEntityDescription *)anEntity
{
	NSMutableArray *properties = [NSMutableArray arrayWithArray:[self properties]];
	
	NSDictionary *parentPropertiesByName = [anEntity propertiesByName];
	NSEnumerator *e = [parentPropertiesByName keyEnumerator];
	id key;
	while ( key = [e nextObject] )
	{
		// let's grab each property and examine what type it is
		// then copy it "by hand" to a new object and add it

		id parentProperty = [parentPropertiesByName objectForKey:key];
		id property = [[[[parentProperty class] alloc] init] autorelease];
		
		// set the common things
		[(NSPropertyDescription *)property setName:[[[parentProperty title] copy] autorelease]];
		[property setOptional:[parentProperty isOptional]];
		[property setTransient:[parentProperty isTransient]];
		[property setUserInfo:nil];
		
		// set the class specific things
		if ( [parentProperty isKindOfClass:[NSAttributeDescription class]] )
		{
			[property setAttributeType:[parentProperty attributeType]];
			[property setDefaultValue:[[[parentProperty defaultValue] copy] autorelease]];
		}
		else if ( [parentProperty isKindOfClass:[NSRelationshipDescription class]] )
		{
			[property setDestinationEntity:[parentProperty destinationEntity]];
			[property setInverseRelationship:[parentProperty inverseRelationship]];
			[property setDeleteRule:[parentProperty deleteRule]];
			[property setMinCount:[parentProperty minCount]];
			[property setMaxCount:[parentProperty maxCount]];
		}
		else if ( [parentProperty isKindOfClass:[NSFetchedPropertyDescription class]] )
		{
			[property setFetchRequest:[parentProperty fetchRequest]];
		}
		
		[properties addObject:property];
	}
	
	[self setProperties:properties];
}

- (void)addSubentity:(NSEntityDescription *)anEntity
{
	NSMutableArray *subentities = [NSMutableArray arrayWithArray:[self subentities]];
	[subentities addObject:anEntity];
	[self setSubentities:subentities];
}

@end
