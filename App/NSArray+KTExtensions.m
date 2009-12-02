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
