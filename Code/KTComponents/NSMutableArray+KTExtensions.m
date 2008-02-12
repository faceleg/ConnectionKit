//
//  NSMutableArray+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 5/2/07.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "NSMutableArray+KTExtensions.h"


@implementation NSMutableArray ( KTExtensions )

- (void)fastAddObjectsFromArray:(NSArray *)anArray
{
	int i;
	for ( i=0; i<[anArray count]; i++ )
	{
		id object = [anArray objectAtIndex:i];
		[self addObject:object];
	}
}

/*	This is trickier that it might at first appear. To move an object DOWN the array
 *	some of the objects below it will have to move up. Therefore we consider newIndex as
 *	the index BEFORE the array was modified at all.
 */
- (void)moveObjectAtIndex:(unsigned)oldIndex toIndex:(unsigned)newIndex
{
	// Bail if there's nothing to do
	if (oldIndex == newIndex) {
		return;
	}
	
	// Insert a second copy of the object in the array
	[self insertObject:[self objectAtIndex:oldIndex] atIndex:newIndex];
	
	// Remove the original object (if moving UP, it will have changed index)
	if (newIndex < oldIndex) {
		oldIndex++;
	}
	[self removeObjectAtIndex:oldIndex];
}

@end
