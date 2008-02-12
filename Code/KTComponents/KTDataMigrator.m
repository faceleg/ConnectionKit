//
//  KTDataMigrator.m
//  KTComponents
//
//  Created by Terrence Talbot on 8/31/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDataMigrator.h"

#import "Debug.h"
#import "KT.h"
#import "KTDocument.h"
#import "KTStoredArray.h"
#import "KTStoredDictionary.h"
#import "KTStoredSet.h"
#import "KTUtilities.h"
#import "NSArray+KTExtensions.h"
#import "NSError+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+KTExtensions.h"

/*
 
 Note: We have these fields in the current data model, which we might want to update:
 
	addBool1 -- exclude from site map
	addString1	-- currently used to hold the FLOAT of the image replacement font adjustment
	addString2 -- encoded dictionary with lots of other parameters
 
Note: "isStale" does not seem to be used.  See staleness.
*/
 

@interface KTDataMigrator ( Private )
- (NSManagedObject *)correspondingObjectForObject:(NSManagedObject *)anObject;

- (void)migrateMatchingAttributesFromObject:(NSManagedObject *)managedObjectA 
								   toObject:(NSManagedObject *)managedObjectB;

- (void)migrateStorageRelationshipNamed:(NSString *)aRelationshipName
							 fromObject:(NSManagedObject *)managedObjectA
							   toObject:(NSManagedObject *)managedObjectB;

- (void)migrateAbstractPluginRelationshipsFromObject:(NSManagedObject *)managedObjectA
											toObject:(NSManagedObject *)managedObjectB;

- (void)migrateElementContainerRelationshipsFromObject:(NSManagedObject *)managedObjectA
											  toObject:(NSManagedObject *)managedObjectB;
- (NSManagedObject *)migrateElement:(NSManagedObject *)elementA toContainer:(NSManagedObject *)containerB;


- (BOOL)migratePages:(NSError **)error;

- (BOOL)migrateFromPage:(NSManagedObject *)pageA toPage:(NSManagedObject *)pageB;
- (BOOL)migrateFromPagelet:(NSManagedObject *)pageletA toPagelet:(NSManagedObject *)pageletB;
- (BOOL)migrateFromMediaRef:(NSManagedObject *)mediaRefA toMediaRef:(NSManagedObject *)mediaRefB;

- (BOOL)migrateMedia:(NSError **)error;
- (BOOL)migrateDocmentInfo:(NSError **)error;

+ (BOOL)validatePathForNewStore:(NSString *)aStorePath error:(NSError **)outError;
- (BOOL)isValidManagedObject:(NSManagedObject *)aManagedObject;
@end


/*! model changes, by version:

	10000: shipped w/ public betas b11, b12
	       base version

	10001: shipped w/ public beta b13
	       Media added isPublished, a boolean attribute, with a default of NO

    10002: shipped w/ beta b15
           DocumentInfo added siteID, a string, meant to store a GUID
           Page added useAbsoluteLinks, an optional boolean with no default
           Page added shortenedTitleHTML, an optional string with no default
           Page added pageTitleFormat, an optional string with no default
           Page changed shortTitle to fileName, still an optional string with no default
           Media added cachedImages, an optional to-many relationship to CachedImage
           added CachedImage, a new entity for storing info about ~/Library/Caches/Sandvox/<Images>

*/
	

@implementation KTDataMigrator

+ (void)crashKTDataMigrator
{
	*((int*)(-1)) = 0;
}

/*! upgrades the document, in-place, returning whether procedure was successful */
+ (BOOL)upgradeDocumentWithURL:(NSURL *)aStoreURL modelVersion:(NSString *)aVersion error:(NSError **)outError
{
	// move the original to a new location
	NSString *originalPath = [aStoreURL path];
	NSString *destinationPath = [KTDataMigrator renamedFileName:originalPath modelVersion:aVersion];
	
	BOOL originalMoved = [[NSFileManager defaultManager] movePath:originalPath toPath:destinationPath handler:nil];
	if ( !originalMoved )
	{
		// we cannot proceed, pass back an error and return NO
		NSString *errorDescription = [NSString stringWithFormat:
			NSLocalizedString(@"Unable to rename document from %@ to %@. Upgrade cannot be completed.","Alert: Unable to rename document from %@ to %@. Upgrade cannot be completed."),
			originalPath, destinationPath];
		
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError localizedDescription:errorDescription];
		*outError = error;
		
		return NO;
	}
	
	// use the original URL as our newStoreURL
	NSURL *newStoreURL = [aStoreURL copy];
	if ( (nil == newStoreURL) || ![newStoreURL isFileURL] )
	{
		NSString *errorDescription = [NSString stringWithFormat:
			NSLocalizedString(@"Unable to upgrade document at path %@. Path does not appear to be a file.","Alert: Unable to upgrade document at path %@. Path does not appear to be a file."), [newStoreURL path]];
				
		NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileReadInvalidFileNameError localizedDescription:errorDescription];
		*outError = error;
		
		return NO;
	}
		
	// check that we have a good path and we can write to it
	if ( ![KTDataMigrator validatePathForNewStore:[newStoreURL path] error:outError] )
	{
		return NO;
	}
		
	// make a migrator instance
	KTDataMigrator *migrator = [[KTDataMigrator alloc] init];
	
	// set old and new store URLs
	[migrator setOldStoreURL:[NSURL fileURLWithPath:destinationPath]];
	[migrator setNewStoreURL:newStoreURL];
	
	// migrate!
	NSError *localError = nil;
	BOOL result = [migrator genericallyMigrateDataFromOldModelVersion:aVersion error:&localError];
	
	if ( NO == result )
	{
		if ( nil != localError )
		{
			*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTCannotUpgrade localizedDescription:
				[NSString stringWithFormat:
					NSLocalizedString(@"Unable to migrate document data from %@ to %@, reason: %@.","Alert: Unable to migrate document data from %@ to %@, reason: %@."),
					[[aStoreURL path] lastPathComponent], [[newStoreURL path] lastPathComponent], localError]];
		}
		else
		{
			*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTCannotUpgrade localizedDescription:
				[NSString stringWithFormat:
					NSLocalizedString(@"Unable to migrate document data from %@ to %@.","Alert: Unable to migrate document data from %@ to %@."),
					[[aStoreURL path] lastPathComponent], [[newStoreURL path] lastPathComponent]]];
		}
	}
	
	[migrator release];
	[newStoreURL release];

	return result;
}

- (BOOL)genericallyMigrateDataFromOldModelVersion:(NSString *)aVersion error:(NSError **)error
{
	// set up old and new models
	[self setOldManagedObjectModel:[KTUtilities genericModelWithVersion:aVersion]];
	[self setNewManagedObjectModel:[KTUtilities genericModelWithVersion:nil]];
	
	// set up old and new core data stacks
	[self setOldManagedObjectContext:[KTUtilities contextWithURL:[self oldStoreURL] 
														   model:[self oldManagedObjectModel]]];
	[self setNewManagedObjectContext:[KTUtilities contextWithURL:[self newStoreURL] 
														   model:[self newManagedObjectModel]]];
	
	// migrate
	TJT((@"saving new context..."));
	if ( [[self newManagedObjectContext] save:error] )
	{
        // copy metadata and update the new context to the new model version
        TJT((@"migrating metadata..."));
        NSDictionary *oldMetadata = [NSPersistentStoreCoordinator metadataForPersistentStoreWithURL:[self oldStoreURL]
                                                                                              error:nil];
        NSMutableDictionary *newMetadata = [[NSPersistentStoreCoordinator metadataForPersistentStoreWithURL:[self newStoreURL]
                                                                                                      error:nil] mutableCopy];
        [newMetadata addEntriesFromDictionary:oldMetadata];
        
        NSPersistentStoreCoordinator *coordinator = [[self newManagedObjectContext] persistentStoreCoordinator];
        id store = [coordinator persistentStoreForURL:[self newStoreURL]];
        [newMetadata setValue:kKTModelVersion forKey:kKTMetadataModelVersionKey];
        [coordinator setMetadata:newMetadata forPersistentStore:store];
		[newMetadata release];
        TJT((@"saving migrated metadata..."));
		
        if ( [[self newManagedObjectContext] save:error] )
        {
            if ( [self migrateMedia:error] )
            {
				// after saving the migrated media, we need to fix up the objectIDCache
				// since the act of saving invalidates the "newObjectID" by turning the
				// URIRepresentation from a temporary store ID to a permanent store ID
				NSMutableArray *mediaArray = [NSMutableArray array];
				
				NSEnumerator *e = [[self objectIDCache] keyEnumerator];
				NSString *oldObjectID;
				while ( oldObjectID = [e nextObject] )
				{
					NSString *newObjectID = [[self objectIDCache] valueForKey:oldObjectID];
					
					KTMedia *newMedia = (KTMedia *)[[self newManagedObjectContext] objectWithURIRepresentationString:newObjectID];
					NSAssert((nil != newMedia), @"did not find newMedia in context!");
					
					NSMutableDictionary *mediaMap = [NSMutableDictionary dictionary];
					[mediaMap setValue:newMedia forKey:@"newMedia"];
					[mediaMap setValue:oldObjectID forKey:@"oldObjectID"];
					[mediaArray addObject:mediaMap];
				}
				
                TJT((@"saving migrated Media..."));
				
                if ( [[self newManagedObjectContext] save:error] )
                {
					e = [mediaArray objectEnumerator];
					NSDictionary *mediaMap;
					while ( mediaMap = [e nextObject] )
					{
						KTMedia *newMedia = [mediaMap objectForKey:@"newMedia"];
						NSString *oldObjectID2 = [mediaMap objectForKey:@"oldObjectID"];
						
						[[self objectIDCache] setValue:[newMedia URIRepresentationString] 
												forKey:oldObjectID2];		
					}
					if ( [self migratePages:error] )
					{
						if ( [self migrateDocmentInfo:error] )
						{
							TJT((@"saving migrated objects..."));
							if ( [[self newManagedObjectContext] save:error] )
							{
								return YES;
							}
						}
					}
                }	
            }	
        }
    }
	
	if ( nil != *error )
	{
		TJT((@"error: %@", *error));
	}

	return NO;
}

#pragma mark attribute migration

/*! copies attribute values from managedObjectA to managedObjectB that exist in both entities */
- (void)migrateMatchingAttributesFromObject:(NSManagedObject *)managedObjectA 
								   toObject:(NSManagedObject *)managedObjectB
{
    // get the array of attribute keys and set the items accordingly
	NSArray *attributeKeysA = [[managedObjectA entity] attributeKeys];
	NSArray *attributeKeysB = [[managedObjectB entity] attributeKeys];
	
	// loop through the keys
    int i, count = [attributeKeysB count];
    NSString *attributeName;
    for ( i=0; i<count; i++ ) 
	{
        // Get the attribute name, then copy the value
        attributeName = [attributeKeysB objectAtIndex:i];
		if ( [attributeKeysA containsObjectEqualToString:attributeName] )
		{
			id value = [managedObjectA valueForKey:attributeName];
			if ( nil != value )
			{
				[managedObjectB setValue:value forKey:attributeName];
			}
		}
    }	
}

#pragma mark abstract relationship migration

- (void)migrateStorageRelationshipNamed:(NSString *)aRelationshipName
							 fromObject:(NSManagedObject *)managedObjectA
							   toObject:(NSManagedObject *)managedObjectB
{
	NSAssert((nil != aRelationshipName), @"aRelationshipName cannot be nil!");
	NSAssert((nil != managedObjectA), @"managedObjectA cannot be nil!");
	NSAssert((nil != managedObjectB), @"managedObjectB cannot be nil!");
	
	
	id storageObjectA = [managedObjectA valueForKey:aRelationshipName];
	id storageObjectB = [self correspondingObjectForObject:storageObjectA];
	if ( nil == storageObjectB )
	{
		//NSLog(@"migrating %@ for %@", aRelationshipName, [managedObjectA managedObjectDescription]);

		storageObjectB = [NSEntityDescription insertNewObjectForEntityForName:[[storageObjectA entity] name]
													   inManagedObjectContext:[managedObjectB managedObjectContext]];
		NSAssert((nil != storageObjectB), @"storageObjectB cannot be nil!");
		
		[[self objectIDCache] setValue:[storageObjectB URIRepresentationString] 
								forKey:[storageObjectA URIRepresentationString]];		
	}
	else
	{
		//NSLog(@"    again %@ for %@", aRelationshipName, [managedObjectA managedObjectDescription]);
	}

	if ( [[storageObjectB class] isEqual:[KTStoredDictionary class]] )
	{
		[storageObjectB addEntriesFromDictionary:storageObjectA];
	}
	else if ( [[storageObjectB class] isEqual:[KTStoredArray class]] )
	{
		[storageObjectB copyObjectsFromArray:storageObjectA];
	}
	else if ( [[storageObjectB class] isEqual:[KTStoredSet class]] )
	{
		[storageObjectB copyObjectsFromArray:storageObjectA];
	}
	else
	{
		NSLog(@"Unknown storage class!");
	}
	
	[managedObjectB setValue:storageObjectB forKey:aRelationshipName];
	NSAssert([[storageObjectB valueForKey:@"owner"] isEqual:managedObjectB], @"owner is not set correctly!");
}

- (void)migrateAbstractPluginRelationshipsFromObject:(NSManagedObject *)managedObjectA
											toObject:(NSManagedObject *)managedObjectB
{
	NSAssert((nil != managedObjectA), @"managedObjectA cannot be nil!");
	NSAssert((nil != managedObjectB), @"managedObjectB cannot be nil!");
	
	// root
	NSString *newRootURIString = [[self objectIDCache] valueForKey:@"newRoot"];
	NSAssert((nil != newRootURIString), @"newRootURIString cannot be nil!");
	NSManagedObject *newRoot = [[managedObjectB managedObjectContext] objectWithURIRepresentationString:newRootURIString];
	NSAssert((nil != newRoot), @"newRoot cannot be nil!");
	[managedObjectB setValue:newRoot forKey:@"root"];
	
	// pluginProperties	
	[self migrateStorageRelationshipNamed:@"pluginProperties"
							   fromObject:managedObjectA
								 toObject:managedObjectB];
	
	// mediaRefs
	NSSet *mediaRefsA = [managedObjectA valueForKey:@"mediaRefs"];
	if ( [mediaRefsA count] > 0 )
	{
		NSMutableSet *mediaRefsB = [managedObjectB mutableSetValueForKey:@"mediaRefs"];
		NSEnumerator *e = [mediaRefsA objectEnumerator];
		NSManagedObject *mediaRefA = nil;
		while ( mediaRefA = [e nextObject] )
		{
			NSManagedObject *mediaRefB = [self correspondingObjectForObject:mediaRefA];
			if ( nil == mediaRefB )
			{
				mediaRefB = [NSEntityDescription insertNewObjectForEntityForName:@"MediaRef"
														  inManagedObjectContext:[managedObjectB managedObjectContext]];
				NSAssert((nil != mediaRefB), @"mediaRefB cannot be nil!");
				[[self objectIDCache] setValue:[mediaRefB URIRepresentationString] forKey:[mediaRefA URIRepresentationString]];
			}
			[self migrateFromMediaRef:mediaRefA toMediaRef:mediaRefB];
			[mediaRefsB addObject:mediaRefB];
		}
	}
}

#pragma mark Element Container migration

- (void)migrateElementContainerRelationshipsFromObject:(NSManagedObject *)managedObjectA
											  toObject:(NSManagedObject *)managedObjectB
{
	// elements
	NSEnumerator *e = [[[managedObjectA valueForKey:@"elements"] allObjects] objectEnumerator];
	NSManagedObject *elementA = nil;
	while ( elementA = [e nextObject] )
	{
		NSManagedObject *elementB = [self migrateElement:elementA toContainer:managedObjectB];
		[[managedObjectB mutableSetValueForKey:@"elements"] addObject:elementB];
	}
}

#pragma mark Element migration

- (NSManagedObject *)migrateElement:(NSManagedObject *)elementA toContainer:(NSManagedObject *)containerB
{
	// does elementB already exist?
	NSManagedObject *elementB = [self correspondingObjectForObject:elementA];
	if ( nil == elementB )
	{
		// no elementB, make one
		elementB = [NSEntityDescription insertNewObjectForEntityForName:@"Element"
												 inManagedObjectContext:[containerB managedObjectContext]];
		NSAssert((nil != elementB), @"elementB cannot be nil!");
		[[self objectIDCache] setValue:[elementB URIRepresentationString] forKey:[elementA URIRepresentationString]];
	}
	
	// migrate attributes
	[self migrateMatchingAttributesFromObject:elementA
									 toObject:elementB];
	
	// migrate AbstractPlugin relationships
	[self migrateAbstractPluginRelationshipsFromObject:elementA 
											  toObject:elementB];
	
	// set elementB's container relationship
	[elementB setValue:containerB forKey:@"container"];
	
	return elementB;
}

#pragma mark Page migration

- (BOOL)migratePages:(NSError **)error
{
	TJT((@"migrating Pages..."));

	BOOL result = YES;
	
	// first, find our root
	NSManagedObject *oldRoot = (NSManagedObject *)[[self oldManagedObjectContext] root];
	NSAssert((nil != oldRoot), @"oldRoot is nil!");
	// cache it under the name "oldRoot"
	[[self objectIDCache] setValue:[oldRoot URIRepresentationString] forKey:@"oldRoot"];
	
	// second, make a new root
	NSManagedObject *newRoot = [NSEntityDescription insertNewObjectForEntityForName:@"Root"
															 inManagedObjectContext:[self newManagedObjectContext]];
	// cache it for later
	[[self objectIDCache] setValue:[newRoot URIRepresentationString] forKey:[oldRoot URIRepresentationString]];
	// cache it under the name "newRoot"
	[[self objectIDCache] setValue:[newRoot URIRepresentationString] forKey:@"newRoot"];

	// fetch all Pages
	NSArray *fetchedObjects = [[self oldManagedObjectContext] allObjectsWithEntityName:@"Page"
																				 error:error];
	if ( nil != *error )
	{
		return NO;
	}
		
	NSEnumerator *e = [fetchedObjects objectEnumerator];
	NSManagedObject *oldPage = nil;
	while ( oldPage = [e nextObject] )
	{
		// is newPage already in the cache?
		NSManagedObject *newPage = [self correspondingObjectForObject:oldPage];
		if ( nil == newPage )
		{
			// no, insert a new Page in newManagedObjectContext
			newPage = [NSEntityDescription insertNewObjectForEntityForName:@"Page"
													inManagedObjectContext:[self newManagedObjectContext]];
			// cache it for later
			[[self objectIDCache] setValue:[newPage URIRepresentationString] forKey:[oldPage URIRepresentationString]];
		}
		
		result = result && [self migrateFromPage:oldPage toPage:newPage];
	}

	return result;
}

- (BOOL)migrateFromPage:(NSManagedObject *)pageA toPage:(NSManagedObject *)pageB
{
	// migrate attributes
	[self migrateMatchingAttributesFromObject:pageA
									 toObject:pageB];
    
    // 10002: changed shortTitle to fileName
    NSString *shortTitle = [pageA valueForKey:@"shortTitle"];
    if ( nil != shortTitle )
    {
        [pageB setValue:shortTitle forKey:@"fileName"];
    }
    
    // request from Dan, 4/2/06, wrap copyrightHTML in <p>...</p>
    NSString *copyrightHTML = [pageB valueForKey:@"copyrightHTML"];
    if ( nil != copyrightHTML )
    {
        if ( ![copyrightHTML hasPrefix:@"<p>"] )
        {
            copyrightHTML = [NSString stringWithFormat:@"<p>%@", copyrightHTML];
        }
        if ( ![copyrightHTML hasSuffix:@"</p>"] )
        {
            copyrightHTML = [NSString stringWithFormat:@"%@</p>", copyrightHTML];
        }
        [pageB setValue:copyrightHTML forKey:@"copyrightHTML"];
    }
	
	// migrate relationships
	//  AbstractPlugin
	[self migrateAbstractPluginRelationshipsFromObject:pageA
											  toObject:pageB];
	
	//  ElementContainer
	[self migrateElementContainerRelationshipsFromObject:pageA
												toObject:pageB];
	
	//  parent
	NSManagedObject *parentA = [pageA valueForKey:@"parent"];
	if ( nil != parentA )
	{
		NSManagedObject *parentB = [self correspondingObjectForObject:parentA];
		if ( nil == parentB )
		{
			// create a placeholder and cache it for later population
			parentB = [NSEntityDescription insertNewObjectForEntityForName:@"Page"
													inManagedObjectContext:[pageB managedObjectContext]];
			NSAssert((nil != parentB), @"parentB cannot be nil!");
			[[self objectIDCache] setValue:[parentB URIRepresentationString] forKey:[parentA URIRepresentationString]];
		}
		[pageB setValue:parentB forKey:@"parent"];
		[[parentB mutableSetValueForKey:@"children"] addObject:pageB];
	}
	
	//  children
	NSEnumerator *e = [[[pageA valueForKey:@"children"] allObjects] objectEnumerator];
	NSManagedObject *childA = nil;
	while ( childA = [e nextObject] )
	{
		NSManagedObject *childB = [self correspondingObjectForObject:childA];
		if ( nil == childB )
		{
			// create a placeholder and cache it for later population
			childB = [NSEntityDescription insertNewObjectForEntityForName:@"Page"
												   inManagedObjectContext:[pageB managedObjectContext]];
			NSAssert((nil != childB), @"childB cannot be nil!");
			[[self objectIDCache] setValue:[childB URIRepresentationString] forKey:[childA URIRepresentationString]];
		}
		[[pageB mutableSetValueForKey:@"children"] addObject:childB];
		[childB setValue:pageB forKey:@"parent"];
	}
	
	// callouts
	NSSet *calloutsA = [pageA valueForKey:@"callouts"];
	if ( [calloutsA count] > 0 )
	{
		NSMutableSet *calloutsB = [pageB mutableSetValueForKey:@"callouts"];
		NSEnumerator *e2 = [calloutsA objectEnumerator];
		NSManagedObject *calloutA = nil;
		while ( calloutA = [e2 nextObject] )
		{
			NSManagedObject *calloutB = [self correspondingObjectForObject:calloutA];
			if ( nil == calloutB )
			{
				calloutB = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
														 inManagedObjectContext:[pageB managedObjectContext]];
				NSAssert((nil != calloutB), @"calloutB cannot be nil!");
				[[self objectIDCache] setValue:[calloutB URIRepresentationString] forKey:[calloutA URIRepresentationString]];
			}
			[self migrateFromPagelet:calloutA toPagelet:calloutB];
			[calloutsB addObject:calloutB];
		}
	}
	
	// sidebars
	NSSet *sidebarsA = [pageA valueForKey:@"sidebars"];
	if ( [sidebarsA count] > 0 )
	{
		NSMutableSet *sidebarsB = [pageB mutableSetValueForKey:@"sidebars"];
		NSEnumerator *e2 = [sidebarsA objectEnumerator];
		NSManagedObject *sidebarA = nil;
		while ( sidebarA = [e2 nextObject] )
		{
			NSManagedObject *sidebarB = [self correspondingObjectForObject:sidebarA];
			if ( nil == sidebarB )
			{
				sidebarB = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
														 inManagedObjectContext:[pageB managedObjectContext]];
				NSAssert((nil != sidebarB), @"sidebarB cannot be nil!");
				[[self objectIDCache] setValue:[sidebarB URIRepresentationString] forKey:[sidebarA URIRepresentationString]];
			}
			[self migrateFromPagelet:sidebarA toPagelet:sidebarB];
			[sidebarsB addObject:sidebarB];
		}
	}
	
	//  keywords	
	[self migrateStorageRelationshipNamed:@"keywords"
							   fromObject:pageA
								 toObject:pageB];
	
	//  pendingDeletions (does it make sense to migrate these?)
	[self migrateStorageRelationshipNamed:@"pendingDeletions"
							   fromObject:pageA
								 toObject:pageB];
	
	return YES; // could later beef this up with error checking
}

#pragma mark Pagelet migration

- (BOOL)migrateFromPagelet:(NSManagedObject *)pageletA toPagelet:(NSManagedObject *)pageletB
{
	// migrate attributes
	[self migrateMatchingAttributesFromObject:pageletA
									 toObject:pageletB];
	
	// migrate relationships
	//  AbstractPlugin
	[self migrateAbstractPluginRelationshipsFromObject:pageletA
											  toObject:pageletB];
	
	//  ElementContainer
	[self migrateElementContainerRelationshipsFromObject:pageletA
												toObject:pageletB];
	
	//  owner relationship (is set during Page migration, after this method is called)
	
	return YES; // could later beef this up with error checking
}	

#pragma mark MediaRef migration

- (BOOL)migrateFromMediaRef:(NSManagedObject *)mediaRefA toMediaRef:(NSManagedObject *)mediaRefB
{
	// migrate attributes
	[self migrateMatchingAttributesFromObject:mediaRefA 
									 toObject:mediaRefB];
	
	// migrate media relationship
	//  media should already have been copied to the new context
	//  all we need to do is find the corresponding object
	NSManagedObject *mediaA = [mediaRefA valueForKey:@"media"];
	NSManagedObject *mediaB = [self correspondingObjectForObject:mediaA];
	NSAssert((nil != mediaB), @"mediaB cannot be nil! should have been copied by now");
	[mediaRefB setValue:mediaB forKey:@"media"];
	
	// migrate owner relationship
	//  should be later set by migrateAbstractPluginRelationshipsFromObject:toObject:
	
	return YES; // could later beef this up with error checking
}

#pragma mark Media migration

- (BOOL)migrateMedia:(NSError **)error
{
	TJT((@"migrating Media..."));
	// fetch all Media
	NSArray *fetchedObjects = [[self oldManagedObjectContext] allObjectsWithEntityName:@"Media"
																				 error:error];
	if ( nil != *error )
	{
		return NO;
	}
	
	NSEnumerator *e = [fetchedObjects objectEnumerator];
	NSManagedObject *oldMedia = nil;
	while ( oldMedia = [e nextObject] )
	{
		// create a new media object
		NSManagedObject *newMedia = [NSEntityDescription insertNewObjectForEntityForName:@"Media"
																  inManagedObjectContext:[self newManagedObjectContext]];
		NSAssert(nil != newMedia, @"newMedia is nil!");
		
		// cache URI for matching
		[[self objectIDCache] setValue:[newMedia URIRepresentationString] forKey:[oldMedia URIRepresentationString]];
		
		NSManagedObjectContext *newContext = [newMedia managedObjectContext];
		
		// copy attributes
		[self migrateMatchingAttributesFromObject:oldMedia 
										 toObject:newMedia];
		
		// (10001) add attribute isPublished
		NSNumber *defaultIsPublished = [[[[[[self newManagedObjectModel] entitiesByName] valueForKey:@"Media"] attributesByName] valueForKey:@"isPublished"] defaultValue];
		[newMedia setValue:defaultIsPublished forKey:@"isPublished"];
		
		// copy mediaData (a special relationship, required in all cases)
		NSManagedObject *newMediaData = [NSEntityDescription insertNewObjectForEntityForName:@"MediaData"
																	  inManagedObjectContext:newContext];
		[newMedia setValue:newMediaData forKey:@"mediaData"];
		[newMedia setValue:[oldMedia valueForKeyPath:@"mediaData.contents"]
				forKeyPath:@"mediaData.contents"];
		[newMedia setValue:[oldMedia valueForKeyPath:@"mediaData.digest"]
				forKeyPath:@"mediaData.digest"];
		
		// copy relationships
		//  copy thumbnailData, if present
		if ( nil != [oldMedia valueForKey:@"thumbnailData"] )
		{
			NSManagedObject *newThumbnailData = [NSEntityDescription insertNewObjectForEntityForName:@"ThumbnailData"
																			  inManagedObjectContext:newContext];
			[newMedia setValue:newThumbnailData forKey:@"thumbnailData"];
			[newMedia setValue:[oldMedia valueForKeyPath:@"thumbnailData.contents"]
					forKeyPath:@"thumbnailData.contents"];
			[newMedia setValue:[oldMedia valueForKeyPath:@"thumbnailData.digest"]
					forKeyPath:@"thumbnailData.digest"];
		}
		
		//  copy fileAttributes, if present
		KTStoredDictionary *fileAttributes = [oldMedia valueForKey:@"fileAttributes"];
		if ( nil != fileAttributes )
		{
			[self migrateStorageRelationshipNamed:@"fileAttributes"
									   fromObject:oldMedia
										 toObject:newMedia];
			
		}
		
		//  copy metadata, if present
		KTStoredDictionary *metadata = [oldMedia valueForKey:@"metadata"];
		if ( nil != metadata )
		{
			[self migrateStorageRelationshipNamed:@"metadata"
									   fromObject:oldMedia
										 toObject:newMedia];			
		}
		
		// note: mediaRefs is also a relationship, but that will be set as an inverse
		// when the actual mediaRef itself is copied to the new context
	}
	
	return YES; // could later beef this up with error checking
}

#pragma mark DocumentInfo migration

- (BOOL)migrateDocmentInfo:(NSError **)error
{
	TJT((@"migrating DocumentInfo..."));
	// fetch old DocumentInfo
	NSArray *fetchedObjects = [[self oldManagedObjectContext] allObjectsWithEntityName:@"DocumentInfo"
																				 error:error];
	if ( nil != *error )
	{
		return NO;
	}	
	NSAssert(([fetchedObjects count] == 1), @"should only be 1 DocumentInfo per document");
	NSManagedObject *oldDocumentInfo = [fetchedObjects objectAtIndex:0];
	
	NSManagedObject *newDocumentInfo = [NSEntityDescription insertNewObjectForEntityForName:@"DocumentInfo"
																	 inManagedObjectContext:[self newManagedObjectContext]];
	NSAssert((nil != newDocumentInfo), @"newDocumentInfo is nil!");
	
	// migrate attributes
	[self migrateMatchingAttributesFromObject:oldDocumentInfo 
									 toObject:newDocumentInfo];
    
    // 10002: add siteID
    if ( nil == [newDocumentInfo valueForKey:@"siteID"] )
    {
        [newDocumentInfo setValue:[NSString shortGUIDString] forKey:@"siteID"];
    }
    	
	// migrate relationships
	//  hostProperties
	[self migrateStorageRelationshipNamed:@"hostProperties"
							   fromObject:oldDocumentInfo
								 toObject:newDocumentInfo];
	
    // publishedDesigns	
	[self migrateStorageRelationshipNamed:@"publishedDesigns"
							   fromObject:oldDocumentInfo
								 toObject:newDocumentInfo];	
	
	//  requiredBundles
	[self migrateStorageRelationshipNamed:@"requiredBundles"
							   fromObject:oldDocumentInfo
								 toObject:newDocumentInfo];	
    	
	//  root
	NSString *newRootURIString = [[self objectIDCache] valueForKey:@"newRoot"];
	NSAssert((nil != newRootURIString), @"newRootURIString cannot be nil!");
	NSManagedObject *newRoot = [[self newManagedObjectContext] objectWithURIRepresentationString:newRootURIString];
	NSAssert((nil != newRoot), @"newRoot cannot be nil!");
	[newDocumentInfo setValue:newRoot forKey:@"root"];
	
	return YES; // could later beef this up with error checking
}

#pragma mark init

- (id)init
{
	if ( nil == [super init] )
	{
		return nil;
	}
	
	[self setObjectIDCache:[NSMutableDictionary dictionary]];
	
	return self;
}

#pragma mark dealloc

- (void)dealloc
{
	[self setNewStoreURL:nil];
	[self setOldStoreURL:nil];
	[self setNewManagedObjectContext:nil];
	[self setOldManagedObjectContext:nil];
	[self setNewManagedObjectModel:nil];
	[self setOldManagedObjectModel:nil];
	[self setObjectIDCache:nil];
	[super dealloc];
}

#pragma mark accessors

- (NSManagedObjectModel *)oldManagedObjectModel
{
    return myOldManagedObjectModel; 
}

- (void)setOldManagedObjectModel:(NSManagedObjectModel *)anOldManagedObjectModel
{
    [anOldManagedObjectModel retain];
    [myOldManagedObjectModel release];
    myOldManagedObjectModel = anOldManagedObjectModel;
}

- (NSManagedObjectModel *)newManagedObjectModel
{
    return myNewManagedObjectModel; 
}

- (void)setNewManagedObjectModel:(NSManagedObjectModel *)aNewManagedObjectModel
{
    [aNewManagedObjectModel retain];
    [myNewManagedObjectModel release];
    myNewManagedObjectModel = aNewManagedObjectModel;
}

- (NSManagedObjectContext *)oldManagedObjectContext
{
    return myOldManagedObjectContext; 
}

- (void)setOldManagedObjectContext:(NSManagedObjectContext *)anOldManagedObjectContext
{
    [anOldManagedObjectContext retain];
    [myOldManagedObjectContext release];
    myOldManagedObjectContext = anOldManagedObjectContext;
}

- (NSManagedObjectContext *)newManagedObjectContext
{
    return myNewManagedObjectContext; 
}

- (void)setNewManagedObjectContext:(NSManagedObjectContext *)aNewManagedObjectContext
{
    [aNewManagedObjectContext retain];
    [myNewManagedObjectContext release];
    myNewManagedObjectContext = aNewManagedObjectContext;
}

- (NSURL *)oldStoreURL
{
	return myOldStoreURL;
}

- (void)setOldStoreURL:(NSURL *)aStoreURL
{
	[aStoreURL retain];
	[myOldStoreURL release];
	myOldStoreURL = aStoreURL;
}

- (NSURL *)newStoreURL
{
	return myNewStoreURL;
}

- (void)setNewStoreURL:(NSURL *)aStoreURL
{
	[aStoreURL retain];
	[myNewStoreURL release];
	myNewStoreURL = aStoreURL;
}

- (NSMutableDictionary *)objectIDCache 
{ 
	return myObjectIDCache;
}

- (void)setObjectIDCache:(NSMutableDictionary *)anObjectIDCache
{
    [anObjectIDCache retain];
    [myObjectIDCache release];
    myObjectIDCache = anObjectIDCache;
}

#pragma mark support

+ (NSString *)renamedFileName:(NSString *)originalFileNameWithExtension modelVersion:(NSString *)aVersion
{
	NSString *fileName = [originalFileNameWithExtension stringByDeletingPathExtension];
	NSString *extension = [originalFileNameWithExtension pathExtension];
	NSString *previous = NSLocalizedString(@"previous",
										   "name appened to copy of file before version migration");
	
	//return [NSString stringWithFormat:@"%@-%@.%@", fileName, aVersion, extension];
	return [NSString stringWithFormat:@"%@-%@.%@", fileName, previous, extension];
}

// this is a slightly cleaned up method from Apple's Migrator example
+ (BOOL)validatePathForNewStore:(NSString *)aStorePath error:(NSError **)outError
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *storeDirectory = [aStorePath stringByDeletingLastPathComponent];
    
	// check that we at least have aStorePath
    if (nil == aStorePath || [@"" isEqualToString:aStorePath])
	{
		*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTNoDocPathSpecified localizedDescription:NSLocalizedString(@"No document path specified.","No document path specified.")];
        return NO;
    }
    
	// does aStorePath already exist? if so, can we overwrite it?
	// if not, does it have a valid parent directory?
	// if not, create a valid path
    BOOL isDirectory = NO;
    if ([fileManager fileExistsAtPath:aStorePath isDirectory:&isDirectory])
	{
        if ( isDirectory ) 
		{
			*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTPathIsDirectory localizedDescription:NSLocalizedString(@"Specified document path is a directory.","Specified document path is a directory.")];
            return NO;
        } 
		else 
		{
            if ( ![fileManager removeFileAtPath:aStorePath handler:nil] ) 
			{
				*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTCannotRemove localizedDescription:[NSString stringWithFormat:
					NSLocalizedString(@"Can\\U2019t remove pre-existing file at path (%@)","Error: Can't remove pre-existing file at path (%@)"), aStorePath]];      
                return NO;
            }
        }
    } 
	else if ( [fileManager fileExistsAtPath:storeDirectory isDirectory:&isDirectory] ) 
	{
        if ( isDirectory )
		{
            if ( ![fileManager isWritableFileAtPath:storeDirectory] ) 
			{
				*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTDirNotWritable localizedDescription:[NSString stringWithFormat:
					NSLocalizedString(@"Can\\U2019t write file to path - directory is not writable (%@)","Error: Can't write file to path - directory is not writable (%@)"), storeDirectory]];       
                return NO;
            }
        }
		else
		{
			*outError = [NSError errorWithDomain:kKTDataMigrationErrorDomain code:KTParentNotDirectory localizedDescription:[NSString stringWithFormat:
				NSLocalizedString(@"Can\\U2019t write file to path - parent is not a directory (%@)","Error: Can't write file to path - parent is not a directory (%@)"), storeDirectory]]; 
            return NO;
        }
    }
	else
	{
        return [KTUtilities createPathIfNecessary:storeDirectory error:outError];
    }
	
    return YES;
}

/*! returns object in newManagedObjectContext matching anObject in oldManagedObjectContext */
- (NSManagedObject *)correspondingObjectForObject:(NSManagedObject *)anObject
{
	NSManagedObject *result = nil;
	
	NSString *URIStringA = [anObject URIRepresentationString];
	NSString *URIStringB = [[self objectIDCache] valueForKey:URIStringA];
	
	if ( nil != URIStringB )
	{
		result = [[self newManagedObjectContext] objectWithURIRepresentationString:URIStringB];
	}
	
	return result;	
}

/*! attempts an attribute fetch (uniqueID) which causes a fault to fire,
	if an exception is thrown because the fault can't be fulfilled,
	this catches it (instead of crapping out) and returns NO
*/
- (BOOL)isValidManagedObject:(NSManagedObject *)aManagedObject
{
	BOOL result = NO;
	@try
	{
		NSString *uniqueID = [aManagedObject valueForKey:@"uniqueID"];
		if ( nil != uniqueID )
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
			TJT((@"%@ is not/no longer a valid managed object.", [aManagedObject managedObjectDescription]));
		}
	}
	
	return result;
}

@end
