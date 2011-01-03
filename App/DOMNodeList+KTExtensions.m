//
//  DOMNodeList+KTExtensions.m
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "DOMNodeList+KTExtensions.h"


@implementation DOMNodeList (KTExtensions)

/*	Methods to basically do the same as NSArray.
 */
- (unsigned)indexOfItemIdenticalTo:(DOMNode *)item
{
	unsigned result = NSNotFound;
	
	unsigned length = [self length];
	int i;
	for (i=0; i<length; i++)
	{
		if ([self item:i] == item)
		{
			result = i;
			break;
		}
	}
	
	return result;
}

@end
