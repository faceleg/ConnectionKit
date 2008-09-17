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
#import "KTDocumentInfo.h"
#import "KTDocWindowController.h"
#import "KTHostProperties.h"
#import "KTInfoWindowController.h"
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

- (BOOL)hasRSSFeeds;	// determine if we need to show export panel
{
	NSMutableArray *RSSCollectionArray = [NSMutableArray array];
	
	KTPage *root = [[self documentInfo] root];
	[root makeSelfOrDelegatePerformSelector:@selector(addRSSCollectionsToArray:forPage:) withObject:RSSCollectionArray withPage:root recursive:YES];
	return [RSSCollectionArray count] > 0;
}

- (NSString *)siteTitleHTML
{
	return [[[self displayName] stringByDeletingPathExtension] stringByEscapingHTMLEntities];		// get the default title from the document name
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

// NSLocalizedStringWithDefaultValue(@"navigateNextHTML",		nil, [NSBundle mainBundle], @"Next",		@"alt text of navigation button"),	@"navigateNextHTML",
// NSLocalizedStringWithDefaultValue(@"navigateListHTML",		nil, [NSBundle mainBundle], @"List",		@"alt text of navigation button"),	@"navigateListHTML",
// NSLocalizedStringWithDefaultValue(@"navigatePreviousHTML",	nil, [NSBundle mainBundle], @"Previous",	@"alt text of navigation button"),	@"navigatePreviousHTML",
// NSLocalizedStringWithDefaultValue(@"navigateMainHTML",		nil, [NSBundle mainBundle], @"Main",		@"text of navigation button"),		@"navigateMainHTML",

// Return the appropriate localization for these default values.

- (NSString *)titleHTML
{
	// Note: the use of NS...Localized...String...With...Default...Value below gets this string picked up by genstrings for 
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"titleHTML" language:[[[[self documentInfo] root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"titleHTML", nil, [NSBundle mainBundle], @"Untitled",  @"Default Title of page")
		];
	return result;
}
- (NSString *) siteSubtitleHTML
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"siteSubtitleHTML" language:[[[[self documentInfo] root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"siteSubtitleHTML", nil, [NSBundle mainBundle], @"This is the subtitle for your site.",  @"Default introduction statement for a page")
		];
	return result;
}
- (NSString *) defaultRootPageTitleText
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"defaultRootPageTitleText" language:[[[[self documentInfo] root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"defaultRootPageTitleText", nil, [NSBundle mainBundle], @"Home Page", @"Title of initial home page")];
	return result;
}

// DERIVED

- (NSString *)siteSubtitleText
{
	NSString *result = [self siteSubtitleHTML];
	if (![result isEqualToString:@""])
	{
		result = [result stringByConvertingHTMLToPlainText];
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


// TODO: hook these methods below back up, remember to add in Index plugins, etc.

/*! returns a recursively assembled NSMutableSet of NSBundles used for each active component */
- (NSMutableSet *)bundlesRequiredByPlugin:(id)aPlugin
{
    NSMutableSet *requiredBundles = [NSMutableSet set];

//    if ( [aPlugin isKindOfClass:[KTCollection class]] )
	if ( [aPlugin isKindOfClass:[KTPage class]] && [(KTPage *)aPlugin index])
    {
        // add Collection's bundle
        NSBundle *bundle = [NSBundle bundleForClass:[aPlugin class]];
        OBASSERT(bundle);
        [requiredBundles addObject:bundle];

        // add Collection's pages' bundles
        NSEnumerator *enumerator = [[(KTPage *)aPlugin children] objectEnumerator];
        id item;
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }

		// add sidebars
        enumerator = [[(KTPage *)aPlugin pageletsInLocation:KTSidebarPageletLocation] objectEnumerator];
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }
    }
    else if ( [aPlugin isKindOfClass:[KTPage class]] )
    {
        // add Page's bundle
        NSBundle *bundle = [NSBundle bundleForClass:[aPlugin class]];
        OBASSERT(bundle);
        [requiredBundles addObject:bundle];

        // add Page's elements
        NSEnumerator *enumerator = [[(KTPage *)aPlugin wrappedValueForKey:@"elements"] objectEnumerator];
        id item;
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }

        // add Page's callouts
        enumerator = [[(KTPage *)aPlugin callouts] objectEnumerator];
        while ( item = [enumerator nextObject] )
        {
            [requiredBundles unionSet:[self bundlesRequiredByPlugin:item]];
        }
    }
    else
    {
        // just add aComponent's bundle
        NSBundle *bundle = [NSBundle bundleForClass:[aPlugin class]];
        OBASSERT(bundle);
        [requiredBundles addObject:bundle];
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
            OBASSERT([bundle bundleIdentifier]);
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
		else if ([path hasSuffix:@"/"])
		{
			result = (KTPage *)[[self documentInfo] root];
		}
	}
	return result;
}
@end
