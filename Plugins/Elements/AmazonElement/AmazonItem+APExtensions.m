//
//  AmazonItem+APExtensions.m
//  Amazon List
//
//  Created by Mike on 29/01/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "AmazonItem+APExtensions.h"

#import <AmazonSupport/AmazonSupport.h>


@implementation AmazonItem (APExtensions)

- (NSString *)creator
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
	NSMutableArray *creators = [NSMutableArray arrayWithCapacity: [creatorElements count]];
	
	NSXMLElement *creatorElement;
	
	for (creatorElement in creatorElements)
	{
		[creators addObject: [creatorElement stringValue]];
	}
	
	
	return [creators componentsJoinedByString: @", "];
}

- (NSString *)releaseDate;
{
	NSString *result = nil;
	
	// Look for a publication date. If not found go with release date
	NSXMLElement *xml = [self attributesXML];
	
	result = [xml stringValueForName: @"PublicationDate"];
	if (!result) {
		result = [xml stringValueForName: @"ReleaseDate"];
	}
	
	return result;
}

@end
