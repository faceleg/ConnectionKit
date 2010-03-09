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

#pragma mark Perform Selector

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
		LOG((@"adding to stale set: %@", [[self titleBox] text]));
		[aSet addObject:self];
	}
}

@end
