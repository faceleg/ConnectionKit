//
//  KTMediaManager.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Manage media objects: files, images, movies, etc. embedded in a document

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	A KTDocument has one Media manager.
	Works with KTMediaObject, defined in KTComponents framework

IMPLEMENTATION NOTES & CAUTIONS:
	MediaManager should be kept as lightweight as possible, only
	doing things that work with all Media in a document as a whole.

TO DO:
	x
 */

#import "KTOldMediaManager.h"

#import "KT.h"
#import "KTDocument.h"
#import "KTMediaDataProxy.h"
#import "KTMediaURLProtocol.h"

#import "SandvoxPrivate.h"


@interface KTOldMediaManager ( Private )
- (NSMutableDictionary *)mediaCache;
- (void)setMediaCache:(NSMutableDictionary *)aCachedMedia;
- (NSMutableSet *)uploadCache;
- (void)setUploadCache:(NSMutableSet *)aSet;
- (NSManagedObjectID *)mediaNotFoundMediaObjectIDInManagedObjectContext:(KTManagedObjectContext *)aContext;
@end


@implementation KTOldMediaManager

#pragma mark -
#pragma mark init/dealloc

+ (KTOldMediaManager *)mediaManagerWithDocument:(KTDocument *)aDocument
{
    KTOldMediaManager *manager = [[self alloc] init];
    [manager setDocument:aDocument];
	
    return [manager autorelease];
}

- (id)init
{
    self = [super init];
    if ( nil != self )
    {
		[self setMediaCache:[NSMutableDictionary dictionary]];
		[self setUploadCache:[NSMutableSet set]];
    }

    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
	[self setUploadCache:nil];
	[self setMediaCache:nil];
    [self setDocument:nil];

    [super dealloc];
}

#pragma mark -
#pragma mark retrieval

- (void)cacheAllObjects:(KTManagedObjectContext *)aManagedObjectContext
{
	NSEnumerator *e = [[self allObjects:aManagedObjectContext] objectEnumerator];
	KTMedia *media = nil;
	while ( media = [e nextObject] )
	{
		NSString *uniqueID = [media wrappedValueForKey:@"uniqueID"];
		[myMediaCache setObject:media forKey:uniqueID];
	}
}

- (NSArray *)allObjects:(KTManagedObjectContext *)aManagedObjectContext
{
	OBASSERTSTRING((nil != aManagedObjectContext), @"myDocument is nil!");
	return [aManagedObjectContext allObjectsWithEntityName:@"Media" error:nil];
}

/*! returns array of media objects with 1 or more media refs in aManagedObjectContext
	NB: this is used as a binding in the MediaInspector */

- (NSArray *)activeObjects
{
	return [self activeObjects:(KTManagedObjectContext *)[[self document] managedObjectContext]];
}

- (NSArray *)activeObjects:(KTManagedObjectContext *)aManagedObjectContext
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaRefs.@count > 0"];
    NSArray *objects = [aManagedObjectContext objectsWithEntityName:@"Media"
														  predicate:predicate
															  error:nil];
	return objects;
}

- (NSArray *)allMediaRefs:(KTManagedObjectContext *)aManagedObjectContext
{
	return [aManagedObjectContext allObjectsWithEntityName:@"MediaRef" error:nil];
}

- (NSArray *)allMediaRefsWithoutOwners:(KTManagedObjectContext *)aManagedObjectContext
{
	// return all MediaRefs where owner = nil
	return [aManagedObjectContext objectsWithEntityName:@"MediaRef"
											  predicate:[NSPredicate predicateWithFormat:@"owner == %@", [NSNull null]]
												  error:nil];
}

- (NSArray *)objectsOfType:(NSString *)aUTI managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	// return all Media where mediaUTI = aUTI
	return [aManagedObjectContext objectsWithEntityName:@"Media"
											  predicate:[NSPredicate predicateWithFormat:@"mediaUTI like %@", aUTI]
												  error:nil];
}

#pragma mark -

/*! @discussion objectWithUniueID: is actually the most important method, though all are used. It is this method that fetches media objects referenced by templates from the datastore, caching them as needed. */
- (KTMedia *)objectWithUniqueID:(NSString *)aUniqueID managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	OBASSERTSTRING((nil != aUniqueID), @"aUniqueID cannot be nil");
	KTMedia *media = nil;
	
	// see if we can return a cached object first
	if ( nil != [myMediaCache objectForKey:aUniqueID] )
	{
		media = [myMediaCache objectForKey:aUniqueID];
	}
	else
	{		
		media = (KTMedia *)[aManagedObjectContext objectWithUniqueID:aUniqueID entityName:@"Media"];
		if ( nil != media )
		{
			[self cacheMedia:media];
		}
	}
	
	return media;
}

- (KTMedia *)objectWithURIRepresentation:(NSURL *)aURL managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	return (KTMedia *)[aManagedObjectContext objectWithURIRepresentation:aURL];
}

- (KTMedia *)objectWithName:(NSString *)aName managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	OBASSERTSTRING((nil != aName), @"aName cannot be nil"); OBASSERTSTRING([aName length] > 0, @"name should not be empty string");
	
	// see if we've already loaded and cached the object first
	NSEnumerator *e = [[myMediaCache allValues] objectEnumerator];
	KTMedia *media = nil;
	while ( media = [e nextObject] )
	{
		if ( [[media name] isEqualToString:aName] )
		{
			return media;
		}
	}
	
	// not in the cache, fetch from the datastore
    media = nil;
	
	NSError *localError = nil;
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name like %@", aName];
	NSArray *fetchedObjects = [aManagedObjectContext objectsWithEntityName:@"Media"
																 predicate:predicate
																	 error:&localError];
	
	if ( [fetchedObjects count] == 1 )
    {
        media = [fetchedObjects objectAtIndex:0];
    }
	else if ( [fetchedObjects count] > 1 ) 
	{
		NSLog(@"objectWithName: %@ is not unique", aName); // log to console for inclusion in bug reports
		media = [fetchedObjects objectAtIndex:0];
	}
	
    return media;
}

- (KTMedia *)objectWithOriginalPath:(NSString *)aPath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	NSError *localError = nil;
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"originalPath like %@", aPath];
	NSArray *fetchedObjects = [aManagedObjectContext objectsWithEntityName:@"Media"
																 predicate:predicate
																	 error:&localError];	
	if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1)  )
	{
		return [fetchedObjects objectAtIndex:0];
	}
	
	return nil;
}

- (KTMedia *)objectWithOriginalPath:(NSString *)aPath
					   creationDate:(NSCalendarDate *)aCalendarDate
			   managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	NSError *localError = nil;
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(originalPath like %@) and (originalCreationDate == %@)", 
		aPath, aCalendarDate];
	NSArray *fetchedObjects = [aManagedObjectContext objectsWithEntityName:@"Media"
																 predicate:predicate
																	 error:&localError];	
	if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1)  )
	{
		return [fetchedObjects objectAtIndex:0];
	}
	
	return nil;
}

#pragma mark -
#pragma mark garbage collection

- (void)collectGarbage
{
	//OBASSERTSTRING(![myDocument hasPeerContextsInFlight], @"there should be no peer contexts");
	
	[[[self document] undoManager] disableUndoRegistration];
	
    // find all Media with no MediaRefs and remove them
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"mediaRefs.@count == 0"];
    NSArray *objects = [[[self document] managedObjectContext] objectsWithEntityName:@"Media"
                                                                           predicate:predicate
                                                                               error:nil];
    NSEnumerator *e = [objects objectEnumerator];
    id object = nil;
    while ( object = [e nextObject] )
    {
		if (![[object name] isEqualToString:kKTMediaNotFoundMediaName]) {	// don't remove special media
			NSLog(@"GC: removing media %@ no longer referenced", [object name]);
			[self removeFromDocument:object];
		}
    }
	
	// find all duplicate media and repoint mediaRefs to point to one of them
	KTManagedObjectContext *context = (KTManagedObjectContext *)[[self document] managedObjectContext];
	NSMutableSet *duplicateMedia = [NSMutableSet set];
	BOOL finishedProcessing = NO;
	while ( !finishedProcessing )
	{
		BOOL didFindDuplicate = NO;
		objects = [self allObjects:context];
		e = [objects objectEnumerator];
		while ( object = [e nextObject] )
		{
			// get object's mediaDigest and thumbnailDigest
			NSString *mediaDigest = [object wrappedValueForKey:@"mediaDigest"];
			NSString *thumbnailDigest = [object wrappedValueForKey:@"thumbnailDigest"];
			
			if ( nil != thumbnailDigest )
			{
				predicate = [NSPredicate predicateWithFormat:@"(mediaDigest == %@) && (thumbnailDigest == %@)", mediaDigest, thumbnailDigest];
			}
			else
			{
				predicate = [NSPredicate predicateWithFormat:@"(mediaDigest == %@) && (thumbnailDigest == %@)", mediaDigest, [NSNull null]];
			}
			
			NSError *localError = nil;
			NSArray *fetchedObjects = [context objectsWithEntityName:@"Media" predicate:predicate error:&localError];
			if ( [fetchedObjects count] > 1 )
			{
				// we have more than one of supposedly identical media objects
				int i;
				for ( i=0; i<[fetchedObjects count]; i++ )
				{
					KTMedia *media = [fetchedObjects objectAtIndex:i];
					if (![media isEqual:object] )	// skip the one we're going to claim is canonical
					{
					// get all mediaRefs that point to media and repoint them to object
					predicate = [NSPredicate predicateWithFormat:@"media == %@", media];
					NSArray *mediaRefs = [context objectsWithEntityName:@"MediaRef" predicate:predicate error:&localError];
					if ( [mediaRefs count] > 0 )
					{
						int j;
						for ( j=0; j<[mediaRefs count]; j++ )
						{
							KTMediaRef *mediaRef = [mediaRefs objectAtIndex:j];
							[mediaRef threadSafeSetValue:object forKey:@"media"];
							NSLog(@"GC: repointing mediaRef %@ to new canonical media", [mediaRef name]);
							didFindDuplicate = YES;
						}
					}
					[duplicateMedia addObject:media];
				}
			}
		}
		}
		finishedProcessing = !didFindDuplicate;
	}
	
	// remove duplicate media
    e = [duplicateMedia objectEnumerator];
    object = nil;
    while ( object = [e nextObject] )
    {
		NSLog(@"GC: removing duplicate media %@", [object name]);
        [self removeFromDocument:object];
    }
	
	[[[self document] undoManager] enableUndoRegistration];
}

- (void)removeFromDocument:(KTMedia *)aMediaObject
{
	// rather than remove aMediaObject from either uploadCache or mediaCache
	// we now just let dealloc take care of it

	//OBASSERTSTRING(![myDocument hasPeerContextsInFlight], @"there should be no peer contexts");
	OBASSERTSTRING([NSThread isMainThread], @"should be main thread");

	KTDocument *document = [aMediaObject document];
	KTManagedObjectContext *context = (KTManagedObjectContext *)[document managedObjectContext];
	
	OBASSERTSTRING([context isEqual:[aMediaObject managedObjectContext]], @"contexts should be the same");
		
	// if aMediaObject is MEDIA_NOT_FOUND media, don't remove
	if ( [[aMediaObject name] isEqualToString:kKTMediaNotFoundMediaName] )
	{
		return;
	}
			 
    // remove any cachedImages
    NSSet *cachedImages = [aMediaObject wrappedValueForKey:@"cachedImages"];
    NSEnumerator *e = [cachedImages objectEnumerator];
    KTCachedImage *cachedImage;
    while ( cachedImage = [e nextObject] )
    {
        // delete cachedImage from context first! (since media has a DENY rule in place)
        (void)[cachedImage removeCacheFile];
        [context threadSafeDeleteObject:cachedImage];
    }
    
    // remove media object, actual close of document will handle the save
    [context threadSafeDeleteObject:aMediaObject];
}

#pragma mark publication

///*! returns dictionary of media to upload to site
//	key = filePath, value = data
//*/
//- (NSDictionary *)activeMediaInfo
//{
//	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
//	NSFileManager *fm = [NSFileManager defaultManager];
//	
//	[myDocument savePeerContexts];
//	
//	NSManagedObjectContext *context = [myDocument managedObjectContext];
//	BOOL didLock = [(KTManagedObjectContext *)context lockIfNeeded];
//	
//	NSEnumerator *e = [[self uploadCache] objectEnumerator];
//	id rep;
//	int i = 0;
//	
//	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
//	
//	while ( rep = [e nextObject] )
//	{
//		NSMutableDictionary *record = [NSMutableDictionary dictionary];
//		
//		if ( [rep isKindOfClass:[KTMedia class]] )
//		{
//			NSString *dataFilePath = [rep dataFilePath];
//			
//			if ( (nil != dataFilePath) && ([dataFilePath length] > 0) && [fm fileExistsAtPath:dataFilePath] )
//			{
//				[record setObject:dataFilePath forKey:@"filename"];
//                
//                NSDictionary *fileAttributes = [fm fileAttributesAtPath:dataFilePath traverseLink:YES];
//                NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
//				if ( nil != fileSize )
//				{
//					[record setObject:fileSize forKey:@"size"];
//				}
//				else
//				{
//					NSLog(@"error: media at %@ is zero bytes!", dataFilePath);
//				}
//			}
//			else
//			{
//				KTMediaDataProxy *proxy = [[KTMediaDataProxy alloc] initWithDocument:[self document] media:rep];
//				if (proxy != nil)
//				{
//					[record setObject:proxy forKey:@"data"];
//				}
//				else
//				{
//					NSLog(@"error: could not create media data proxy for \"%@\"!", [rep name]);
//				}
//				[proxy release];
//			}
//			[record setObject:rep forKey:@"media"];
//			[dictionary setObject:record forKey:[rep fileName]];
//		}
//		else if ( [rep isKindOfClass:[KTMediaRef class]] )
//		{
//			KTMedia *media = [(KTMediaRef *)rep media];
//			NSString *dataFilePath = [media dataFilePath];
//			
//			if (dataFilePath != nil && [dataFilePath length] > 0 && [fm fileExistsAtPath:dataFilePath])
//			{
//				[record setObject:dataFilePath forKey:@"filename"];
//				//[record setObject:[media valueForKey:@"mediaDataLength"] forKey:@"size"];
//                
//                NSDictionary *fileAttributes = [fm fileAttributesAtPath:dataFilePath traverseLink:YES];
//                NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
//				if ( nil != fileSize )
//				{
//					[record setObject:fileSize forKey:@"size"];
//				}
//				else
//				{
//					NSLog(@"error: media at %@ is zero bytes!", dataFilePath);
//				}
//			}
//			else
//			{
//				KTMediaDataProxy *proxy = [[KTMediaDataProxy alloc] initWithDocument:[self document] media:media];
//				if (proxy != nil)
//				{
//					[record setObject:proxy forKey:@"data"];
//				}
//				else
//				{
//					NSLog(@"error: could not create media data proxy for \"%@\"!", [media name]);
//				}
//				[proxy release];
//			}
//			
//			[record setObject:media forKey:@"media"];
//			[dictionary setObject:record forKey:[media fileName]];			
//		}
//		else if ( [rep isKindOfClass:[KTCachedImage class]] )
//		{
//			KTMedia *media = [(KTCachedImage *)rep media];
//			NSString *imageName = [rep name];
//						
//			if ( [rep hasValidCacheFileNoRecache] )
//			{
//				// cacheAbsolutePath
//				if ( nil == [rep cacheAbsolutePath] )
//				{
//					NSLog(@"error: %@ is not cached, recaching...", [rep imageName]);
//					[rep recacheInPreferredFormat];
//				}
//				if ( nil != [rep cacheAbsolutePath] )
//				{
//					[record setObject:[rep cacheAbsolutePath] forKey:@"filename"];
//				}
//				else
//				{
//					NSLog(@"error: failed to cache %@", [rep imageName]);
//				}
//				
//				// cacheSize
//				if ([rep cacheSize] == nil)
//				{
//					NSLog(@"KTCachedImage cacheSize is nil, recaching...");
//					[rep recacheInPreferredFormat];
//					NSLog(@"cacheSize is now %@", [rep cacheSize]);
//				}
//				if ( nil != [rep cacheSize] )
//				{
//					[record setObject:[rep cacheSize] forKey:@"size"];
//				}
//				else
//				{
//					NSLog(@"KTCachedImage cacheSize is nil, unable to recache.");
//				}
//			}
//			else
//			{
//				// OLD WAY
////				NSData *data = [media dataForImageName:imageName];
////				[record setObject:data forKey:@"data"];
//				//LOG((@"KTMediaDataProxy created for %@_%@", [media name], imageName));
//				KTMediaDataProxy *proxy = [[KTMediaDataProxy alloc] initWithDocument:[self document] media:media name:imageName];
//				if (proxy != nil)
//				{
//					[record setObject:proxy forKey:@"data"];
//				}
//				else
//				{
//					NSLog(@"error: could not create media data proxy for \"%@\" name \"%@\"!", [media name], imageName);
//				}
//				[proxy release];
//			}
//			
//			NSString *fileName = [media fileNameForImageName:imageName];
//
//			[record setObject:media forKey:@"media"];
//			[dictionary setObject:record forKey:fileName];
//		}
//		else if ( [rep isKindOfClass:[KTMediaDataProxy class]] )
//		{
//			
//		}
//		i++;
//		if (i % 5 == 4)
//		{
//			[pool release];
//			pool = [[NSAutoreleasePool alloc] init];
//		}
//	}
//	[pool release];
//	
//	[(KTManagedObjectContext *)context unlockIfNeeded:didLock];
//		
//	return [NSDictionary dictionaryWithDictionary:dictionary];
//}
	
/*! returns dictionary of media to upload to site
key = filePath, value = data
*/

- (NSDictionary *)activeMediaInfo:(KTManagedObjectContext *)aManagedObjectContext;
{
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	NSFileManager *fm = [NSFileManager defaultManager];
	
	[myDocument savePeerContexts];
	
	[aManagedObjectContext lockPSCAndSelf];
	
	NSEnumerator *e = [[[self uploadCache] allObjects] objectEnumerator];
	id proxy;
	int i = 0;
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	while ( proxy = [e nextObject] )
	{
		OBASSERTSTRING([proxy isKindOfClass:[KTMediaDataProxy class]], @"proxy should be a KTMediaDataProxy");
		
		NSMutableDictionary *record = [NSMutableDictionary dictionary];
		
		id proxiedObject = nil;
		
		KTMedia *media = [self objectWithUniqueID:[(KTMediaDataProxy *)proxy mediaID] managedObjectContext:aManagedObjectContext];
		OBASSERTSTRING((nil != media), @"media should not be nil");
		
		NSString *imageName = [(KTMediaDataProxy *)proxy name];
		if ( nil != imageName )
		{
			// if we have an imageName, we're a proxy for a CachedImage
			proxiedObject = [media imageForImageName:imageName];
			OBASSERTSTRING((nil != proxiedObject), @"proxiedObject should not be nil");
			OBASSERTSTRING([proxiedObject isKindOfClass:[KTCachedImage class]], @"proxiedObject should be a KTCachedImage");			
		}
		
		if ( nil == proxiedObject )
		{
			proxiedObject = media;
		}
		
		if ( [proxiedObject isKindOfClass:[KTMedia class]] )
		{
			NSString *dataFilePath = [proxiedObject dataFilePath];
			if ( (nil != dataFilePath) && ([dataFilePath length] > 0) && [fm fileExistsAtPath:dataFilePath] )
			{
				[record setObject:dataFilePath forKey:@"filename"];
                
                NSDictionary *fileAttributes = [fm fileAttributesAtPath:dataFilePath traverseLink:YES];
                NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
				if ( nil != fileSize )
				{
					[record setObject:fileSize forKey:@"size"];
				}
				else
				{
					NSLog(@"error: media at %@ is zero bytes!", dataFilePath);
				}
			}
			else
			{
				[record setObject:proxy forKey:@"data"];
			}
			[record setObject:proxiedObject forKey:@"media"];
			[dictionary setObject:record forKey:[proxiedObject fileName]];
		}
		else if ( [proxiedObject isKindOfClass:[KTCachedImage class]] )
		{
			if ( [proxiedObject hasValidCacheFileNoRecache] )
			{
				[record setObject:[proxiedObject cacheAbsolutePath] forKey:@"filename"];
				[record setObject:[proxiedObject cacheSize] forKey:@"size"];
			}
			else
			{
				[record setObject:proxy forKey:@"data"];
			}
			
			[record setObject:media forKey:@"media"];

			NSString *fileName = [media fileNameForImageName:imageName];
			[dictionary setObject:record forKey:fileName];
		}
		i++;
		if (i % 5 == 4)
		{
			[pool release];
			pool = [[NSAutoreleasePool alloc] init];
		}
	}
	[pool release];
	
	[aManagedObjectContext unlockPSCAndSelf];
	
	return [NSDictionary dictionaryWithDictionary:dictionary];
}


/*! caches either KTMedia or KTCachedImage for publication */
- (void)cacheReference:(id)anObject
{
	if ( [[self document] publishingMode] != kGeneratingPreview )
	{
		// NB: warning: If we want to log this, we have to somehow prevent 
		//  mediaPathRelativeTo -> URL -> fileNameForImageName -> imageForImageName
		//  from helpfully caching the ref for you, causing recursion
		// POSSIBLE FIX: have some alternate methods that go down a slightly different path, but not caching.
		//TJT((@"caching reference: %@", [anObject mediaPathRelativeTo:aPage]));
		if ( nil != anObject )
		{
			KTMediaDataProxy *proxy = [KTMediaDataProxy proxyForObject:anObject];
			if ( nil != proxy )
			{
				[[self uploadCache] addObject:proxy];
				//LOG((@"caching %@ %p", [proxy className], proxy));
			}
			else
			{
				LOG((@"could not create proxy for %@ %p", [anObject className], anObject));
			}
		}
	}
}

- (void)willUploadMedia
{
	// clear cache so that only needed references get added as site is parsed
	//[self setUploadCache:[NSMutableSet set]];
	[[self uploadCache] removeAllObjects];
}

- (void)didUploadMedia
{
	// we're done with media, so clear cache to release objects
	[[self uploadCache] removeAllObjects];
}

#pragma mark -
#pragma mark accessors

- (NSManagedObjectID *)mediaNotFoundMediaObjectIDInManagedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{	
	KTMedia *media = [self objectWithName:kKTMediaNotFoundMediaName managedObjectContext:aManagedObjectContext];
	if ( nil == media )
	{
		// this is here for legacy documents that are not prepopulated with a "Media Not Found" media object

		// create in aManagedObjectContext
		[aManagedObjectContext lockPSCAndSelf];
		media = [KTMedia mediaWithImage:[NSImage qmarkImage] insertIntoManagedObjectContext:aManagedObjectContext];
		
		// set special name
		[media setValue:kKTMediaNotFoundMediaName forKey:@"name"];
		
		// save context to get rid of temp objectID
		[myDocument saveContext:aManagedObjectContext onlyIfNecessary:NO];
		[aManagedObjectContext unlockPSCAndSelf];
	}
	
	if ( [media isManagedObject] )
	{
		return [media objectID];
	}
	else
	{
		NSLog(@"error: could not create/locate missing image graphic in context %@", aManagedObjectContext);
		return nil;
	}
}

- (NSMutableSet *)uploadCache
{
	return myUploadCache;
}

- (void)setUploadCache:(NSMutableSet *)aSet
{
	[aSet retain];
	[myUploadCache release];
	myUploadCache = aSet;
}

- (NSMutableDictionary *)mediaCache
{
    return myMediaCache; 
}

- (void)setMediaCache:(NSMutableDictionary *)aCachedMedia
{
    [aCachedMedia retain];
    [myMediaCache release];
    myMediaCache = aCachedMedia;
}

- (KTDocument *)document
{
    return myDocument;
}

// MADE THIS BE A WEAK REFERENCE
- (void)setDocument:(KTDocument *)aDocument
{
//    [aDocument retain];
//    [myDocument release];
    myDocument = aDocument;
}

#pragma mark notifications

- (void)objectDidBecomeActive:(NSNotification *)aNotification
{
	//KTMedia *media = [aNotification object];
	// could do something here such as update a binding
}

- (void)objectDidBecomeInactive:(NSNotification *)aNotification
{
	KTMedia *media = [aNotification object];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:kKTMediaObjectDidBecomeActiveNotification 
												  object:media];
	[[NSNotificationCenter defaultCenter] removeObserver:self 
													name:kKTMediaObjectDidBecomeInactiveNotification 
												  object:media];
	[myMediaCache removeObjectForKey:[media uniqueID]];
}

#pragma mark -
#pragma mark Media Reference Refreshing

- (NSString *)transformMediaReferencesForMediaPaths:(NSSet *)aMediaPathsSet 
									   inHTMLString:(NSString *)html 
											element:(KTElement *)anElement
{
	if ( (nil == html) || (nil == anElement) )
	{
		return nil;
	}
	
	NSMutableString *imgSrcTagHack = [NSMutableString stringWithString:html];
	
	KTManagedObjectContext *context = (KTManagedObjectContext *)[anElement managedObjectContext];
	[context lockPSCAndSelf];

	KTPage *page = // [anElement page];	// NOTE: THIS REALLY SHOULD BE THE PAGE CURRENTLY BEING GENERATED
		[[self document] currentlyParsedPage];
		
	OFF((@"Updating media references, owner page = '%@', currentlyParsedPage '%@', text = %@...",
		 [[anElement page] titleText],
		 [page titleText],
		 [html substringToIndex:MIN([html length], 100)] ));
	
	// nil page?  It's probably because we got an update but we're not in the process of parsing a page.  In this case, though,
	// the element's owner page should be the correct page.
	if ( nil == page )
	{
		page = [anElement page];
	}
	
	// Still not found?
	if ( nil == page )
	{
		[context unlockPSCAndSelf];
		NSLog(@"error: transformMediaReferences's page (element container) is nil");
		return nil;
	}
	
	BOOL absoluteMediaPaths = [[self document] useAbsoluteMediaPaths];
	
	NSEnumerator *e = [aMediaPathsSet objectEnumerator];
	NSString *mediaPath;
	while ( mediaPath = [e nextObject] )
	{
		NSString *mediaPrefix = [@"/" stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]];
		if ( ![mediaPath hasPrefix:mediaPrefix] )
		{
			// we've found an IMG that isn't a _Media, skip it
			continue;
		}
		NSDictionary *mediaInfo = [self mediaInfoForMediaPath:mediaPath managedObjectContext:context];
		KTMedia *media = [mediaInfo valueForKey:@"media"];
		if ( nil != media )
		{
			// strip off ?ref= info, if present
			NSString *refInfo = nil;
			NSRange refRange = [mediaPath rangeOfString:@"?ref="];
			if ( refRange.location != NSNotFound )
			{
				refInfo = [mediaPath substringFromIndex:refRange.location];
			}
			
			NSString *imageName = [mediaInfo valueForKey:@"imageName"];
			if ( nil != imageName )
			{
				NSString *newPath
				= absoluteMediaPaths
				? [media publishedURLForImageName:imageName] 
				: [media mediaPathRelativeTo:page forFileName:[media fileNameForImageName:imageName] allowFile:NO];
				
				if ( (nil != refInfo) && (kGeneratingPreview == [[self document] publishingMode]) )
				{
					newPath = [newPath stringByAppendingString:refInfo];
				}
				
				OFF((@"transformMediaReferencesForMediaPaths(1) Replacing %@ with %@", mediaPath, newPath));
				
				// search for path with end-quote afterwards, so we don't re-replace existing ?ref=....
				NSString *target = [mediaPath stringByAppendingString:@"\""];
				NSString *replacement = [newPath stringByAppendingString:@"\""];
				
				// fix for 14762 (don't do anything destructive if either path is nil, just skip)
				if ((nil == target) || (nil == replacement)) break;

				[imgSrcTagHack replaceOccurrencesOfString:target
											   withString:replacement
												  options:NSLiteralSearch
													range:NSMakeRange(0,[imgSrcTagHack length])];
			}
			else
			{
				NSString *newPath
				= absoluteMediaPaths
				? [media publishedURL] 
				: [media mediaPathRelativeTo:page];
				
				if ( (nil != refInfo) && (kGeneratingPreview == [[self document] publishingMode]) )
				{
					newPath = [newPath stringByAppendingString:refInfo];
				}				

				OFF((@"transformMediaReferencesForMediaPaths(2) Replacing %@ with %@", mediaPath, newPath));
				
				NSString *target = mediaPath;
				NSString *replacement = newPath;
				
				// fix for 14762 (don't do anything destructive if either path is nil, just skip)
				if ((nil == target) || (nil == replacement)) break;
				
				[imgSrcTagHack replaceOccurrencesOfString:target
											   withString:replacement
												  options:NSLiteralSearch
													range:NSMakeRange(0,[imgSrcTagHack length])];
			}
		}
	}
	
	[context unlockPSCAndSelf];
	
	return imgSrcTagHack;
}

/*! returns SET of media paths by scanning anHTMLString
Scans for Media_/  and then backs up to beginning quote mark, and forward to previous quote mark

*/
- (NSSet *)mediaPathsWithinHTMLString:(NSString *)anHTMLString
{
	NSMutableSet *set = [NSMutableSet set];
	
	/// it's possible that we'll get passed a nil string, such as when clearing a summary out
	/// in that case, we just want to skip all of this and return an empty set
	if ( (nil != anHTMLString) && ([anHTMLString length] > 0) )
	{
	NSString *keyword = [NSString stringWithFormat:@"%@/", [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]];	//	_Media/
	
	NSScanner *scanner = [NSScanner scannerWithRealString:anHTMLString];
	while ( ![scanner isAtEnd] )
	{
		NSString *beforeKeyword = nil;	
		BOOL foundBeforeKeyword = [scanner scanUpToRealString:keyword intoString:&beforeKeyword];
		if (!foundBeforeKeyword)
		{
			break;
		}
		NSString *keywordFound = nil;
		BOOL foundKeyword = [scanner scanRealString:keyword intoString:&keywordFound];
		if (!foundKeyword)
		{
			break;
		}
		
		NSRange whereOpeningQuote = [beforeKeyword rangeOfString:@"\"" options:NSBackwardsSearch];
		if (NSNotFound != whereOpeningQuote.location)
		{
			NSString *betweenQuoteAndKeyword = [beforeKeyword substringFromIndex:NSMaxRange(whereOpeningQuote)];
			NSString *afterKeyword = nil;
			
			(void) [scanner scanUpToString:@"\"" intoString:&afterKeyword];
			NSString *token = [NSString stringWithFormat:@"%@%@%@", betweenQuoteAndKeyword, keywordFound, afterKeyword];
			if ( nil != token )
			{
				[set addObject:token];
			}
		}
	}
	}
	
	return [NSSet setWithSet:set];	
}

/*! returns array of names found in media paths ?ref=<name> */
- (NSArray *)namesOfMediaReferencesWithinHTMLString:(NSString *)anHTMLString
{
    NSMutableArray *array = [NSMutableArray array];
    
    // start by grabbing all the paths
    NSSet *paths = [self mediaPathsWithinHTMLString:anHTMLString];
    
    // extract the name of each media reference (they should all be unique!)
    // check for the location of ?ref= and take everything after that
    NSEnumerator *e = [paths objectEnumerator];
    NSString *path = nil;
    while ( path = [e nextObject] )
    {
        NSRange startOfRefRange = [path rangeOfString:@"?ref="];
        if ( startOfRefRange.location != NSNotFound )
        {
            unsigned int startOfNameIndex = startOfRefRange.location + startOfRefRange.length;
            NSString *name = [path substringFromIndex:startOfNameIndex];
            if ( [name length] > 0 )
            {
                [array addObject:name];
            }
        }
    }
    
    return [NSArray arrayWithArray:array];
}


/*! returns array of media references specified by aMediaPathsSet */
// NB: this should use a set not an array, they shouldn't be called refs, they're not
- (NSArray *)mediaReferencesForMediaPaths:(NSSet *)aMediaPathsSet element:(KTElement *)anElement
{
	NSMutableArray *array = [NSMutableArray array];
	
	NSEnumerator *e = [aMediaPathsSet objectEnumerator];
	NSString *mediaPath;
	while ( mediaPath = [e nextObject] )
	{
		NSDictionary *mediaInfo = [self mediaInfoForMediaPath:mediaPath managedObjectContext:(KTManagedObjectContext *)[anElement managedObjectContext]];
		KTMedia *media = [mediaInfo valueForKey:@"media"];
		if ( nil != media )
		{
			NSString *imageName = [mediaInfo valueForKey:@"imageName"];
			if ( nil != imageName )
			{
				id mediaRef = [media imageForImageName:imageName];
				if ( nil != mediaRef )
				{
					[array addObject:mediaRef];
				}
				else
				{
					NSLog(@"error: could not find image for imageName %@", imageName);
				}

			}
			else
			{
				[array addObject:media];
			}
		}
	}
	
	return [NSArray arrayWithArray:array];
}


- (NSString *)updateMediaReferencesWithinHTMLString:(NSString *)anHTMLString element:(KTElement *)anElement
{
	// make sure MediaManager is caching any/all references
	NSSet *toUpdate = [self mediaPathsWithinHTMLString:anHTMLString];
	NSArray *refs = [self mediaReferencesForMediaPaths:toUpdate element:anElement];
	NSEnumerator *e = [refs objectEnumerator];
	id mediaRef;
	while ( mediaRef = [e nextObject] )
	{
		[self cacheReference:mediaRef];
	}
	
	// fix up src paths to account for absolute publishing roots
	NSString *result = [self transformMediaReferencesForMediaPaths:toUpdate inHTMLString:anHTMLString element:anElement];
	
	return result;
}


#pragma mark support

- (void)cacheMedia:(KTMedia *)aMediaObject
{
	if ( YES ) return;
	if ( nil == [myMediaCache objectForKey:[aMediaObject uniqueID]] )
	{
		[myMediaCache setObject:aMediaObject forKey:[aMediaObject uniqueID]];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(objectDidBecomeActive:) 
													 name:kKTMediaObjectDidBecomeActiveNotification 
												   object:aMediaObject];
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(objectDidBecomeInactive:) 
													 name:kKTMediaObjectDidBecomeInactiveNotification 
												   object:aMediaObject];
	}
}

- (NSString *)uniqueNameWithName:(NSString *)aName managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	OBASSERTSTRING((nil != aName), @"uniqueNameWithName cannot use nil");
	
	NSString *uniqueName = aName;
	
	KTMedia *test = [self objectWithName:uniqueName managedObjectContext:aManagedObjectContext];
	int bump = 1;
	while ( nil != test )
	{
		++bump;
		NSString *testName = [uniqueName stringByAppendingString:[NSString stringWithFormat:@"-%@", [[NSNumber numberWithInt:bump] stringValue]]];
		test = [self objectWithName:testName managedObjectContext:aManagedObjectContext];
	}
	
	if ( bump > 1 )
	{
		uniqueName = [uniqueName stringByAppendingString:[NSString stringWithFormat:@"-%@", [[NSNumber numberWithInt:bump] stringValue]]];
	}
	
	return uniqueName;
}

/*! return a valid media:/ URL given aRelativePath ... unless we have a real file we can point to */
- (NSURL *)URLForMediaPath:(NSString *)aRelativePath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	NSURL *result = nil;
	
	NSDictionary *mediaInfo = [self mediaInfoForMediaPath:aRelativePath managedObjectContext:aManagedObjectContext];
	KTMedia *media = [mediaInfo valueForKey:@"media"];
	NSString *imageName = [mediaInfo valueForKey:@"imageName"];	// nil is okay (original, I think)

	NSString *dataFilePath = [media dataFilePath];
	if ( (nil != dataFilePath) && (nil == imageName) )
	{
		result = [NSURL fileURLWithPath:dataFilePath];
	}
	else
	{	
		result = [KTMediaURLProtocol URLForDocument:[self document]
                                            mediaID:[media uniqueID]
                                          imageName:imageName];
	}

	return result;
}

/*! return just the media object referenced by aRelativePath */
- (KTMedia *)objectForMediaPath:(NSString *)aRelativePath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	NSDictionary *mediaInfo = [self mediaInfoForMediaPath:aRelativePath 
									 managedObjectContext:aManagedObjectContext];
	KTMedia *result = [mediaInfo objectForKey:@"media"];
	return result;
}

/*! return the media object and imageName (if any) referenced by aRelativePath
	keys = media, imageName

	NOW THIS MAY JUST BE A MEDIA FILE NAME, NOT NECESSARILY A PATH
*/
- (NSDictionary *)mediaInfoForMediaPath:(NSString *)aRelativePath managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext
{
	// the idea here is that aRelativePath will be something like /_Media/<name>_<tag>.<extension><?ref=<track>>
	// and we need to find the media object and the imageName (if any) from the passed-in path
		
	if ( ![aRelativePath isKindOfClass:[NSString class]] )
	{
		NSLog(@"warning: mediaInfoForMediaPath: given nil path");
		return [NSDictionary dictionary];
	}
	
	NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
	
	// first, we just look at the lastPathComponent
	NSString *fileName = [aRelativePath lastPathComponent];
	
	// next, we take off any tracking reference
	NSRange trackRange = [fileName rangeOfString:@"?ref="];
	if ( NSNotFound != trackRange.location )
	{
		fileName = [fileName substringToIndex:trackRange.location];
	}
	
	// next, we take off the extension
	fileName = [fileName stringByDeletingPathExtension];
	
	KTMedia *media = nil;
	NSString *mediaName = nil;
	NSString *imageName = nil;
	
	// next, we go hunting backwards for a "_" character
	// if we find one, we try whatever is beyond it as a tag WE CANT DO THIS IF THE FIRST CHAR IS _ AND THATS THE LOCATION, OTHERWISE NAME IS NIL
	NSRange suffixRange = [fileName rangeOfString:@"_" options:NSBackwardsSearch];
	if ( (suffixRange.length > 0) && (suffixRange.location > 0) )
	{
		mediaName = [fileName substringToIndex:suffixRange.location];
		media = [self objectWithName:mediaName managedObjectContext:aManagedObjectContext];
		
		if ( nil != media )
		{
			NSString *possibleTag = [fileName substringFromIndex:(suffixRange.location+1)];
			imageName = [media imageNameForTag:possibleTag];	
		}
	}
	
	// didn't find one, try just the fileName, as-is
	if ( nil == media )
	{
		mediaName = fileName;
		media = [self objectWithName:mediaName managedObjectContext:aManagedObjectContext];
	}
		
	if ( nil == media )
	{
        // no media! substitute a broken image
		if ( nil != mediaName )
		{
			/// if we're pasting rtfd from another document, this is ok
			/// Sandvox will pick the media back up as "pastedGraphic"
			NSLog(@"warning: unable to locate media \"%@\", substituting ? icon", mediaName);
			NSLog(@"     (if pasting from another document, ignore this warning)");
		}
		NSManagedObjectID *mediaID = [self mediaNotFoundMediaObjectIDInManagedObjectContext:aManagedObjectContext];
		media = (KTMedia *)[aManagedObjectContext objectWithID:mediaID];
	}
	
	[dictionary setValue:media forKey:@"media"];
	if ( nil != imageName )
	{
		[dictionary setValue:imageName forKey:@"imageName"];
	}
		
	return [NSDictionary dictionaryWithDictionary:dictionary];
}

/*! return the MediaRef name for aRelativePath (?ref=), nil if there isn't one */
- (NSString *)refNameForMediaPath:(NSString *)aRelativePath
{
	// first, we just look at the lastPathComponent
	NSString *result = [aRelativePath lastPathComponent];
	
	// next, we take off any tracking reference
	NSRange trackRange = [result rangeOfString:@"?ref="];
	if ( NSNotFound != trackRange.location )
	{
		result = [result substringFromIndex:(trackRange.location+trackRange.length)];
	}
	else
	{
		result = nil;
	}
	
	//TJT((@"returning refName of %@ for path %@", result, aRelativePath));
	
	return result;
}

@end
