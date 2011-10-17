//
//  AmazonPrice.h
//  AmazonSupport
//
//  Created by Mike on 01/05/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "CacheableObject.h"

@interface AmazonPrice : NSObject
{
	NSUInteger	myAmount;
	NSString	*myCurrencyCode;
	NSString	*myFormattedPrice;
}

- (id)initWithXML:(NSXMLElement *)xml;

- (NSUInteger)amount;
- (NSString *)currencyCode;
- (NSString *)formattedPrice;

@end
