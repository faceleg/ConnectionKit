//
//  KTMediaRef.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/8/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTMediaRef.h"

#import "Debug.h"
#import "KTDocument.h"
#import "KTMedia.h"
#import "NSFetchRequest+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSPersistentStoreCoordinator+KTExtensions.h"

@implementation KTMediaRef

+ (NSSet *)reservedMediaRefNames
{
	static NSSet *sReservedMediaRefs;
	
	if (!sReservedMediaRefs)
	{
		sReservedMediaRefs = [[NSSet alloc] initWithObjects:@"thumbnail", @"headerImage", @"bannerImage", @"favicon", nil];
	}
	
	return sReservedMediaRefs;
}

/*! standard constructor, assumes that instance will be created in aMediaObject's context */
+ (KTMediaRef *)mediaRefWithMedia:(KTMedia *)aMediaObject
                             name:(NSString *)aName
                            owner:(KTAbstractPlugin *)anOwner
{
	NSParameterAssert(nil != aName);
	NSParameterAssert(nil != aMediaObject);
	
	KTManagedObjectContext *context = (KTManagedObjectContext *)[aMediaObject managedObjectContext];
	[context lockPSCAndSelf];
	
	KTMediaRef *result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaRef"
													   inManagedObjectContext:context];
	
	if ( nil != result )
	{
		// set attributes
        [result setValue:aName forKey:@"name"];
		
		// set relationships
		[result setValue:aMediaObject forKey:@"media"];
		
		if ( nil != anOwner )
		{
			[result setValue:anOwner forKey:@"owner"];
		}
		
		OFF((@"\"retaining\" %@ named %@", [result managedObjectDescription], aName));
		
		// we inserted a new MediaRef, we always need to save so changes propagate immediately
		[[result document] saveContext:context onlyIfNecessary:YES];
	}
	
	[context unlockPSCAndSelf];
	
	return result;
}

/*! constructor for reconstituting MediaRef from a dictionary (generally via the pasteboard) */
+ (KTMediaRef *)mediaRefWithArchiveDictionary:(NSDictionary *)aDictionary
										owner:(KTAbstractPlugin *)anOwner
{
	NSParameterAssert([anOwner isKindOfClass:[KTAbstractPlugin class]]);

    KTMediaRef *result = nil;
    
    if ( [aDictionary count] > 0 )
    {
		KTManagedObjectContext *context = (KTManagedObjectContext *)[anOwner managedObjectContext];
		[context lockPSCAndSelf];
		
        result = [NSEntityDescription insertNewObjectForEntityForName:@"MediaRef"
                                               inManagedObjectContext:context];
        if ( nil != result )
        {
            // set attributes
            [result setValue:[aDictionary valueForKey:@"name"] forKey:@"name"];
            
            // set relationships
            [result setValue:anOwner forKey:@"owner"];
            
            // find and set media
            KTMedia *media = [context objectMatchingMediaDigest:[aDictionary valueForKey:@"mediaDigest"]
												thumbnailDigest:[aDictionary valueForKey:@"thumbnailDigest"]];
			if ( nil != media )
			{
				[result setValue:media forKey:@"media"];
				// we inserted a new MediaRef, we always need to save so changes propagate immediately
				[[result document] saveContext:context onlyIfNecessary:YES];				
			}
			else
			{
				NSLog(@"error: reconstituted mediaRef (%@) could not locate matching media in context", [result valueForKey:@"name"]);
				[context deleteObject:result];
				result = nil;
			}
        }
		
		[context unlockPSCAndSelf];
    }
	
	return result;	
}

/*! "retain" media by creating a new KTMediaRef in aMediaObject's context */
+ (KTMediaRef *)retainMedia:(KTMedia *)aMediaObject
                       name:(NSString *)aName
					  owner:(KTAbstractPlugin *)anOwner
{
    NSParameterAssert(nil != aMediaObject);
    NSParameterAssert(nil != aName);
    NSParameterAssert(nil != anOwner);
	    
    if ( nil != [anOwner mediaRefNamed:aName] )
	{
		NSLog(@"warning: retainMedia::: name:%@ already exists, should release first", aName);
		
		// release any of the "reserved" previous MediaRef(s) with same aName and anOwner
		if ([[[self class] reservedMediaRefNames] containsObject:aName] &&
			[[NSUserDefaults standardUserDefaults] boolForKey:@"RemoveDuplicateReservedMediaRefs"])
		{
	//		while ([anOwner mediaRefNamed:aName])
	//		{
	//			//[KTMediaRef releaseMediaRef:[anOwner mediaRefNamed:aName]];
	//		}
			/// Mike: I was going to use the above, commented out, code but it is too slow. Instead do this:
			
			[anOwner lockPSCAndMOC];
			NSArray *mediaRefs = [anOwner mediaRefsNamed:aName];
			NSEnumerator *mediaRefEnumerator = [mediaRefs objectEnumerator];
			KTMediaRef *aMediaRef;
			while (aMediaRef = [mediaRefEnumerator nextObject])
			{
				[[anOwner managedObjectContext] deleteObject:aMediaRef];
			}
			[[anOwner document] saveContext:(KTManagedObjectContext *)[anOwner managedObjectContext] onlyIfNecessary:YES];
			[anOwner unlockPSCAndMOC];
		}
	}
	
	OFF((@"retainMedia: %@ name: %@ owner: %@", [aMediaObject managedObjectDescription], aName, [anOwner managedObjectDescription]));
	KTMediaRef *result = [KTMediaRef mediaRefWithMedia:aMediaObject name:aName owner:anOwner];
		
    return result;
}

/*! "release" media by deleting KTMediaRef that corresponds to parameters */
+ (BOOL)releaseMedia:(KTMedia *)aMediaObject
                name:(NSString *)aName
			   owner:(KTAbstractPlugin *)anOwner
{
    NSParameterAssert(nil != aMediaObject);
    NSParameterAssert(nil != anOwner);
	
	KTMediaRef *mediaRef = [KTMediaRef objectMatchingMedia:aMediaObject
                                                      name:aName
													 owner:anOwner];
	if ( nil != mediaRef  )
	{
		OFF((@"releaseMedia: %@ name: %@ owner: %@", [aMediaObject managedObjectDescription], aName, [anOwner managedObjectDescription]));
		[self releaseMediaRef:mediaRef];
		return YES;
	}
	else
	{
		NSLog(@"error: asked to release MediaRef named %@ but none was found in context!", aName);
	}
	
	return NO;
}

/*! "release" media by simply deleting the media ref */
+ (void)releaseMediaRef:(KTMediaRef *)aMediaRef
{
	if ( nil != aMediaRef )
	{
		// since mediaRef's delete rule for both owner and media is nullify,
		// removing the underlying relationships should automatically be handled 
		// by the context and the rules in its model
		KTManagedObjectContext *context = (KTManagedObjectContext *)[aMediaRef managedObjectContext];
		[context lockPSCAndSelf];
		
		KTDocument *document = [aMediaRef document];
		KTAbstractPlugin *owner = [aMediaRef valueForKey:@"owner"];
		KTMedia *media = [aMediaRef valueForKey:@"media"];
		
		OFF((@"releaseMediaRef: %@ name: %@ media: %@ owner: %@", [aMediaRef managedObjectDescription], [aMediaRef valueForKey:@"name"], [media managedObjectDescription], [owner managedObjectDescription]));

		NSMutableSet *mediaMediaRefs = [media mutableSetValueForKey:@"mediaRefs"];
		[mediaMediaRefs removeObject:aMediaRef];
		
		NSMutableSet *ownerMediaRefs = [owner mutableSetValueForKey:@"mediaRefs"];
		[ownerMediaRefs removeObject:aMediaRef];
		
		[context deleteObject:aMediaRef];
		
		// save after deleting object so changes are propagated
		[document saveContext:context onlyIfNecessary:YES];

		[context unlockPSCAndSelf];
	}
}

+ (KTMediaRef *)objectMatchingMedia:(KTMedia *)aMediaObject
                               name:(NSString *)aName
							  owner:(KTAbstractPlugin *)anOwner
{
	NSParameterAssert(nil != aName);
	NSParameterAssert(nil != aMediaObject);
	NSParameterAssert(nil != anOwner);
	
	KTMediaRef *result = nil;
	
	// construct a predicate, querying on parameters
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(media == %@) && (name == %@) && (owner == %@)", aMediaObject, aName, anOwner];
	
	// perform the query
	NSManagedObjectContext *context = [aMediaObject managedObjectContext];
	NSError *localError = nil;
	NSArray *fetchedObjects = [context objectsWithEntityName:@"MediaRef"
												   predicate:predicate
													   error:&localError];	
	// extract the result
	if ( (nil != fetchedObjects) && ([fetchedObjects count] == 1) )
	{
		result = [fetchedObjects objectAtIndex:0];
	}
		
	return result;
}

/*! returns media's document */
- (KTDocument *)document
{
	return [[self media] document];
}

- (KTMedia *)media
{
	return [self wrappedValueForKey:@"media"];
}

- (NSString *)name 
{
	return [self wrappedValueForKey:@"name"];
}

// any message we don't understand, we forward on to our corresponding media object
- (void)forwardInvocation:(NSInvocation *)invocation
{
    SEL aSelector = [invocation selector];
	
	[self lockPSCAndMOC];
	KTMedia *media = [self media];
	[self unlockPSCAndMOC];
	
    if ( [media respondsToSelector:aSelector] )
	{
		OFF((@"%@ forwarding %@ to %@", [self managedObjectDescription], NSStringFromSelector(aSelector), [media managedObjectDescription]));
        [invocation invokeWithTarget:media];
	}
    else
	{
        [self doesNotRecognizeSelector:aSelector];
	}
}

// any key we don't understand, we see if media can figure it out
- (id)valueForUndefinedKey:(NSString *)aKey
{
	// locking here ultimately deadlocks in imageForImageName:
	KTMedia *media = [self media]; // is threadsafe
#if 0
	NSString *mediaName = [media name];
	NSString *refName = [self valueForKey:@"name"];
	NSLog(@"mediaRef %@ asking media %@ valueForKey: %@", refName, mediaName, aKey);
#endif
	[self lockPSCAndMOC];
	id result = [media valueForKey:aKey];
	[self unlockPSCAndMOC];
	return result;
}

/// we now implement -publishedURL here, so that we can find
/// our owner, and its delegate, and get the appropriateScaledImage

// Used for RSS feed; we need the URL where the image is found
- (NSString *)publishedURL
{
	NSString *result = nil;
	
	KTMedia *media = [self media];
	if ( [media isImage] )
	{
		// ask the owner's delegate what size is required
		KTAbstractPlugin *owner = [self valueForKey:@"owner"];
		id delegate = [owner delegate];
		if ( [delegate respondsToSelector:@selector(appropriateScaledImage)] )
		{
			KTCachedImage *cachedImage = [delegate appropriateScaledImage];
			result = [cachedImage publishedURL];
		}
	}
	
	if ( nil == result )
	{
		// return URL to "original" media
		result = [media publishedURL];
	}
	
	return result;
}

- (NSString *)enclosureURL
{
	NSString *result = nil;
	
	KTMedia *media = [self media];
	if ( [media isImage] )
	{
		KTCachedImage *cachedImage = nil;
		
		if ( ![[NSUserDefaults standardUserDefaults] boolForKey:@"RSSFeedEnclosuresAreOriginalImages"] )
		{
			// ask the owner's delegate what size is required
			KTAbstractPlugin *owner = [self valueForKey:@"owner"];
			id delegate = [owner delegate];
			if ( [delegate respondsToSelector:@selector(appropriateScaledImage)] )
			{
				cachedImage = [delegate appropriateScaledImage];
			}
		}
		else
		{
			cachedImage = [media originalAsImage];
		}
		
		result = [cachedImage publishedURL];
	}
	else 
	{
		result = [media publishedURL];
	}

	OBASSERT(nil != result);
	return result;
}

- (int)enclosureDataLength;
{
	int result = -1;
	
	KTMedia *media = [self media];
	if ( [media isImage] )
	{
		KTCachedImage *cachedImage = nil;
		
		if ( ![[NSUserDefaults standardUserDefaults] boolForKey:@"RSSFeedEnclosuresAreOriginalImages"] )
		{
			// ask the owner's delegate what size is required
			KTAbstractPlugin *owner = [self valueForKey:@"owner"];
			id delegate = [owner delegate];
			if ( [delegate respondsToSelector:@selector(appropriateScaledImage)] )
			{
				cachedImage = [delegate appropriateScaledImage];
			}
		}
		else
		{
			cachedImage = [media originalAsImage];
		}
		
		result = [[cachedImage cacheSize] intValue];
		if ( 0 == result )
		{
			result = [[cachedImage data] length];
		}
	}
	else 
	{
		result = [media dataLength];
	}	
	
	OBASSERT(result != -1);
	return result;
}

- (NSString *)enclosureMIMEType
{
	NSString *result = nil;
	
	KTMedia *media = [self media];
	if ( [media isImage] )
	{
		KTCachedImage *cachedImage = nil;
		
		if ( ![[NSUserDefaults standardUserDefaults] boolForKey:@"RSSFeedEnclosuresAreOriginalImages"] )
		{
			// ask the owner's delegate what size is required
			KTAbstractPlugin *owner = [self valueForKey:@"owner"];
			id delegate = [owner delegate];
			if ( [delegate respondsToSelector:@selector(appropriateScaledImage)] )
			{
				cachedImage = [delegate appropriateScaledImage];
			}
		}
		else
		{
			cachedImage = [media originalAsImage];
		}
		
		result = [cachedImage formatUTI];
		if ( nil == result )
		{
			NSLog(@"error: unable to determine MIMEType: no UTI for object %@", [cachedImage managedObjectDescription]);
			result = @"";
		}		
	}
	else
	{
		result = [media mediaUTI];
	}
	
	OBASSERT(result != nil);
	return result;
}

/// we now implemenet -mediaPathRelativeTo: here, as well as in media,
/// so that we can notice if a scaled image is being substituted
/// and return the correct relative path
///
/// this is to implement [[mediapath item.enclosure]] for Dan

- (NSString *)mediaPathRelativeTo:(KTPage *)aPage
{
	NSString *result = nil;
	
	KTMedia *media = [self media];
	if ( [media isImage] )
	{
		// ask the owner's delegate what size is required
		KTAbstractPlugin *owner = [self valueForKey:@"owner"];
		id delegate = [owner delegate];
		if ( [delegate respondsToSelector:@selector(appropriateScaledImage)] )
		{
			KTCachedImage *cachedImage = [delegate appropriateScaledImage];
			result = [cachedImage mediaPathRelativeTo:aPage];
		}
	}
	
	if ( nil == result )
	{
		result = [media mediaPathRelativeTo:aPage];
	}
	
	return result;
}

- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage
{
	NSString *result = nil;
	
	KTMedia *media = [self media];
	if ( [media isImage] )
	{
		KTCachedImage *cachedImage = nil;
		
		if ( ![[NSUserDefaults standardUserDefaults] boolForKey:@"RSSFeedEnclosuresAreOriginalImages"] )
		{
			// ask the owner's delegate what size is required
			KTAbstractPlugin *owner = [self valueForKey:@"owner"];
			id delegate = [owner delegate];
			if ( [delegate respondsToSelector:@selector(appropriateScaledImage)] )
			{
				cachedImage = [delegate appropriateScaledImage];
			}
		}
		else
		{
			cachedImage = [media originalAsImage];
		}
		
		result = [cachedImage mediaPathRelativeTo:aPage];
	}
	else 
	{
		result = [media mediaPathRelativeTo:aPage];
	}
	
	OBASSERT(nil != result);
	return result;
}

#pragma mark copying

- (NSDictionary *)archiveDictionary
{
	// a MediaRef should be archivable on its attributes alone
    // its media and owner need to exist in the new context, before
    // unarchiving, be discovered, and the relationships reestablished
	
	NSMutableDictionary *rep = [NSMutableDictionary dictionary];
    [rep setValue:[self valueForKey:@"name"] forKey:@"name"];
    
    // we add mediaDigest and thumbnailDigest to the archive dictionary
    // from the underlying media object so that we can find it again
    // when this media ref is unarchived
    NSString *mediaDigest = [self valueForKeyPath:@"media.mediaDigest"];
    NSString *thumbnailDigest = [self valueForKeyPath:@"media.thumbnailDigest"];
    [rep setValue:mediaDigest forKey:@"mediaDigest"];
    if ( nil != thumbnailDigest )
    {
        [rep setValue:thumbnailDigest forKey:@"thumbnailDigest"];
    }
	
	return [NSDictionary dictionaryWithDictionary:rep];
}

- (KTManagedObject *)copyToContext:(KTManagedObjectContext *)aContext
{
	[self lockPSCAndMOC];
	[aContext lockPSCAndSelf];
	
    // find our entity name
    NSString *entityName = [[self entity] name];
    
	// create a copy of this object in aContext
	KTMediaRef *newMediaRef = [NSEntityDescription insertNewObjectForEntityForName:entityName
															inManagedObjectContext:aContext];
		
	// copy attributes
	[newMediaRef copyAttributesFromObject:self];
	
	// copy owner	
	KTAbstractPlugin *owner = [self valueForKey:@"owner"];
	NSAssert((nil != owner), @"owner cannot be nil!");
	[newMediaRef copyToOneRelationshipForKey:@"owner" fromObject:self useExisting:YES];
	
	// locate media in aContext and connect relationship
	KTMedia *media = [self media];
	NSAssert((nil != media), @"media cannot be nil!");
	
	KTMedia *mediaInOtherContext = (KTMedia *)[media similarObjectInContext:aContext];
	NSAssert((nil != mediaInOtherContext), @"mediaInOtherContext cannot be nil!");
	[newMediaRef setValue:mediaInOtherContext forKey:@"media"];
	
	// save and refresh context(s)
	KTDocument *document = [newMediaRef document];
	[document saveContext:(KTManagedObjectContext *)aContext onlyIfNecessary:YES];
	
	[aContext unlockPSCAndSelf];
	[self unlockPSCAndMOC];
		
	return newMediaRef;
}
	
//- (NSPredicate *)predicateForSimilarObject 
//{
//	if ( nil != [self valueForKey:@"thumbnailDigest"] )
//	{
//		return [NSPredicate predicateWithFormat:@"(name like %@) && (mediaDigest like %@) && (thumbnailDigest like %@)", [self valueForKey:@"name"], [self valueForKey:@"mediaDigest"], [self valueForKey:@"thumbnailDigest"]];
//	}
//	else
//	{
//		return [NSPredicate predicateWithFormat:@"(name like %@) && (mediaDigest like %@)", [self valueForKey:@"name"], [self valueForKey:@"mediaDigest"]];
//	}
//}

@end
