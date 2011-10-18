//
//  NSDictionary+Amazon.m
//  iMediaAmazon
//
//  Created by Dan Wood on 1/2/07.
//  Copyright (c) 2007-2011 Karelia Software. All rights reserved.
//

#import "NSDictionary+Amazon.h"

@implementation NSDictionary ( Amazon )

// Init -- informal protocol for initializing with some simple xml
- (id)initWithXMLElement:(NSXMLElement *)xml;
{
	NSMutableDictionary *dict = [NSMutableDictionary dictionary];

	// Run through each child element, using its string value as a dictionary value
	NSEnumerator *enumerator = [[xml children] objectEnumerator];
	NSXMLNode *child;

	while (child = [enumerator nextObject])
	{
		// Ignore this child if it is not an element
		if ([child isKindOfClass: [NSXMLElement class]])
		{
			[dict setObject: [child stringValue] forKey: [child name]];
		}
	}
	
	return [self initWithDictionary: dict];
}

@end
