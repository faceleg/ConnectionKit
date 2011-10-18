//
//  AmazonItemLookup.h
//  Amazon Support
//
//  Created by Mike on 24/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	Looks up the properties of an Amazon item from its ID. The ID can be
//	an ASIN, SKU, UPC, EAN, JAN or ISBN. Note that not all options are
//	available in all stores.


#import <Cocoa/Cocoa.h>
#import "AmazonECSOperation.h"


typedef enum {
	AmazonIDTypeASIN = 0,
	AmazonIDTypeSKU = 1,
	AmazonIDTypeUPC = 2,
	AmazonIDTypeEAN = 3,
	AmazonIDTypeJAN = 4,
	AmazonIDTypeISBN = 5,
} AmazonIDType;

enum {	// Lookup errors
	AmazonItemLoopupInvalidRequestError = 1,
	AmazonItemLookupNoItemsFoundError = 2,
};


@interface AmazonItemLookup : AmazonECSOperation
{
	NSString		*_itemID;
	AmazonIDType	_itemIDType;
}

- (id)initWithStore:(AmazonStoreCountry)country
			 itemId:(NSString *)itemID;

- (id)initWithStore:(AmazonStoreCountry)country
			 itemID:(NSString *)itemID
			 IDType:(AmazonIDType)idType;

// Accessors
- (NSString *)itemID;
- (AmazonIDType)itemIDType;

// Results
- (NSArray *)returnedItems;
@end
