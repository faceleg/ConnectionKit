//
//  NSManagedObjectModel+KTExtensions.m
//  ModelTester
//
//  Created by Terrence Talbot on 2/28/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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

/*! Returns an autoreleaed model from KTComponents_aVersion.mom.
 *  Passing in nil for aVersion will return the standard KTComponents model.
 */
+ (NSManagedObjectModel *)modelWithVersion:(NSString *)aVersion
{
	NSManagedObjectModel *result = nil;
	
    
    // Figure out the name of the model.
	NSString *modelName = nil;
	if (!aVersion || [aVersion isEqualToString:kKTModelVersion])
	{
		modelName = @"Sandvox";
	}
    else if ([aVersion isEqualToString:kKTModelVersion_ORIGINAL])
    {
        modelName = @"KTComponents";
    }
    
    
    // Try to locate the model
    if (modelName)
    {
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSString *path = [bundle pathForResource:modelName
                                          ofType:@"mom"];
        //inDirectory:@"Models"];
        
        if (path)
        {
            result = [NSManagedObjectModel modelWithPath:path];
        }
	}
	
	return result;
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
	OBPRECONDITION(anEntity);
    
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
			[NSException raise:kKareliaGeneralException format:@"unable to construct model at path: %@", modelPath];
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
	OBPRECONDITION(substitutionKey);
    
    if (!substitution) substitution = [NSNull null];
    
    NSDictionary *substitutions = [NSDictionary dictionaryWithObject:substitution forKey:substitutionKey];
	NSFetchRequest *result = [self fetchRequestFromTemplateWithName:name substitutionVariables:substitutions];
	
	return result;
}

@end
