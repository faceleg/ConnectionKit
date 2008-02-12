//
//  URLSource.m
//  KTPlugins
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
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

#import "URLSource.h"

@implementation URLSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:
		@"WebURLsWithTitlesPboardType",
		@"BookmarkDictionaryListPboardType",
		NSURLPboardType,	// Apple URL pasteboard type
		nil];
}

- (unsigned int)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)draggingInfo isCreatingPagelet:(BOOL)isCreatingPagelet
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	NSArray *theArray = nil;
	
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]]
		&& nil != (theArray = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"]) )
	{
		NSArray *urlArray = [theArray objectAtIndex:0];
		return [urlArray count];
	}
	return 1;	// can't find any multiplicity
}

/*!	Don't allow file URLs.
*/
- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
	int result = KTSourcePriorityNone;
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSURLPboardType]])
	{
		NSURL *extractedURL = [NSURL URLFromPasteboard:pboard];

		if (nil != extractedURL)
		{
			if (![extractedURL isFileURL])
			{
				result = KTSourcePriorityReasonable;
			}
			else	// file URL, see if it's a webloc
			{
				NSString *path = [extractedURL path];
				if ([[path pathExtension] isEqualToString:@"webloc"])
				{
					result = KTSourcePriorityReasonable;
				}
			}
		}
	}
	return result;
}
	
- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    BOOL result = NO;
    
    NSString *urlString = nil;
    NSString *urlTitle= nil;
    
    NSArray *orderedTypes = [self acceptedDragTypesCreatingPagelet:isAPagelet];

    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	
    NSString *bestType = [pboard availableTypeFromArray:orderedTypes];
    
    if ( [bestType isEqualToString:@"BookmarkDictionaryListPboardType"] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:@"BookmarkDictionaryListPboardType"];
        NSDictionary *objectInfo = [arrayFromData objectAtIndex:anIndex];
        urlString = [objectInfo valueForKey:@"URLString"];
        urlTitle = [[objectInfo valueForKey:@"URIDictionary"] valueForKey:@"title"];
    }
    else if ( [bestType isEqualToString:@"WebURLsWithTitlesPboardType"] )
    {
        NSArray *arrayFromData = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
        NSArray *urlStringArray = [arrayFromData objectAtIndex:0];
        NSArray *urlTitleArray = [arrayFromData objectAtIndex:1];
        urlString = [urlStringArray objectAtIndex:anIndex];
        urlTitle = [urlTitleArray objectAtIndex:anIndex];
    }
    else if ( [bestType isEqualToString:NSURLPboardType] )
    {
		NSURL *extractedURL = [NSURL URLFromPasteboard:pboard];
		urlString = [extractedURL absoluteString];
		// Note: no title available from this
		
		// We may be able to get title from CorePasteboardFlavorType 'urln'
		if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"CorePasteboardFlavorType 0x75726C6E"]])
		{
			urlTitle = [pboard stringForType:@"CorePasteboardFlavorType 0x75726C6E"];
		}
		
		// Convert .webloc files to their contained URL
		if ([extractedURL isFileURL])
		{
			NSString *path = [extractedURL path];
			if ([[path pathExtension] isEqualToString:@"webloc"])
			{
				// Use the Carbon Resource Manager to read 'url ' resource #256.
				NSData *urlData = [[NSFileManager defaultManager] readFromResourceFileAtPath:path
																						type:'url '
																					   named:nil
																						  id:256];
				// Sring sems to be pre ASCII, with 2-bytes converted to % escapes
				urlString = [[[NSString alloc] initWithData:urlData encoding:NSASCIIStringEncoding] autorelease];
				urlString = [urlString encodeLegally];
				
				// Use the Carbon Resource Manager to read 'urln' resource #256.
				NSData *nameData = [[NSFileManager defaultManager] readFromResourceFileAtPath:path
																						 type:'urln'
																						named:nil
																						   id:256];
				// empirically, this seems to be UTF8 encoded.
				urlTitle = [[[NSString alloc] initWithData:nameData encoding:NSUTF8StringEncoding] autorelease];
			}
		}
    }
    
    if ( nil != urlString )
    {
        [aDictionary setValue:urlString forKey:kKTDataSourceURLString];
        if ( nil != urlTitle )
        {
            [aDictionary setValue:urlTitle forKey:kKTDataSourceTitle];
        }
		// 
		// currently no suggested pagelet type defined.... an iFrame pagelet is too esoteric.  Maybe a simple "bookmark" pagelet?  Especially if multiple URLs selected, maybe from Safari
		
        result = YES;
    }
    
    return result;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.LinkPage";
}
- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.LinkListPagelet";
}




@end
