//
//  APAmazonList.m
//  Amazon List
//
//  Created by Mike on 10/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "APAmazonList.h"
#import "APAutomaticListProduct.h"

#import <AmazonSupport/AmazonSupport.h>
#import "SandvoxPlugin.h"


@interface APAmazonList ()

// Delegate
- (void)sendLookupOperationsDidFinishCallback;

// Accessors
- (void)setLoadingData:(BOOL)loadingData;
- (void)setListType:(AmazonListType)type;
- (void)setLoadingListType:(AmazonListType)type;
- (void)setProducts:(NSArray *)products;
- (void)setListURL:(NSURL *)URL;

// List Lookup
- (NSMutableArray *)listLookupOperations;
- (void)beginListLookupOperationWithProductPage:(unsigned)page;
- (void)firstListLookupDidFinish:(AmazonListLookup *)listLookupOp;
- (void)otherListLookupDidFinish:(AmazonListLookup *)listLookupOp;
- (BOOL)allListLookupsHaveLoaded;
- (AmazonListType)listTypeToTryAfterType:(AmazonListType)previousType;

@end


# pragma mark -


@implementation APAmazonList

#pragma mark -
#pragma mark Init & Dealloc

/*	Init with an unknown list type for each type to be tried in turn (does result in slower loading!)
 *	Once the correct type is found, the stored listType value is changed to match
 */
- (id)initWithID:(NSString *)listID
		listType:(AmazonListType)listType
		   store:(AmazonStoreCountry)store
		 sorting:(AmazonWishListSorting)sorting
		delegate:(id)delegate
{
	[super init];
	
	
	// Store the parameters
	myDelegate = delegate;
	[self setLoadingData:YES];
	myID = [listID copy];
	myListType = listType;
	myStoreCountry = store;
	mySorting = sorting;
	
	
	// Begin the list lookup
	AmazonListType listTypeToLoad = listType;
	if (listTypeToLoad == AmazonListTypeUnknown) {
		listTypeToLoad = AmazonWishList;
	}
	[self setLoadingListType:listTypeToLoad];
	
	[self beginListLookupOperationWithProductPage:1];
	
	
	return self;
}

- (void)dealloc
{
	[myListLookups makeObjectsPerformSelector:@selector(cancel)];
	
	[myID release];
	[myProducts release];
	
	[myLastLoadError release];
	[myListLookups release];
	[myLoadingProducts release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Delegate

- (id)delegate { return myDelegate; }

- (void)sendLookupOperationsDidFinishCallback
{
	[self setLoadingData:NO];
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(amazonListLookupOperationsDidFinish:)]) {
		[delegate amazonListLookupOperationsDidFinish:self];
	}
}

#pragma mark -
#pragma mark Accessors

- (BOOL)isLoadingData { return myLoadingData; }

- (void)setLoadingData:(BOOL)loadingData { myLoadingData = loadingData; }

- (NSString *)listID { return myID; }

- (NSError *)lastLoadError { return myLastLoadError; }

- (void)setLastLoadError:(NSError *)error
{
	[error retain];
	[myLastLoadError release];
	myLastLoadError = error;
}

- (AmazonStoreCountry)store { return myStoreCountry; }

- (AmazonWishListSorting)sorting { return mySorting; }

- (AmazonListType)listType { return myListType; }

- (void)setListType:(AmazonListType)type { myListType = type; }

- (AmazonListType)loadingListType { return myLoadingListType; }

- (void)setLoadingListType:(AmazonListType)type { myLoadingListType = type; }

- (NSArray *)products { return myProducts; }

- (void)setProducts:(NSArray *)products
{
	products = [products copy];
	[myProducts release];
	myProducts = products;
}

- (NSURL *)listURL { return myURL; }

- (void)setListURL:(NSURL *)URL
{
	[URL retain];
	[myURL release];
	myURL = URL;
}

#pragma mark -
#pragma mark List Lookups

- (NSMutableArray *)listLookupOperations
{
	if (!myListLookups) {
		myListLookups = [[NSMutableArray alloc] initWithCapacity:1];
	}
	
	return myListLookups;
}

- (void)beginListLookupOperationWithProductPage:(unsigned)page
{
	AmazonListLookup *lookupOp = [[AmazonListLookup alloc] initWithStore:[self store]];
	[lookupOp setListID:[self listID]];
	[lookupOp setListType:[self loadingListType]];
	[lookupOp setProductPage:page];
	[lookupOp setSorting:[self sorting]];
	
	[[self listLookupOperations] addObject:lookupOp];
	[lookupOp loadWithDelegate:self];
	[lookupOp release];
}

- (void)asyncObject:(id)listLookupOp didFailWithError:(NSError *)error;
{
	// Ignore if not one of our lookups
	if (![[self listLookupOperations] containsObjectIdenticalTo:listLookupOp])
		return;
	
	
	// Cancel any remaining lookups
	[[self listLookupOperations] makeObjectsPerformSelector:@selector(cancel)];
	[[self listLookupOperations] removeAllObjects];
	
	
	// If loading an unknown list type, try another. Otherwise, store the error & alert our delegate
	if ([self listType] == AmazonListTypeUnknown)
	{
		AmazonListType nextType = [self listTypeToTryAfterType:[self loadingListType]];
		[self setLoadingListType:nextType];
		
		if (nextType == 0) {
			[self setLastLoadError:error];
			[self sendLookupOperationsDidFinishCallback];
		}
		else {
			[self beginListLookupOperationWithProductPage:1];
		}
	}
	else
	{
		[self setLastLoadError:error];
		[self sendLookupOperationsDidFinishCallback];
	}
}

- (void)asyncObjectDidFinishLoading:(id)listLookupOp;
{
	// Ignore if not one of our lookups
	if (![[self listLookupOperations] containsObjectIdenticalTo:listLookupOp])
		return;
	
	
	// Is the lookup our first?
	if (listLookupOp == [[self listLookupOperations] firstObjectKS]) {
		[self firstListLookupDidFinish:listLookupOp];
	}
	else {
		[self otherListLookupDidFinish:listLookupOp];
	}
}

- (void)firstListLookupDidFinish:(AmazonListLookup *)listLookupOp
{
	// Create list lookups for the other pages
	/// No longer doing this, loading the first page only.
	///	I've left the code here in case we might want it in the future
/*	unsigned pages = [listLookupOp totalPages];
	int i;
	for (i = 1; i < pages; i++)
	{
		[self beginListLookupOperationWithProductPage:(i + 1)];
	}
	*/
	
	// Store the list URL
	[self setListURL:[listLookupOp listURL]];
	
	
	// Proceed to load the products in the list as normal
	[self otherListLookupDidFinish:listLookupOp];
}

- (void)otherListLookupDidFinish:(AmazonListLookup *)listLookupOp
{
	// Load the products in the list
	[self loadProductsFromAmazonItems:[listLookupOp returnedItems]];
	
	// If all lookup operations have completed, transfer loading products to the proper products array
	if ([self allListLookupsHaveLoaded])
	{
		[self setListType:[self loadingListType]];
		[self setProducts:[self loadingProducts]];
		[[self listLookupOperations] removeAllObjects];
		
		[self sendLookupOperationsDidFinishCallback];
	}
}

// Checks every list lookup operation to see if it has loaded its data
- (BOOL)allListLookupsHaveLoaded
{
	BOOL result = YES;
	
	NSArray *listLookups = [self listLookupOperations];
	AmazonListLookup *lookupOp;
	
	for (lookupOp in listLookups)
	{
		if (![lookupOp dataHasLoaded]) {
			result = NO;
			break;
		}
	}
	
	return result;
}

/*	Takes into consideration the store being loaded to decide what list type to try next
 *	Returns 0 if there is nothing left to try.
 */
- (AmazonListType)listTypeToTryAfterType:(AmazonListType)previousType
{
	AmazonListType result = 0;
	
	switch (previousType)
	{
		case AmazonWishList:
			result = AmazonListmaniaList;
			break;
		
		case AmazonListmaniaList:
		{
			// Only the US and UK stores suppport Wedding Registries
			AmazonStoreCountry store = [self store];
			if (store == AmazonStoreUS || store == AmazonStoreUK) {
				result = AmazonWeddingRegistry;
			}
			break;
		}
		
		default:
			result = 0;
			break;
	}
	
	return result;
}

#pragma mark -
#pragma mark Product Loading

- (NSMutableArray *)loadingProducts
{
	if (!myLoadingProducts)
		myLoadingProducts = [[NSMutableArray alloc] init];
	
	return myLoadingProducts;
}

- (void)loadProductsFromAmazonItems:(NSArray *)listItems;
{
	NSMutableArray *loadingProducts = [self loadingProducts];
	
	// Run through each Amazon item
	AmazonItem *item;
	
	for (item in listItems)
	{
		// Create an equivalent APAmazonProduct from the item, but only if it has an ASIN
		if ([item amazonID])
		{
			APAutomaticListProduct *product = [[APAutomaticListProduct alloc] initWithAmazonItem:item];
			[loadingProducts addObject:product];
			[product loadThumbnail];
			[product release];
		}
	}
}

@end
