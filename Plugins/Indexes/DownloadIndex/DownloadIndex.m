//
//  DownloadIndex.m
//  KTPlugins
//
//  Created by Mike on 17/12/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "DownloadIndex.h"


@implementation DownloadIndex

- (NSSize)thumbnailSize
{
	return NSMakeSize(128.0, 128.0);
}

- (NSSet *)requiredMediaIdentifiers
{
	// We must hang onto the scaled images required for each page
	NSArray *pagesInIndex = [[self page] pagesInIndex];
	
	unsigned count = [[self valueForKeyPath:@"page.collectionMaxIndexItems"] unsignedIntValue];
	if (count > 0 && ([pagesInIndex count] > count) )
	{
		pagesInIndex = [pagesInIndex subarrayWithRange:NSMakeRange(0, count)];
	}
	
	
	NSMutableSet *result = [NSMutableSet setWithCapacity:[pagesInIndex count]];
	NSEnumerator *childPagesEnumerator = [pagesInIndex objectEnumerator];
	KTPage *aPage;
	while (aPage = [childPagesEnumerator nextObject])
	{
		NSSize thumbsSize = [self thumbnailSize];
		KTMediaContainer *scaledThumbnail = [[aPage thumbnail] imageToFitSize:thumbsSize];
		[result addObjectIgnoringNil:[scaledThumbnail identifier]];
	}
	
	
	return result;
}

@end
