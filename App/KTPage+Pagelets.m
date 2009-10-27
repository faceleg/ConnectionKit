//
//  KTPage+Pagelets.m
//  KTComponents
//
//  Created by Mike on 26/05/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTPage.h"

#import "Debug.h"

#import "KTAbstractElement+Internal.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "SVSidebarEntry.h"

#import "NSArray+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSSortDescriptor+Karelia.h"


@interface KTPage (PageletsPrivate)

// Private, non-KVO-compliant accessors
- (NSArray *)topSidebars;
- (NSArray *)bottomSidebars;
- (NSArray *)sidebars;
- (NSArray *)sortedPageletsWithPredicate:(NSPredicate *)predicate;

- (NSArray *)allInheritableTopSidebars;
- (NSArray *)allInheritableBottomSidebars;

- (NSArray *)_sidebarPagelets;

@end


#pragma mark -


@implementation KTPage (Pagelets)

+ (void)initialize_pagelets
{
}

#pragma mark -
#pragma mark Simple Accessors

- (BOOL)includeSidebar
{
	BOOL result = [self wrappedBoolForKey:@"includeSidebar"];		// not an optional property, so it's OK to convert to a non-object
	return result;
}

- (void)setIncludeSidebar:(BOOL)flag { [self setWrappedBool:flag forKey:@"includeSidebar"]; }

- (BOOL)includeInheritedSidebar { return [self wrappedBoolForKey:@"includeInheritedSidebar"]; }

- (void)setIncludeInheritedSidebar:(BOOL)flag
{
	[self setWrappedBool:flag forKey:@"includeInheritedSidebar"];
	
	// Our -allSidebars list has changed since we have presumably inherited some pagelets
	[self invalidateSidebarPageletsCache:YES recursive:YES];
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
#pragma mark Modifying Pagelet Positioning

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
			result = [self sidebars];
			break;
		case KTTopSidebarPageletLocation:
			result = [self topSidebars];
			break;
		case KTBottomSidebarPageletLocation:
			result = [self bottomSidebars];
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
	//[self lockPSCAndMOC];
	[[self mutableSetValueForKey:@"pagelets"] addObject:pagelet];
	//[self unlockPSCAndMOC];
	
	
	// Insert the pagelet into the array and update the ordering of all pagelets
	NSMutableArray *pagelets = [[NSMutableArray alloc] initWithArray:existingPagelets];
	[pagelets insertObject:pagelet atIndex:index];
	[KTPage updatePageletOrderingsFromArray:pagelets];
	[pagelets release];
	
	
	// And finally cached pagelet lists must have been affected
	if ([pagelet location] == KTSidebarPageletLocation)
	{
		[self invalidateSidebarPageletsCache:YES recursive:[pagelet shouldPropagate]];
	}
	else
	{
		[self invalidateCalloutsCache];
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

- (void)removePagelet:(KTPagelet *)pagelet
{
	[[self mutableSetValueForKey:@"pagelets"] removeObject:pagelet];
	
	// Some caches must have been affected by the change
	if ([pagelet location] == KTSidebarPageletLocation)
	{
		[self invalidateSidebarPageletsCache:YES recursive:[pagelet shouldPropagate]];
	}
	else
	{
		[self invalidateCalloutsCache];
	}
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
#pragma mark Callouts

- (NSArray *)callouts
{
	NSString *key = NSStringFromSelector(_cmd);
	NSArray *result = [self primitiveValueForKey:key];
	
	if (!result)
	{
		// Build the predicate if needed
		static NSPredicate *sPredicate;
		if (!sPredicate)
		{
			sPredicate = [[NSPredicate predicateWithFormat:@"location == 3"] retain];
		}
		
		// Filter and sort the array
		result = [self sortedPageletsWithPredicate:sPredicate];
		[self setPrimitiveValue:result forKey:key];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

- (void)invalidateCalloutsCache
{
	[self setWrappedValue:nil forKey:@"callouts"];
}

#pragma mark -
#pragma mark Non-Inherited Sidebar

- (NSArray *)topSidebars
{
	// Build the predicate if needed
	static NSPredicate *sPredicate;
	if (!sPredicate)
	{
		sPredicate = [[NSPredicate predicateWithFormat:@"location == 1 AND prefersBottom == 0"] retain];
	}
	
	NSArray *result = [self sortedPageletsWithPredicate:sPredicate];
	return result;
}

- (NSArray *)bottomSidebars
{
	// Build the predicate if needed
	static NSPredicate *sPredicate;
	if (!sPredicate)
	{
		sPredicate = [[NSPredicate predicateWithFormat:@"location == 1 AND prefersBottom == 1"] retain];
	}
	
	NSArray *result = [self sortedPageletsWithPredicate:sPredicate];
	return result;
}

- (NSArray *)sidebars
{
	NSArray *result = [[self topSidebars] arrayByAddingObjectsFromArray:[self bottomSidebars]];
	return result;
}

- (NSArray *)sortedPageletsWithPredicate:(NSPredicate *)predicate
{
	// Filter and sort the array
	NSSet *allPagelets = [self pagelets];                                                   OBASSERT(allPagelets);
    NSArray *allPageletsArray = [allPagelets allObjects];                                   OBASSERT(allPageletsArray);
    NSArray *unsortedPagelets = [allPageletsArray filteredArrayUsingPredicate:predicate];   OBASSERT(unsortedPagelets);
	NSArray *result = [unsortedPagelets sortedArrayUsingDescriptors:[NSSortDescriptor orderingSortDescriptors]];
	
	OBPOSTCONDITION(result);
	return result;
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
	NSArray *result = [[self topSidebars] filteredArrayUsingPredicate:sPredicate];
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
	NSArray *result = [[self bottomSidebars] filteredArrayUsingPredicate:sPredicate];
	return result;
}

#pragma mark -
#pragma mark All Sidebar Pagelets
					   
/*	All the sidebar pagelets that should appear on the page, including those inherited from our parent as appropriate.
 *	This is the culmination of all the other methods and is used to generate the HTML.
 */
- (NSArray *)sidebarPagelets
{
	NSString *key = NSStringFromSelector(_cmd);
	NSArray *result = [self wrappedValueForKey:key];
	
	if (!result)
	{
		result = [self _sidebarPagelets];
		[self setPrimitiveValue:result forKey:key];
	}
	
	OBPOSTCONDITION(result);
	return result;
}	

/*	Uncached version of the above.
 */
- (NSArray *)_sidebarPagelets
{
	BOOL includePageletsFromParent = ([self boolForKey:@"includeInheritedSidebar"] && ![self isRoot]);
	
	// Gather the 3 groups of pagelets into one single array
	NSMutableArray *buffer = [[NSMutableArray alloc] init];
	
	if (includePageletsFromParent) {
		[buffer addObjectsFromArray:[[self parent] allInheritableTopSidebars]];
	}
	
	[buffer addObjectsFromArray:[self sidebars]];
	
	if (includePageletsFromParent) {
		[buffer addObjectsFromArray:[[self parent] allInheritableBottomSidebars]];
	}
	
	
	// Tidy up
	NSArray *result = [[buffer copy] autorelease];
	[buffer release];
	return result;
}

/*	Very simple method to invalidate our cache. Does pretty much as it says on the tin
 *	If you pass NO for invalidateCache, but YES for recursive then the receiver won't be affected, but children will.
 */
- (void)invalidateSidebarPageletsCache:(BOOL)invalidateCache recursive:(BOOL)recursive;
{
	if (invalidateCache)
	{
		[self setWrappedValue:nil forKey:@"sidebarPagelets"];
	}
	
	if (recursive)
	{
		[[self children] makeObjectsPerformSelector:@selector(recursiveInvalidateSidebarPageletsCache)];
	}
}

/*	This is a special private method that should ONLY be invoked on child pages as a result of calling
 *	-invalidateSidebarPageletsCache:recursive: on their parent.
 *	This method calls through to the -invalidateSidebarPageletsCache:recursive: but only if the sidebar is inherited.
 */
- (void)recursiveInvalidateSidebarPageletsCache
{
	if ([self boolForKey:@"includeInheritedSidebar"])
	{
		[self invalidateSidebarPageletsCache:YES recursive:YES];
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

#pragma mark HTML

- (NSString *)pageletsHTMLString
{
    NSString *result = @"";
    
    SVSidebarEntry *anEntry = [[self sidebar] firstEntry];
    while (anEntry)
    {
        // Generate HTML for the pagelet
        NSString *templatePath = [[NSBundle mainBundle] pathForResource:@"PageletTemplate" ofType:@"html"];
        NSString *template = [NSString stringWithContentsOfFile:templatePath encoding:NSUTF8StringEncoding error:nil];
        
        SVHTMLTemplateParser *parser = [[SVHTMLTemplateParser alloc] initWithTemplate:template
                                                                            component:[anEntry pagelet]];
        NSString *pageletHTML = [parser parseTemplate];
        result = [result stringByAppendingString:pageletHTML];
        
        
        // Move onto next pagelet
        anEntry = [anEntry nextEntry];
    }
    
    return result;
}

#pragma mark -
#pragma mark Support

/*	Runs through each pagelet in the array and ensures its -ordering property matches with the
 *	index in the array.
 */
+ (void)updatePageletOrderingsFromArray:(NSArray *)pagelets
{
	[pagelets makeObjectsPerformSelector:@selector(willChangeValueForKey:) withObject:@"ordering"];
	
	unsigned i;
	for (i = 0; i < [pagelets count]; i++)
	{
		KTPagelet *pagelet = [pagelets objectAtIndex:i];
		if ([pagelet ordering] != i) {
			[pagelet setPrimitiveValue:[NSNumber numberWithUnsignedInt:i] forKey:@"ordering"];
		}
	}
	
	[pagelets makeObjectsPerformSelector:@selector(didChangeValueForKey:) withObject:@"ordering"];
}

@end
