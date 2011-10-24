//
//  AmazonPrice.m
//  AmazonSupport
//
//  Created by Mike on 01/05/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AmazonPrice.h"

#import "NSXMLElement+Amazon.h"


@implementation AmazonPrice

#pragma mark -
#pragma mark Init & Dealloc

- (id)initWithXML:(NSXMLElement *)xml
{
	[super init];
	
	// Load each accesor from the XML
	if (xml)
	{
		myAmount = [[xml stringValueForName:@"Amount"] integerValue];
		myCurrencyCode = [[xml stringValueForName:@"CurrencyCode"] copy];
		myFormattedPrice = [[xml stringValueForName:@"FormattedPrice"] copy];
	}
	else
	{
		[self release];
		self = nil;
	}
	
	return self;
}

- (void)dealloc
{
	[myCurrencyCode release];
	[myFormattedPrice release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (NSUInteger)amount { return myAmount; }

- (NSString *)currencyCode { return myCurrencyCode; }

- (NSString *)formattedPrice { return myFormattedPrice; }

@end
