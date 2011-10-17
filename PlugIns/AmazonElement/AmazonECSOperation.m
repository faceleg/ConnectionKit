//
//  AmazonECSOperation.m
//  Amazon Support
//
//  Created by Mike on 23/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "AmazonECSOperation.h"

#import "AsyncObjectQueue.h"

#import "NSString+Amazon.h"
#import "NSURL+Amazon.h"
#import "NSXMLElement+Amazon.h"

#import "Sandvox.h"
//#include <openssl/sha.h>
#import <CommonCrypto/CommonHMAC.h>
// usr/include/CommonCrypto/CommonHMAC.h
//#import "OAHMAC_SHA1SignatureProvider.h"

#include <stdio.h>
#include <string.h>
#include <stdlib.h>

@interface NSData (definedInShared)
- (NSString *)base64Encoding;
@end

@implementation AmazonECSOperation

#pragma mark -
#pragma mark Class methods

+ (AmazonStoreCountry) guessCountry
{
	AmazonStoreCountry amazonCountry = AmazonStoreUS;	// default
	NSArray *langArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
	NSTimeZone *zone = [NSTimeZone systemTimeZone];
	NSString *zoneName = [zone name];
	NSString *zoneMajor = [[zoneName componentsSeparatedByString:@"/"] objectAtIndex:0];
	
	BOOL isEngland = [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"GMT"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"BST"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"IST"]] ;
	
	BOOL isEurope = [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"WET"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"WEST"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"CET"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"CEST"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EET"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EEST"]] ;
	
	BOOL isNewfoundland = [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"NST"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"NDT"]];
	
	BOOL isUSOrCanada = [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"WET"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"WEST"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"CET"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"CEST"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EET"]]
		|| [zone isEqualToTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"EEST"]] ;
	
	NSString *locale = @"";
	NSString *lang = @"";
	if ([langArray count])	// probably will never have no language but you never know!
	{
		locale = [langArray objectAtIndex:0];
		lang = [locale substringToIndex:2];
	}
	
	// Now do our guessing
	if ([lang isEqualToString:@"zh"] && [zoneMajor isEqualToString:@"Asia"])
	{
		amazonCountry = AmazonStoreChina;		// Chinese language, and in Asia - assume China
	}
	if ([lang isEqualToString:@"ja"] || [zoneMajor isEqualToString:@"Asia"])
	{
		amazonCountry = AmazonStoreJapan;		// Rest of Asia: assume Japanese store
	}
	else if ([locale isEqualToString:@"fr-CA"] || [locale isEqualToString:@"en-CA"])
	{
		amazonCountry = AmazonStoreCanada;	// Canadian lang -> Canada
	}
	else if ([locale isEqualToString:@"en-GB"] || [lang isEqualToString:@"GD"] || isEngland)
	{
		amazonCountry = AmazonStoreUK;	// British, Gaelic language, or England Time -> UK
	}
	else if ([locale isEqualToString:@"en-AU"] || [zoneMajor isEqualToString:@"Australia"])
	{
		amazonCountry = AmazonStoreUK;	// Australian Continent or Language --> UK
	}
	else if ([locale isEqualToString:@"fr-CH"])
	{
		amazonCountry = AmazonStoreFrance;	// Swiss French -> France
	}
	else if ([lang isEqualToString:@"fr"] && isEurope)
	{
		amazonCountry = AmazonStoreFrance;		// French language in Europe -> France
	}
	else if ([lang isEqualToString:@"es"] && isEurope)
	{
		amazonCountry = AmazonStoreSpain;		// Spanish language in Europe -> Spain
	}
	else if ([lang isEqualToString:@"it"] && isEurope)
	{
		amazonCountry = AmazonStoreItaly;		// Italian language in Europe -> Italy
	}
	if ([lang isEqualToString:@"de"] || isEurope)
	{
		amazonCountry = AmazonStoreGermany;	// German lang, or elsewhere in Europe -> German
	}
	else if (isNewfoundland || [zoneMajor isEqualToString:@"Canada"])
	{
		amazonCountry = AmazonStoreCanada;	// newfoundland, or some kind of generic Canada -> CA
	}
	else if ([lang isEqualToString:@"fr"] && isUSOrCanada)
	{
		amazonCountry = AmazonStoreCanada;	// french-speaker in N.Amer -> Canada
	}
	// else if (isUSOrCanada && [zoneMajor isEqualToString:@"America"]) // AMBIGUOUS STILL
	
	// Fallback (including Alaska, Hawaii Zones: US Store.

	return amazonCountry;
}

+ (NSString *)nameOfStore:(AmazonStoreCountry)store
{
	NSString *result = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			result = SVLocalizedString(@"US","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreUK:
			result = SVLocalizedString(@"UK","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreGermany:
			result = SVLocalizedString(@"German","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreJapan:
			result = SVLocalizedString(@"Japanese","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreFrance:
			result = SVLocalizedString(@"French","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreCanada:
			result = SVLocalizedString(@"Canadian","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreChina:
			result = SVLocalizedString(@"Chinese","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreSpain:
			result = SVLocalizedString(@"Spanish","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		case AmazonStoreItaly:
			result = SVLocalizedString(@"Italian","name of *country*, NOT THEIR LANGUAGE, as in the translated sentence 'Change to the %@ Amazon store?'");
			break;
		default:
			result = nil;
	}
	
	return result;
}

+ (NSString *)topLevelDomainOfStore:(AmazonStoreCountry)store
{
	NSString *result = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			result = @"com";
			break;
		case AmazonStoreUK:
			result = @"co.uk";
			break;
		case AmazonStoreGermany:
			result = @"de";
			break;
		case AmazonStoreJapan:
			result = @"jp";
			break;
		case AmazonStoreFrance:
			result = @"fr";
			break;
		case AmazonStoreCanada:
			result = @"ca";
			break;
		case AmazonStoreChina:
			result = @"cn";
			break;
		case AmazonStoreItaly:
			result = @"it";
			break;
		case AmazonStoreSpain:
			result = @"es";
			break;
		default:
			result = nil;
	}
	
	return result;
}

+ (NSURL *)URLOfStore:(AmazonStoreCountry)store
{
	NSURL *result = nil;
	NSString *resultString = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			resultString = @"http://www.amazon.com";
			break;

		case AmazonStoreUK:
			resultString = @"http://www.amazon.co.uk";
			break;

		case AmazonStoreGermany:
			resultString = @"http://www.amazon.de";
			break;

		case AmazonStoreJapan:
			resultString = @"http://www.amazon.co.jp";
			break;

		case AmazonStoreFrance:
			resultString = @"http://www.amazon.fr";
			break;

		case AmazonStoreCanada:
			resultString = @"http://www.amazon.ca";
			break;

		case AmazonStoreChina:
			resultString = @"http://www.amazon.cn";
			break;
			
		case AmazonStoreSpain:
			resultString = @"http://www.amazon.es";
			break;

		case AmazonStoreItaly:
			resultString = @"http://www.amazon.it";
			break;
			
		default:
			break;
	}
	
	if (resultString) {
		result = [NSURL URLWithString:resultString];
	}
	
	return result;
}

+ (NSString *)associateIDForStore:(AmazonStoreCountry)store
{
	NSString *result = nil;	// There may well be no available ID for a particular store
	
	// Look for an override the user may have specified
	NSString *override = [[NSUserDefaults standardUserDefaults] objectForKey:@"AmazonAssociateID"];
	if (override && ![override isEqualToString:@""]) {
		result = override;
	}
	
	if (!result)
	{
		// Look through the defaults to find the appropriate ID
		NSString *storeCode = [AmazonECSOperation ISOCountryCodeOfStore:store];
		if (storeCode) {
			NSString *keyPath = [NSString stringWithFormat:@"AmazonAssociateIDs.%@", storeCode];
			result = [[NSUserDefaults standardUserDefaults] valueForKeyPath:keyPath];
		}
	}
	
	return result;
}

+ (NSString *)ISOCountryCodeOfStore:(AmazonStoreCountry)store
{
	NSString *result = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			result = @"us";
			break;
		case AmazonStoreUK:
			result = @"uk";
			break;
		case AmazonStoreGermany:
			result = @"de";
			break;
		case AmazonStoreJapan:
			result = @"jp";
			break;
		case AmazonStoreFrance:
			result = @"fr";
			break;
		case AmazonStoreCanada:
			result = @"ca";
			break;
		case AmazonStoreChina:
			result = @"cn";
			break;
		case AmazonStoreSpain:
			result = @"es";
			break;
		case AmazonStoreItaly:
			result = @"it";
			break;
		case AmazonStoreUnknown:
			OBASSERT_NOT_REACHED("You can't ask for the country code of an unknown country, dir!");
			break;
	}
	
	return result;
}

#pragma mark -
#pragma mark RCM

+ (NSURL *)rcmServerForStore:(AmazonStoreCountry)store
{
	NSURL *result = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			result = [NSURL URLWithString:@"http://rcm.amazon.com"];
			break;
		case AmazonStoreUK:
			result = [NSURL URLWithString:@"http://rcm-uk.amazon.co.uk"];
			break;
		case AmazonStoreGermany:
			result = [NSURL URLWithString:@"http://rcm-de.amazon.de"];
			break;
		case AmazonStoreFrance:
			result = [NSURL URLWithString:@"http://rcm-fr.amazon.fr"];
			break;
		case AmazonStoreJapan:
			result = [NSURL URLWithString:@"http://rcm-jp.amazon.co.jp"];
			break;
		case AmazonStoreCanada:
			result = [NSURL URLWithString:@"http://rcm-ca.amazon.ca"];
			break;

		case AmazonStoreSpain:
			result = [NSURL URLWithString:@"http://rcm-es.amazon.es"];
			break;
		case AmazonStoreItaly:
			result = [NSURL URLWithString:@"http://rcm-it.amazon.it"];
			break;
		case AmazonStoreChina:
			result = [NSURL URLWithString:@"http://rcm-cn.amazon.cn"];
			break;

		case AmazonStoreUnknown:
			OBASSERT_NOT_REACHED("You can't ask for the rcm server of an unknown store.");
			break;
	}
	
	return result;
}

+ (NSString *)rcmNumberForStore:(AmazonStoreCountry)store
{
	NSString *result = nil;
	
	switch (store)
	{
		case AmazonStoreUS:
			result = @"1";
			break;
		case AmazonStoreUK:
			result = @"2";
			break;
		case AmazonStoreGermany:
			result = @"3";
			break;
		case AmazonStoreFrance:
			result = @"8";
			break;
		case AmazonStoreJapan:
			result = @"9";
			break;
		case AmazonStoreCanada:
			result = @"15";
			break;

		case AmazonStoreSpain:
			result = @"30";
			break;
		case AmazonStoreItaly:
			result = @"29";
			break;
		case AmazonStoreChina:
			result = @"28";
			break;

		case AmazonStoreUnknown:
			OBASSERT_NOT_REACHED("You can't ask for the rcm number of an unknown store.");
			break;
	}
	
	return result;
}

+ (NSURL *)enhancedProductLinkForASINs:(NSArray *)ASINs store:(AmazonStoreCountry)store
{
	NSURL *result = nil;
	
	NSURL *server = [self rcmServerForStore:store];
	NSString *storeNumber = [self rcmNumberForStore:store];
	
	if (server && storeNumber)
	{
		NSMutableDictionary *parameters = [NSMutableDictionary dictionaryWithCapacity:11];
		
		NSString *assocID = [self associateIDForStore:store];
		if (assocID)
		{
			[parameters setObject:assocID forKey:@"t"];
		}
		[parameters setObject:storeNumber forKey:@"o"];
		[parameters setObject:@"8" forKey:@"p"];
		[parameters setObject:@"as1" forKey:@"l"];
		[parameters setObject:[ASINs componentsJoinedByString:@","] forKey:@"asins"];
		[parameters setObject:@"000000" forKey:@"fc1"];
		[parameters setObject:@"1" forKey:@"IS2"];
		[parameters setObject:@"_top" forKey:@"lt1"];
		[parameters setObject:@"0000FF" forKey:@"lc1"];
		[parameters setObject:@"CCCCCC" forKey:@"bc1"];
		[parameters setObject:@"FFFFFF" forKey:@"bg1"];
		[parameters setObject:@"ifr" forKey:@"f"];
		
		NSURL *baseURL = [NSURL URLWithString:@"/e/cm" relativeToURL:server];
		result = [NSURL URLWithBaseURL:baseURL parameters:parameters];
	}
	
	return result;
}

/*!	Returns the URL to use as the src of an Amazon Search Box iFrame.
 *	If no associate ID is specified, the default is retrieved
 */
+ (NSURL *)searchBoxIFrameURLForStore:(AmazonStoreCountry)store
						  associateID:(NSString *)associateID
					  includeDropdown:(BOOL)dropdown
{
	NSURL *result = nil;
	
	// Grab the right associate ID if needed
	if (!associateID || [associateID isEqualToString:@""]) {
		associateID = [self associateIDForStore:store];
	}
	
	NSURL *server = [self rcmServerForStore:store];
	NSString *storeNumber = [self rcmNumberForStore:store];
	
	if (server && storeNumber)
	{
		NSMutableDictionary *query = [NSMutableDictionary dictionaryWithCapacity:5];
		
		if (associateID)
		{
			[query setObject:associateID forKey:@"t"];
		}
		[query setObject:storeNumber forKey:@"o"];
		[query setObject:@"qs1" forKey:@"l"];	// I don't know what this one does
		[query setObject:@"ifr" forKey:@"f"];	// Or this
		
		if (dropdown) {
			[query setObject:@"27" forKey:@"p"];
		}
		else {
			[query setObject:@"20" forKey:@"p"];
		}
		
		result = [NSURL URLWithBaseURL:[NSURL URLWithString:@"/e/cm" relativeToURL:server]
							parameters:query];
	}
	
	return result;
}

/*	The javascript that needs to be placed after Amazon product links to display popip product previews
 */
+ (NSString *)productPreviewsScriptForStore:(AmazonStoreCountry)store
{
	NSString *result = nil;
	NSString *assocID = [self associateIDForStore:store];
	if (!assocID)
	{
		assocID = @"";
	}
	
	result = [NSString stringWithFormat:
		@"<script type=\"text/javascript\" src=\"http://www.assoc-amazon.%@/s/link-enhancer?tag=%@&o=%@\"></script>\r<noscript><img src=\"http://www.assoc-amazon.%@/s/noscript?tag=%@\" alt=\"\" /></noscript>",
		[self topLevelDomainOfStore:store],
		assocID,
		[self rcmNumberForStore:store],
		[self topLevelDomainOfStore:store],
		assocID];
	
	return result;
}

#pragma mark -
#pragma mark Defaults

+ (NSDictionary *)associateKeyDefaults
{
	// Only use some of these.  It's just not worth the trouble to try and handle these accounts
	return [NSDictionary dictionaryWithObjectsAndKeys:
		@"karelsofwa-20", [self ISOCountryCodeOfStore:AmazonStoreUS],		// paid by direct deposit
		@"karelsoftw-21", [self ISOCountryCodeOfStore:AmazonStoreUK],		// paid by gift certificate
		@"karelsoftw-20", [self ISOCountryCodeOfStore:AmazonStoreCanada],	// "
		//@"karelsoftw00-21", [self ISOCountryCodeOfStore:AmazonStoreFrance],// "  (but not worth the trouble)
		@"karelsoftw02-21", [self ISOCountryCodeOfStore:AmazonStoreGermany],	// "
		// @"karelsoftw-22", [self ISOCountryCodeOfStore:AmazonStoreJapan],	// " (but impossible to figure out!
			
			// We're not bothering with associates programs of the newer countries....
			
		nil];
}

#pragma mark -
#pragma mark Init/Dealloc

- (id)initWithStore:(AmazonStoreCountry)country
		  operation:(NSString *)operation
		 parameters:(NSDictionary *)parameters
	  resultListKey:(NSString *)aResultListKey
		  resultKey:(NSString *)aResultKey;
{
	if ((self = [super initWithOperation:operation parameters:parameters resultListKey:aResultListKey resultKey:aResultKey]) != nil)
	{
		[self setStore:country];
		[[self params] setObject:@"AWSECommerceService" forKey: @"Service"];
		[[self params] setObject:@"2011-08-01" forKey:@"Version"];
		[self setResponseGroups:[[self class] defaultResponseGroups]];
	}
	return self;
}

#pragma mark -
#pragma mark Loading

// Overridden so that base URL is calculated, not set
- (NSURL *)baseURL
{
	NSString *storeURLString = nil;

	// Figure out the URL of the store
	switch ([self store])
	{
		case AmazonStoreUS:
			storeURLString = @"http://webservices.amazon.com/onca/xml";
			break;

		case AmazonStoreUK:
			storeURLString = @"http://webservices.amazon.co.uk/onca/xml";
			break;

		case AmazonStoreGermany:
			storeURLString = @"http://webservices.amazon.de/onca/xml";
			break;

		case AmazonStoreJapan:
			storeURLString = @"http://webservices.amazon.co.jp/onca/xml";
			break;

		case AmazonStoreFrance:
			storeURLString = @"http://webservices.amazon.fr/onca/xml";
			break;

		case AmazonStoreCanada:
			storeURLString = @"http://webservices.amazon.ca/onca/xml";
			break;

		case AmazonStoreItaly:
			storeURLString = @"http://webservices.amazon.it/onca/xml";
			break;
		case AmazonStoreSpain:
			storeURLString = @"http://webservices.amazon.es/onca/xml";
			break;
		case AmazonStoreChina:
			storeURLString = @"http://webservices.amazon.cn/onca/xml";
			break;
			
		default:
			break;
	}

	if (!storeURLString)
		return nil;

	// Build the URL
	return [NSURL URLWithString: storeURLString];
}

- (NSDictionary *)requestParameters
{
	NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:[super requestParameters]];
	
	NSString *associateID = [self associateID];
	if (associateID) {
		[result setObject:associateID forKey:@"AssociateTag"];
	}
	
	NSString *tstamp = [[NSDate date] descriptionWithCalendarFormat:@"%Y-%m-%dT%H:%M:%SZ" timeZone:[NSTimeZone timeZoneWithName:@"GMT"] locale:nil];
	[result setObject:tstamp forKey:@"Timestamp"];

	
	return result;
}

- (NSString*)signedString:(NSString*)strToSign
{
	
#define SHA256_DIGEST_SIZE 32
	char const* key = (char const*)[[AmazonOperation secretKeyID] UTF8String];	// amazon_nomoney@karelia.com secret key, no monetary accounts hooked up to this account!
	OBASSERT(key);
	char const* data = (char const*) [strToSign UTF8String];
	
	//char const* data = "what do ya want for nothing?";
	//char const* key  = "Jefe";
	// Expected hex: 5bdcc146bf60754e6a042426089575c75a003f089d2739839dec58b964ec3843
	// Expected encoded Base64: W9zBRr9gdU5qBCQmCJV1x1oAPwidJzmDnexYuWTsOEM%3D
	
	uint8_t result[SHA256_DIGEST_SIZE] = {0};
	uint8_t *mac = &result[0];
	unsigned int result_len = SHA256_DIGEST_SIZE;
	int i;
	char res_hexstring[1 + SHA256_DIGEST_SIZE * 2] = { 0 };

    CCHmac(kCCHmacAlgSHA256, key, strlen(key), data, strlen(data), mac);
    
	for (i = 0; i < result_len; i++) {
		sprintf(&(res_hexstring[i * 2]), "%02x", result[i]);
	}

	NSData *signedData = [NSData
						  dataWithBytes:result
						  length:SHA256_DIGEST_SIZE];
	
	NSString *base = [signedData base64Encoding];	// defined in Shared; loaded by App
	// escape plus and equal characters since this will be in a URL
	NSMutableString *str = [NSMutableString stringWithString:base];
	[str replaceOccurrencesOfString:@"+"
						 withString:@"%2B"
							options:0
							  range:NSMakeRange(0,[str length])];
	[str replaceOccurrencesOfString:@"="
						 withString:@"%3D"
							options:0
							  range:NSMakeRange(0,[str length])];
	return str;
}

// this is overridden so that request URL orders its parameters and adds validation
- (NSURL *)requestURL
{
	NSDictionary *requestParameters = [self requestParameters];
	
	// Need to order the request keys, by ASCII .... not alpha... so that AWSAccessKeyId is before AssociateTag
	NSMutableArray *requestKeys = [NSMutableArray arrayWithArray:[requestParameters allKeys]];
	[requestKeys sortUsingSelector:@selector(compare:)];
	
	NSMutableString *s = [NSMutableString string];
	NSEnumerator *e = [requestKeys objectEnumerator];
	id key;
		 
	while ((key = [e nextObject]))
	{
		NSString *rawParameter = [requestParameters objectForKey:key];
		NSString *parameter = nil;
		if ([rawParameter isKindOfClass:[NSArray class]])
		{
			parameter = [((NSArray *)rawParameter) componentsJoinedByString:@","];
		}
		else {
			parameter = [rawParameter description];
		}
		
		NSString *escapedKey
		= [(NSString *) CFURLCreateStringByAddingPercentEscapes(
			NULL, (CFStringRef) key, NULL, NULL, kCFStringEncodingUTF8) autorelease];
		NSString *escapedObject
		= [(NSString *) CFURLCreateStringByAddingPercentEscapes(
			NULL, (CFStringRef) parameter, NULL, (CFStringRef)@":,", kCFStringEncodingUTF8) autorelease];
		[s appendFormat:@"%@=%@&", escapedKey, escapedObject];
	}
	[s deleteCharactersInRange:NSMakeRange([s length] - 1, 1)];
	
	// Combine the store URL and request paramaeters
	NSURL *baseURL = [self baseURL];
	NSString *stringToSign = [NSString
							  stringWithFormat:@"GET\n%@\n%@\n%@", [baseURL host], [baseURL path], s];

	NSString *signedString = [self signedString:stringToSign]; 
	NSString *queryString = [NSString stringWithFormat:@"?%@&Signature=%@", s, signedString];
		
	NSURL *url = [NSURL URLWithString:queryString relativeToURL:baseURL];
	return url;
}


#pragma mark -
#pragma mark Post-Loading

- (BOOL)requestIsValidUncached
{
	// Locate the correct XML item
	BOOL result = NO;
	NSError *error = nil;
	NSXMLDocument *document = [self XMLDoc];

	NSString *xpath = [NSString stringWithFormat:@"/%@/Items/Request/IsValid", [self resultListKey]];
	NSArray *elements = [document nodesForXPath: xpath error: &error];

	if (error || [elements count] == 0)
	{
		result = NO;
	}
	else
	{
		NSString *stringValue = [[elements objectAtIndex: 0] stringValue];
		result = [stringValue boolValue];
	}

	return result;
}

- (NSError *)requestErrorUncached
{
	NSError *result = nil;
	// Look for errors returned by Amazon in the XML
	NSXMLDocument *document = [self XMLDoc];
	
	NSString *xpath = [NSString stringWithFormat: @"/%@/%@/Request/Errors/Error",
												  [self resultListKey],
												  [self resultKey]];

	NSArray *errorElements = [document nodesForXPath: xpath error: &result];
	if (errorElements && [errorElements count] > 0)
	{
		// Run through each error element, building up an array of NSError objects
		NSMutableString *errorString = [NSMutableString string];

		NSEnumerator *errorsEnumerator = [errorElements objectEnumerator];
		NSXMLElement *errorElement;

		while (errorElement = [errorsEnumerator nextObject])
		{
			// We need to retrieve the Code and Message for the error
			NSString *code = [errorElement stringValueForName: @"Code"];
			NSString *message = [errorElement stringValueForName: @"Message"];

			[errorString appendFormat:@"%@: %@; ", code, message];
			
		}
		[errorString deleteCharactersInRange:NSMakeRange([errorString length]-2, 2)];

		// Build the error userInfo dictionary
		NSDictionary *errorDict =
			[NSDictionary dictionaryWithObjectsAndKeys: errorString, NSLocalizedDescriptionKey,
				nil];
		
		// Create the error object and at it to the array
		result = [NSError errorWithDomain: @"AmazonECSOperationError" code: 0 userInfo: errorDict];
	}
	return result;
}

#pragma mark -
#pragma mark Accessors

- (AmazonStoreCountry)store
{
    return myStore;
}

- (void)setStore:(AmazonStoreCountry)aStore
{
    myStore = aStore;
}

- (NSString *)associateID
{
	return [[self class] associateIDForStore:[self store]];
}

#pragma mark -
#pragma mark Repsonse Group

- (NSArray *)responseGroups { return [[self params] objectForKey:@"ResponseGroup"]; }

- (void)setResponseGroups:(NSArray *)responseGroups
{
	[[self params] setObject:responseGroups forKey:@"ResponseGroup"];
}

+ (NSArray *)defaultResponseGroups { return nil; }

#pragma mark -
#pragma mark Description

- (NSString *)description
{
	NSString *country;
	switch (myStore)
	{
		case AmazonStoreUS:			country = @"US";		break;
		case AmazonStoreUK:			country = @"UK";		break;
		case AmazonStoreGermany:	country = @"GERMANY";	break;
		case AmazonStoreJapan:		country = @"JAPAN";		break;
		case AmazonStoreFrance:		country = @"FRANCE";	break;
		case AmazonStoreCanada:		country = @"CANADA";	break;
		case AmazonStoreItaly:		country = @"ITALY";		break;
		case AmazonStoreSpain:		country = @"SPAIN";		break;
		case AmazonStoreChina:		country = @"CHINA";		break;
		default:	country = [NSString stringWithFormat:@"Unknown [%d]", myStore]; break;
	}

	return [NSString stringWithFormat:@"%@ Country:%@", [super description], country];
}


@end
