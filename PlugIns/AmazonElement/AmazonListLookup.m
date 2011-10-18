//
//  AmazonListLookup.m
//  Amazon Support
//
//  Created by Mike on 03/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AmazonListLookup.h"

#import "AmazonItem.h"
#import "AmazonListItem.h"


@interface AmazonListLookup (Private)

- (NSString *)listTypeString;
- (NSString *)sortingString;

@end

@implementation AmazonListLookup

# pragma mark *** Creating a Request ***

+ (NSArray *)defaultResponseGroups
{
	return [NSArray arrayWithObjects:@"Medium", @"Images", @"ListFull", nil];
}

- (id)initWithStore:(AmazonStoreCountry)store
{
	[super initWithStore:store
			   operation:@"ListLookup"
			  parameters:[NSDictionary dictionary]
		   resultListKey:@"ListLookupResponse"
			   resultKey:@"Lists"];
	
	[self setProductPage:1];
	
	return self;
}

- (NSDictionary *)requestParameters
{
	NSMutableDictionary *result =	// We add our own parameters to the defaults
		[NSMutableDictionary dictionaryWithDictionary: [super requestParameters]];
	
	[result setObject:[self listID] forKey:@"ListId"];
	[result setObject:[self listTypeString] forKey:@"ListType"];
	
	NSUInteger productPage = [self productPage];
	NSString *productPageString = [[NSNumber numberWithUnsignedInteger:productPage] stringValue];
	[result setObject:productPageString forKey:@"ProductPage"];
	
	if ([self sorting] != 0) {
		[result setObject:[self sortingString] forKey:@"Sort"];
	}
	
	return result;
}

#pragma mark -
# pragma mark Basic Accessors

- (NSString *)listID { return myListID; }

- (void)setListID:(NSString *)ID
{
	ID = [ID copy];
	[myListID release];
	myListID = ID;
}

- (NSUInteger)productPage { return myPageNo; }

- (void)setProductPage:(NSUInteger)productPage { myPageNo = productPage; }

#pragma mark -
# pragma mark List Type

- (AmazonListType)listType { return myListType; }

- (void)setListType:(AmazonListType)listType { myListType = listType; }

- (NSString *)listTypeString
{
	NSString *result = nil;

	switch (myListType)
	{
		case AmazonWishList:
			result = @"WishList";
			break;

		case AmazonListmaniaList:
			result = @"Listmania";
			break;

		case AmazonWeddingRegistry:
			result = @"WeddingRegistry";
			break;
		
		default:
			NSLog("Unknown list type should never be passed to Amazon");
			break;
	}

	return result;
}

# pragma mark Sorting

- (AmazonWishListSorting)sorting { return mySorting; }

- (void)setSorting:(AmazonWishListSorting)sorting { mySorting = sorting; }

- (NSString *)sortingString
{
	NSString *result = nil;
	
	switch ([self sorting])
	{
		case AmazonSortWishListByDateAdded:
			result = @"DateAdded";
			break;
		
		case AmazonSortWishListByDateEditied:
			result = @"LastUpdated";
			break;
		
		case AmazonSortWishListByPrice:
			result = @"Price";
			break;
	}
	
	return result;
}	

# pragma mark *** Cached Accessors ***

- (NSURL *)listURL { return [self cachedValueForKey: @"listURL"]; }

- (NSURL *)listURLUncached
{
	NSString *xpath = [NSString stringWithFormat: @"/%@/%@/List/ListURL", 
												  [self resultListKey],
												  [self resultKey]];
	
	NSError *error = nil;
	NSArray *xmlElements = [[self XMLDoc] nodesForXPath: xpath error: &error];
	
	// Return 0 if there was an error
	NSURL *result = nil;
	if (!error && xmlElements && [xmlElements count] > 0) {
		result = [NSURL URLWithString: [[xmlElements objectAtIndex: 0] stringValue]];
	}
	
	return result;
}

- (NSUInteger)totalItems { return [[self cachedValueForKey: @"totalItems"] unsignedIntegerValue]; }

- (NSUInteger)totalItemsUncached
{
	NSString *xpath = [NSString stringWithFormat: @"/%@/%@/List/TotalItems", 
												  [self resultListKey],
												  [self resultKey]];
	
	NSError *error = nil;
	NSArray *xmlElements = [[self XMLDoc] nodesForXPath: xpath error: &error];
	
	// Return 0 if there was an error
	NSUInteger result = 0;
	if (!error && xmlElements && [xmlElements count] > 0) {
		result = [[[xmlElements objectAtIndex: 0] stringValue] integerValue];
	}
	
	return result;
}

- (NSUInteger)totalPages { return [[self cachedValueForKey: @"totalPages"] unsignedIntegerValue]; }

- (NSUInteger)totalPagesUncached
{
	NSString *xpath = [NSString stringWithFormat: @"/%@/%@/List/TotalPages",
												  [self resultListKey],
												  [self resultKey]];
	
	NSError *error = nil;
	NSArray *xmlElements = [[self XMLDoc] nodesForXPath: xpath error: &error];
	
	// Return 0 if there was an error
	NSUInteger result = 0;
	if (!error && xmlElements && [xmlElements count] > 0) {
		result = [[[xmlElements objectAtIndex: 0] stringValue] integerValue];
	}
	
	return result;
}

# pragma mark *** Response ***


- (NSArray *)returnedItems { return [self cachedValueForKey: @"returnedItems"]; }

- (NSArray *)returnedItemsUncached
{
	NSString *xpath = [NSString stringWithFormat: @"/%@/Lists/List/ListItem", [self resultListKey]];
	NSArray *result = [self fetchArrayOfObjectAtXPath: xpath asClass: [AmazonListItem class]];

	return result;
}

- (NSString *)description
{
	NSString *type;
	switch (myListType)
	{
		case AmazonWishList:			type = @"WISHLIST";		break;
		case AmazonListmaniaList:		type = @"LISTMANIA";	break;
		case AmazonWeddingRegistry:		type = @"REGISTRY";		break;
		default:	type = [NSString stringWithFormat:@"Unknown [%d]", myListType]; break;
	}
	return [NSString stringWithFormat:@"%@ ID:%@ type:%@",
		[super description],
		myListID,
		type
		];
}

@end
