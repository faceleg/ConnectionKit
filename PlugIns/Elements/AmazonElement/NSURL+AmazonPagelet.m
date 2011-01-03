//
//  NSURL+AmazonPagelet.m
//  Amazon List
//
//  Created by Mike on 10/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "NSURL+AmazonPagelet.h"

#import "AmazonIDFormatter.h"

#import "Sandvox.h"


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
        NSString *query = [[self query] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        NSMutableString *buffer = [query mutableCopy];
        [buffer replaceOccurrencesOfString:@"+"
                                withString:@" "
                                   options:0
                                     range:NSMakeRange(0, [buffer length])];
        
		query = [buffer autorelease];
        pathComponents = [query pathComponents];
		
		result = [pathComponents searchPathComponentsForASIN];
	}
	
	return result;
}

@end


#pragma mark -

@implementation NSString (NSURLAmazonPagelet)

/*! Remove all characters not in the set. Return a new string
 */
- (NSString *)amazonList_stringByRemovingCharactersNotInSet:(NSCharacterSet *)validCharacters
{
	NSMutableString *intermediateResult = [[NSMutableString alloc] initWithCapacity: [self length]];
	NSScanner *scanner = [[NSScanner alloc] initWithString: self];
	
	while (![scanner isAtEnd])
	{
		[scanner scanUpToCharactersFromSet: validCharacters intoString: NULL];
		
		// If we have now reached the end of the string, exit the loop early
		if ([scanner isAtEnd])
			break;
		
		NSString *resultSubString = nil;
		[scanner scanCharactersFromSet: validCharacters intoString: &resultSubString];
		
		[intermediateResult appendString: resultSubString];
	}
	
	// Tidy up
	[scanner release];
	
	NSString *result = [NSString stringWithString: intermediateResult];
	[intermediateResult release];
	return result;
}

- (BOOL)isLikelyToBeAmazonListID
{
	// Remove all non-alphanumeric characters and make uppercase
	// If this still matches the original then it is likely to be a valid ID
	NSCharacterSet *characters = [AmazonIDFormatter legalAmazonIDCharacters];
	NSString *processedString = [[self amazonList_stringByRemovingCharactersNotInSet:characters] uppercaseString];
	
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
