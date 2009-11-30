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
	KTPage *firstParent = [firstPage parentPage];
	
	unsigned int i;
	for ( i=1; i<[self count]; i++ )
	{
		KTPage *nextPage = [self objectAtIndex:i];
		if ( ![firstParent isEqual:[nextPage parentPage]] )
		{
			return NO;
		}
	}
	
	return YES;
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
        if ( nil != [aPage parentPage] )
		{
            if ( page == [aPage parentPage] )
			{
                return YES;
            }
        }
    }
	
    return NO;
}


@end
