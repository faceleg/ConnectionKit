//
//  NSManagedObjectContext+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 6/28/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSManagedObjectContext+KTExtensions.h"

#import "Debug.h"
#import "KTDocumentInfo.h"
#import "KTManagedObject.h"
#import "KTManagedObjectContext.h"
#import "KTMedia.h"
#import "KTPage.h"
#import "KTPagelet.h"
#import "NSDocumentController+KTExtensions.h"
#import "NSFetchRequest+KTExtensions.h"
#import "NSString+KTExtensions.h"


@interface NSManagedObjectContext ( KTManagedObjectContext )
- (void)checkPublishingModeAndThread;
@end


@implementation NSManagedObjectContext ( KTExtensions )

- (void)deleteObjects:(NSSet *)objects
{
	NSEnumerator *enumerator = [objects objectEnumerator];
	NSManagedObject *anObject;
	while (anObject = [enumerator nextObject])
	{
		[self deleteObject:anObject];
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

	@try
	{
		// note to future debuggers: we ALWAYS need to lock the context here to prevent
		// a "statement is still active" error. if we only lockIfNecessary, it's possible
		// that this method could be called on the main thread while another thread is
		// doing the same. DO NOT REMOVE THIS LOCK. DO NOT MAKE IT CONDITIONAL.
		[self lockPSCAndSelf];
		NSManagedObjectModel *model= [[self persistentStoreCoordinator] managedObjectModel];
		fetchRequest = [model fetchRequestFromTemplateWithName:aTemplateName
										 substitutionVariables:aDictionary];
		fetchedObjects = [self executeFetchRequest:fetchRequest error:&localError];
	}
	@catch (NSException *exception)
	{
		NSLog(@"error: %@ threw exception, name:%@ reason:%@", 
			  [fetchRequest shortDescription], [exception name], [exception reason]);
	}	
	@finally
	{
		[self unlockPSCAndSelf];
		
		if ( (nil == fetchedObjects) && (nil != anError) )
		{
			*anError = localError;
		}		
	}
	
	return fetchedObjects;
}

- (NSArray *)objectsWithEntityName:(NSString *)anEntityName
						 predicate:(NSPredicate *)aPredicate
							 error:(NSError **)anError
{
	NSAssert((nil != anEntityName), @"anEntityName cannot be nil");
	// nil predicate means "return all objects of anEntityName"
	
	NSArray *fetchedObjects = nil;
	NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
	NSError *localError = nil;
	
	NSEntityDescription *entity = [NSEntityDescription entityForName:anEntityName
											  inManagedObjectContext:self];
	NSAssert((nil != entity), @"entity should not be nil");
	[fetchRequest setEntity:entity];
	
	if ( nil != aPredicate )
	{
		[fetchRequest setPredicate:aPredicate];
	}
	
	@try
	{
		// note to future debuggers: we ALWAYS need to lock the context here to prevent
		// a "statement is still active" error. if we only lockIfNecessary, it's possible
		// that this method could be called on the main thread while another thread is
		// doing the same. DO NOT REMOVE THIS LOCK. DO NOT MAKE IT CONDITIONAL.
		[self lockPSCAndSelf];
		fetchedObjects = [self executeFetchRequest:fetchRequest error:&localError];
	}
	@catch (NSException *exception)
	{
		NSLog(@"error: %@ threw exception, name:%@ reason:%@", 
			  [fetchRequest shortDescription], [exception name], [exception reason]);
	}	
	@finally
	{
		[self unlockPSCAndSelf];

		if ( nil == fetchedObjects && nil != anError )
		{
			*anError = localError;
		}
		
		[fetchRequest release];
	}
	
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
			if ( nil != object )
			{
				[objects addObject:object];
			}
        }
        
        return [objects allObjects]; // return set as array
    }
    
    return nil;
}

// return media object matching digest(s), nil is taken into account
- (KTMedia *)objectMatchingMediaDigest:(NSString *)aMediaDigest
					   thumbnailDigest:(NSString *)aThumbnailDigest
{
	NSAssert((nil != aMediaDigest), @"aMediaDigest cannot be nil");
	
	KTMedia *result = nil;
	
	NSPredicate *predicate = nil;
	if ( nil != aThumbnailDigest )
	{
		predicate = [NSPredicate predicateWithFormat:@"(mediaDigest == %@) && (thumbnailDigest == %@)", aMediaDigest, aThumbnailDigest];
	}
	else
	{
		predicate = [NSPredicate predicateWithFormat:@"(mediaDigest == %@) && (thumbnailDigest == %@)", aMediaDigest, [NSNull null]];
	}
	
	NSError *localError = nil;
	NSArray *fetchedObjects = [self objectsWithEntityName:@"Media"
												predicate:predicate
													error:&localError];
		
	// return only the first object that matches
	if ( [fetchedObjects count] > 0 )
	{
		if ( [fetchedObjects count] > 1 )
		{
			NSLog(@"warning: document contains more than one Media with mediaDigest %@ and thumbnailDigest %@, close and reopen document to correct this problem", 
				  aMediaDigest, aThumbnailDigest);
		}
		result = [fetchedObjects objectAtIndex:0];
	}
	
	return result;
}

- (KTManagedObject *)objectWithUniqueID:(NSString *)aUniqueID entityNames:(NSArray *)aNamesArray
{
	NSAssert((nil != aUniqueID), @"aUniqueID cannot be nil");
	NSAssert((nil != aNamesArray), @"aNamesArray cannot be nil");
	
	NSEnumerator *e = [aNamesArray objectEnumerator];
	NSString *entityName;
	while ( entityName = [e nextObject] )
	{
		NSManagedObject *matchingObject = [self objectWithUniqueID:aUniqueID entityName:entityName];
		if ( nil != matchingObject )
		{
			return (KTManagedObject *)matchingObject;
		}
	}
	
	return nil;
}

- (KTManagedObject *)objectWithUniqueID:(NSString *)aUniqueID entityName:(NSString *)anEntityName
{
	NSAssert((nil != aUniqueID), @"aUniqueID cannot be nil");
	NSAssert((nil != anEntityName), @"anEntityName cannot be nil");
	
	KTManagedObject *result = nil;
    
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

- (KTManagedObject *)objectWithUniqueID:(NSString *)aUniqueID
{
	NSAssert((nil != aUniqueID), @"aUniqueID cannot be nil");
	
	// we have to search in Root, Page, Pagelet, Element, and Media
	NSArray *entityNames = [NSArray arrayWithObjects:
		@"Page", 
		@"Pagelet", 
		nil];
	
	return (KTManagedObject *)[self objectWithUniqueID:aUniqueID entityNames:entityNames];
}

- (KTAbstractPlugin *)pluginWithUniqueID:(NSString *)pluginID
{
	static NSArray *entityNames;
	if (!entityNames)
	{
		entityNames = [[NSArray alloc] initWithObjects:@"Pagelet", @"Page", nil];
	}
	
	KTAbstractPlugin *result = (KTAbstractPlugin *)[self objectWithUniqueID:pluginID entityNames:entityNames];
	return result;
}

- (KTMedia *)mediaWithUniqueID:(NSString *)anID
{
	KTMedia *result = nil;
	
	if ( (nil != anID) && ![anID isEqualToString:@""] )
	{
		result = (KTMedia *)[self objectWithUniqueID:anID entityName:@"Media"];
	}
	
	return result;
}

- (KTPage *)pageWithUniqueID:(NSString *)anID
{
	KTPage *result = nil;
	
	if ( (nil != anID) && ![anID isEqualToString:@""] )
	{
		result = (KTPage *)[self objectWithUniqueID:anID entityName:@"Page"];
	}
	
	return result;
}

- (NSManagedObject *)objectWithURIRepresentation:(NSURL *)aURL
{
	NSAssert((nil != aURL), @"aURL cannot be nil");
	
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
	return (KTDocument *)[[NSDocumentController sharedDocumentController] documentForManagedObjectContext:self];
}

- (KTDocumentInfo *)documentInfo
{
	NSError *localError = nil;
	NSArray *fetchedObjects = [self objectsWithEntityName:@"DocumentInfo"
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

- (NSArray *)allPages;
{
	return [self allObjectsWithEntityName:@"Page" error:NULL];
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
	return [self isEqual:[[self document] managedObjectContext]];
}

- (void)makeAllPluginsPerformSelector:(SEL)selector withObject:(id)object withPage:(KTPage *)page
{
	NSArray *pages = [self allObjectsWithEntityName:@"Page" error:NULL];
	NSArray *pagelets = [self allObjectsWithEntityName:@"Pagelet" error:NULL];
	
	NSMutableArray *plugins = [[NSMutableArray alloc] initWithCapacity:[pages count] + [pagelets count]];
	[plugins addObjectsFromArray:pages];
	[plugins addObjectsFromArray:pagelets];
	
	NSEnumerator *pluginsEnumerator = [plugins objectEnumerator];
	KTAbstractPlugin *aPlugin;
	while (aPlugin = [pluginsEnumerator nextObject])
	{
		[aPlugin makeSelfOrDelegatePerformSelector:selector withObject:object withPage:page recursive:NO];
	}
	
	[plugins release];
}

@end
