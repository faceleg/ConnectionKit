//
//  MoviePageDelegate.m
//  KTPlugins
//
//  Copyright (c) 2005, Karelia Software. All rights reserved.
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

#import "MoviePageDelegate.h"

@implementation MoviePageDelegate

#pragma mark -
#pragma mark Page Thumbnail

/*	Whenever the user tries to "clear" the thumbnail image, we'll instead reset it to match the page content.
 */
- (BOOL)pageShouldClearThumbnail:(KTPage *)page
{
	KTMediaContainer *posterImage = [[self delegateOwner] valueForKeyPath:@"mainElement.posterImage"];
	[[self delegateOwner] setThumbnail:posterImage];
	
	return NO;
}

#pragma mark -
#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"mainElement.captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }

#pragma mark -
#pragma mark Photo Album navigation

/*!	returns true if there is more than 1 photo page */
- (BOOL)needsPhotoNavigation
{
	[[self delegateOwner] lockPSCAndMOC];

	if (![[self page] includeInIndexAndPublish])
	{
		[[self delegateOwner] unlockPSCAndMOC];
		return NO;	// a page not in the index won't have the <- ->
	}
	
	NSSet *siblings = [[[self page] parent] childrenInIndexSet];
	NSEnumerator *theEnum = [siblings objectEnumerator];
	KTPage *sibling;
	int count = 0;
	
	while (nil != (sibling = [theEnum nextObject]) )
	{
		NSString *identifier = [[sibling bundle] bundleIdentifier];
		if ([identifier isEqualToString:@"sandvox.PhotoPage"] || [identifier isEqualToString:@"sandvox.MoviePage"])
		{
			count++;
			if (count >= 2)		// include photo navigation if 2 or more items
			{
				[[self delegateOwner] unlockPSCAndMOC];
				return YES;
			}
		}
	}
    
	[[self delegateOwner] unlockPSCAndMOC];
	return NO;		// didn't find enough elements to put the photo navigation there
}

// click right
- (NSString *)nextURLPath;
{
	[[self delegateOwner] lockPSCAndMOC];
	
	NSArray *siblings = [[[self page] parent] sortedChildrenInIndex];
	unsigned int whereSelf = [siblings indexOfObject:[self page]];
	NSAssert(NSNotFound != whereSelf, @"didn't find photo page among siblings");
	if (whereSelf < [siblings count] - 1)	// if you are at the end, there can be no next siblings
	{
		NSArray *afterSelf = [siblings subarrayWithRange:NSMakeRange(whereSelf+1, [siblings count] - (whereSelf+1))];
		NSEnumerator *theEnum = [afterSelf objectEnumerator];
		KTPage *sibling;
        
		while (nil != (sibling = [theEnum nextObject]) )
		{
			NSString *identifier = [[sibling bundle] bundleIdentifier];
			if ([identifier isEqualToString:@"sandvox.PhotoPage"] || [identifier isEqualToString:@"sandvox.MoviePage"])
			{
				[[self delegateOwner] unlockPSCAndMOC];
				return [sibling localPathAllowingIndexPage:YES];
			}
		}
	}

	[[self delegateOwner] unlockPSCAndMOC];

	return nil;
}

// click center
- (NSString *)parentURLPath;
{
	[[self delegateOwner] lockPSCAndMOC];
	NSString *result = [[[self page] parent] pathRelativeTo:[self page]];
	[[self delegateOwner] unlockPSCAndMOC];
	return result;
}

// click left
- (NSString *)previousURLPath;
{
	[[self delegateOwner] lockPSCAndMOC];

	NSArray *siblings = [[[self page] parent] sortedChildrenInIndex];
	int whereSelf = [siblings indexOfObject:[self page]];
	NSAssert(NSNotFound != whereSelf, @"didn't find photo page among siblings");
	if (whereSelf > 0)	// position zero on list means there can be no previous!
	{
		NSArray *beforeSelf = [siblings subarrayWithRange:NSMakeRange(0, whereSelf)];
		NSEnumerator *theEnum = [beforeSelf reverseObjectEnumerator];
		KTPage *sibling;
		
		while (nil != (sibling = [theEnum nextObject]) )
		{
			NSString *identifier = [[sibling bundle] bundleIdentifier];
			if ([identifier isEqualToString:@"sandvox.PhotoPage"] || [identifier isEqualToString:@"sandvox.MoviePage"])
			{
				[[self delegateOwner] unlockPSCAndMOC];
				return [sibling localPathAllowingIndexPage:YES];
			}
		}
	}
    
	[[self delegateOwner] unlockPSCAndMOC];
	return nil;
}

@end
