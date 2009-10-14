//
//  KTPagelet.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "KTPagelet+Internal.h"

#import "Debug.h"
#import "KT.h"
#import "KTAbstractElement+Internal.h"
#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTElementPlugin.h"
#import "SVHTMLTemplateParser.h"
#import "KTManagedObject.h"
#import "KTPage.h"
#import "SVPageletBody.h"

#import "NSBundle+Karelia.h"
#import "NSBundle+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"

#import "Registration.h"


@interface KTPagelet ()
+ (KTPagelet *)_insertNewPageletWithPage:(KTPage *)page pluginIdentifier:(NSString *)identifier location:(KTPageletLocation)location;
- (NSSet *)allPagesThatInheritSidebarsFromPage:(KTPage *)page;
@end


@implementation KTPagelet

#pragma mark -
#pragma mark Initialization

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[KTPagelet setKeys:[NSArray arrayWithObjects: @"ordering", @"location", @"prefersBottom", nil]
		triggerChangeNotificationsForDependentKey: @"canMoveUp"];
	
	[KTPagelet setKeys:[NSArray arrayWithObjects: @"ordering", @",location", @"prefersBottom", nil]
		triggerChangeNotificationsForDependentKey: @"canMoveDown"];
	
	[pool release];
}

/*	Creates a fresh pagelet for the chosen page
 */
+ (KTPagelet *)pageletWithPage:(KTPage *)page plugin:(KTElementPlugin *)plugin;
{	
	OBPRECONDITION(page);	OBPRECONDITION(plugin);
	
	
	// Figure out where to place the pagelet
	KTPageletLocation location = KTSidebarPageletLocation;
	if (![page includeSidebar])
	{
		if ([page includeCallout])
		{
			location = KTCalloutPageletLocation;
		}
		else
		{
			OBASSERTSTRING([page sidebarChangeable], @"Attempting to create pagelet on page which allows neither sidebar or callouts");
			[page setIncludeSidebar:YES];
		}
	}
	
	KTPagelet *result = [self insertNewPageletWithPage:page pluginIdentifier:[[plugin bundle] bundleIdentifier] location:location];
	return result;
}

+ (KTPagelet *)insertNewPageletWithPage:(KTPage *)page
                       pluginIdentifier:(NSString *)pluginIdentifier
                               location:(KTPageletLocation)location;
{
    OBPRECONDITION(page);
    OBPRECONDITION(pluginIdentifier);
    
    // Create the pagelet
	KTPagelet *result = [self _insertNewPageletWithPage:page
									   pluginIdentifier:pluginIdentifier
											   location:location];
	
	// Tell the pagelet to awake
	[result awakeFromBundleAsNewlyCreatedObject:YES];
    
    return result;
}

/*	Private support method that creates a basic pagelet.
 */
+ (KTPagelet *)_insertNewPageletWithPage:(KTPage *)page pluginIdentifier:(NSString *)identifier location:(KTPageletLocation)location
{
	OBPRECONDITION([page managedObjectContext]);		OBPRECONDITION(identifier);
	
	
	// Create the pagelet
	KTPagelet *result = [NSEntityDescription insertNewObjectForEntityForName:@"Pagelet"
													  inManagedObjectContext:[page managedObjectContext]];
	OBASSERT(result);
	
	
	// Seup the pagelet's properties
	[result setValue:identifier forKey:@"pluginIdentifier"];
	[result setLocation:location];
	
	[page addPagelet:result];
	
	return result;
}

+ (KTPagelet *)pageletWithPage:(KTPage *)aPage dataSourceDictionary:(NSDictionary *)aDictionary
{
	KTElementPlugin *plugin = [aDictionary objectForKey:kKTDataSourcePlugin];
	
	KTPagelet *pagelet = [self pageletWithPage:aPage plugin:plugin];
	[pagelet awakeFromDragWithDictionary:aDictionary];
	
	return pagelet;
}

#pragma mark -
#pragma mark Awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	// First set fallback title, but then we'll let below override it
	if ( isNewlyCreatedObject )
	{
		NSString *titleText = [[self plugin] pluginPropertyForKey:@"KTPageletUntitledName"];
		[self setTitleHTML:titleText];		// really we just have text, but the prop is HTML
		
		[self setShowBorder:NO];	// new pagelets now DON'T show border initially, let people turn it on.
	}
	
	[super awakeFromBundleAsNewlyCreatedObject:isNewlyCreatedObject];
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];

    NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
    if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		NSFileManager *fm = [NSFileManager defaultManager];
		title = [[fm displayNameAtPath:[aDictionary valueForKey:kKTDataSourceFileName]] stringByDeletingPathExtension];
	}
	if (nil != title)
	{
		NSString *titleHTML = [self titleHTML];
		if (nil == titleHTML || [titleHTML isEqualToString:@""] || [titleHTML isEqualToString:[[self plugin] pluginPropertyForKey:@"KTPluginUntitledName"]])
		{
			[self setTitleHTML:[title stringByEscapingHTMLEntities]];
		}
	}
}

#pragma mark -
#pragma mark Basic accessors

- (int)ordering { return [self wrappedIntegerForKey:@"ordering"]; }

- (BOOL)shouldPropagate { return [self wrappedBoolForKey:@"shouldPropagate"]; }

- (void)setShouldPropagate:(BOOL)propagate
{
	[self setWrappedBool:propagate forKey:@"shouldPropagate"];
	
	// Our page's simple caches are not affected, but child pages are if in the sidebar.
	if ([self location] == KTSidebarPageletLocation)
	{
		[[self page] invalidateSidebarPageletsCache:NO recursive:YES];
	}
}

- (NSString *)introductionHTML 
{
	NSString *result = [self wrappedValueForKey:@"introductionHTML"];
	if (!result)
	{
		result = @"";
	}
	
	return result;
}

- (void)setIntroductionHTML:(NSString *)value {	[self setWrappedValue:value forKey:@"introductionHTML"]; }

- (NSString *)cssClassName { return [[self plugin] pageletCSSClassName]; }

- (BOOL)showBorder { return [self wrappedBoolForKey:@"showBorder"]; }

- (void)setShowBorder:(BOOL)flag { [self setWrappedBool:flag forKey:@"showBorder"]; }

#pragma mark -
#pragma mark Page

- (KTPage *)page { return [self wrappedValueForKey:@"page"]; }


/*	Sidebar pagelets put in an appearance on many pages. This returns a list of all those pages.
 *	Obviously for a callout, it just contains the one page.
 */
- (NSSet *)allPages
{
	NSSet *result = nil;
	
	if ([self location] == KTCalloutPageletLocation || ![self shouldPropagate])
	{
		result = [NSSet setWithObject:[self page]];
	}
	else
	{
		KTPage *mainPage = [self page];
		NSMutableSet *pages = [[NSMutableSet alloc] initWithObjects:mainPage, nil];
		[pages unionSet:[self allPagesThatInheritSidebarsFromPage:mainPage]];
		
		result = [NSSet setWithSet:pages];
		[pages release];
	}
	
	return result;
}

/*	Support method for -allPages
 */
- (NSSet *)allPagesThatInheritSidebarsFromPage:(KTPage *)page
{
	NSMutableSet *result = [NSMutableSet set];
	
	NSEnumerator *childPages = [[page children] objectEnumerator];
	KTPage *aPage;
	
	while (aPage = [childPages nextObject])
	{
		if ([aPage includeSidebar] && [aPage boolForKey:@"includeInheritedSidebar"])
		{
			[result addObject:aPage];
			[result unionSet:[self allPagesThatInheritSidebarsFromPage:aPage]];
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Location

/*	The pagelet location as stored in the DB. Does NOT distinguish between top and bottom sidebars.
 */
- (KTPageletLocation)location { return [self wrappedIntegerForKey:@"location"]; }

/*	The pagelet location as stored in the database. DOES distinguish between top and bottom sidebars.
 */
- (KTPageletLocation)locationByDifferentiatingTopAndBottomSidebars
{
	KTPageletLocation result = [self location];
	
	if (result == KTSidebarPageletLocation)
	{
		if ([self prefersBottom]) {
			result = KTBottomSidebarPageletLocation;
		}
		else {
			result = KTTopSidebarPageletLocation;
		}
	}
	
	return result;
}

/*	If you try to set the location to be a top or bottom sidebar, an exception is raised
 */
- (void)setLocation:(KTPageletLocation)location
{
	// Ensure no-one tries to set a top or bottom sidebar location
	OBASSERTSTRING((location == KTSidebarPageletLocation || location == KTCalloutPageletLocation),
				   @"Can't directly set the location of a pagelet to top or bottom sidebar; use -setPrefersBottom: instead");
	
	// Store the value
	[self willChangeValueForKey:@"location"];
	[self setPrimitiveValue:[NSNumber numberWithInt:location] forKey:@"location"];
	
	// Since we are potentially inserting the pagelet in an array, the orderings must be updated to avoid conflicts
	[KTPage updatePageletOrderingsFromArray:[self pageletsInSameLocation]];
	
	[self didChangeValueForKey:@"location"];
	
	// Our location has changed so various caches are affected
	[[self page] invalidateCalloutsCache];
	[[self page] invalidateSidebarPageletsCache:YES recursive:[self shouldPropagate]];
}

- (BOOL)prefersBottom {	return [self wrappedBoolForKey:@"prefersBottom"]; }

- (void)setPrefersBottom:(BOOL)prefersBottom
{
	[self willChangeValueForKey:@"prefersBottom"];
	[self setPrimitiveValue:[NSNumber numberWithBool:prefersBottom] forKey:@"prefersBottom"];
	
	// Since we are potentially inserting the pagelet in an array, the orderings must be updated to avoid conflicts
	[KTPage updatePageletOrderingsFromArray:[self pageletsInSameLocation]];
	
	[self didChangeValueForKey:@"prefersBottom"];
	
	
	// For callouts this has no affect on position, so no caches need updating
	if ([self location] != KTCalloutPageletLocation)
	{
		[[self page] invalidateSidebarPageletsCache:YES recursive:[self shouldPropagate]];
	}
}

/*	A shortcut to the methods in KTPage for getting all the pagelets in the same location as us
 */
- (NSArray *)pageletsInSameLocation
{
	NSArray *result = [[self page] pageletsInLocation:[self locationByDifferentiatingTopAndBottomSidebars]];
	return result;
}

#pragma mark moving

- (BOOL)canMoveUp
{
	unsigned index = [[self pageletsInSameLocation] indexOfObject:self];
	BOOL result = (index != 0 && index != NSNotFound);
	return result;
}

- (BOOL)canMoveDown
{
	NSArray *pageletsInSameLocation = [self pageletsInSameLocation];
	BOOL result = ![[pageletsInSameLocation lastObject] isEqual:self];
	return result;
}

/*	Swaps the pagelet with the one above it
 */
- (void)moveUp
{
	NSMutableArray *fellowPagelets = [[NSMutableArray alloc] initWithArray:[self pageletsInSameLocation]];
	unsigned index = [fellowPagelets indexOfObjectIdenticalTo:self];
	[fellowPagelets exchangeObjectAtIndex:index withObjectAtIndex:index - 1];
	[KTPage updatePageletOrderingsFromArray:fellowPagelets];
	
	// Tidy up
	[fellowPagelets release];
	
	// The move will have some cache
	if ([self location] == KTCalloutPageletLocation)
	{
		[[self page] invalidateCalloutsCache];
	}
	else
	{
		[[self page] invalidateSidebarPageletsCache:YES recursive:[self shouldPropagate]];
	}
}

/*	Swaps the pagelet with the one below it
 */
- (void)moveDown
{
	NSMutableArray *fellowPagelets = [[NSMutableArray alloc] initWithArray:[self pageletsInSameLocation]];
	unsigned index = [fellowPagelets indexOfObjectIdenticalTo:self];
	[fellowPagelets exchangeObjectAtIndex:index withObjectAtIndex:index + 1];
	[KTPage updatePageletOrderingsFromArray:fellowPagelets];
	
	// Tidy up
	[fellowPagelets release];
	
	// The move will have some cache
	if ([self location] == KTCalloutPageletLocation)
	{
		[[self page] invalidateCalloutsCache];
	}
	else
	{
		[[self page] invalidateSidebarPageletsCache:YES recursive:[self shouldPropagate]];
	}
}

#pragma mark -
#pragma mark KTWebViewComponent protocol

/*	Add to the default list of components: pagelets (and their components), index (if it exists)
 */
- (NSString *)uniqueWebViewID
{
	NSString *result = [NSString stringWithFormat:@"ktpagelet-%@", [self uniqueID]];
	return result;
}

#pragma mark -
#pragma mark Support

// More human-readable description
- (NSString *)shortDescription
{
	return [NSString stringWithFormat:@"%@ <%p> : %@ %@ %@", [self class], self,
		[self titleHTML], [self wrappedValueForKey:@"uniqueID"], [self wrappedValueForKey:@"pluginIdentifier"]];
}

- (BOOL)canHaveTitle
{
	return [[[self plugin] pluginPropertyForKey:@"KTPageletCanHaveTitle"] boolValue];
}

@end
