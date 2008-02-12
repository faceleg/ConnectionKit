//
//  NSIndexPath+KTExtensions.m
//  Hertzfeld
//
//  Created by Terrence Talbot on 2/20/05.
//  Copyright 2005 __MyCompanyName__. All rights reserved.
//

#import "NSIndexPath+Karelia.h"


@implementation NSIndexPath ( KTExtensions  )

- (NSIndexPath *)indexPathByIncrementingLastIndex
{
	unsigned int length = [self length];
	unsigned int last = length-1;

	unsigned int theIndexes[length];	
	[self getIndexes:theIndexes];
	
	int value = theIndexes[last];
	theIndexes[last] = ++value;
	
	return [NSIndexPath indexPathWithIndexes:theIndexes length:length];
}

- (NSIndexPath *)indexPathByDecrementingLastIndex
{
	NSIndexPath *tempIndexPath = [self indexPathByRemovingLastIndex];

	int lastIndex = [self indexAtPosition:([self length]-1)];
	--lastIndex;
	
	if ( lastIndex < 0 )
	{
		return tempIndexPath;
	}
	else
	{
		return [tempIndexPath indexPathByAddingIndex:lastIndex];
	}
}

- (NSIndexPath *)indexPathOfParent
{
	return [self indexPathByRemovingLastIndex];
}

- (unsigned int)indexAtEndPosition
{
	return [self indexAtPosition:([self length]-1)];
}

@end
