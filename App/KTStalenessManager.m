//
//  KTStalenessManager.m
//  Marvel
//
//  Created by Mike on 28/11/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//


/*	We maintain 2 separate lists of pages:
 *
 *		Pages which are already -isStale only have their staleness attribute monitored.
 *		This is the -observedStalePages list.
 *		
 *		All other pages are parsed and have all their keyPaths observed. This is the -observedPages list.
 *
 *	A public API is presented for the overall list of pages. The two separate lists are only exposed internally.
 */
 
/*	There is a rather interesting case that needs to be handled by the staleness manager. Consider a site with a number of pages,
 *	each dependent upon the key "titleHTML" of a particular page. So, the natural behavior would be to observer this key once
 *	for each dependent page and to set the KVO context to be the page the keypath originates from. However, when you then remove
 *	an observer, there is no control over which observer is removed; thereby messing up the KVO contexts.
 *	The solution: ignore context.
 */

#import "KTStalenessManager.h"

#import "KTAbstractPage.h"
#import "KTPage.h"
#import "KTParsedKeyPath.h"
#import "KTStalenessHTMLParser.h"
#import "KTWebViewTextBlock.h"

#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"


@interface KTStalenessManager ()
- (NSMutableDictionary *)nonStalePages;
- (void)addNonStalePage:(KTAbstractPage *)page;
- (void)removeNonStalePage:(KTAbstractPage *)page;

@end


#pragma mark -


@implementation KTStalenessManager

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithDocument:(KTDocument *)document
{
	[super init];
	
	myDocument = document;	// Weak ref
	myObservedPages = [[NSMutableSet alloc] init];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(documentWillClose:)
												 name:KTDocumentWillCloseNotification
											   object:document];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(mocDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:[document managedObjectContext]];
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self stopObservingAllPages];
	[myNonStalePages release];
	
	[myObservedPages release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Public API

- (KTDocument *)document { return myDocument; }

- (void)beginObservingPage:(KTAbstractPage *)page
{
	OBPRECONDITION(page);
    
    // We observe the staleness of all pages
	if (![myObservedPages containsObject:page])
	{
		[page addObserver:self forKeyPath:@"isStale" options:0 context:NULL];
		[myObservedPages addObject:page];
	}
	
	// Parse and observe component keypaths if non-stale
	if (![page boolForKey:@"isStale"])
	{
		[self addNonStalePage:page];
	}
}

/*	Runs through every page in the document
 *	If the page is not already stale, we parse it to get a list of keypaths and begin
 *	observing them.
 */
- (void)beginObservingAllPages
{
	NSArray *pages = [[[self document] managedObjectContext] allObjectsWithEntityName:@"AbstractPage"
																				error:NULL];
	
	// Little trick to make sure the dictionary is a decent size to start with
	if (!myNonStalePages) {
		myNonStalePages = [[NSMutableDictionary alloc] initWithCapacity:[pages count]];
	}
	
	NSEnumerator *pagesEnumerator = [pages objectEnumerator];
	KTAbstractPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]; // Autorelease pool is needed for large sites
        [self beginObservingPage:aPage];
        [pool release];
	}
}

- (void)stopObservingPage:(KTAbstractPage *)page
{
	[self removeNonStalePage:page];
	
	[page removeObserver:self forKeyPath:@"isStale"];
	[myObservedPages removeObject:page];
}

- (void)stopObservingAllPages
{
	NSEnumerator *pagesEnumerator = [[NSSet setWithSet:myObservedPages] objectEnumerator];
	KTAbstractPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		[self stopObservingPage:aPage];
	}
}

#pragma mark -
#pragma mark Not Stale Pages

- (NSMutableDictionary *)nonStalePages
{
	if (!myNonStalePages)
	{
		myNonStalePages = [[NSMutableDictionary alloc] initWithCapacity:1];
	}
	
	return myNonStalePages;
}

- (NSMutableSet *)observedKeyPathsOfNonStalePage:(KTAbstractPage *)page
{
	NSMutableSet *result = [[self nonStalePages] objectForKey:page];
	
	if (!result)
	{
		result = [[NSMutableSet alloc] initWithCapacity:1];
		CFDictionarySetValue((CFMutableDictionaryRef)[self nonStalePages], page, result);
		[result release];
	}
	
	return result;
}

- (NSSet *)nonStalePagesDependentUponKeyPath:(NSString *)keyPath ofObject:(NSObject *)object
{
	// Run through all non-stale pages to see if they are dependent upon the key
	KTParsedKeyPath *parsedKeyPath = [[KTParsedKeyPath alloc] initWithKeyPath:keyPath ofObject:object];
	NSMutableSet *buffer = [[NSMutableSet alloc] init];
	
	NSEnumerator *pagesEnumerator = [[self nonStalePages] keyEnumerator];
	KTPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		NSSet *pageKeyPaths = [self observedKeyPathsOfNonStalePage:aPage];
		if ([pageKeyPaths containsObject:parsedKeyPath])
		{
			[buffer addObject:aPage];
		}
	}
	
	
	// Tidy up
	[parsedKeyPath release];
	
	NSSet *result = [[buffer copy] autorelease];
	[buffer release];
	return result;
}

- (void)addNonStalePage:(KTAbstractPage *)page
{
	// Only begin observing the page if we're not already doing so
	if (![[self nonStalePages] objectForKey:page])
	{
		// Parse the page as quickly as possible. The parser delegate (us) will pick up observation info.
		KTHTMLParser *parser = [[KTStalenessHTMLParser alloc] initWithPage:page];
		[parser setDelegate:self];
		[parser setHTMLGenerationPurpose:kGeneratingRemote];
		
		[parser parseTemplate];
		
		[parser release];
	}
}

- (void)beginObservingKeyPath:(NSString *)keyPath ofObject:(id)object onNonStalePage:(KTAbstractPage *)page;
{
	KTParsedKeyPath *parsedKeyPath = [[KTParsedKeyPath alloc] initWithKeyPath:keyPath ofObject:object];
	OBASSERT(parsedKeyPath);
    
    NSMutableSet *observedKeyPaths = [self observedKeyPathsOfNonStalePage:page];
	unsigned oldCount = [observedKeyPaths count];
    [observedKeyPaths addObject:parsedKeyPath];
    
    if ([observedKeyPaths count] != oldCount)   // Rather than doing -containsObject: followed by -addObject:, we compare
    {                                           // the counts for performance.
		[object addObserver:self forKeyPath:keyPath options:0 context:NULL];
	}
	
	[parsedKeyPath release];
}

- (void)removeNonStalePage:(KTAbstractPage *)page
{
	// Ignore pages without an ID. I think we don't have to do this now that pages, not IDs,  are used as keys - Mike.
	/*
	if (![page uniqueID]) {
		return;
	}*/
	
	
	NSSet *observedKeyPaths = [self observedKeyPathsOfNonStalePage:page];
	NSEnumerator *keypathsEnumerator = [observedKeyPaths objectEnumerator];
	KTParsedKeyPath *keyPath;
	
	while (keyPath = [keypathsEnumerator nextObject])
	{
		[[keyPath parsedObject] removeObserver:self forKeyPath:[keyPath keyPath]];
	}
	
	[[self nonStalePages] removeObjectForKey:page];
}

#pragma mark -
#pragma mark Parser Delegate

- (void)parser:(KTHTMLParser *)parser didEncounterKeyPath:(NSString *)keyPath ofObject:(id)object
{
	[self beginObservingKeyPath:keyPath ofObject:object onNonStalePage:[parser currentPage]];
}

- (void)HTMLParser:(KTHTMLParser *)parser didParseTextBlock:(KTWebViewTextBlock *)textBlock
{
    [self beginObservingKeyPath:[textBlock HTMLSourceKeyPath]
                       ofObject:[textBlock HTMLSourceObject]
                 onNonStalePage:[parser currentPage]];
}

#pragma mark -
#pragma mark Support

/*	Whenever pages are inserted or deleted 
 */
- (void)mocDidChange:(NSNotification *)notification
{
	NSSet *insertedObjects = [[notification userInfo] objectForKey:NSInsertedObjectsKey];
	NSEnumerator *enumerator = [insertedObjects objectEnumerator];
	NSManagedObject *aManagedObject;
	while (aManagedObject = [enumerator nextObject])
	{
		if ([aManagedObject isKindOfClass:[KTAbstractPage class]])
		{
			[self beginObservingPage:(KTAbstractPage *)aManagedObject];
		}
	}
	
	NSSet *deletedObjects = [[notification userInfo] objectForKey:NSDeletedObjectsKey];
	enumerator = [deletedObjects objectEnumerator];
	while (aManagedObject = [enumerator nextObject])
	{
		if ([aManagedObject isKindOfClass:[KTAbstractPage class]])
		{
			[self stopObservingPage:(KTAbstractPage *)aManagedObject];
		}
	}
}

/*	This ensures we don't accidentally keep observing the document after it's been dealloced
 */
- (void)documentWillClose:(NSNotification *)notification
{
	[self stopObservingAllPages];
}

/*	Somewhere a keypath affecting one or more of our pages changed.
 */
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	// Ignore notifications in the background
	if (![NSThread isMainThread]) {
		return;
	}
	
	
	// The pages have changed in some way. Mark them stale and move to the stale list.
	NSSet *affectedPages = [self nonStalePagesDependentUponKeyPath:keyPath ofObject:object];
	[affectedPages setBool:YES forKey:@"isStale"];
	
	
	// When page staleness changes, begin or stop observing it as appropriate
	if ([keyPath isEqualToString:@"isStale"] && [object isKindOfClass:[KTAbstractPage class]])
	{
		KTAbstractPage *page = (KTAbstractPage *)object;
		if ([page boolForKey:@"isStale"])	// The delay ensures the rest of the system has caught up first. Otherwise we get
		{									// strange KVO exceptions or the page immediately being set stale again.
			[self performSelector:@selector(removeNonStalePage:) withObject:page afterDelay:0.0];
		}
		else
		{
			[self performSelector:@selector(addNonStalePage:) withObject:page afterDelay:0.0];
		}
	}
}

@end
