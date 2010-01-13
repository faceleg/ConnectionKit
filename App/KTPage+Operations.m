//
//  KTPage+Operations.m
//  KTComponents
//
//  Created by Dan Wood on 8/9/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTPage+Internal.h"

#import "Debug.h"
#import "KTAbstractIndex.h"
#import "KTDocument.h"

#import "NSObject+Karelia.h"
#import "NSSet+KTExtensions.h"


@implementation KTPage ( Operations )

- (void)setValue:(id)value forKey:(NSString *)key recursive:(BOOL)recursive
{
    [self setValue:value forKey:key];
    
    if (recursive)
    {
        NSEnumerator *childrenEnumerator = [[self childItems] objectEnumerator];
        KTPage *aChildPage;
        while (aChildPage = [childrenEnumerator nextObject])
        {
            [aChildPage setValue:value forKey:key recursive:YES];
        }
    }
}

#pragma mark -
#pragma mark Perform Selector

/*	Add to the default behavior by respecting the recursive flag
 */
- (void)makeSelfOrDelegatePerformSelector:(SEL)selector
							   withObject:(void *)anObject
								 withPage:(KTPage *)page
								recursive:(BOOL)recursive
{
	[super makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:recursive];
	
	if (recursive)
	{
		NSEnumerator *childrenEnumerator = [[self childItems] objectEnumerator];
		KTPage *aPage;
		while (aPage = [childrenEnumerator nextObject])
		{
			[aPage makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:recursive];
		}
	}
}

/*	Perform the selector on our components (pagelets, index if present). Then allow
 *	-makeSelfOrDelegatePerformSelector: to take over.
 */
- (void)makeComponentsPerformSelector:(SEL)selector
						   withObject:(void *)anObject
							 withPage:(KTPage *)page
							recursive:(BOOL)recursive
{
	// Bail early if we've been deleted
	if ([self isDeleted])
	{
		return;
	}
	
	
	// Index - if we have no index, this call is to nil, so does nothing
	KTAbstractIndex *index = [self index];
	[index makeComponentsPerformSelector:selector withObject:anObject withPage:page];
	
	
	// Self/delegate, and then children
	[self makeSelfOrDelegatePerformSelector:selector withObject:anObject withPage:page recursive:recursive];
}

// Called via recursiveComponentPerformSelector
// Kind of inefficient since we're just looking to see if there are ANY RSS collections

- (void)addRSSCollectionsToArray:(NSMutableArray *)anArray forPage:(KTPage *)aPage
{
	BOOL rss = ([self collectionCanSyndicate] && [self collectionSyndicate]);
	if (rss)
	{
		[anArray addObject:self];
	}
}

- (void)addDesignsToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	NSString *pageDesign = [self wrappedValueForKey:@"designBundleIdentifier"];		// NOT inherited
	if (pageDesign)
	{
		//LOG((@"%@ adding design:%@", [self class], pageDesign));
		[aSet addObject:pageDesign];
	}
}

// Called via recursiveComponentPerformSelector
- (void)addStaleToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
	if ([self boolForKey:@"isStale"])
	{
		LOG((@"adding to stale set: %@", [[self title] text]));
		[aSet addObject:self];
	}
}

#pragma mark -
#pragma mark Spotlight

@end
