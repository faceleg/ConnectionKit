//
//  NSManagedObjectContext+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/28/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "NSManagedObjectContext+KTExtensions.h"

#import "KTSite.h"
#import "KTPage.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSFetchRequest+KTExtensions.h"
#import "NSString+KTExtensions.h"

#import "Debug.h"


@implementation NSManagedObjectContext (KTExtensions)

/*! returns an autoreleased core data stack with file at aStoreURL */
+ (NSManagedObjectContext *)contextWithStoreType:(NSString *)storeType
                                             URL:(NSURL *)aStoreURL
                                           model:(NSManagedObjectModel *)aModel
                                           error:(NSError **)outError;
{
	NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:aModel];
	
    NSPersistentStore *store = [coordinator addPersistentStoreWithType:storeType
                                                         configuration:nil
                                                                   URL:aStoreURL
                                                               options:nil
                                                                 error:outError];
	
	NSManagedObjectContext *result = nil;
    if (store)
	{
		NSManagedObjectContext *result = [[[NSManagedObjectContext alloc] init] autorelease];
        [result setPersistentStoreCoordinator:coordinator];
	}
    
    // Tidy up
	[coordinator release];
	
	return result;	
}

- (void)deleteObjectsInCollection:(id)collection   // Assume objects conform to -objectEnumerator
{
	NSEnumerator *enumerator = [collection objectEnumerator];
	NSManagedObject *anObject;
	while (anObject = [enumerator nextObject])
	{
		if ([anObject isKindOfClass:[KTAbstractPage class]])
        {
            [self deletePage:(KTAbstractPage *)anObject];
        }
        else
        {
            [self deleteObject:anObject];
        }
	}
}

#pragma mark workhorse that sends executeFetchRequest:

- (NSArray *)objectsWithFetchRequestTemplateWithName:(NSString *)aTemplateName
							   substitutionVariables:(NSDictionary *)aDictionary
											   error:(NSError **)anError
{
	NSArray *fetchedObjects = nil;
	NSFetchRequest *fetchRequest = nil;
	NSError *localError = nil;
	
	// note to future debuggers: we ALWAYS need to lock the context here to prevent
	// a "statement is still active" error. if we only lockIfNecessary, it's possible
	// that this method could be called on the main thread while another thread is
	// doing the same. DO NOT REMOVE THIS LOCK. DO NOT MAKE IT CONDITIONAL.
	//[self lockPSCAndSelf];
	NSManagedObjectModel *model= [[self persistentStoreCoordinator] managedObjectModel];
	fetchRequest = [model fetchRequestFromTemplateWithName:aTemplateName
									 substitutionVariables:aDictionary];
	fetchedObjects = [self executeFetchRequest:fetchRequest error:&localError];
	
	return fetchedObjects;
}

#pragma mark convenience methods that message workhorse

// return array of unique values for aColumnName for all instances of anEntityName
- (NSArray *)objectsForColumnName:(NSString *)aColumnName entityName:(NSString *)anEntityName
{
    NSError *localError = nil;
    NSArray *allInstances = [self fetchAllObjectsForEntityForName:anEntityName error:&localError];
    
    if ( [allInstances count] > 0 )
    {
        NSMutableSet *objects = [NSMutableSet setWithCapacity:[allInstances count]];
        
        NSManagedObject *instance;
        for ( instance in allInstances )
        {
			id object = [instance valueForKey:aColumnName];
			if (object)
			{
				[objects addObject:object];
			}
        }
        
        return [objects allObjects]; // return set as array
    }
    
    return nil;
}

- (NSManagedObject *)objectWithUniqueID:(NSString *)aUniqueID entityName:(NSString *)anEntityName
{
	OBASSERTSTRING((nil != aUniqueID), @"aUniqueID cannot be nil");
	OBASSERTSTRING((nil != anEntityName), @"anEntityName cannot be nil");
	
	NSManagedObject *result = nil;
    
    NSString *searchID = [aUniqueID copy];
	
	NSError *localError = nil;
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"uniqueID == %@", searchID];
	NSArray *fetchedObjects = [self fetchAllObjectsForEntityForName:anEntityName
												predicate:predicate
													error:&localError];
	
	if ( (nil == fetchedObjects) || ([fetchedObjects count] == 0) )
	{
		result = nil;
	}
	else if ( [fetchedObjects count] == 1 )
	{
		result = [fetchedObjects objectAtIndex:0];
	}
	else
	{
		result = [fetchedObjects objectAtIndex:0];
		NSLog(@"error: document contains more than one %@ with uniqueID %@", anEntityName, searchID);
	}

	[searchID release];
	
	return result;
}

- (NSManagedObject *)objectWithURIRepresentation:(NSURL *)aURL
{
	OBASSERTSTRING((nil != aURL), @"aURL cannot be nil");
	
	NSManagedObject *result = nil;
	
	NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
	NSManagedObjectID *objectID = [coordinator managedObjectIDForURIRepresentation:aURL];
	
	if ( nil != objectID )
	{
		result = [self objectWithID:objectID];
	}
	
	return result;
}

- (NSManagedObject *)objectWithURIRepresentationString:(NSString *)aURIRepresentationString
{
	NSURL *URL = [NSURL URLWithString:aURIRepresentationString]; // do NOT encodeLegally, it is unnecessary
	return [self objectWithURIRepresentation:URL];
}

- (KTDocument *)document
{
	OBASSERT_NOT_REACHED("-[NSManagedObjectContext document] is dead. Long live -[KTPSC document]");
	return nil;
}

- (KTSite *)site
{
	NSError *localError = nil;
	NSArray *fetchedObjects = [self fetchAllObjectsForEntityForName:@"Site"
												predicate:nil
													error:&localError];
	
	if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1)  )
	{
		return [fetchedObjects objectAtIndex:0];
	}
	
	return nil;
}

- (void)willDeletePage:(KTAbstractPage *)page;
{
    // Let plug-ins know
    [[NSNotificationCenter defaultCenter] postNotificationName:SVPageWillBeDeletedNotification
                                                        object:page];
    
    // Repeat for any children that are going the same way
    for (KTPage *aPage in [page childItems])
    {
        [self willDeletePage:aPage];
    }
    for (KTAbstractPage *aPage in [page archivePages])
    {
        [self willDeletePage:aPage];
    }
}

- (void)deletePage:(KTAbstractPage *)page;  // Please ALWAYS call this for pages as it posts a notification first
{
    [self willDeletePage:page];
    [self deleteObject:page];
}

- (void)lockPSCAndSelf
{
	//[self checkPublishingModeAndThread];
	//[[self persistentStoreCoordinator] lock];
	//[self lock];
}

- (void)unlockPSCAndSelf
{
	//[self checkPublishingModeAndThread];
	//[self unlock];
	//[[self persistentStoreCoordinator] unlock];
}

#pragma mark debugging support

/*! returns set of all updated, inserted, and deleted objects in context */
- (NSSet *)changedObjects
{
	NSMutableSet *set = [NSMutableSet set];
	
	[set unionSet:[self insertedObjects]];
	[set unionSet:[self deletedObjects]];
	[set unionSet:[self updatedObjects]];
	
	return [NSSet setWithSet:set];
}

- (BOOL)isDocumentMOC
{
	return NO;	// Disabled for 1.5
	return [self isEqual:[[self document] managedObjectContext]];
}

@end
