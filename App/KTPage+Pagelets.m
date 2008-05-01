//
//  KTPage+Pagelets.m
//  KTComponents
//
//  Created by Mike on 26/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "Debug.h"

#import "KTDocument.h"
#import "KTElementPlugin.h"

#import "NSMutableArray+Karelia.h"
#import "NSSortDescriptor+Karelia.h"


@interface KTPage (PageletsPrivate)

- (NSArray *)allInheritableTopSidebars;
- (NSArray *)allInheritableBottomSidebars;

- (NSArray *)_allSidebarPagelets;

@end


#pragma mark -


@implementation KTPage (Pagelets)

+ (void)initialize_pagelets
{
	[self setKeys:[NSArray arrayWithObjects:@"topSidebarPagelets", @"bottomSidebarPagelets", nil]
		triggerChangeNotificationsForDependentKey:@"sidebarPagelets"];
}

#pragma mark -
#pragma mark Raw accessors

- (BOOL)includeSidebar
{
	BOOL result = [self wrappedBoolForKey:@"includeSidebar"];		// not an optional property, so it's OK to convert to a non-object
	return result;
}

- (void)setIncludeSidebar:(BOOL)flag
{
	[self setWrappedBool:flag forKey:@"includeSidebar"];
	
	// Our -allSidebars list has changed since we have presumably inherited some pagelets
	[self invalidateAllSidebarPageletsCache:YES recursive:YES];
}

/*!	Returns a constant of whether this page template can do callouts.  Contrast to includeSidebar,
	which is a property.
*/
- (BOOL)includeCallout
{
	BOOL result = [[[self plugin] pluginPropertyForKey:@"KTPageAllowsCallouts"] boolValue];
	return result;
}

/*	Whether this page template can show or hide the sidebar is there or not. Normally static, but some plugins
 *	dynamically change it.
 */
- (BOOL)sidebarChangeable { return [self wrappedBoolForKey:@"sidebarChangeable"]; }

- (void)setSidebarChangeable:(BOOL)flag { [self setWrappedBool:flag forKey:@"sidebarChangeable"]; }

- (NSSet *)pagelets { return [self wrappedValueForKey:@"pagelets"]; }

#pragma mark -
#pragma mark Ordered accessors

/*	Fetches all pagelets in the specified KTPageletLocation, correctly ordered.
 *	Even works for KTSidebarPageletLocation!
 */
- (NSArray *)pageletsInLocation:(KTPageletLocation)location
{
	NSArray *result = nil;
	
	switch (location)
	{
		case KTCalloutPageletLocation:
			result = [self callouts];
			break;
		case KTSidebarPageletLocation:
			result = [self sidebarPagelets];
			break;
		case KTTopSidebarPageletLocation:
			result = [self topSidebarPagelets];
			break;
		case KTBottomSidebarPageletLocation:
			result = [self bottomSidebarPagelets];
			break;
	}
	
	OBPOSTCONDITION(result);
	return result;
}

/*	Inserts the pagelet in the appropriate location based on its properties -prefersBottom and -location
 *	Do not attempt to insert a pagelet for the second time as it cannot be in two places at once!
 *	Instead use the -setPrefersBottom and -setLocation methods to reposition a pagelet.
 */
- (void)insertPagelet:(KTPagelet *)pagelet atIndex:(unsigned)index
{
	// A set cannot contain the same object twice. Trying to insert a pagelet for a second time
	// would screw up the ordering keys.
	OBASSERTSTRING(![[self pagelets] containsObject:pagelet], @"Attempting to insert a pagelet twice");
	
	
	// Get the array of pagelets BEFORE the new one is added to it
	KTPageletLocation location = [pagelet locationByDifferentiatingTopAndBottomSidebars];
	NSArray *existingPagelets = [self pageletsInLocation:location];
	
	
	// Add the pagelet to our set
	[self lockPSCAndMOC];
	[pagelet setValue:self forKey:@"page"];
	[self unlockPSCAndMOC];
	
	
	// Insert the pagelet into the array and update the ordering of all pagelets
	NSMutableArray *pagelets = [[NSMutableArray alloc] initWithArray:existingPagelets];
	[pagelets insertObject:pagelet atIndex:index];
	[KTPage updatePageletOrderingsFromArray:pagelets];
	[pagelets release];
	
	
	// And finally cached pagelet lists must have been affected
	[self invalidateSimplePageletCaches];
	if ([pagelet location] == KTSidebarPageletLocation)
	{
		[self invalidateAllSidebarPageletsCache:YES recursive:[pagelet shouldPropagate]];
	}
}

/*	A nice shortcut to doing -insertPagelet:atIndex: at the end of the array.
 */
- (void)addPagelet:(KTPagelet *)pagelet
{
	KTPageletLocation location = [pagelet locationByDifferentiatingTopAndBottomSidebars];
	unsigned index = [[self pageletsInLocation:location] count];
	[self insertPagelet:pagelet atIndex:index];
}

/* Contextual menu item actions to move pagelets between locations.
 */
- (void)movePageletToCallouts:(id)sender
{
	KTPagelet *pagelet = [sender representedObject];
	[pagelet setLocation:KTCalloutPageletLocation];
}

- (void)movePageletToSidebar:(id)sender
{
	KTPagelet *pagelet = [sender representedObject];
	[pagelet setLocation:KTSidebarPageletLocation];
}

#pragma mark -
#pragma mark Non-Inherited Pagelets

- (NSArray *)callouts { return [self wrappedValueForKey:NSStringFromSelector(_cmd)]; }

- (NSArray *)topSidebarPagelets { return [self wrappedValueForKey:NSStringFromSelector(_cmd)]; }

- (NSArray *)bottomSidebarPagelets { return [self wrappedValueForKey:NSStringFromSelector(_cmd)]; }

- (NSArray *)sidebarPagelets
{
	NSArray *result = [[self topSidebarPagelets] arrayByAddingObjectsFromArray:[self bottomSidebarPagelets]];
	return result;
}

- (void)invalidateSimplePageletCaches
{
	[[self managedObjectContext] refreshObject:self mergeChanges:YES];
}

#pragma mark inheritable

/*	The following 2 methods use their counterparts above but also filter out any non-propogating pagelets
*	IMPORTANT: These methods are NOT KVO-compliant.
 */

- (NSArray *)inheritableTopSidebarPagelets
{
	// Build the predicate
	static NSPredicate *sPredicate;
	if (!sPredicate)
	{
		sPredicate = [[NSPredicate predicateWithFormat:@"shouldPropagate == 1",
					  KTSidebarPageletLocation] retain];
	}
	
	// Filter usual result
	NSArray *result = [[self topSidebarPagelets] filteredArrayUsingPredicate:sPredicate];
	return result;
}

- (NSArray *)inheritableBottomSidebarPagelets
{
	// Build the predicate
	static NSPredicate *sPredicate;
	if (!sPredicate)
	{
		sPredicate = [[NSPredicate predicateWithFormat:@"shouldPropagate == 1",
					   KTSidebarPageletLocation] retain];
	}
	
	// Filter usual result
	NSArray *result = [[self bottomSidebarPagelets] filteredArrayUsingPredicate:sPredicate];
	return result;
}

#pragma mark -
#pragma mark All Sidebar Pagelets
					   
/*	All the sidebar pagelets that should appear on the page, including those inherited from our parent as appropriate.
 *	This is the culmination of all the other methods and is used to generate the HTML.
 */
- (NSArray *)allSidebarPagelets
{
	if (!myAllSidebarPageletsCache)
	{
		myAllSidebarPageletsCache = [[self _allSidebarPagelets] copy];
	}
	
	return myAllSidebarPageletsCache;
}	

/*	Uncached version of the above.
 */
- (NSArray *)_allSidebarPagelets
{
	BOOL includePageletsFromParent = ([self boolForKey:@"includeInheritedSidebar"] && ![self isRoot]);
	
	// Gather the 3 groups of pagelets into one single array
	NSMutableArray *result = [NSMutableArray array];
	
	if (includePageletsFromParent) {
		[result addObjectsFromArray:[[self parent] allInheritableTopSidebars]];
	}
	
	[result addObjectsFromArray:[self sidebarPagelets]];
	
	if (includePageletsFromParent) {
		[result addObjectsFromArray:[[self parent] allInheritableBottomSidebars]];
	}
	
	return result;
}

/*	Very simple method to invalidate our cache. Does pretty much as it says on the tin
 *	If you pass NO for invalidateCache, but YES for recursive then the receiver won't be affected, but children will.
 */
- (void)invalidateAllSidebarPageletsCache:(BOOL)invalidateCache recursive:(BOOL)recursive;
{
	if (invalidateCache)
	{
		[self willChangeValueForKey:@"allSidebarPagelets"];
		[myAllSidebarPageletsCache release];	myAllSidebarPageletsCache = nil;
		[self didChangeValueForKey:@"allSidebarPagelets"];
	}
	
	if (recursive)
	{
		NSEnumerator *childrenEnumerator = [[self children] objectEnumerator];
		KTPage *aPage;
		while (aPage = [childrenEnumerator nextObject])
		{
			[aPage invalidateAllSidebarPageletsCache:YES recursive:YES];
		}
	}
}

#pragma mark support

/*	Our inheritable sidebar pagelets plus any inherited from our parent.
 *	IMPORTANT: These 2 methods are NOT KVO-compliant.
 */
- (NSArray *)allInheritableTopSidebars
{
	NSMutableArray *array = [[NSMutableArray alloc] init];
	
	if (![self isRoot] && [self boolForKey:@"includeInheritedSidebar"]) {
		[array fastAddObjectsFromArray:[[self parent] allInheritableTopSidebars]];	// recurse
	}
	
	[array fastAddObjectsFromArray:[self inheritableTopSidebarPagelets]];	// add my own sidebars that can be inherited
	
	// Tidy up
	NSArray *result = [NSArray arrayWithArray:array];
	[array release];
	
	return result;
}

- (NSArray *)allInheritableBottomSidebars
{
	NSMutableArray *array = [[NSMutableArray alloc] initWithArray:
		[self inheritableBottomSidebarPagelets]];	// add my own sidebars at the bottom first

	if (![self isRoot] && [self boolForKey:@"includeInheritedSidebar"]) {
		[array fastAddObjectsFromArray:[[self parent] allInheritableBottomSidebars]];	// recurse
	}
	
	// Tidy up
	NSArray *result = [NSArray arrayWithArray:array];
	[array release];
	
	return result;
}

#pragma mark -
#pragma mark Support

/*	Runs through each pagelet in the array and ensures its -ordering property matches with the
 *	index in the array.
 */
+ (void)updatePageletOrderingsFromArray:(NSArray *)pagelets
{
	unsigned i;
	for (i = 0; i < [pagelets count]; i++)
	{
		KTPagelet *pagelet = [pagelets objectAtIndex:i];
		if ([pagelet ordering] != i) {
			[pagelet setInteger:i forKey:@"ordering"];
		}
	}
	
	// It's messy and complicated but we're doing the process twice in order to make sure -canMoveUp etc. are correct
	for (i = 0; i < [pagelets count]; i++)
	{
		KTPagelet *pagelet = [pagelets objectAtIndex:i];
		[pagelet setOrdering:i];
	}
}

@end
