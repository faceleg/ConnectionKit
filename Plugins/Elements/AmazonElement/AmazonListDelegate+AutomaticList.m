//
//  AmazonListDelegate+AutomaticList.m
//  Amazon List
//
//  Created by Mike on 30/08/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "AmazonListDelegate.h"

#import "NSURL+AmazonPagelet.h"


@implementation AmazonListDelegate (AutomaticList)

#pragma mark Accessors

/*	We're actually being a bit naughty here. Although this is just validation we're also setting some values
 *	for other keys which we shouldn't really do. However I can't think of a better way of tackling this.
 */
- (BOOL)validateAutomaticListCode:(NSString **)code error:(NSError **)error
{
	NSString *listID = nil;
	AmazonListType listType = AmazonListTypeUnknown;
	
	
	// Is the code a URL?
	NSURL *URL = nil;
	if (*code) {
		URL = [NSURL URLWithString:*code];
	}
	
	if (URL && [URL hasNetworkLocation])
	{
		// Is it an Amazon URL?
		AmazonStoreCountry store = [URL amazonStore];
		if (store != AmazonStoreUnknown)
		{
			// Set our store from the URL
			[[self propertiesStorage] setInteger:store forKey:@"store"];
			
			// Attempt to get the list type and ID from the URL
			[URL getAmazonListType:&listType andID:&listID];
			
			if (!listID)
			{
				
				// Amazon can very irratatingly provide us with a URL with no ID in it.
				if ([[URL path] hasPrefix:@"/gp/registry/wishlist"])
				{
					
					// Let's be sneaky and try to pull the HTML from Safari, searching it for the ID
					NSURL *safariURL = nil;
					NSString *HTML = nil;
					[NSAppleScript getWebBrowserURL:&safariURL title:NULL source:&HTML];
					
					if (safariURL && HTML && [safariURL isEqual:URL])
					{
						// Search for something good
						NSScanner *scanner = [NSScanner scannerWithString:HTML];
						
						[scanner scanUpToString:@"&colid=" intoString:NULL];
						[scanner scanString:@"&colid=" intoString:NULL];
						
						NSCharacterSet *characters = [NSCharacterSet alphanumericASCIICharacterSet];
						[scanner scanCharactersFromSet:characters intoString:&listID];
					}
					
					if (!listID)
					{
						// If that didn't work, alert the user
						NSAlert *alert = [[[NSAlert alloc] init] autorelease];
						[alert setMessageText:LocalizedStringInThisBundle(@"The URL entered is not the public URL of an Amazon list.", "alert title")];
						[alert setInformativeText:LocalizedStringInThisBundle(@"Please click the purple help button to view instructions on how to find the public URL of an Amazon list.", "alert text")];
						[alert addButtonWithTitle:LocalizedStringInThisBundle(@"Close", "button")];
						[[[alert buttons] objectAtIndex:0] setKeyEquivalent:@""];	// We don't want the user blindly hitting enter
						[alert setShowsHelp:YES];
						[alert setDelegate:self];
						
						[alert runModal];
						
						[self setAutomaticList:nil];
					}
				}
			}
		}
	}
	
	
	// If we had any success interpreting the code, save it back as the validated value
	if (listID) {
		*code = listID;
	}
	[[self propertiesStorage] setInteger:listType forKey:@"automaticListType"];
	
	return YES;
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	return [NSHelpManager gotoHelpAnchor:@"Locating_an_Amazon_List's_Public_URL"];
}

#pragma mark The list

- (APAmazonList *)automaticList { return myAutomaticList; }

- (void)setAutomaticList:(APAmazonList *)list
{
	[list retain];
	[myAutomaticList release];
	myAutomaticList = list;
}

- (NSArray *)automaticListProductsToDisplay { return myAutomaticListProductsToDisplay; }

- (void)setAutomaticListProductsToDisplay:(NSArray *)products
{
	products = [products copy];
	[myAutomaticListProductsToDisplay release];
	myAutomaticListProductsToDisplay = products;
}

#pragma mark List loading

- (void)loadAutomaticList
{
	// Don't bother if there is no list code set
	NSString *listCode = [[self propertiesStorage] valueForKey:@"automaticListCode"];
	if (!listCode || [listCode isEqualToString:@""])
	{
		[self setAutomaticList:nil];
		return;
	}
	
	
	// Begin loading
	APAmazonList *list = [[APAmazonList alloc] initWithID:listCode
												 listType:[[self propertiesStorage] integerForKey:@"automaticListType"]
													store:[[self propertiesStorage] integerForKey:@"store"]
												  sorting:[[self propertiesStorage] integerForKey:@"automaticListSorting"]
												 delegate:self];
	
	[self setAutomaticList:list];
	[list release];
}

- (void)amazonListLookupOperationsDidFinish:(APAmazonList *)list
{
	// Ignore if not our list
	if (list != [self automaticList]) {
		return;
	}
	
	// Was a list found?
	BOOL listFound = ([list products] && [[list products] count] > 0);
	if (listFound)
	{
		// Store the list type, but do NOT make it an undoable operation since this would register a second undo
		// command for the process of loading a list.
		NSManagedObjectContext *moc = [[self delegateOwner] managedObjectContext];
		[moc processPendingChanges];
		[[moc undoManager] disableUndoRegistration];
		[[self propertiesStorage] setInteger:[list listType] forKey:@"automaticListType"];
		[moc processPendingChanges];
		[[moc undoManager] enableUndoRegistration];
	}
}

# pragma mark HTML

- (NSURL *)kareliaHTMLURL
{
	NSURL *serviceURL = [NSURL URLWithString:@"http://service.karelia.com/amazonList.php"];
	
	NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity: 19];
	
	[query setValue:@"on" forKey:@"js"];	// Enable javascript
	[query setValue:[NSString stringWithFormat:@"%i", [[self propertiesStorage] integerForKey:@"store"]] forKey:@"s"];	// Store
	[query setValue:[[self propertiesStorage] valueForKey:@"automaticListCode"] forKey:@"id"];		// listID
	[query setValue:[NSString stringWithFormat:@"%i", [[self propertiesStorage] integerForKey:@"automaticListType"]] forKey:@"t"];	// listType
	[query setValue:[NSString stringWithFormat:@"%i", [[self propertiesStorage] integerForKey:@"automaticListSorting"]] forKey:@"o"];	// Sorting
	[query setValue:[NSString stringWithFormat:@"%i", [[self propertiesStorage] integerForKey:@"layout"]] forKey:@"l"];	// layout
	[query setValue:[NSString stringWithFormat:@"%u", [[self propertiesStorage] integerForKey:@"centeredThumbnailWidths"]] forKey:@"w"];	// Width of centered thubmnails
	[query setValue:[NSString stringWithFormat:@"%i", [[self propertiesStorage] integerForKey:@"frame"]] forKey:@"f"];	// Frame
	
	// Number products
	int maxNoProducts = [[self propertiesStorage] integerForKey:@"maxNumberProducts"];
	if (maxNoProducts > 0) {
		[query setValue:[NSString stringWithFormat:@"%i", maxNoProducts] forKey:@"m"];
	}
	
	if ([[self propertiesStorage] boolForKey:@"showThumbnails"]) {
		[query setValue:@"on" forKey:@"th"];
	}
	if ([[self propertiesStorage] boolForKey:@"showTitles"]) {
		[query setValue:@"on" forKey:@"ti"];
	}
	if ([[self propertiesStorage] boolForKey:@"showCreators"]) {
		[query setValue:@"on" forKey:@"cr"];
	}
	if ([[self propertiesStorage] boolForKey:@"showComments"]) {
		[query setValue:@"on" forKey:@"cm"];
	}
	if ([[self propertiesStorage] boolForKey:@"showPrices"]) {
		[query setValue:@"on" forKey:@"pr"];
	}
	if ([[self propertiesStorage] boolForKey:@"showNewPricesOnly"]) {
		[query setValue:@"on" forKey:@"np"];
	}
	if ([[self propertiesStorage] boolForKey:@"showLinkToList"]) {
		[query setValue:@"on" forKey:@"fl"];
	}
	
	// Whether products should be bought for the visitor or site owner
	if ([[self propertiesStorage] integerForKey:@"automaticListType"] == AmazonWishList ||
		[[self propertiesStorage] integerForKey:@"automaticListType"] == AmazonWeddingRegistry)
	{
		[query setValue:@"on" forKey:@"me"];
	}
	
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"DebugAmazonListService"]) {
		[query setValue:@"on" forKey:@"dev"];
	}
	
	
	
	return [NSURL URLWithBaseURL:serviceURL parameters:query];
}

@end
