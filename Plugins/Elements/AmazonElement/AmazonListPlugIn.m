//
//  AmazonListDelegate.m
//  Amazon List
//
//  Created by Mike on 22/12/2006.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "AmazonListPlugIn.h"

#import "APManualListProduct.h"
#import "APAmazonList.h"
#import "APInspectorController.h"

#import <AmazonSupport/AmazonSupport.h>


#import "NSURL+AmazonPagelet.h"


NSString * const APDisplayTabIdentifier = @"display";
NSString * const APProductsOrListTabIdentifier = @"productsOrList";


// LocalizedStringInThisBundle(@"Please add Amazon products to this list using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"Please specify an Amazon list (e.g. a wish list or listmania) to display using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"This is a placeholder; your Amazon list will appear here once published or if you enable live data feeds in the preferences.", "Placeholder text")
// LocalizedStringInThisBundle(@"This is a placeholder for an Amazon product; It will appear here once published or if you enable live data feeds in the preferences.", "Placeholder text")


@interface AmazonListPlugIn ()
@end


#pragma mark -


@implementation AmazonListPlugIn

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
	[AmazonOperation setAccessKeyID:@"AKIAILC2YRBONHT2JFVA"];	// amazon_nomoney@karelia.com secret key, no monetary accounts hooked up to this account!
	[AmazonOperation setHash:@"zxPWQOd2RAGbj2z4eQurrD1061DHuXZlgy8/ZpyC"];

	//[AmazonOperation setAssociateID:@"karelsofwa-20"];
}

- (id)initWithArguments:(NSDictionary *)arguments
{
    self = [super initWithArguments:arguments];
    
    
    // Observer storage
    [self addObserver:self
			  forKeyPaths:[NSSet setWithObjects:@"layout", @"showThumbnails", @"showTitles", @"automaticListCode", @"automaticListSorting", nil]
				  options:NSKeyValueObservingOptionNew
				  context:NULL];
	
	[self addObserver:self
			  forKeyPaths:[NSSet setWithObjects:@"listSource", @"manualListProducts", nil]
				  options:0
				  context:NULL];
    
    
    return self;
}

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	if (isNewlyCreatedObject)
	{
		// When creating a new pagelet, try to use the most recent Amazon store
		NSNumber *lastSelectedStore = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonLatestStore"];
		if (lastSelectedStore) [self setStore:[lastSelectedStore integerValue]];
		
		
		// And also most recent layout
		NSNumber *lastLayout = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonLastLayout"];
		if (lastLayout) [self setLayout:[lastLayout integerValue]];
		
		
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
			[self setListSource:AmazonPageletLoadFromList];
			[self setAutomaticListCode:[browserURL absoluteString]];
		}
		
		
		// If there is a predefined list ID, go with it
		NSString *defaultListCode = [[[self bundle] objectForInfoDictionaryKey:@"DefaultListIDs"]
			objectForKey:[AmazonECSOperation ISOCountryCodeOfStore:[self store]]];
		
		[self setAutomaticListCode:defaultListCode];
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
	if ([[self propertiesStorage] integerForKey:@"listSource"] == AmazonPageletLoadFromList) {
		[self loadAutomaticList];
	}
}

#pragma mark Dealloc

- (void)dealloc
{
	// Remove old observations
	[self removeObserver:self forKeyPaths:[NSSet setWithObjects:@"manualListProducts",
                                                                @"layout",
                                                                @"showThumbnails",
                                                                @"showTitles",
                                                                @"automaticListCode",
                                                                @"automaticListSorting",
                                                                @"listSource",
                                                                nil]];
	
	// End KVO
	[_products removeObserver:self
		  fromObjectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_products count])]
				   forKeyPaths:[NSSet setWithObjects:@"productCode", @"comment", @"loadingData", @"store", nil]];
					
	// Relase iVars
	[_products release];
	[myAutomaticList release];
	[myAutomaticListProductsToDisplay release];
	
	[super dealloc];
}

#pragma mark Properties

+ (NSSet *)plugInKeys
{
    return [NSSet setWithObjects:@"store", @"listSource", @"layout", @"showProductPreviews", @"frame", @"automaticListCode", @"automaticListType", @"automaticListSorting", @"showPrices", @"showThumbnails", @"showNewPricesOnly", @"showTitles", @"maxNumberProducts", @"showComments", @"showCreators", @"products", nil];
}

@synthesize store = _store;
- (void)setStore:(AmazonStoreCountry)newStore
{
    _store = newStore;
    
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

@synthesize listSource = _listSource;
@synthesize layout = _layout;
@synthesize showProductPreviews = _showProductPreviews;
@synthesize frame = _frame;

@synthesize automaticListCode = _automaticListCode;
@synthesize automaticListType = _automaticListType;
@synthesize automaticListSorting = _automaticListSorting;
@synthesize showPrices = _showPrices;
@synthesize showThumbnails = _showThumbnails;
@synthesize showNewPricesOnly = _showNewPricesOnly;
@synthesize showTitles = _showTitles;
@synthesize maxNumberProducts = _maxNumberProducts;
@synthesize showComments = _showComments;
@synthesize showCreators = _showCreators;
@synthesize centeredThumbnailWidths = _centeredThumbnailWidths;


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
	if (object != self)
    {
		return;
	}
	
	
	id changeNewObject = [change objectForKey:NSKeyValueChangeNewKey];
	id changeOldObject = [change objectForKey:NSKeyValueChangeOldKey];
	
	
	if ([keyPath isEqualToString:@"layout"])
	{
		// Save the new layout to the defaults
		[[NSUserDefaults standardUserDefaults] setObject:changeNewObject
												  forKey:@"AmazonLastLayout"];
	}
	else if ([keyPath isEqualToString:@"showThumbnails"])
	{
		// When setting showThumbnails to false, ensure showing titles is true
		if (changeNewObject == [NSNull null] || ![changeNewObject boolValue]) {
			[self setShowTitles:YES];
		}
	}
	else if ([keyPath isEqualToString:@"showTitles"])
	{
		// When setting showThumbnails to false, ensure showing titles is true
		if (changeNewObject == [NSNull null] || ![changeNewObject boolValue]) {
			[self setShowThumbnails:YES];
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

#pragma mark -
#pragma mark Store

- (BOOL)validateStore:(NSNumber **)store error:(NSError **)error
{
	// If there are existing list items, warn the user of the possible implications
	if ([self listSource] == AmazonPageletPickByHand)
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
				*store = [NSNumber numberWithInteger:[self store]];
			}
		}
	}
	else if ([[self propertiesStorage] integerForKey:@"listSource"] == AmazonPageletLoadFromList)
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
				*store = [[self propertiesStorage] valueForKey:@"store"];
			}
		}
	}
	
	return YES;
}

#pragma mark Markup

- (NSString *)layoutCSSClassName;
{
    return [[self class] CSSClassNameForLayout:[self layout]];
}

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
	BOOL result = ([[self propertiesStorage] integerForKey:@"listSource"] == AmazonPageletLoadFromList ||
				   [[self propertiesStorage] integerForKey:@"layout"] == APLayoutEnhanced ||
				   [[self propertiesStorage] integerForKey:@"layout"] == APLayoutRandom);
				   
	return result;
}

#pragma mark -
#pragma mark Product Previews

/*	If the user has requested it, add the product preview popups javascript to the end of the page */
- (void)addLevelTextToEndBody:(NSMutableString *)ioString forPage:(KTPage *)aPage	// level, since we don't want this on all pages on the site!
{
	if ([self showProductPreviews])
	{
		NSString *script = [AmazonECSOperation productPreviewsScriptForStore:[[self propertiesStorage] integerForKey:@"store"]];
		if (script)
		{
			// Only append the script if it's not already there (e.g. if there's > 1 element)
			if ([ioString rangeOfString:script].location == NSNotFound) {
				[ioString appendString:script];
			}
		}
	}
}

#pragma mark Inspector

+ (Class)inspectorViewControllerClass;
{
    return [APInspectorController class];
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
