//
//  AmazonOperation.h
//  Amazon Support
//
//  Created by Mike on 23/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	Subclass of AmazonOperation.
//	Main task is to provide the correct Amazon ECS URL for REST operations. Subclasses then
//	append the correct parameters for a specific operation.
//	Also has class methods for accessing information about a store. e.g. Name.

#import <Foundation/Foundation.h>
#import "AmazonOperation.h"


#ifndef LocalizedStringInThisBundle
	#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]
#endif


typedef enum {
	AmazonStoreUS = 1,
	AmazonStoreUK = 2,
	AmazonStoreGermany = 3,
	AmazonStoreJapan = 4,
	AmazonStoreFrance = 5,
	AmazonStoreCanada = 6,
	AmazonStoreItaly = 7,
	AmazonStoreSpain = 8,
	AmazonStoreChina = 9,
	AmazonStoreUnknown = -1,
} AmazonStoreCountry;


@interface AmazonECSOperation : AmazonOperation
{
	AmazonStoreCountry	myStore;
}

+ (AmazonStoreCountry)guessCountry;

+ (NSString *)nameOfStore:(AmazonStoreCountry)store;
+ (NSString *)topLevelDomainOfStore:(AmazonStoreCountry)store;
+ (NSURL *)URLOfStore:(AmazonStoreCountry)store;
+ (NSString *)associateIDForStore:(AmazonStoreCountry)store;
+ (NSString *)ISOCountryCodeOfStore:(AmazonStoreCountry)store;

// RCM
+ (NSURL *)enhancedProductLinkForASINs:(NSArray *)ASINs store:(AmazonStoreCountry)store;

+ (NSURL *)searchBoxIFrameURLForStore:(AmazonStoreCountry)store
						  associateID:(NSString *)associateID
					  includeDropdown:(BOOL)dropdown;

+ (NSString *)productPreviewsScriptForStore:(AmazonStoreCountry)store;

// Defaults					  
+ (NSDictionary *)associateKeyDefaults;

// Init
- (id)initWithStore:(AmazonStoreCountry)country
		  operation:(NSString *)operation
		 parameters:(NSDictionary *)parameters
	  resultListKey:(NSString *)aResultListKey
		  resultKey:(NSString *)aResultKey;

// public accessors
- (AmazonStoreCountry)store;
- (void)setStore:(AmazonStoreCountry)aStore;

- (NSString *)associateID;

- (NSArray *)responseGroups;
- (void)setResponseGroups:(NSArray *)responseGroups;
+ (NSArray *)defaultResponseGroups;

@end

