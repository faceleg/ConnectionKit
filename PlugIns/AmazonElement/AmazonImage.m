//
//  AmazonImage.m
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "AmazonImage.h"

#import "NSXMLElement+Amazon.h"

@interface AmazonImage ( Private )

- (void)setAmazonSize:(AmazonImageSize)anAmazonSize;
- (void)setDimensions:(NSSize)aDimensions;

@end

@implementation AmazonImage

#pragma mark -
#pragma mark Init/Dealloc

// Documented here: http://aaugh.com/imageabuse.html

- (id)initWithSize:(AmazonImageSize)aSize ASIN:(NSString *)anASIN country:(AmazonStoreCountry)aCountry;
{
	static NSArray *sImageCodes = nil;
	if (nil == sImageCodes) sImageCodes = [[NSArray alloc] initWithObjects:
		@"?", @"THUMBZZZ", @"MZZZZZZZ", @"LZZZZZZZ", nil];

	//                        xxx  US  UK  DE  JA  FR  CA
	NSInteger countryCodeLookup[] = { 999, 1,  2,  3,  9,  8,  1 };	// convert our enum to the code needed

	NSString *urlString = [NSString stringWithFormat:
		@"http://images.amazon.com/images/P/%@.0%d._SC%@_.jpg",
		anASIN, countryCodeLookup[aCountry], [sImageCodes objectAtIndex:aSize]];
	
	NSURL *url = [NSURL URLWithString:urlString];
	if ((self = [super initWithURL:url]) != nil)
	{
		myAmazonSize = aSize;
	}
	return self;
}


- (id)initWithXML:(NSXMLElement *)xml
{
	// Image URL
	NSString *urlString = [xml stringValueForName: @"URL"];
	NSURL *url			= [NSURL URLWithString:urlString];
	if ((self = [super initWithURL:url]) != nil)
	{
		// Amazon size
		NSString *sizeString = [xml name];
		if ([sizeString isEqualToString: @"SmallImage"])
			myAmazonSize = AmazonImageSmall;
		else if ([sizeString isEqualToString: @"MediumImage"])
			myAmazonSize = AmazonImageMedium;
		else if ([sizeString isEqualToString: @"LargeImage"])
			myAmazonSize = AmazonImageLarge;

		// Dimensions
		CGFloat width = [[xml stringValueForName: @"Width"] doubleValue];
		CGFloat height = [[xml stringValueForName: @"Height"] doubleValue];
		myDimensions = NSMakeSize(width, height);
	}
	return self;
}

#pragma mark -
#pragma mark Accessors

- (AmazonImageSize)amazonSize
{
    return myAmazonSize;
}

- (void)setAmazonSize:(AmazonImageSize)anAmazonSize
{
    myAmazonSize = anAmazonSize;
}

- (NSSize)dimensions
{
    return myDimensions;
}

- (void)setDimensions:(NSSize)aDimensions
{
    myDimensions = aDimensions;
}

#pragma mark -
#pragma mark Description

- (NSString *)description
{
	NSString *sizeDesc;
	switch (myAmazonSize)
	{
		case AmazonImageSmall:		sizeDesc = @"SMALL";		break;
		case AmazonImageMedium:		sizeDesc = @"MEDIUM";		break;
		case AmazonImageLarge:		sizeDesc = @"LARGE";		break;
		default: sizeDesc = [NSString stringWithFormat:@"Unknown [%d]", myAmazonSize]; break;
	}
	return [NSString stringWithFormat:@"%@ Size: %@ %@",
		[super description], sizeDesc,  NSStringFromSize(myDimensions)];
}

@end
