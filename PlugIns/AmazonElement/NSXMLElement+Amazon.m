//
//  NSXMLElement+Amazon.m
//  Amazon Support
//
//  Created by Mike on 27/12/2006.
//  Copyright 2006-2011 Karelia Software. All rights reserved.
//

#import "NSXMLElement+Amazon.h"

//#import "NSArray+Amazon.h"


@implementation NSXMLElement ( Amazon )

- (NSXMLElement *)elementForName:(NSString *)elementName
{
	// Returns the first element found for that name
	NSArray *elements = [self elementsForName: elementName];
	
	NSXMLElement *result = nil;
	if (elements && [elements count] > 0) {
		result = [elements objectAtIndex:0];
	}
	
	return result;
}

- (NSString *)stringValueForName:(NSString *)elementName
{
	// Returns the string value of the first element for that name
	NSXMLElement *element = [self elementForName: elementName];
	NSString *stringValue = [element stringValue];

	return stringValue;
}

// TODO: MERGE WITH NSDICTIONARY INITIALIZER

- (NSDictionary *)simpleDictionaryRepresentation
{
	NSMutableDictionary *intermediateDictionary =
		[[[NSMutableDictionary alloc] initWithCapacity: [self childCount]] autorelease];

	// Run through each child element, using its string value as a dictionary value
	NSEnumerator *enumerator = [[self children] objectEnumerator];
	NSXMLNode *child;

	while (child = [enumerator nextObject])
	{
		// Ignore this child if it is not an element
		if ([child isKindOfClass: [NSXMLElement class]])
		{
			NSString *key = [child name];
			NSString *stringValue = [child stringValue];

			[intermediateDictionary setObject: stringValue forKey: key];
		}
	}

	// Convert the intermediate dictionary to an immutable one and return it
	NSDictionary *dictionaryRep = [NSDictionary dictionaryWithDictionary:intermediateDictionary];
	return dictionaryRep;
}

@end
