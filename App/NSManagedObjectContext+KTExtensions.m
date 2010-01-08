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

- (NSArray *)objectsWithEntityName:(NSString *)anEntityName
						 predicate:(NSPredicate *)aPredicate
							 error:(NSError **)anError
{
	OBASSERTSTRING((nil != anEntityName), @"anEntityName cannot be nil");
	// nil predicate means "return all objects of anEntityName"
	
	NSArray *fetchedObjects = nil;
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSError *localError = nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:anEntityName
											  inManagedObjectContext:self];
	OBASSERTSTRING((nil != entity), @"entity should not be nil");
	[fetchRequest setEntity:entity];
	
	if ( nil != aPredicate )
	{
		[fetchRequest setPredicate:aPredicate];
	}
	
	// note to future debuggers: we ALWAYS need to lock the context here to prevent
	// a "statement is still active" error. if we only lockIfNecessary, it's possible
	// that this method could be called on the main thread while another thread is
	// doing the same. DO NOT REMOVE THIS LOCK. DO NOT MAKE IT CONDITIONAL.
	//[self lockPSCAndSelf];
	fetchedObjects = [self executeFetchRequest:fetchRequest error:&localError];
	
	return fetchedObjects;
}

#pragma mark convenience methods that message workhorse

- (NSArray *)allObjectsWithEntityName:(NSString *)anEntityName
								error:(NSError **)anError
{
	return [self objectsWithEntityName:anEntityName
							 predicate:nil
								 error:anError];
}

// return array of unique values for aColumnName for all instances of anEntityName
- (NSArray *)objectsForColumnName:(NSString *)aColumnName entityName:(NSString *)anEntityName
{
    NSError *localError = nil;
    NSArray *allInstances = [self allObjectsWithEntityName:anEntityName error:&localError];
    
    if ( [allInstances count] > 0 )
    {
        NSMutableSet *objects = [NSMutableSet setWithCapacity:[allInstances count]];
        
        NSEnumerator *e = [allInstances objectEnumerator];
        NSManagedObject *instance;
        while ( instance  = [e nextObject] )
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
	NSArray *fetchedObjects = [self objectsWithEntityName:anEntityName
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
	NSArray *fetchedObjects = [self objectsWithEntityName:@"Site"
												predicate:nil
													error:&localError];
	
	if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1)  )
	{
		return [fetchedObjects objectAtIndex:0];
	}
	
	return nil;
}

- (KTPage *)root
{
	NSError *localError = nil;
	NSArray *fetchedObjects = [self objectsWithEntityName:@"Root"
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
    if ([page isKindOfClass:[KTPage class]])
    {
        for (KTPage *aPage in [(KTPage *)page childPages])
        {
            [self willDeletePage:aPage];
        }
        for (KTAbstractPage *aPage in [(KTPage *)page archivePages])
        {
            [self willDeletePage:aPage];
        }
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

- (void)makeAllPluginsPerformSelector:(SEL)selector withObject:(id)object withPage:(KTPage *)page
{
	NSArray *pages = [self allObjectsWithEntityName:@"Page" error:NULL];
	NSArray *pagelets = [NSArray array];//[self allObjectsWithEntityName:@"OldPagelet" error:NULL];
	
	NSMutableArray *plugins = [[NSMutableArray alloc] initWithCapacity:[pages count] + [pagelets count]];
	[plugins addObjectsFromArray:pages];
	[plugins addObjectsFromArray:pagelets];
	
	NSEnumerator *pluginsEnumerator = [plugins objectEnumerator];
	KTAbstractElement *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		[aPlugin makeSelfOrDelegatePerformSelector:selector withObject:object withPage:page recursive:NO];
	}
	
	[plugins release];
}

@end
