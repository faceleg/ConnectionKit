//
//  AmazonListDelegate.m
//  Amazon List
//
//  Created by Mike on 22/12/2006.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "AmazonListDelegate.h"

#import "APManualListProduct.h"
#import "APAmazonList.h"

#import <AmazonSupport/AmazonSupport.h>
#import "SandvoxPlugin.h"


#import "NSURL+AmazonPagelet.h"


NSString * const APDisplayTabIdentifier = @"display";
NSString * const APProductsOrListTabIdentifier = @"productsOrList";


// LocalizedStringInThisBundle(@"Please add Amazon products to this list using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Please specify an Amazon list (e.g. a wish list or listmania) to display using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"This is a placeholder; your Amazon list will appear here once published or if you enable live data feeds in the preferences.", "Placeholder text")
// LocalizedStringInThisBundle(@"This is a placeholder for an Amazon product; It will appear here once published or if you enable live data feeds in the preferences.", "Placeholder text")


@interface AmazonListDelegate (Private)

- (void)storeDidChangeTo:(AmazonStoreCountry)newStore;

- (void)loadAutomaticList;

@end


@implementation AmazonListDelegate

#pragma mark -
#pragma mark Initalization

+ (void)initialize
{
	// Register value transformers
	KSIsEqualValueTransformer *transformer = nil;
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutCentered]];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsCentered"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutBullets]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsNotBullets"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutEnhanced]];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsEnhanced"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutEnhanced]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsNotEnhanced"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:APLayoutRandom]];
	[transformer setNegatesResult:YES];
	[NSValueTransformer setValueTransformer:transformer forName:@"AmazonListLayoutIsNotRandom"];
	[transformer release];
	
	transformer = [[KSIsEqualValueTransformer alloc] initWithComparisonValue:[NSNumber numberWithInt:AmazonWishList]];
	[NSValueTransformer setValueTransformer:transformer forName:@"AutomaticAmazonListTypeIsWishList"];
	[transformer release];
	
	
	
	// Prepare Amazon operations
	[AmazonOperation setAccessKeyID:@"1G2SED49VBVR5P60KB82"];	// associated with amazon_affiliate@karelia.com
	[AmazonOperation setSecretKeyID:@"4WjVNkO5E83Vp3ybV2cGg5kkQG0LPLQG3JRf8Z+X"];	// associated with amazon_affiliate@karelia.com

	//[AmazonOperation setAssociateID:@"karelsofwa-20"];
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	KTAbstractElement *element = [self delegateOwner];
    
    
    if (isNewlyCreatedObject)
	{
		// When creating a new pagelet, try to use the most recent Amazon store
		NSNumber *lastSelectedStore = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonLatestStore"];
		if (lastSelectedStore)
			[element setValue:lastSelectedStore forKey:@"store"];
		
		
		// And also most recent layout
		NSNumber *lastLayout = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonLastLayout"];
		if (lastLayout) {
			[element setValue:lastLayout forKey:@"layout"];
		}
		
		
		// Get the current URL from Safari and look for a possible product or list
		NSURL *browserURL = nil;
		[NSAppleScript getWebBrowserURL:&browserURL title:NULL source:NULL];
		
		NSString *ASIN = [browserURL amazonProductASIN];	// Product
		if (ASIN && ![ASIN isEqualToString:@""])
		{
			APManualListProduct *product = [[APManualListProduct alloc] init];
			[self insertObject:product inProductsAtIndex:0];
			
			[product setProductCode:[browserURL absoluteString]];
			[product release];
		}
		
		NSString *listID = nil;	// List
		[browserURL getAmazonListType:NULL andID:&listID];
		if (listID && ![listID isEqualToString:@""])
		{
			[element setInteger:AmazonPageletLoadFromList forKey:@"listSource"];
			[element setValue:[browserURL absoluteString] forKey:@"automaticListCode"];
		}
		
		
		// If there is a predefined list ID, go with it
		NSString *defaultListCode = [[[self bundle] objectForInfoDictionaryKey:@"DefaultListIDs"]
			objectForKey:[AmazonECSOperation ISOCountryCodeOfStore:[element integerForKey:@"store"]]];
		
		[element setValue:defaultListCode forKey:@"automaticListCode"];
	}
	else
	{
		// Load manual list products
		[self unarchiveManualListProductsFromPluginProperties];
	}
    
    
    // Make sure we have a valid layout CSS class
    if (![element valueForKey:@"layoutCSSClassName"])
    {
        [self plugin:element didSetValue:[element valueForKey:@"layout"] forPluginKey:@"layout" oldValue:nil];
    }
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	// Look for an Amazon URL
	NSString *URLString = [aDataSourceDictionary valueForKey:kKTDataSourceURLString];
	if (URLString)
	{
		NSURL *URL = [NSURL URLWithString:URLString];
		NSString *ASIN = [URL amazonProductASIN];	// Product
		
        if (ASIN && ![ASIN isEqualToString:@""])
		{
			APManualListProduct *product = [[APManualListProduct alloc] init];
			[self insertObject:product inProductsAtIndex:0];
			
			[product setProductCode:URLString];
            [product validateValueForKey:@"productCode" error:NULL];
			[product release];
		}
	}
}

- (void)awakeFromNib
{
	// Load the automatic list if needed
	if ([[self delegateOwner] integerForKey:@"listSource"] == AmazonPageletLoadFromList) {
		[self loadAutomaticList];
	}
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	// End KVO
	[myProducts removeObserver:self
		  fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [myProducts count])]
				   forKeyPaths:[NSSet setWithObjects:@"productCode", @"comment", @"loadingData", @"store", nil]];
					
	// Relase iVars
	[myProducts release];
	[myAutomaticList release];
	[myAutomaticListProductsToDisplay release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark KVC / KVO

- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError
{
	// Slightly hacky - we're performing our own validation when the store is changed
	if ([inKeyPath isEqualToString:@"store"])
	{
		return [self validateValue:ioValue forKey:@"store" error:outError];
	}
	else if ([inKeyPath isEqualToString:@"centeredThumbnailWidths"])
	{
		return [self validateValue:ioValue forKey:@"centeredThumbnailWidths" error:outError];
	}
	else if ([inKeyPath isEqualToString:@"automaticListCode"])
	{
		return [self validateValue:ioValue forKey:@"automaticListCode" error:outError];
	}
	else
	{
		return [super validatePluginValue:ioValue forKeyPath:inKeyPath error:outError];
	}
}

/*	We wish to observe various changes to the plugin
 */
- (void)setDelegateOwner:(id)newOwner
{
	// Remove old observations
	[[self delegateOwner] removeObserver:self forKeyPaths:[NSSet setWithObjects:@"manualListProducts",
																				@"store",
																				@"layout",
																				@"showThumbnails",
																				@"showTitles",
																				@"automaticListCode",
																				@"automaticListSorting",
																				@"listSource",
																				nil]];
	
	[super setDelegateOwner:newOwner];
	
	[newOwner addObserver:self
			   forKeyPath:@"store"
				  options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew)
				  context:NULL];
	
	[newOwner addObserver:self
			  forKeyPaths:[NSSet setWithObjects:@"layout", @"showThumbnails", @"showTitles", @"automaticListCode", @"automaticListSorting", nil]
				  options:NSKeyValueObservingOptionNew
				  context:NULL];
	
	[newOwner addObserver:self
			  forKeyPaths:[NSSet setWithObjects:@"listSource", @"manualListProducts", nil]
				  options:0
				  context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
					    change:(NSDictionary *)change
					   context:(void *)context
{
	// Pass on manual list observations
	if ([[self products] containsObjectIdenticalTo:object])
	{
		[self observeValueForKeyPath:keyPath ofManualListProduct:object change:change context:context];
	}
	
	// Bail if the object's not our associated plugin
	if (object != [self delegateOwner]) {
		return;
	}
	
	
	id changeNewObject = [change objectForKey:NSKeyValueChangeNewKey];
	id changeOldObject = [change objectForKey:NSKeyValueChangeOldKey];
	
	
	if ([keyPath isEqualToString:@"manualListProducts"])
	{
		if (!manualListIsBeingArchivedOrUnarchived) {
			[self unarchiveManualListProductsFromPluginProperties];
		}
	}
	else if ([keyPath isEqualToString:@"store"])
	{
		if (changeNewObject != [NSNull null] && ![changeNewObject isEqual:changeOldObject])
        {
			[self storeDidChangeTo:[changeNewObject intValue]];
		}
	}
	else if ([keyPath isEqualToString:@"layout"])
	{
		// Save the new layout to the defaults
		[[NSUserDefaults standardUserDefaults] setObject:changeNewObject
												  forKey:@"AmazonLastLayout"];
	}
	else if ([keyPath isEqualToString:@"showThumbnails"])
	{
		// When setting showThumbnails to false, ensure showing titles is true
		if (changeNewObject == [NSNull null] || ![changeNewObject boolValue]) {
			[[self delegateOwner] setBool:YES forKey:@"showTitles"];
		}
	}
	else if ([keyPath isEqualToString:@"showTitles"])
	{
		// When setting showThumbnails to false, ensure showing titles is true
		if (changeNewObject == [NSNull null] || ![changeNewObject boolValue]) {
			[[self delegateOwner] setBool:YES forKey:@"showThumbnails"];
		}
	}
	else if ([keyPath isEqualToString:@"automaticListCode"] || [keyPath isEqualToString:@"automaticListSorting"])
	{
		[self loadAutomaticList];
	}
	
	//	Changes to the layout or list source need us to recalculate the availability of the
	//	"showPrices" appearance option
	if ([keyPath isEqualToString:@"layout"] || [keyPath isEqualToString:@"listSource"])
	{
		[self willChangeValueForKey:@"showPricesOptionAvailable"];
		[self didChangeValueForKey:@"showPricesOptionAvailable"];
	}
}

- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
    if ([key isEqualToString:@"layout"])
    {
        [plugin setValue:[[self class] CSSClassNameForLayout:[value intValue]]
                  forKey:@"layoutCSSClassName"];
    }
}

#pragma mark -
#pragma mark Store

- (BOOL)validateStore:(NSNumber **)store error:(NSError **)error
{
	// If there are existing list items, warn the user of the possible implications
	if ([[self delegateOwner] integerForKey:@"listSource"] == AmazonPageletPickByHand)
	{
		if ([self products] && [[self products] count] > 0)
		{
			NSString *titleFormat = LocalizedStringInThisBundle(@"Change to the %@ Amazon store?", "alert title");
			NSString *storeName = [AmazonECSOperation nameOfStore:[*store intValue]];	// already localized
			NSString *title = [NSString stringWithFormat:titleFormat, storeName];
			
			NSAlert *alert =
				[NSAlert alertWithMessageText:title
								defaultButton:LocalizedStringInThisBundle(@"Change Store", "button text")
							  alternateButton:LocalizedStringInThisBundle(@"Cancel", "button text")
								  otherButton:nil
					informativeTextWithFormat:LocalizedStringInThisBundle(@"Not all products are available in every country. By changing the store, some of the products in your list may no longer be found.", "alert message")];
			
			int result = [alert runModal];
			if (result == NSAlertAlternateReturn) {
				*store = [[self delegateOwner] valueForKey:@"store"];
			}
		}
	}
	else if ([[self delegateOwner] integerForKey:@"listSource"] == AmazonPageletLoadFromList)
	{
		NSArray *listProducts = [[self automaticList] products];
		if (listProducts && [listProducts count] > 0)
		{
			NSString *titleFormat = LocalizedStringInThisBundle(@"Change to the %@ Amazon store?", "alert title");
			NSString *storeName = [AmazonECSOperation nameOfStore:[*store intValue]];	// already localized
			NSString *title = [NSString stringWithFormat:titleFormat, storeName];
			
			NSAlert *alert =
				[NSAlert alertWithMessageText:title
								defaultButton:LocalizedStringInThisBundle(@"Change Store", "button text")
							  alternateButton:LocalizedStringInThisBundle(@"Cancel", "button text")
								  otherButton:nil
					informativeTextWithFormat:LocalizedStringInThisBundle(@"Amazon lists are normally specific to a particular country. If you change the store your list may no longer be found.", "alert message")];
			
			int result = [alert runModal];
			if (result == NSAlertAlternateReturn) {
				*store = [[self delegateOwner] valueForKey:@"store"];
			}
		}
	}
	
	return YES;
}

- (void)storeDidChangeTo:(AmazonStoreCountry)newStore
{
	// Save the new value in the prefs for future plugins
	[[NSUserDefaults standardUserDefaults] setInteger:newStore forKey:@"AmazonLatestStore"];
	
	// Reload the manual and automatic lists
	[self loadAutomaticList];
	
	NSEnumerator *enumerator = [[self products] objectEnumerator];
	APManualListProduct *product;
	while (product = [enumerator nextObject]) {
		[product setStore:newStore];
	}
	
	[self loadAllManualListProducts];
}

#pragma mark -
#pragma mark HTML

+ (NSString *)CSSClassNameForLayout:(APListLayout)layout;
{
	NSString *result = nil;
	
	switch (layout)
	{
		case APLayoutLeft:
			result = @"amazonListLayoutLeft";
			break;
		case APLayoutRight:
			result = @"amazonListLayoutRight";
			break;
		case APLayoutAlternating:
			result = @"amazonListLayoutAlt";
			break;
		case APLayoutCentered:
			result = @"amazonListLayoutCenter";
			break;
		case APLayoutTwoUp:
			result = @"amazonListLayoutTwoUp";
			break;
		case APLayoutEnhanced:
			result = @"amazonListLayoutEnhanced";
			break;
		case APLayoutRandom:
			result = @"amazonListLayoutRandom";
			break;
        default:
            result = @"";
            break;
	}
	
	return result;
}

- (BOOL)showPricesOptionAvailable
{
	// Not available in all circumstances
	BOOL result = ([[self delegateOwner] integerForKey:@"listSource"] == AmazonPageletLoadFromList ||
				   [[self delegateOwner] integerForKey:@"layout"] == APLayoutEnhanced ||
				   [[self delegateOwner] integerForKey:@"layout"] == APLayoutRandom);
				   
	return result;
}

#pragma mark -
#pragma mark Product Previews

/*	If the user has requested it, add the product preview popups javascript to the end of the page */
- (void)addLevelTextToEndBody:(NSMutableString *)ioString forPage:(KTPage *)aPage	// level, since we don't want this on all pages on the site!
{
	if ([[self delegateOwner] boolForKey:@"showProductPreviews"])
	{
		NSString *script = [AmazonECSOperation productPreviewsScriptForStore:[[self delegateOwner] integerForKey:@"store"]];
		if (script)
		{
			// Only append the script if it's not already there (e.g. if there's > 1 element)
			if ([ioString rangeOfString:script].location == NSNotFound) {
				[ioString appendString:script];
			}
		}
	}
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
	return [KSWebLocation webLocationPasteboardTypes];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)sender
{
    return 1;
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    KTSourcePriority result = KTSourcePriorityNone;
    
	NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pboard
													  readWeblocFiles:YES
													   ignoreFileURLs:YES];
	
	if (webLocations && [webLocations count] > dragIndex)
	{
		NSURL *URL = [[webLocations objectAtIndex:dragIndex] URL];
		if ([URL amazonProductASIN])
		{
			result = KTSourcePriorityIdeal;
		}
	}
	
	return result;
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;
{
    BOOL result = NO;
    
    NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pasteboard
													  readWeblocFiles:YES
													   ignoreFileURLs:YES];
	
	
	if (webLocations && [webLocations count] > dragIndex)
	{
		NSURL *URL = [[webLocations objectAtIndex:dragIndex] URL];
		NSString *title = [[webLocations objectAtIndex:dragIndex] title];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (!KSISNULL(title))
		{
			[aDictionary setObject:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}

@end
