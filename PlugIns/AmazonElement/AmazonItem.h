//
//  AmazonItem.h
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	A simple object to represent an Amazon item.
//	Amazon ECS operations return XML which AmazonItems can be
//	inited from.

#import <Cocoa/Cocoa.h>
#import "CacheableObject.h"

#import "AmazonOperation.h"


@class AmazonPrice;
@class AmazonImage;

@interface AmazonItem : CacheableObject
{
	NSString		*_ASIN;
	NSURL			*_detailsPage;
	NSXMLElement	*myAttributes;
	
	AmazonPrice	*myListPrice;
	AmazonPrice	*myLowestNewPrice;
	AmazonPrice *myLowestUsedPrice;
	AmazonPrice *myLowestCollectiblePrice;

	AmazonImage	*_smallImage;
	AmazonImage	*_mediumImage;
	AmazonImage	*_largeImage;
}

// Init -- informal protocol for initializing with some simple xml
- (id)initWithXMLElement:(NSXMLElement *)xml;

// Accessors
- (NSXMLElement *)attributesXML;

- (NSString *)amazonID;
- (NSString *)title;
- (NSString *)creator;
- (NSURL *)detailsPage;

- (AmazonPrice *)listPrice;
- (AmazonPrice *)lowestNewPrice;
- (AmazonPrice *)lowestUsedPrice;
- (AmazonPrice *)lowestCollectiblePrice;

// Images
- (AmazonImage *)smallImage;
- (AmazonImage *)mediumImage;
- (AmazonImage *)largeImage;

- (AmazonImage *)imageToFitSize:(NSSize)size;
- (AmazonImage *)imageToFitWidth:(CGFloat)width;
- (AmazonImage *)largestAvailableImage;

@end
