//
//  AmazonListLookup.h
//  Amazon Support
//
//  Created by Mike on 03/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Looks up the contents and properties of an Amazon list from the list ID
//	and type. Some lists have multiple "pages;" all the products in the list
//	cannot be downloaded at once. Thus you must also specify the page to load.


#import <Foundation/Foundation.h>
#import "AmazonECSOperation.h"


typedef enum {
	AmazonListTypeUnknown = -1,
	AmazonWishList = 1,
	AmazonListmaniaList = 2,
	AmazonWeddingRegistry = 3,
} AmazonListType;

typedef enum {
	AmazonSortWishListByDateAdded = 1,
	AmazonSortWishListByDateEditied = 2,
	AmazonSortWishListByPrice = 3,
} AmazonWishListSorting;


@interface AmazonListLookup : AmazonECSOperation
{
	NSString		*myListID;
	AmazonListType	myListType;
	NSUInteger		myPageNo;
	NSInteger				mySorting;
}

- (id)initWithStore:(AmazonStoreCountry)store;

// Accessors
- (NSString *)listID;
- (void)setListID:(NSString *)ID;

- (AmazonListType)listType;
- (void)setListType:(AmazonListType)type;

- (NSUInteger)productPage;
- (void)setProductPage:(NSUInteger)productPage;

- (AmazonWishListSorting)sorting;
- (void)setSorting:(AmazonWishListSorting)sorting;

- (NSURL *)listURL;
- (NSUInteger)totalItems;
- (NSUInteger)totalPages;
- (NSArray *)returnedItems;

@end
