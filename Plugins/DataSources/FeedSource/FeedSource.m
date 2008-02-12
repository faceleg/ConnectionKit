//
//  FeedSource.m
//  KTPlugins
//
//  Copyright (c) 2004, Karelia Software. All rights reserved.
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

#import "FeedSource.h"

// Feed type defined by NetNewsWire, also exported by Vienna newsreader.  (No other news readers
// that I can find allow you to drag out a feed source)
// CorePasteboardFlavorType 'RSSs'
#define kNetNewsWireString @"CorePasteboardFlavorType 0x52535373"
@implementation FeedSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:
		kNetNewsWireString,	// from NetNewsWire
		@"WebURLsWithTitlesPboardType",
		@"BookmarkDictionaryListPboardType",
		NSURLPboardType,	// Apple URL pasteboard type
		nil];
}

// handle feed-specific info...

- (unsigned int)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)draggingInfo
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	NSArray *theArray = nil;

	if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kNetNewsWireString]]
		 && nil != (theArray = [pboard propertyListForType:kNetNewsWireString]) )
	{
		return [theArray count];
	}
	return 1;	// can't find any multiplicity
}

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];

	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kNetNewsWireString]]
		&& nil != [pboard propertyListForType:kNetNewsWireString])
	{
		return KTSourcePriorityIdeal;	// Yes, it's really a feed, from NNW
	}
		
	// Check to make sure it's not file: or feed:
	NSURL *extractedURL = [NSURL URLFromPasteboard:pboard];	// this type should be available, even if it's not the richest
	NSString *scheme = [extractedURL scheme];
	if ([scheme isEqualToString:@"feed"])
	{
		return KTSourcePriorityIdeal;	// Yes, a feed URL is what we want
	}
	if ([scheme hasPrefix:@"http"])	// http or https -- see if it has 
	{
		NSString *extension = [[[extractedURL path] pathExtension] lowercaseString];
		if ([extension isEqualToString:@"xml"]
			|| [extension isEqualToString:@"rss"]
			|| [extension isEqualToString:@"rdf"]
			|| [extension isEqualToString:@"atom"])	// we support reading of atom, not generation.
		{
			return KTSourcePriorityIdeal;
		}
	}

	// Otherwise, it doesn't look like it's a feed, so reject
	return KTSourcePriorityNone;
}

- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    BOOL result = NO;
    
    NSString *feedURLString = nil;
    NSString *feedTitle= nil;
	NSString *pageURLString = nil;
    
    NSArray *orderedTypes = [self acceptedDragTypesCreatingPagelet:isAPagelet];

    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	
    NSString *bestType = [pboard availableTypeFromArray:orderedTypes];
    
    if ( [bestType isEqualToString:@"BookmarkDictionaryListPboardType"] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:@"BookmarkDictionaryListPboardType"];
        NSDictionary *objectInfo = [arrayFromData objectAtIndex:anIndex];
        feedURLString = [objectInfo valueForKey:@"URLString"];
        feedTitle = [[objectInfo valueForKey:@"URIDictionary"] valueForKey:@"title"];
    }
    else if ( [bestType isEqualToString:@"WebURLsWithTitlesPboardType"] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
        NSArray *urlStringArray = [arrayFromData objectAtIndex:0];
        NSArray *urlTitleArray = [arrayFromData objectAtIndex:1];
        feedURLString = [urlStringArray objectAtIndex:anIndex];
        feedTitle = [urlTitleArray objectAtIndex:anIndex];
    }
    else if ( [bestType isEqualToString:kNetNewsWireString] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:kNetNewsWireString];
        NSDictionary *firstFeed = [arrayFromData objectAtIndex:anIndex];
        feedURLString = [firstFeed objectForKey:@"sourceRSSURL"];
		pageURLString = [firstFeed objectForKey:@"sourceHomeURL"];
        feedTitle = [firstFeed objectForKey:@"sourceName"];
    }
    else if ( [bestType isEqualToString:NSURLPboardType] )		// only one here
    {
		NSURL *url = [NSURL URLFromPasteboard:pboard];
		feedURLString = [url absoluteString];
		// Note: no title available from this
    }
    
    if ( nil != feedURLString )
    {
        [aDictionary setValue:feedURLString forKey:kKTDataSourceFeedURLString];
        if ( nil != feedTitle )
        {
            [aDictionary setValue:feedTitle forKey:kKTDataSourceTitle];
        }
		if (nil != pageURLString)	// only shows up on NNW drags
		{
			[aDictionary setValue:feedURLString forKey:kKTDataSourceURLString];
		}
        result = YES;
    }
    
    return result;
}

- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.FeedPagelet";
}

@end
