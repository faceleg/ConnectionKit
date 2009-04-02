//
//  NSURL+AmazonPagelet.m
//  Amazon List
//
//  Created by Mike on 10/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "NSURL+AmazonPagelet.h"

#import "SandvoxPlugin.h"


@interface NSURL (AmazonPageletPrivate)

- (BOOL)fromQueryGetAmazonListType:(AmazonListType *)listTyp andID:(NSString **)listID;
@end


@interface NSArray (NSURLAmazonPagelet)
- (NSString *)ASINCodeAfterPathComponent:(NSString *)component;
- (NSString *)searchPathComponentsForASIN;
@end


#pragma mark -


@implementation NSURL (AmazonPagelet)

#pragma mark -
#pragma mark Store

- (AmazonStoreCountry)amazonStore
{
	AmazonStoreCountry result = AmazonStoreUnknown;
	
	NSString *host = [self host];
	if (host)
	{
		if ([host hasSuffix: @"amazon.com"]) {
			result = AmazonStoreUS;
		}
		else if ([host hasSuffix: @"amazon.co.uk"]) {
			result = AmazonStoreUK;
		}
		else if ([host hasSuffix: @"amazon.ca"]) {
			result = AmazonStoreCanada;
		}
		else if ([host hasSuffix: @"amazon.fr"]) {
			result = AmazonStoreFrance;
		}
		else if ([host hasSuffix: @"amazon.de"]) {
			result = AmazonStoreGermany;
		}
		else if ([host hasSuffix: @"amazon.jp"] || [host hasSuffix: @"amazon.co.jp"]) {
			result = AmazonStoreJapan;
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark ASIN

- (NSString *)amazonProductASIN
{
	// Bail if not a suitable Amazon URL
	if ([self amazonStore] == AmazonStoreUnknown) {
		return nil;
	}
	
	
	
	NSString *path = [self path];
	NSArray *pathComponents = [path pathComponents];
	
	NSString *result = [pathComponents searchPathComponentsForASIN];
	
	// If we still have nothing try decoding the URL
	if (!result)
	{
		NSString *query = [[self query] stringByReplacingPercentEscapesForURLQuery];
		pathComponents = [query pathComponents];
		
		result = [pathComponents searchPathComponentsForASIN];
	}
	
	return result;
}

#pragma mark -
#pragma mark Lists

- (void)getAmazonListType:(AmazonListType *)listType andID:(NSString **)listId
{
	AmazonListType possibleListType = 0;
	NSString *possibleListID = nil;
	BOOL IDFound = NO;
	
	// First try our query string
	IDFound = [self fromQueryGetAmazonListType:&possibleListType andID:&possibleListID];
	if (IDFound)
	{
		if (listType) *listType = possibleListType;
		if (listId) *listId = possibleListID;
	}
	else
	{	
		NSString *path = [self path];
		NSArray *pathComponents = [path pathComponents];
		
		NSRange searchRange = NSMakeRange(0, [pathComponents count] - 1);	// We're not interested in searching the last path component
		unsigned index;
		
		
		
		// Wedding registry
		index = [pathComponents indexOfObject: @"wedding" inRange: searchRange];
		if (index != NSNotFound)
		{
			if (listType) *listType = AmazonWeddingRegistry;
			if (listId) *listId = [pathComponents objectAtIndex:(index + 1)];
			return;
		}
		
		if ([path hasPrefix: @"/exec/obidos/registry/"] &&
			[pathComponents count] >= 5)
		{
			if (listType) *listType = AmazonWishList;
			if (listId) *listId = [pathComponents objectAtIndex: 4];
			return;
		}
		
		
		// Wish list
		index = [pathComponents indexOfObject: @"wishlist" inRange: searchRange];
		if (index != NSNotFound)
		{
			// We have to make sure this isn't a wishlist path to a non-list page
			NSString *possibleID = [pathComponents objectAtIndex: index + 1];
			if ([possibleID isLikelyToBeAmazonListID])
			{
				if (listType) *listType = AmazonWishList;
				if (listId) *listId = possibleID;
				return;
			}
		}
		
		index = [pathComponents indexOfObject: @"registry" inRange: searchRange];
		if (index != NSNotFound)
		{
			NSString *possibleID = [pathComponents objectAtIndex: index + 1];
			if ([possibleID isLikelyToBeAmazonListID])
			{
				if (listType) *listType = AmazonWishList;
				if (listId) *listId = possibleID;
				return;
			}
		}
		
		
		// Listmania
		index = [pathComponents indexOfObject: @"lm" inRange: searchRange];
		if (index != NSNotFound)
		{
			NSString *possibleID = [pathComponents objectAtIndex: index + 1];
			if ([possibleID isLikelyToBeAmazonListID]) {
				if (listType) *listType = AmazonListmaniaList;
				if (listId) *listId = possibleID;
				return;
			}
		}
		
		index = [pathComponents indexOfObject: @"fullview" inRange: searchRange];
		if (index != NSNotFound)
		{
			NSString *possibleID = [pathComponents objectAtIndex: index + 1];
			if ([possibleID isLikelyToBeAmazonListID]) {
				if (listType) *listType = AmazonListmaniaList;
				if (listId) *listId = possibleID;
				return;
			}
		}
		
		index = [pathComponents indexOfObject: @"listmania" inRange: searchRange];
		if (index != NSNotFound)
		{
			NSString *possibleID = [pathComponents objectAtIndex: index + 1];
			if ([possibleID isLikelyToBeAmazonListID]) {
				if (listType) *listType = AmazonListmaniaList;
				if (listId) *listId = possibleID;
				return;
			}
		}
	}
}

- (BOOL)fromQueryGetAmazonListType:(AmazonListType *)listType andID:(NSString **)listID
{
	*listType = 0;
	*listID = nil;
	
	// Bail if the URL does not begin with /gp/registry/
	if (![[self path] hasPrefix: @"/gp/registry/"]) {
		return NO;
	}
	
	// Search the query
	NSDictionary *query = [self queryDictionary];
	
	NSString *possibleListID = [query objectForKey: @"id"];
	NSString *possibleListType = [query objectForKey: @"type"];
	
	if (possibleListID && possibleListType)	// Only a match if both keys exist and are suitable
	{
		if ([possibleListType isEqualToString: @"wishlist"]) {
			*listType = AmazonWishList;
		}
		if ([possibleListType isEqualToString: @"wedding"]) {
			*listType = AmazonWeddingRegistry;
		}
		
		if (*listType != 0)
			*listID = possibleListID;
	}
	
	return (*listType != 0);
}

@end

#pragma mark -

@implementation NSString (NSURLAmazonPagelet)

- (BOOL)isLikelyToBeAmazonListID
{
	// Remove all non-alphanumeric characters and make uppercase
	// If this still matches the original then it is likely to be a valid ID
	NSCharacterSet *characters = [NSCharacterSet alphanumericASCIICharacterSet];
	NSString *processedString = [[self stringByRemovingCharactersNotInSet: characters] uppercaseString];
	
	BOOL result = [processedString isEqualToString: self];
	return result;
}

@end


@implementation NSArray (NSURLAmazonPagelet)

- (NSString *)ASINCodeAfterPathComponent:(NSString *)component
{
	NSString *result = nil;
	
	NSRange searchRange = NSMakeRange(0, [self count] - 1);	// Not interested in last component
	
	unsigned index = [self indexOfObject: component inRange: searchRange];
	if (index != NSNotFound)
	{
		NSString *code = [self objectAtIndex: index + 1];
		if ([code isLikelyToBeAmazonListID]) {
			result = code;
		}
	}
	
	return result;
}

- (NSString *)searchPathComponentsForASIN
{
	NSString *result = nil;
	
	// Search order is /ASIN /product /dp /reader /images /- /obidos
	result = [self ASINCodeAfterPathComponent: @"ASIN"];
	
	if (!result) {
		result = [self ASINCodeAfterPathComponent: @"product"];
	}
	
	if (!result) {
		result = [self ASINCodeAfterPathComponent: @"dp"];
	}
	
	if (!result) {
		result = [self ASINCodeAfterPathComponent: @"reader"];
	}
	
	if (!result) {
		result = [self ASINCodeAfterPathComponent: @"images"];
	}
	
	if (!result) {
		result = [self ASINCodeAfterPathComponent: @"-"];
	}
	
	if (!result) {
		result = [self ASINCodeAfterPathComponent: @"obidos"];
	}
	
	return result;
}

@end
