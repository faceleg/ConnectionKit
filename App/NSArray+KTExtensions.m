//
//  NSArray+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/1/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "NSArray+KTExtensions.h"

#import "KTPage+Internal.h"
#import "NSArray+Karelia.h"

@implementation NSArray (KTExtensions)

- (BOOL)objectsHaveCommonParent
{
	if ( [self isEmpty] )
	{
		return NO;
	}
	
	KTPage *firstPage = [self firstObjectKS];
	KTPage *firstParent = [firstPage parent];
	
	unsigned int i;
	for ( i=1; i<[self count]; i++ )
	{
		KTPage *nextPage = [self objectAtIndex:i];
		if ( ![firstParent isEqual:[nextPage parent]] )
		{
			return NO;
		}
	}
	
	return YES;
}

#warning Is this even used?
- (KTPage *)commonParent
{
	KTPage *firstPage = [self firstObjectKS];
	KTPage *seedParent = [firstPage parent];
	KTPage *commonParent = nil;
	
	if ( [seedParent isRoot] )
	{
		return seedParent;
	}
	
	if ( (nil == seedParent) || [firstPage isDeleted] )
	{
		// somehow we're being asked for the parent of a deleted page!
		return nil;
	}
	
	BOOL parentFound = NO;
	while ( !parentFound )
	{
		commonParent = seedParent;
		
		unsigned int i;
		for ( i=0; i<[self count]; i++ )
		{
			KTPage *child = [self objectAtIndex:i];
			if ( ![child isDeleted] && ![child isDescendantOfPage:commonParent] )
			{
				// we didn't find a common parent,
				// back up one level and try again
				seedParent = [commonParent parent];
				if ( [seedParent isRoot] )
				{
					return seedParent;
				}
			}
		}
		
		// if we got through all the pages without changing the seedParent, we're done
		if ( [seedParent isEqual:commonParent] )
		{
			parentFound = YES;
		}
	}
	
	return commonParent;
}



- (BOOL)containsRoot
{
	NSEnumerator *e  = [self objectEnumerator];
	KTPage *page;
	while ( page = [e nextObject] )
	{
		if ( [page isRoot] )
		{
			return YES;
		}
	}
	
	return NO;
}

/*! returns whether any object in the array isDeleted */
- (BOOL)containsDeletedObject
{
	NSEnumerator *e  = [self objectEnumerator];
	NSManagedObject *object;
	while ( object = [e nextObject] )
	{
		if ( [object isDeleted] )
		{
			return YES;
		}
	}
	
	return NO;
}

- (NSArray *)parentObjects
{
	NSMutableArray *array = [NSMutableArray array];
	
	NSEnumerator *e = [self objectEnumerator];
	KTPage *page;
	while ( page = [e nextObject] )
	{
		if (![array containsParentOfPage:page])
		{
			[array addObject:page];
		}
	}
	
	return [NSArray arrayWithArray:array];
}

- (BOOL)containsParentOfPage:(KTPage *)aPage
{
    NSEnumerator *e = [self objectEnumerator];
    KTPage *page;
    while ( page = [e nextObject] )
	{
        if ( nil != [aPage parent] )
		{
            if ( page == [aPage parent] )
			{
                return YES;
            }
        }
    }
	
    return NO;
}


@end
