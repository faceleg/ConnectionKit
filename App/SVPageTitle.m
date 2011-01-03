//
//  KTPageTitle.m
//  Sandvox
//
//  Created by Mike on 23/01/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
//

#import "SVPageTitle.h"

#import "KTPage+Paths.h"


@interface KTPage (ChildrenPrivate)
- (void)invalidateSortedChildrenCache;
@end


@implementation SVPageTitle

@dynamic page;

- (void)setTextHTMLString:(NSString *)html
{
    [self willChangeValueForKey:@"textHTMLString"];
    [self setPrimitiveValue:html forKey:@"textHTMLString"];
    [self didChangeValueForKey:@"textHTMLString"];
	
	
    // If the page hasn't been published yet, update the filename to match
	KTPage *page = [self page];
	if ([page shouldUpdateFileNameWhenTitleChanges] && ![page datePublished])
	{
		[page setFileName:[[page suggestedFilename] stringByDeletingPathExtension]];
	}
	
	
	// Invalidate our parent's sortedChildren cache if it is alphabetically sorted
	SVCollectionSortOrder sorting = [[[page parentPage] collectionSortOrder] integerValue];
	if (sorting == SVCollectionSortAlphabetically)
	{
		[[page parentPage] invalidateSortedChildrenCache];
	}
}

@end
