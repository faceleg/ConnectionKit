//
//  NSArray+KTExtensions.m
//  KTComponents
//
//  Created by Terrence Talbot on 9/1/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "NSArray+KTExtensions.h"

#import "KTPage.h"

@implementation NSArray ( KTExtensions )

/*	To complement +arrayWithObject: since oddly NSArray has no corresponding init method.
 */
- (id)initWithObject:(id)anObject
{
	return [self initWithObjects:anObject, nil];
}

/*	The same as -objectAtIndex: but the order is reversed
 *	i.e. index 0 corresponds to [array count]
 */
- (id)objectAtReverseIndex:(int)index
{
	id result = [self objectAtIndex:([self count] - index - 1)];
	return result;
}

- (BOOL)containsObjectIdenticalTo:(id)object
{
	unsigned int objectIndex = [self indexOfObjectIdenticalTo: object];
	
	if (objectIndex == NSNotFound) {
		return NO;
	}
	else {
		return YES;
	}
}

- (BOOL)containsObjectEqualToString:(NSString *)aString
{
	NSEnumerator *e = [self objectEnumerator];
	id object;
	while ( object = [e nextObject] )
	{
		if ( [object isKindOfClass:[NSString class]] && [object isEqualToString:aString] )
		{
			return YES;
		}
	}
	
	return NO;
}

- (id)firstObject
{
	return [self objectAtIndex:0];
}

- (id)firstObjectOrNilIfEmpty
{
	id result = nil;
	
	if (![self isEmpty]) {
		result = [self objectAtIndex: 0];
	}
	
	return result;
}

- (BOOL)isEmpty
{
	return ([self count] == 0);
}

- (void)removeObserver:(NSObject *)anObserver fromObjectsAtIndexes:(NSIndexSet *)indexes forKeyPaths:(NSSet *)keyPaths
{
	NSEnumerator *enumerator = [keyPaths objectEnumerator];
	NSString *aKeyPath;
	
	while (aKeyPath = [enumerator nextObject])
	{
		[self removeObserver:anObserver fromObjectsAtIndexes:indexes forKeyPath:aKeyPath];
	}
}

#pragma mark -

- (BOOL)objectsHaveCommonParent
{
	if ( [self isEmpty] )
	{
		return NO;
	}
	
	KTPage *firstPage = [self firstObject];
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

- (KTPage *)commonParent
{
	KTPage *firstPage = [self firstObject];
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
			if ( ![child isDeleted] && ![commonParent containsDescendant:child] )
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
		if ( ![array containsParentOfPage:page] )
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


// -----------------------------------------------------------------------------
//	colorValue:
//		Converts an NSArray with three (or four) NSValues into an RGB Color
//		(plus alpha, if specified).
//
//  REVISIONS:
//		2004-05-18  witness documented.
// -----------------------------------------------------------------------------
//  Created by Uli Kusterer on Mon Jun 02 2003.
//  Copyright (c) 2003 M. Uli Kusterer. All rights reserved.

-(NSColor*)		colorValue
{
	float			fRed, fGreen, fBlue, fAlpha = 1.0;
	
	fRed = [[self objectAtIndex:0] floatValue];
	fGreen = [[self objectAtIndex:1] floatValue];
	fBlue = [[self objectAtIndex:2] floatValue];
	if( [self count] > 3 )	// Have alpha info?
		fAlpha = [[self objectAtIndex:3] floatValue];
	
	return [NSColor colorWithCalibratedRed: fRed green: fGreen blue: fBlue alpha: fAlpha];
}


@end
