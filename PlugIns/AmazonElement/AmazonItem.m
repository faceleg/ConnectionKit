//
//  AmazonItem.m
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "AmazonItem.h"
#import "AmazonImage.h"
#import "AmazonPrice.h"

#import "NSXMLElement+Amazon.h"


@interface AmazonItem (Private)

- (void)_loadImagesFromXML:(NSXMLElement *)xml;
+ (void)_getImageURL:(NSURL **)url andSize:(NSSize *)size fromXML:(NSXMLElement *)xml;

- (void)loadPricesFromXML:(NSXMLElement *)xml;
@end

@implementation AmazonItem

# pragma mark *** Init & Dealloc ***

- (id)initWithXMLElement:(NSXMLElement *)xml
{
	[super init];

	// ASIN
	_ASIN = [[xml stringValueForName: @"ASIN"] copy];

	// Details Page
	NSString *detailsPageAddress = [xml stringValueForName: @"DetailPageURL"];
	if (detailsPageAddress) {
		_detailsPage = [[NSURL alloc] initWithString: detailsPageAddress];
	}

	// Item attributes
	myAttributes = [[xml elementForName: @"ItemAttributes"] copy];

	// Images
	[self _loadImagesFromXML: xml];
	
	// Prices
	[self loadPricesFromXML:xml];

	return self;
}

- (void)_loadImagesFromXML:(NSXMLElement *)xml
{
	NSXMLElement *smallImageXML = [xml elementForName: @"SmallImage"];
	if (smallImageXML)
		_smallImage = [[AmazonImage alloc] initWithXML: smallImageXML];

	NSXMLElement *mediumImageXML = [xml elementForName: @"MediumImage"];
	if (mediumImageXML)
		_mediumImage = [[AmazonImage alloc] initWithXML: mediumImageXML];

	NSXMLElement *largeImageXML = [xml elementForName: @"LargeImage"];
	if (largeImageXML)
		_largeImage = [[AmazonImage alloc] initWithXML: largeImageXML];
}

# pragma mark *** Dealloc ***

- (void)dealloc
{
	[_ASIN release];
	[_detailsPage release];
	[myAttributes release];
	
	[myListPrice release];
	[myLowestNewPrice release];
	[myLowestUsedPrice release];
	[myLowestCollectiblePrice release];

	[_smallImage release];
	[_mediumImage release];
	[_largeImage release];

	[super dealloc];
}

# pragma mark *** General Accessors ***

- (NSXMLElement *)attributesXML { return myAttributes; }

- (NSString *)amazonID { return _ASIN; }

- (NSString *)title { return [[self attributesXML] stringValueForName:@"Title"]; }

- (NSString  *)creator
{
	NSXMLElement *xml = [self attributesXML];
	
	
	// First figure out if we are using Artist, Author or Manufacturer
	NSArray *creatorElements = nil;
	
	creatorElements = [xml elementsForName: @"Artist"];
	if ([creatorElements count] == 0) {
		creatorElements = [xml elementsForName: @"Author"];
	}
	if ([creatorElements count] == 0) {
		creatorElements = [xml elementsForName: @"Director"];
	}
	if ([creatorElements count] == 0) {
		creatorElements = [xml elementsForName: @"Manufacturer"];
	}
	
	
	// Put the string values of all creator elements together
	NSMutableArray *creators = [NSMutableArray arrayWithCapacity:[creatorElements count]];
	
	NSEnumerator *enumerator = [creatorElements objectEnumerator];
	NSXMLElement *creatorElement;
	
	while (creatorElement = [enumerator nextObject])
	{
		[creators addObject:[creatorElement stringValue]];
	}
	
	
	return [creators componentsJoinedByString:@", "];
}

- (NSURL *)detailsPage { return _detailsPage; }

#pragma mark -
#pragma mark Pricing

- (void)loadPricesFromXML:(NSXMLElement *)xml
{
	NSXMLElement *listPriceXML = [[xml elementForName:@"ItemAttributes"] elementForName:@"ListPrice"];
	myListPrice = [[AmazonPrice alloc] initWithXML:listPriceXML];
	
	NSXMLElement *offers = [xml elementForName:@"OfferSummary"];
	
	NSXMLElement *newPriceXML = [offers elementForName:@"LowestNewPrice"];
	myLowestNewPrice = [[AmazonPrice alloc] initWithXML:newPriceXML];
	
	NSXMLElement *usedPriceXML = [offers elementForName:@"LowestUsedPrice"];
	myLowestUsedPrice = [[AmazonPrice alloc] initWithXML:usedPriceXML];
	
	NSXMLElement *collectiblePriceXML = [offers elementForName:@"LowestCollectiblePrice"];
	myLowestCollectiblePrice = [[AmazonPrice alloc] initWithXML:collectiblePriceXML];
}

- (AmazonPrice *)listPrice { return myListPrice; }

- (AmazonPrice *)lowestNewPrice { return myLowestNewPrice; }

- (AmazonPrice *)lowestUsedPrice { return myLowestUsedPrice; }

- (AmazonPrice *)lowestCollectiblePrice { return myLowestCollectiblePrice; }

# pragma mark *** Images ***

- (AmazonImage *)smallImage { return [[_smallImage retain] autorelease]; }

- (AmazonImage *)mediumImage { return [[_mediumImage retain] autorelease]; }

- (AmazonImage *)largeImage { return [[_largeImage retain] autorelease]; }

- (AmazonImage *)imageToFitSize:(NSSize)desiredSize
{
	AmazonImage *image = nil;
	NSSize testImageSize;

	// Pick the smallest image that exceeds or matches the required size in one dimension
	image = [self smallImage];
	testImageSize = [image dimensions];
	if (testImageSize.width >= desiredSize.width || testImageSize.height >=desiredSize.height)
		return image;

	image = [self mediumImage];
	testImageSize = [image dimensions];
	if (testImageSize.width >= desiredSize.width || testImageSize.height >=desiredSize.height)
		return image;

	// If none of the other two match, use the largest image
	return [self largestAvailableImage];
}

- (AmazonImage *)imageToFitWidth:(CGFloat)desiredWidth
{
	AmazonImage *image = nil;
	
	// Pick the smallest image that exceeds or matches the required width
	image = [self smallImage];
	if ([image dimensions].width >= desiredWidth)
		return image;

	image = [self mediumImage];
	if ([image dimensions].width >= desiredWidth)
		return image;

	// If none of the other two match, use the largest image
	return [self largestAvailableImage];
}

- (AmazonImage *)largestAvailableImage
{
	AmazonImage *image;

	image = [self largeImage];
	if (image)
		return image;

	image = [self mediumImage];
	if (image)
		return image;

	image = [self smallImage];
	if (image)
		return image;

	return nil;
}

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ ASIN:%@ URL:%d Attributes:%@ Images:%p/%p/%p",
		[super description],
		_ASIN,
		_detailsPage,
		myAttributes,
		_smallImage, _mediumImage, _largeImage
		];
}

@end
