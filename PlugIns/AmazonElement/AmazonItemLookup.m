//
//  AmazonItemLookup.m
//  Amazon Support
//
//  Created by Mike on 24/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "AmazonItemLookup.h"
#import "AmazonItem.h"

#import "NSString+Amazon.h"

@interface AmazonItemLookup (Private)

- (NSString *)_searchIndex;

- (void)setStore:(AmazonStoreCountry)store;
- (void)setItemID:(NSString *)ID;

- (void)setItemIDType:(AmazonIDType)IDType;
- (NSString *)_itemIDTypeString;

@end

@implementation AmazonItemLookup

# pragma mark *** Creating a Request ***

+ (NSArray *)defaultResponseGroups
{
	return [NSArray arrayWithObjects:@"Medium", @"Images", nil];
}

- (id)initWithStore:(AmazonStoreCountry)country
			 itemId:(NSString *)itemID
{
	return [self initWithStore: country
						itemID: itemID
						IDType: AmazonIDTypeASIN];
}

- (id)initWithStore:(AmazonStoreCountry)country
			 itemID:(NSString *)itemID
			 IDType:(AmazonIDType)idType
{
	[self setItemID: itemID];
	[self setItemIDType: idType];
	[self setStore: country];


	// Build the parameters dictionary
	NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:4];
	
	[parameters setObject:itemID forKey:@"ItemId"];
	[parameters setObject:[self _itemIDTypeString] forKey:@"IdType"];
	
	if (idType == AmazonIDTypeUPC) {
		[parameters setObject:@"All" forKey:@"SearchIndex"];
	}
	else if (idType == AmazonIDTypeISBN) {
		[parameters setObject:@"Books" forKey:@"SearchIndex"];
	}
	
	
	// Init the request
	[self initWithStore:country
			  operation:@"ItemLookup"
			 parameters:parameters
		  resultListKey:@"ItemLookupResponse"
			  resultKey:@"Items"];

	
	return self;
}

# pragma mark *** Dealloc ***

- (void)dealloc
{
	[_itemID release];

	[super dealloc];
}

# pragma mark *** Accessors ***

- (NSString *)itemID { return _itemID; }

- (void)setItemID:(NSString *)ID
{
	if (ID == _itemID)
		return;

	[_itemID release];
	_itemID = [ID retain];
}

- (AmazonIDType)itemIDType { return _itemIDType; }

- (void)setItemIDType:(AmazonIDType)IDType { _itemIDType = IDType; }

- (NSString *)_itemIDTypeString
{
	switch ([self itemIDType])
	{
		case AmazonIDTypeASIN:
			return @"ASIN";
			break;

		case AmazonIDTypeSKU:
			return @"SKU";
			break;

		case AmazonIDTypeUPC:
			return @"UPC";
			break;

		case AmazonIDTypeEAN:
		case AmazonIDTypeJAN:
			return @"EAN";
			break;
		
		case AmazonIDTypeISBN:
			return @"ISBN";
			break;
	}

	return nil;
}


# pragma mark *** Returned Items ***

- (NSArray *)returnedItems { return [self cachedValueForKey: @"returnedItems"]; }

- (NSArray *)returnedItemsUncached
{
	NSArray *result = [self fetchArrayOfObjectAtXPath: @"/ItemLookupResponse/Items/Item"
											  asClass: [AmazonItem class]];

	return result;
}

- (NSString *)description
{
	NSString *type;
	switch (_itemIDType)
	{
		case AmazonIDTypeASIN:		type = @"ASIN";		break;
		case AmazonIDTypeSKU:		type = @"SKU";		break;
		case AmazonIDTypeUPC:		type = @"UPC";		break;
		case AmazonIDTypeEAN:		type = @"EAN";		break;
		case AmazonIDTypeJAN:		type = @"JAN";		break;
		default:	type = [NSString stringWithFormat:@"Unknown [%d]", _itemIDType]; break;
	}
	return [NSString stringWithFormat:@"%@ ID:%@ type:%@",
		[super description],
		_itemID,
		type
		];
}

@end
