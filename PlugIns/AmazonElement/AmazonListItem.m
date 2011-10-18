//
//  AmazonListItem.m
//  Amazon List
//
//  Created by Mike on 16/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AmazonListItem.h"

#import "NSXMLElement+Amazon.h"


@implementation AmazonListItem

- (id)initWithXMLElement:(NSXMLElement *)xml
{
	// Init normally with the "Item" part of the XML tree
	NSXMLElement *itemXML = [xml elementForName: @"Item"];
	[super initWithXMLElement: itemXML];
	
	// Load list specific properties
	myComment = [xml stringValueForName: @"Comment"];
	
	NSString *quantityDesiredString = [xml stringValueForName: @"QuantityDesired"];
	if (quantityDesiredString)
		myQuantityDesired = [quantityDesiredString integerValue];
	
	NSString *quantityReceivedString = [xml stringValueForName: @"QuantityReceived"];
	if (quantityReceivedString)
		myQuantityReceived = [quantityReceivedString integerValue];
	
	return self;
}

- (NSString *)comment { return myComment; }

- (NSUInteger)quantityDesired { return myQuantityDesired; }

- (NSUInteger)quantityReceived { return myQuantityReceived; }

@end
