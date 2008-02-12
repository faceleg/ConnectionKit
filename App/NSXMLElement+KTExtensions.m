//
//  NSXMLElement+KTExtensions.m
//  Marvel
//
//  Created by Mike on 01/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "NSXMLElement+KTExtensions.h"


@implementation NSXMLElement (KTExtensions)

- (void) removeAllNodesAfter:(NSXMLElement *)lastNode;
{
	// NSXMLNode
	NSXMLElement *parent = (NSXMLElement *)[lastNode parent];
	NSXMLElement *stopNode = (NSXMLElement *)[self parent];
	while (nil != parent && parent != stopNode)	// stop if we hit nil, or the parent of self
	{
		unsigned anIndex = [lastNode index];
		int count = [[parent children] count];
		unsigned int i;
		for ( i = count-1; i > anIndex; i-- )
		{
			[parent removeChildAtIndex:i];
		}
		lastNode = parent;	// now we will be working with this parent as the new node to remove things after
		parent = (NSXMLElement *)[lastNode parent];
	}
}

@end
