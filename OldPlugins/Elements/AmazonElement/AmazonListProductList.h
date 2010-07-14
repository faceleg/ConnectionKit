//
//  AmazonListProductList.h
//  Amazon List
//
//  Created by Mike on 10/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	Represents an Amazon list as viewed in the Inspector. Contains an array of
//	products (APAutomaticListProduct) and the various properties of the list.
//	The list cannot be reloaded, a new AmazonListProductList object must be initialized
//	and used to replace the existing one.
//	Multiple AmazonListLookup operations are created to load all pages of the list.
//	If the list type is specified as unknown, lookups will be made for all list types
//	until an appropriate match is found.


#import <Cocoa/Cocoa.h>
#import <AmazonSupport/AmazonSupport.h>


@interface AmazonListProductList : NSObject
{
	id	myDelegate;
	
	BOOL	myLoadingData;
	NSError	*myLastLoadError;
	
	NSString				*myID;
	AmazonListType			myListType;
	AmazonListType			myLoadingListType;
	AmazonStoreCountry		myStoreCountry;
	AmazonWishListSorting	mySorting;
	NSURL					*myURL;
	NSArray					*myProducts;
	
	NSMutableArray	*myListLookups;
	NSMutableArray	*myLoadingProducts;
}

// Init
- (id)initWithID:(NSString *)listID
		listType:(AmazonListType)listType
		   store:(AmazonStoreCountry)store
		 sorting:(AmazonWishListSorting)sorting
		delegate:(id)delegate;

// Accessors
- (id)delegate;

- (BOOL)isLoadingData;
- (NSError *)lastLoadError;

- (NSString *)listID;
- (AmazonStoreCountry)store;
- (AmazonWishListSorting)sorting;

- (AmazonListType)listType;
- (AmazonListType)loadingListType;

- (NSArray *)products;
- (NSURL *)listURL;

// Private - keep out!
- (NSMutableArray *)loadingProducts;

- (void)loadProductsFromAmazonItems:(NSArray *)listItems;
@end


@interface NSObject (APListDelegate)
- (void)amazonListLookupOperationsDidFinish:(AmazonListProductList *)list;

- (void)amazonList:(AmazonListProductList *)list didFailToLoadWithError:(NSError *)error;
- (void)amazonListDidFinishLoading:(AmazonListProductList *)list;
@end
