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
- (NSArray *)pageletsForPredicate:(NSPredicate *)predicate;

+ (NSPredicate *)calloutsPredicate;
+ (NSPredicate *)sidebarsPredicate;
+ (NSPredicate *)topSidebarsPredicate;
+ (NSPredicate *)bottomSidebarsPredicate;
+ (NSPredicate *)inheritableTopSidebarsPredicate;
+ (NSPredicate *)inheritableBottomSidebarsPredicate;
@end


@implementation KTPage (Pagelets)

#pragma mark -
#pragma mark Raw accessors

/*!	Defined here to be parallel to includeCallout, even though it's just a wrapper
*/
- (BOOL)includeSidebar
{
	BOOL result = [self wrappedBoolForKey:@"includeSidebar"];		// not an optional property, so it's OK to convert to a non-object
	return result;
}

- (void)setIncludeSidebar:(BOOL)flag
{
	[self setWrappedBool:flag forKey:@"includeSidebar"];
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
			result = [self orderedCallouts];
			break;
		case KTSidebarPageletLocation:
			result = [self orderedSidebars];
			break;
		case KTTopSidebarPageletLocation:
			result = [self orderedTopSidebars];
			break;
		case KTBottomSidebarPageletLocation:
			result = [self orderedBottomSidebars];
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
	NSAssert(![[self pagelets] containsObject:pagelet], @"Attempting to insert a pagelet twice");
	
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
}

/*	A nice shortcut to doing -insertPagelet:atIndex: at the end of the array.
 */
- (void)addPagelet:(KTPagelet *)pagelet
{
	KTPageletLocation location = [pagelet locationByDifferentiatingTopAndBottomSidebars];
	unsigned index = [[self pageletsInLocation:location] count];
	[self insertPagelet:pagelet atIndex:index];
}

#pragma mark -
#pragma mark -pageletsInLocation: shortcuts

/*	These 4 just call straight through to -pageletsInLocation: with the right argument
 */

- (NSArray *)orderedCallouts { return [self pageletsForPredicate:[KTPage calloutsPredicate]]; }

- (NSArray *)orderedTopSidebars { return [self pageletsForPredicate:[KTPage topSidebarsPredicate]]; }

- (NSArray *)orderedBottomSidebars { return [self pageletsForPredicate:[KTPage bottomSidebarsPredicate]]; }

- (NSArray *)orderedSidebars { return [self pageletsForPredicate:[KTPage sidebarsPredicate]]; }

#pragma mark -
#pragma mark Inheritable sidebar pagelets

/*	Filters out the top sidebar pagelets that won't appear on child pages
 */
- (NSArray *)orderedInheritableTopSidebars
{
	return [self pageletsForPredicate:[KTPage inheritableTopSidebarsPredicate]];
}

/*	Filters out the bottom sidebar pagelets that won't appear on child pages
 */
- (NSArray *)orderedInheritableBottomSidebars
{
	return [self pageletsForPredicate:[KTPage inheritableBottomSidebarsPredicate]];
}

/*	Our inheritable sidebar pagelets plus any inherited from our parent.
 *	During publishing these methods are cached for performance.
 */
- (NSArray *)allInheritableTopSidebars
{
	NSArray *result = nil;
	
	//if ([[self document] XpublishingMode] == kGeneratingPreview) {
		result = [self _allInheritableTopSidebars];
	//}
	//else {
	//	result = [[self document] cachedAllInheritableTopSidebarsForPage:self];
	//}
	
	return result;
}

- (NSArray *)_allInheritableTopSidebars
{
	NSMutableArray *array = [[NSMutableArray alloc] init];
	
	if (![self isRoot] && [self boolForKey:@"includeInheritedSidebar"]) {
		[array fastAddObjectsFromArray:[[self parent] allInheritableTopSidebars]];	// recurse
	}
	
	[array fastAddObjectsFromArray:[self orderedInheritableTopSidebars]];	// add my own sidebars that can be inherited
	
	// Tidy up
	NSArray *result = [NSArray arrayWithArray:array];
	[array release];
	
	return result;
}

- (NSArray *)allInheritableBottomSidebars
{
	NSArray *result = nil;
	
	//if ([[self document] XpublishingMode] == kGeneratingPreview) {
		result = [self _allInheritableBottomSidebars];
	//}
	//else {
	//	result = [[self document] cachedAllInheritableBottomSidebarsForPage:self];
	//}
	
	return result;
}

- (NSArray *)_allInheritableBottomSidebars
{
	NSMutableArray *array = [[NSMutableArray alloc] initWithArray:
		[self orderedInheritableBottomSidebars]];	// add my own sidebars at the bottom first

	if (![self isRoot] && [self boolForKey:@"includeInheritedSidebar"]) {
		[array fastAddObjectsFromArray:[[self parent] allInheritableBottomSidebars]];	// recurse
	}
	
	// Tidy up
	NSArray *result = [NSArray arrayWithArray:array];
	[array release];
	
	return result;
}

#pragma mark -
#pragma mark Inherited sidebar pagelets

/*	All the sidebar pagelets that should appear on the page, including those inherited from our parent as appropriate
 */
- (NSArray *)allSidebars
{
	BOOL includeInheritedSidebar = ([self boolForKey:@"includeInheritedSidebar"] && ![self isRoot]);
	
	// Gather the 3 groups of pagelets into one single array
	NSMutableArray *tempResult = [[NSMutableArray alloc] init];
	
	if (includeInheritedSidebar) {
		[tempResult fastAddObjectsFromArray:[[self parent] allInheritableTopSidebars]];
	}
	
	[tempResult fastAddObjectsFromArray:[self pageletsInLocation:KTSidebarPageletLocation]];
	
	if (includeInheritedSidebar) {
		[tempResult fastAddObjectsFromArray:[[self parent] allInheritableBottomSidebars]];
	}
	
	// Tidy up
	NSArray *result = [NSArray arrayWithArray:tempResult];
	[tempResult release];
	
	return result;
}

#pragma mark -
#pragma mark Support

- (NSArray *)pageletsForPredicate:(NSPredicate *)predicate
{
	NSMutableArray *result = [NSMutableArray arrayWithArray:[[self pagelets] allObjects]];
	[result filterUsingPredicate:predicate];
	
	if (predicate == [KTPage sidebarsPredicate])
	{
		[result sortUsingDescriptors:[NSSortDescriptor sidebarPageletsSortDescriptors]];
	}
	else
	{
		[result sortUsingDescriptors:[NSSortDescriptor orderingSortDescriptors]];
	}
	
	return result;
}

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

#pragma mark predicates

+ (NSPredicate *)calloutsPredicate
{
	static NSPredicate *predicate;
	if (!predicate)
	{
		predicate = [[NSPredicate predicateWithFormat:@"location == %i", KTCalloutPageletLocation] retain];
	}
	return predicate;
}

+ (NSPredicate *)sidebarsPredicate;
{
	static NSPredicate *predicate;
	if (!predicate)
	{
		predicate = [[NSPredicate predicateWithFormat:@"location == %i", KTSidebarPageletLocation] retain];
	}
	return predicate;
}

+ (NSPredicate *)topSidebarsPredicate;
{
	static NSPredicate *predicate;
	if (!predicate)
	{
		predicate = [[NSPredicate predicateWithFormat:@"location == %i AND prefersBottom == 0",
													  KTSidebarPageletLocation] retain];
	}
	return predicate;
}

+ (NSPredicate *)bottomSidebarsPredicate;
{
	static NSPredicate *predicate;
	if (!predicate)
	{
		predicate = [[NSPredicate predicateWithFormat:@"location == %i AND prefersBottom == 1",
													  KTSidebarPageletLocation] retain];
	}
	return predicate;
}

+ (NSPredicate *)inheritableTopSidebarsPredicate;
{
	static NSPredicate *predicate;
	if (!predicate)
	{
		predicate = [[NSPredicate predicateWithFormat:@"location == %i AND prefersBottom == 0 AND shouldPropagate == 1",
													  KTSidebarPageletLocation] retain];
	}
	return predicate;
}

+ (NSPredicate *)inheritableBottomSidebarsPredicate;
{
	static NSPredicate *predicate;
	if (!predicate)
	{
		predicate = [[NSPredicate predicateWithFormat:@"location == %i AND prefersBottom == 1 AND shouldPropagate == 1",
													  KTSidebarPageletLocation] retain];
	}
	return predicate;
}

@end
