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

#import "Registration.h"


@implementation KTDocument (Lookup)

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

- (NSString *) defaultRootPageTitleText
{
	NSString *result = [[NSBundle mainBundle] localizedStringForString:@"defaultRootPageTitleText" language:[[[[self documentInfo] root] master] valueForKey:@"language"]
		fallback:NSLocalizedStringWithDefaultValue(@"defaultRootPageTitleText", nil, [NSBundle mainBundle], @"Home Page", @"Title of initial home page")];
	return result;
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
