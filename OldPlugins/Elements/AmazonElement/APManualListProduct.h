//
//  APManualListProduct.h
//  Amazon List
//
//  Created by Mike on 02/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//	A subclass of APAmazonProduct can load its product details from Amazon
//	Posts NSNotifcations whenever any product properties change


#import <Cocoa/Cocoa.h>
#import <AmazonSupport/AmazonSupport.h>

#import "AmazonListProduct.h"


@class AmazonProductPlaceholder;

@class AmazonItemLookup;
@class AmazonImage;


@interface APManualListProduct : AmazonListProduct
{
	@private
	
	NSString			*myProductCode;
	NSError				*myLastLoadError;
	AmazonItemLookup	*myItemLookupOp;
}

// Init & Load
- (void)load;	// Loads everything including the thumbnail
- (NSError *)lastLoadError;

// Accessors
- (NSString *)productCode;
- (void)setProductCode:(NSString *)code;
- (AmazonIDType)productCodeIDType;

- (void)clearProductData;

- (NSURL *)enhancedDisplayIFrameURL;

@end


@interface NSObject (AmazonProductDelegate)

- (void)amazonProduct:(APManualListProduct *)product
	didFailToLoadDetailsWithError:(NSError *)error;

- (void)amazonProductDidLoadProductDetails:(APManualListProduct *)product;

@end