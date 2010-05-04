//
//  LinkListPageletDelegate.m
//  Sandvox SDK
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
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

#import "LinkListPageletDelegate.h"

// LocalizedStringInThisBundle(@"(Add links via Details Inspector)", "String_On_Page_Template")

@implementation LinkListPageletDelegate

/*	When possible, create a starting link from the user's web browser
 */
- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewlyCreatedObject
{
	if (isNewlyCreatedObject)
	{
		NSURL *URL = nil;	NSString *title = nil;
		[NSAppleScript getWebBrowserURL:&URL title:&title source:NULL];
		if (URL)
		{
			if (!title) title = @"";
            
            NSMutableDictionary *newLink = [NSMutableDictionary dictionaryWithObjectsAndKeys:
				[title stringByEscapingHTMLEntities], @"titleHTML",
				[URL absoluteString], @"url", nil];
			
			NSArray *links = [NSArray arrayWithObject:newLink];
			[[self delegateOwner] setValue:links forKey:@"linkList"];
		}
	}
}



/*!	Create a single item with all the URLs listed.  This means we parse the pasteboard directly.
*/
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	NSString *oldTitle = [[self delegateOwner] titleHTML];
	[super awakeFromDragWithDictionary:aDictionary];
	// Above sets the title ... Restore it to the generic.
	[[self delegateOwner] setTitleHTML:oldTitle];
	
	// We are building up this array
	NSMutableArray *array = [NSMutableArray array];

	NSPasteboard *pboard = [aDictionary objectForKey:kKTDataSourcePasteboard];
    NSArray *orderedTypes = [NSArray arrayWithObjects:
		@"WebURLsWithTitlesPboardType",
		@"BookmarkDictionaryListPboardType",
		NSURLPboardType,	// Apple URL pasteboard type
		nil];
    NSString *bestType = [pboard availableTypeFromArray:orderedTypes];
    
    if ( [bestType isEqualToString:@"BookmarkDictionaryListPboardType"] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:@"BookmarkDictionaryListPboardType"];
		NSEnumerator *theEnum = [arrayFromData objectEnumerator];
		NSDictionary *objectInfo;

		while (nil != (objectInfo = [theEnum nextObject]) )
		{
			NSDictionary *oneEntry = [NSDictionary dictionaryWithObjectsAndKeys:
				[objectInfo valueForKey:@"URLString"], @"url",
				[[[objectInfo valueForKey:@"URIDictionary"] valueForKey:@"title"] stringByEscapingHTMLEntities], @"titleHTML",
				nil];
			[array addObject:oneEntry];
		}
    }
    else if ( [bestType isEqualToString:@"WebURLsWithTitlesPboardType"] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
        NSArray *urlStringArray = [arrayFromData objectAtIndex:0];
        NSArray *urlTitleArray = [arrayFromData objectAtIndex:1];
		unsigned int i;
		for (i = 0 ; i < [urlStringArray count] ; i++ )
		{
 			NSDictionary *oneEntry = [NSDictionary dictionaryWithObjectsAndKeys:
				[urlStringArray objectAtIndex:i], @"url",
				[[urlTitleArray objectAtIndex:i] stringByEscapingHTMLEntities], @"titleHTML",
				nil];
			[array addObject:oneEntry];
		}
	}
    else	// other; use the single-entry info already given to us
    {
		NSString *urlString = [aDictionary valueForKey:kKTDataSourceURLString];
		if ( nil != urlString )
		{
			NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
			if (nil == title)
			{
				title = urlString;
			}
			NSDictionary *singleEntry = [NSDictionary dictionaryWithObjectsAndKeys:
				urlString, @"url",
				[title stringByEscapingHTMLEntities], @"titleHTML",
				nil];
			[array addObject:singleEntry];
		}
	}
	
	[[self delegateOwner] setValue:array forKey:@"linkList"];
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            @"WebURLsWithTitlesPboardType",
            @"BookmarkDictionaryListPboardType",
            NSURLPboardType,	// Apple URL pasteboard type
            NSStringPboardType,
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)pboard
{
	NSArray *theArray = nil;
	
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]]
		&& nil != (theArray = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"]) )
	{
		NSArray *urlArray = [theArray objectAtIndex:0];
		return [urlArray count];
	}
	return 1;	// can't find any multiplicity
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    int result = KTSourcePriorityNone;
    
	NSArray *webLocations = [NSClassFromString(@"KSWebLocation") webLocationsFromPasteboard:pboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	// Only allow creating a link list pagelet from a drag to pagelet area
	if (isCreatingPagelet && webLocations && [webLocations count] >= 1)
	{
		result = KTSourcePriorityReasonable;
	}
	
	return result;
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    
    NSArray *webLocations = [NSClassFromString(@"KSWebLocation") webLocationsFromPasteboard:pasteboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > 0)
	{
		NSURL *URL = [[webLocations objectAtIndex:0] URL];
		NSString *title = [[webLocations objectAtIndex:0] title];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (title && (id)title != [NSNull null])
		{
			[aDictionary setValue:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}

@end
