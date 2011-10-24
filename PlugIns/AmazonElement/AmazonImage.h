//
//  AmazonImage.h
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//
//	A subclass of AsyncImage. Rather than loading the image from a particuar URL, specify some XML
//	or a size, ASIN and country. These paramaters are parsed to build the correct URL and the image
//	downloaded as per normal.


#import <Cocoa/Cocoa.h>
#import "AsyncImage.h"
#import "AmazonECSOperation.h"


typedef enum {
	AmazonImageUnknown = 0,
	AmazonImageSmall = 1,
	AmazonImageMedium = 2,
	AmazonImageLarge = 3,
} AmazonImageSize;


@interface AmazonImage : AsyncImage
{
	AmazonImageSize		myAmazonSize;
	NSSize				myDimensions;
}

- (id)initWithXML:(NSXMLElement *)xml;
- (id)initWithSize:(AmazonImageSize)aSize ASIN:(NSString *)anASIN country:(AmazonStoreCountry)aCountry;

- (AmazonImageSize)amazonSize;
- (NSSize)dimensions;

@end

