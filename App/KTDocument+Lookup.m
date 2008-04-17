//
//  KTDocument+Lookup.m
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//
/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Utility methods called from below pages to find out document-related information.


 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:

 IMPLEMENTATION NOTES & CAUTIONS:

 */

#import "KTDocument.h"

#import "Debug.h"
#import "KT.h"
#import "KTAbstractElement.h"
#import "KTAppDelegate.h"
#import "KTDesign.h"
#import "KTDesignURLProtocol.h"
#import "KTDocWindowController.h"
#import "KTInfoWindowController.h"
#import "KTKeypathURLProtocol.h"
#import "KTPage.h"
#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSAttributedString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSCharacterSet+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"

#import "Registration.h"

@implementation KTDocument ( Lookup )

#pragma mark -
#pragma mark Generated properties

- (NSString *)metaRobots
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];	
	return [defaults objectForKey:@"metaRobots"];
}


/*!	Invoked to fill in the web pages for the meta 'generator' value
*/
- (NSString *)appNameVersion
{
	NSString *version = [NSApplication appVersion];
	
	NSString *applicationName = [NSApplication applicationName];
	if ([[NSApp delegate] isPro])
	{
		applicationName = [applicationName stringByAppendingString:@" Pro"];
	}
	
	return [NSString stringWithFormat:@"%@ %@", applicationName, version];
}

/*!	Return a code that indicates what license is used.  To help with blacklists or detecting piracy.
	Returns a nonsense value
*/
- (NSString *) hash
{
	return (nil != gRegistrationHash) ? gRegistrationHash : @""; 
}

/*!	For RSS generation
*/
- (NSString *)documentLastBuildDate
{
	return [[NSCalendarDate calendarDate] descriptionRFC822];		// NOW in the proper format
}

// TODO: get the domain name or identifier of the site

- (NSString *)domainNameDashes
{
	NSMutableString *string = [NSMutableString stringWithString:[self publishedSiteURL]];
	if ([string hasPrefix:@"http://"])
	{
		[string deleteCharactersInRange:NSMakeRange(0,7)];
	}
	if ([string hasSuffix:@"/"])
	{
		[string deleteCharactersInRange:NSMakeRange([string length]-1, 1)];
	}
	[string replace:@"." with:@"_"];
	[string replace:@"/" with:@"_"];
	unichar firstChar = [string characterAtIndex:0];
	if (   ![[NSCharacterSet characterSetWithRange:NSMakeRange((unsigned int)'A', 26)] characterIsMember:firstChar]
		&& ![[NSCharacterSet characterSetWithRange:NSMakeRange((unsigned int)'a', 26)] characterIsMember:firstChar])
	{
		[string insertString:@"host_" atIndex:0];
	}
	return [string stringByRemovingCharactersInSet:[[NSCharacterSet alphanumericASCIIUnderlineCharacterSet] invertedSet]];
}

+ (NSArray *)_siteMenuSortDescriptors
{
	static NSArray *result;
	
	if (!result)
	{
		NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"indexPath" ascending:YES];
		result = [[NSArray alloc] initWithObject:sortDescriptor];
		[sortDescriptor release];
	}
	
	return result;
}

- (NSArray *)siteMenu
{
	// Fetch all the pages qualifying to fit in the Site Menu.
	NSFetchRequest *request = [[self managedObjectModel] fetchRequestTemplateForName:@"SiteOutlinePages"];
	
	NSError *error = nil;
	NSArray *unsortedResult = [[self managedObjectContext] executeFetchRequest:request error:&error];
	if (error) {
		[[NSAlert alertWithError:error] runModal];
		return nil;
	}
	
	NSMutableArray *result = [NSMutableArray arrayWithArray:unsortedResult];
	
	
	// Root has to be handled specially
	BOOL includeRoot = [[self root] includeInSiteMenu];
	if (includeRoot)
	{
		[result removeObjectIdenticalTo:[self root]];
	}
	
	
	// Sort the pages according to their index path from root
	[result sortUsingDescriptors:[KTDocument _siteMenuSortDescriptors]];
	
	
	// Add root back in if needs be
	if (includeRoot)
	{
		[result insertObject:[self root] atIndex:0];
	}
	
	
	return result;
}

- (BOOL)hasRSSFeeds;	// determine if we need to show export panel
{
	NSMutableArray *RSSCollectionArray = [NSMutableArray array];
	
	@try
	{
		KTPage *root = [self root];
		[root makeSelfOrDelegatePerformSelector:@selector(addRSSCollectionsToArray:forPage:) withObject:RSSCollectionArray withPage:root recursive:YES];
	}
	@finally
	{
	}
	return [RSSCollectionArray count] > 0;
}

- (NSString *)siteTitleHTML
{
	return [[[self displayName] stringByDeletingPathExtension] escapedEntities];		// get the default title from the document name
}

- (NSAttributedString *)siteTitleAttributed		// same as above, but don't escape entities
{
	NSString *str = [[self displayName] stringByDeletingPathExtension];
	return [NSAttributedString systemFontStringWithString:str];
}

/*!	Used by iframe pagelets and "keypath:" URL protocol to generate image data showing that iframe is not loaded
*/
- (NSData *)hashPattern
{
	static NSData *sHashData = nil;
	if (nil == sHashData)
	{
		sHashData = [[[NSImage imageNamed:@"qmark50"] TIFFRepresentation] retain];
	}
	return sHashData;	
}

#pragma mark -
#pragma mark Non-simple lookups from the user defaults

// Trigger Localization ... thes are loaded with the [[` ... ]] directive

// NSLocalizedStringWithDefaultValue(@"skipNavigationTitleHTML", nil, [NSBundle mainBundle], @"Site Navigation", @"Site navigation title on web pages (can be empty if link is understandable)")
// NSLocalizedStringWithDefaultValue(@"backToTopTitleHTML", nil, [NSBundle mainBundle], @" ", @"Back to top title, generally EMPTY")
// NSLocalizedStringWithDefaultValue(@"skipSidebarsTitleHTML", nil, [NSBundle mainBundle], @"Sidebar", @"Sidebar title on web pages (can be empty if link is understandable)")
// NSLocalizedStringWithDefaultValue(@"skipNavigationLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip navigation LINK on web pages"), @"skipNavigationLinkHTML",
// NSLocalizedStringWithDefaultValue(@"skipSidebarsLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip sidebars LINK on web pages"), @"skipSidebarsLinkHTML",
 // NSLocalizedStringWithDefaultValue(@"backToTopLinkHTML", nil, [NSBundle mainBundle], @"[Back To Top]", @"back-to-top LINK on web pages"), @"backToTopLinkHTML",

// WHERE IS THIS BEING USED?
// NSLocalizedStringWithDefaultValue(@"indexOverflowHTML", nil, [NSBundle mainBundle], @"View Archives", @"link to archives on web pages"), @"indexOverflowHTML",

// NSLocalizedStringWithDefaultValue(@"navigateNextHTML",		nil, [NSBundle mainBundle], @"Next",		@"alt text of navigation button"),	@"navigateNextHTML",
// NSLocalizedStringWithDefaultValue(@"navigateListHTML",		nil, [NSBundle mainBundle], @"List",		@"alt text of navigation button"),	@"navigateListHTML",
// NSLocalizedStringWithDefaultValue(@"navigatePreviousHTML",	nil, [NSBundle mainBundle], @"Previous",	@"alt text of navigation button"),	@"navigatePreviousHTML",
// NSLocalizedStringWithDefaultValue(@"navigateMainHTML",		nil, [NSBundle mainBundle], @"Main",		@"text of navigation button"),		@"navigateMainHTML",

// Return the appropriate localization for these default values.

- (NSString *) titleHTML
{
	// Note: the use of NS...Localized...String...With...Default...Value below gets this string picked up by genstrings for 
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"titleHTML" language:[[[self root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"titleHTML", nil, [NSBundle mainBundle], @"Untitled",  @"Default Title of page")
		];
	return result;
}
- (NSString *) siteSubtitleHTML
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"siteSubtitleHTML" language:[[[self root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"siteSubtitleHTML", nil, [NSBundle mainBundle], @"This is the subtitle for your site.",  @"Default introduction statement for a page")
		];
	return result;
}
- (NSString *) defaultRootPageTitleText
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"defaultRootPageTitleText" language:[[[self root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"defaultRootPageTitleText", nil, [NSBundle mainBundle], @"Home Page", @"Title of initial home page")];
	return result;
}

// DERIVED

- (NSString *)siteSubtitleText
{
	NSString *result = [self siteSubtitleHTML];
	if (![result isEqualToString:@""])
	{
		result = [result flattenHTML];
	}
	return result;
}



#pragma mark -
#pragma mark Simple lookups from the user defaults

- (NSString *)author
{
	return @"";	// don't inherit from defaults; we want it to be empty if it got emptied out
}

- (NSString *)googleAnalytics
{
	return @"";	// don't inherit from defaults; we want it to be empty if no value set
}

- (BOOL)addBool1
{
	return NO;
}

#pragma mark -
#pragma mark Fallback values for properties in pages and collections

- (NSString *)language
{
// This probably should use -[NSBundle preferredLocalizationsFromArray:forPreferences:]
// http://www.cocoabuilder.com/archive/message/cocoa/2003/4/24/84070
// though there's a problem ... that will return a string like "English" not "en"

	NSArray *langArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
	return [langArray objectAtIndex:0];		// preferred langauge is probably language of file
}


- (NSString *)charset { return @"UTF-8"; }

- (NSURL *)thumbURL
{
	return [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"emptyDoc"]];
}

- (NSString *)thumbURLPath
{
    return [[self thumbURL] absoluteString];
}


/*
	Recursively build map.  Home page gets priority 1.0; second level pages 0.5, third 0.33, etc.
	Items in the site map (besides home page) get 0.95, 0.90, 0.85, ... 0.55 in order that they appear
	This should make the site map be prioritized nicely.
 */

- (void)appendGoogleMapOfPage:(KTPage *)aPage toArray:(NSMutableArray *)ioArray siteMenuCounter:(int *)ioSiteMenuCounter level:(int)aLevel
{
	NSString *url = [[aPage publishedURL] absoluteString];
	if (![url hasPrefix:[self publishedSiteURL]])
	{
		return;	// an external link not in this site
	}
	
	if ([aPage excludedFromSiteMap])	// excluded checkbox checked, or it's an unpublished draft
	{
		return;	// addBool1 is indicator to EXCLUDE from a sitemap.
	}
	
	OBPRECONDITION(aLevel >= 1);
	NSMutableDictionary *entry = [NSMutableDictionary dictionary];
	[entry setObject:url forKey:@"loc"];
	float levelFraction = 1.0 / aLevel;
	if ([aPage boolForKey:@"includeInSiteMenu"] && aLevel > 1)	// boost items in site menu?
	{
		(*ioSiteMenuCounter)++;	// we have one more site menu item
		levelFraction = 0.95 - (0.05 * (*ioSiteMenuCounter));	// .90, .85, 0.80, 0.75 etc.
		if (levelFraction < 0.55) levelFraction = .55;	// keep site menu above .5
	}
	OBASSERT(levelFraction <= 1.0 && levelFraction > 0.0);
	[entry setObject:[NSNumber numberWithFloat:levelFraction] forKey:@"priority"];

	NSDate *lastModificationDate = [aPage wrappedValueForKey:@"lastModificationDate"];
	NSString *timestamp = [lastModificationDate descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ" timeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"] locale:nil];
	[entry setObject:timestamp forKey:@"lastmod"];
	
	// Note: we are not trying to support the "changefreq" parameter
	
	[ioArray addObject:entry];
	

	NSArray *children = [aPage sortedChildren];
	if ([children count])
	{
		NSEnumerator *theEnum = [children objectEnumerator];
		KTPage *aChildPage;
		
		while (nil != (aChildPage = [theEnum nextObject]) )
		{
			[self appendGoogleMapOfPage:aChildPage toArray:ioArray siteMenuCounter:ioSiteMenuCounter level:aLevel+1];
		}
	}
}

- (NSString *)generatedGoogleSiteMapWithManagedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;
{
	NSMutableArray *array = [NSMutableArray array];
	int siteMenuCounter = 0;
	[self appendGoogleMapOfPage:[self root] toArray:array siteMenuCounter:&siteMenuCounter level:1];

	NSMutableString *buf = [NSMutableString string];
	[buf appendString:@"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<urlset xmlns=\"http://www.sitemaps.org/schemas/sitemap/0.9\">\n"];
	NSEnumerator *enumerator = [array objectEnumerator];
	NSDictionary *dict;

	while ((dict = [enumerator nextObject]) != nil)
	{
		[buf appendFormat:@"<url><loc>%@</loc><lastmod>%@</lastmod><priority>%.02f</priority></url>\n",
			[[dict objectForKey:@"loc"] escapedEntities],
			[dict objectForKey:@"lastmod"],
			[[dict objectForKey:@"priority"] floatValue] ];
	}
	[buf appendString:@"</urlset>\n"];
	return buf;
}

/*!	Return path appropriate for inclusion in page; changes whether published or previewing

	This is the path RELATIVE TO THE DESIGN'S MAIN.CSS FILE!
*/
- (NSString *)pathForReplacementImageName:(NSString *)anImageName designBundleIdentifier:(NSString *)aDesignBundleIdentifier
{
	NSString *result = nil;
	
	//switch ((int)[self publishingMode])
	switch ((int)[[self windowController] publishingMode])
	{
		case kGeneratingPreview:
		{
			result = [[KTKeypathURLProtocol URLForDocument:self keyPath:anImageName] absoluteString];
			break;
		}
		default:
		{
			result = [kKTImageReplacementFolder stringByAppendingPathComponent:anImageName];
			break;
		}
	}
	return result;
}

// used by contact element

- (NSString *)URLForDesignBundleIdentifier:(NSString *)aDesignBundleIdentifier
{
	NSString *result = nil;
	
	KTDesign *design = [KTDesign pluginWithIdentifier:aDesignBundleIdentifier];
	
	result = [[self publishedSiteURL] stringByAppendingString:
		[[design remotePath] stringByAppendingPathComponent:@"main.css"]];
	
	return result;
}

- (NSString *)absoluteURLForResourceFile:(NSString *)aFile
{
	OBASSERT_NOT_REACHED("Mike thought this methods was unused.");
	
	NSString *result = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultResourcesPath"];
	if (![result hasSuffix:@"/"])
	{
		result = [result stringByAppendingString:@"/"];
	}
	result = [result stringByAppendingString:[aFile lastPathComponent]];
	
	// make into an absolute URL
	result = [[self publishedSiteURL] stringByAppendingString:result];

	return result;
}

/*!	Gets path to design's placeholder image, or nil
*/
- (NSString *)placeholderImagePathForDesignBundleIdentifier:(NSString *)aDesignBundleIdentifier
{
	KTDesign *design = [KTDesign pluginWithIdentifier:aDesignBundleIdentifier];
	return [design placeholderImagePath];
}

// TODO: hook these methods below back up, remember to add in Index plugins, etc.

/*! returns a recursively assembled NSMutableSet of NSBundles used for each active component */
- (NSMutableSet *)bundlesRequiredByPlugin:(id)aPlugin
{
    NSMutableSet *requiredBundles = [NSMutableSet set];

//    if ( [aPlugin isKindOfClass:[KTCollection class]] )
	if ( [aPlugin isKindOfClass:[KTPage class]] && [(KTPage *)aPlugin index])
    {
        // add Collection's bundle
        [requiredBundles addObject:[NSBundle bundleForClass:[aPlugin class]]];

        // add Collection's pages' bundles
        NSEnumerator *enumerator = [[(KTPage *)aPlugin children] objectEnumerator];
        id item;
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }

		// add sidebars
        enumerator = [[(KTPage *)aPlugin orderedSidebars] objectEnumerator];
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }
    }
    else if ( [aPlugin isKindOfClass:[KTPage class]] )
    {
        // add Page's bundle
        [requiredBundles addObject:[NSBundle bundleForClass:[aPlugin class]]];

        // add Page's elements
        NSEnumerator *enumerator = [[(KTPage *)aPlugin wrappedValueForKey:@"elements"] objectEnumerator];
        id item;
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }

        // add Page's callouts
        enumerator = [[(KTPage *)aPlugin orderedCallouts] objectEnumerator];
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }
    }
    else
    {
        // just add aComponent's bundle
        [requiredBundles addObject:[NSBundle bundleForClass:[aPlugin class]]];
    }

    return requiredBundles;
}

/*! walks through bundlesRequiredByPlugin and returns an array of bundleIdentifiers */
- (NSArray *)bundleIdentifiersRequiredByPlugin:(id)aPlugin
{
    NSMutableArray *bundles = [NSMutableArray array];
    NSEnumerator *enumerator = [[[self bundlesRequiredByPlugin:aPlugin] allObjects] objectEnumerator];
    id bundle;
    while ( bundle = [enumerator nextObject] )
    {
        if ( bundle != [NSBundle mainBundle] )
        {
            [bundles addObject:[bundle bundleIdentifier]];
        }
    }

    return [NSArray arrayWithArray:bundles];
}

- (KTPage *)pageForURLPath:(NSString *)path
{
	KTPage *result = nil;
	
	// skip media objects ... starting or containing Media if it's not a request in the main frame
	if ( NSNotFound == [path rangeOfString:[[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"]].location )
	{
		int whereTilde = [path rangeOfString:kKTPageIDDesignator options:NSBackwardsSearch].location;	// special mark internally to look up page IDs
		if (NSNotFound != whereTilde)
		{
			NSString *idString = [path substringFromIndex:whereTilde+[kKTPageIDDesignator length]];
			NSManagedObjectContext *context = [self managedObjectContext];
			result = [KTPage pageWithUniqueID:idString inManagedObjectContext:context];
		}
		else if ([path isEqualToString:@""] || [path hasSuffix:@"/"])
		{
			result = (KTPage *)[self root];
		}
	}
	return result;
}
@end
