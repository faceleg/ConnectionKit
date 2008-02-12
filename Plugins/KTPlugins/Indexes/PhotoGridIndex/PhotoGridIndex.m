//
//  PhotoGridIndex.m
//  KTPlugins
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "PhotoGridIndex.h"

#import <NSMutableSet+KTExtensions.h>


@implementation PhotoGridIndex

- (NSSize)thumbnailImageSize { return NSMakeSize(128.0, 128.0); }

- (NSSet *)requiredMediaIdentifiers
{
	// We must hang onto the scaled images required for each page
	NSArray *pagesInIndex = [[self page] sortedChildrenInIndex];
	
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
		NSSize thumbsSize = [self thumbnailImageSize];
		KTMediaContainer *scaledThumbnail = [[aPage thumbnail] imageToFitSize:thumbsSize];
		[result addObjectIgnoringNil:[scaledThumbnail identifier]];
	}
	
	
	return result;
}

@end
