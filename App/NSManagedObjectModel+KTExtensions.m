//
//  NSManagedObjectModel+KTExtensions.m
//  ModelTester
//
//  Created by Terrence Talbot on 2/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSManagedObjectModel+KTExtensions.h"

#import "KT.h"
#import "KTAbstractElement.h"

#import "NSException+Karelia.h"

static NSManagedObjectModel *sKTComponentsModel;

@implementation NSManagedObjectModel (KTExtensions)

#pragma mark -
#pragma mark Creating a model

+ (id)modelWithPath:(NSString *)aPath
{
	return [self modelWithURL:[NSURL fileURLWithPath:aPath]];
}

+ (id)modelWithURL:(NSURL *)aFileURL
{
	return [[[self alloc] initWithContentsOfURL:aFileURL] autorelease];
}

- (NSEntityDescription *)entityWithName:(NSString *)aName
{
	NSEnumerator *e = [[self entities] objectEnumerator];
	NSEntityDescription *entity;
	while ( entity = [e nextObject] )
	{
		if ( [aName isEqualToString:[entity name]] )
		{
			return entity;
		}
	}
	
	return nil;
}

#pragma mark -
#pragma mark Modifying models

/*  Convert all but storage classes to NSManagedObject.
 */
- (void)makeGeneric
{
	static NSSet *storageClassNames;
    if (!storageClassNames)
    {
        storageClassNames = [[NSSet alloc] initWithObjects:@"KTStoredDictionary", @"KTStoredArray", @"KTStoredSet", nil];
    }
    
    NSEnumerator *e = [[self entities] objectEnumerator];
    NSEntityDescription *entity = nil;
    while (entity = [e nextObject])
    {
        if (![storageClassNames containsObject:[entity managedObjectClassName]])
        {
            [entity setManagedObjectClassName:[NSManagedObject className]];
        }
    }
}

- (void)addEntity:(NSEntityDescription *)anEntity
{
	NSMutableArray *entities = [NSMutableArray arrayWithArray:[self entities]];
	[entities addObject:anEntity];
	[self setEntities:entities];
}

- (void)removeEntity:(NSEntityDescription *)anEntity
{
	NSMutableArray *entities = [NSMutableArray arrayWithArray:[self entities]];
	[entities removeObject:anEntity];
	[self setEntities:entities];
}

// support

- (BOOL)hasEntityNamed:(NSString *)aString
{
	return (nil != [[self entitiesByName] objectForKey:aString]) ? YES : NO;
}

+ (BOOL)componentsFrameworkModelContainsEntityNamed:(NSString *)aString
{
	if ( nil == sKTComponentsModel )
	{
		NSBundle *bundle = [NSBundle bundleForClass:[KTAbstractElement class]];
		NSString *modelPath = [bundle pathForResource:@"KTComponents" ofType:@"mom"];
		sKTComponentsModel = [[NSManagedObjectModel modelWithPath:modelPath] retain];
		if ( nil == sKTComponentsModel )
		{
			[NSException raise:kKareliaObjectException format:@"unable to construct model at path: %@", modelPath];
		}
	}
	
	return [sKTComponentsModel hasEntityNamed:aString];
}

- (void)prettyPrintDescription
{
	NSLog(@"\n----------------------------model----------------------------\n");
	
	NSArray *entities = [self entities];
	
	NSEnumerator *e = [entities objectEnumerator];
	NSEntityDescription *entity;
	while ( entity = [e nextObject] )
	{
		NSLog(@"Entity: %@", [entity name]);
		NSLog(@"Super Entity: %@", [[entity superentity] name]);
		NSLog(@"ManagedObject ClassName: %@", [entity managedObjectClassName]);
		NSLog(@"Attributes: %@", [[entity attributesByName] description]);
		NSLog(@"Relationships: %@", [[entity relationshipsByName] description]);
		NSLog(@"\n----------------------------------------------\n");
	}
}

#pragma mark -
#pragma mark Fetch request templates

- (NSFetchRequest *)fetchRequestFromTemplateWithName:(NSString *)name
								substitutionVariable:(id)substitution
											  forKey:(NSString *)substitutionKey
{
	NSDictionary *substitutions = [[NSDictionary alloc] initWithObjectsAndKeys:substitution, substitutionKey, nil];
	NSFetchRequest *result = [self fetchRequestFromTemplateWithName:name substitutionVariables:substitutions];
	[substitutions release];
	
	return result;
}

@end
