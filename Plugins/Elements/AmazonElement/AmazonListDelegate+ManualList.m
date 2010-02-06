//
//  AmazonListDelegate+ManualList.m
//  Amazon List
//
//  Created by Mike on 30/08/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "AmazonListPlugIn.h"

#import "APAmazonProduct.h"
#import "APManualListProduct.h"
#import "NSURL+AmazonPagelet.h"


@interface AmazonListPlugIn (ManualListPrivate)
- (NSMutableArray *)_products;
@end


@implementation AmazonListPlugIn (ManualList)

#pragma mark -
#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath
		   ofManualListProduct:(APManualListProduct *)product
						change:(NSDictionary *)change
					   context:(void *)context
{
	// Changes to the comment or product code of a product must be stored
	if ([keyPath isEqualToString:@"productCode"])
	{
		[product load];
		[self archiveManualListProductsAndRegisterUndoOperation:YES];
	}
	else if ([keyPath isEqualToString:@"comment"])
	{
		[self archiveManualListProductsAndRegisterUndoOperation:YES];
	}
	else if ([keyPath isEqualToString:@"loadingData"])
	{
		if (![product isLoadingData]) {
			[self archiveManualListProductsAndRegisterUndoOperation:NO];
		}
	}
	else if ([keyPath isEqualToString:@"store"])
	{
		// If the store of a product is changed either reset it to the default or change our value to match
		AmazonStoreCountry productStore = [product store];
		AmazonStoreCountry currentStore = [[self propertiesStorage] integerForKey:@"store"];
		
		if (productStore == currentStore) {
			return;
		}
		
		unsigned count = [self numberOfManualProductsWithAProductCode];
		if (count == 0 || (count == 1 & [[self products] containsObjectIdenticalTo:product]))
		{
			[[self propertiesStorage] setInteger:productStore forKey:@"store"];
		}
		else
		{
			[product setStore:currentStore];
		}
	}
}

#pragma mark -
#pragma mark Products Array

- (NSArray *)products { return [self _products]; }

- (void)insertObject:(APManualListProduct *)product inProductsAtIndex:(unsigned)index
{
	// If the product's store differs to ours, reset it to the default or change our value to match
	AmazonStoreCountry productStore = [product store];
	AmazonStoreCountry currentStore = [[self propertiesStorage] integerForKey:@"store"];
	
	if ([self numberOfManualProductsWithAProductCode] == 0) {
		[[self propertiesStorage] setInteger:productStore forKey:@"store"];
	}
	else {
		[product setStore:currentStore];
	}
	
	[[self _products] insertObject:product atIndex:index];
	
	
	// Observe various keys of the product
	[product addObserver:self
			 forKeyPaths:[NSSet setWithObjects:@"productCode", @"comment", @"loadingData", @"store", nil]
				 options:0
				 context:nil];
	
	
	// Archive the list if needed
	if (!manualListIsBeingArchivedOrUnarchived)
	{
		[self archiveManualListProductsAndRegisterUndoOperation:YES];
	}
	
	// Attempt to load any product that hasn't yet been loaded
	if (![product ASIN])
	{
		[product load];
	}
}

- (void)removeObjectFromProductsAtIndex:(unsigned)index
{
	NSMutableArray *products = [self _products];
	
	APAmazonProduct *product = [products objectAtIndex:index];
	[product removeObserver:self
				forKeyPaths:[NSSet setWithObjects:@"productCode", @"comment", @"loadingData", @"store", nil]];
	
	[products removeObjectAtIndex:index];
	
	if (!manualListIsBeingArchivedOrUnarchived) {
		[self archiveManualListProductsAndRegisterUndoOperation:YES];
	}
}

- (NSMutableArray *)_products
{
	if (!myProducts) {
		myProducts = [[NSMutableArray alloc] init];
	}
	
	return myProducts;
}

- (unsigned)numberOfManualProductsWithAProductCode
{
	// Is this the only product that has a product code?
	unsigned productsCount = 0;
	NSEnumerator *enumerator = [[self products] objectEnumerator];
	APManualListProduct *aProduct;
	
	while (aProduct = [enumerator nextObject])
	{
		if ([aProduct productCode]) {
			productsCount++;
		}
	}
	
	return productsCount;
}

#pragma mark Product Storage

/*	Archives the manual list of products into the Core Data store.
 *	Specify _registerUndo_ to choose if this should be undoable
 */
- (void)archiveManualListProductsAndRegisterUndoOperation:(BOOL)registerUndo
{
	LOG((@"Archiving manual Amazon products list"));
	
	manualListIsBeingArchivedOrUnarchived = YES;
	
	if (!registerUndo) [self disableUndoRegistration];
	
	NSData *productsData = [NSKeyedArchiver archivedDataWithRootObject:[self products]];
	[[self propertiesStorage] setObject:productsData forKey:@"manualListProducts"];
	
	if (!registerUndo) [self enableUndoRegistration];
	
	manualListIsBeingArchivedOrUnarchived = NO;
}

- (void)unarchiveManualListProductsFromPluginProperties
{
	manualListIsBeingArchivedOrUnarchived = YES;
	
	NSData *productsData = [[self propertiesStorage] objectForKey:@"manualListProducts"];
	
	NSArray *products = nil;
	if (productsData) {
		products = [NSKeyedUnarchiver unarchiveObjectWithData:productsData];
	}
	
	NSMutableArray *editableProducts = [self mutableArrayValueForKey:@"products"];
	[editableProducts setArray:products];
	
	manualListIsBeingArchivedOrUnarchived = NO;
}

#pragma mark -
#pragma mark Product Loading

- (void)loadAllManualListProducts
{
	[[self products] makeObjectsPerformSelector:@selector(load)];
}

#pragma mark Product HTML

- (NSArray *)productsSuitableForPublishing
{
	NSMutableArray *result = [NSMutableArray array];
	
	// Return the products which have a product code, URL and title.
	NSArray *products = [self products];
	NSEnumerator *enumerator = [products objectEnumerator];
	APManualListProduct *product;
	
	while (product = [enumerator nextObject])
	{
		if ([product productCode] && [product URL] && [product title]) {
			[result addObject:product];
		}
	}
	
	return result;
}

- (NSURL *)randomLayoutIFrameURL
{
	return [AmazonECSOperation enhancedProductLinkForASINs:[[self productsSuitableForPublishing] valueForKey:@"ASIN"]
													 store:[[self propertiesStorage] integerForKey:@"store"]];
}

#pragma mark -
#pragma mark Thumbnails

- (unsigned)thumbnailWidths
{
	unsigned result = 0;
	
	switch ([[self propertiesStorage] integerForKey:@"layout"])
	{
		case APLayoutLeft:
		case APLayoutRight:
		case APLayoutAlternating:
			result = 55;
			break;
		case APLayoutCentered:
			result = [self centeredThumbnailWidths];
			break;
		case APLayoutTwoUp:
			result = 85;
			break;
	}
	
	if ([[self propertiesStorage] integerForKey:@"frame"] == APFrameThumbnails) {
		result -= 8;
	}
	
	return result;
}

- (NSString *)thumbnailWidthsString
{
	NSString *result = [NSString stringWithFormat:@"%upx", [self thumbnailWidths]];
	return result;
}

- (BOOL)validateCenteredThumbnailWidths:(id *)width error:(NSError **)error
{
	int suggestedWidth = [*width intValue];
	int correctedWidth = 0;
	
	// Round to the nearest value out of 32, 48, 64, 80 and 100
	if (suggestedWidth < 40) {
		correctedWidth = 32;
	}
	else if (suggestedWidth < 56) {
		correctedWidth = 48;
	}
	else if (suggestedWidth < 72) {
		correctedWidth = 64;
	}
	else if (suggestedWidth < 90) {
		correctedWidth = 80;
	}
	else {
		correctedWidth = 100;
	}
	
	*width = [NSNumber numberWithInt:correctedWidth];
	return YES;
}

- (NSURL *)thumbnailPlaceholderURL
{
	NSString *path = [[self bundle] pathForResource:@"Thumbnail placeholder" ofType:@"png"];
	return [NSURL fileURLWithPath:path];
}

@end
