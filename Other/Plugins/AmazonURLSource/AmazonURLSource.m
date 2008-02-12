//
//  AmazonURLSource.m
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
//  Community Note: This code is distrubuted under the BSD License. We encourage 
//  you to share your Sandvox Plugins similarly.
//

#import "AmazonURLSource.h"


@implementation AmazonURLSource

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(int)anIndex;
{
    int result = KTSourcePriorityNone;
	NSPasteboard *pboard = [draggingInfo draggingPasteboard];

	if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSURLPboardType]] )
	{
        NSURL *url = [NSURL URLFromPasteboard:pboard];
		NSString *host = [url host];
		if (NSNotFound != [host rangeOfString:@"amazon.com"].location)
		{
			result = KTSourcePriorityIdeal;
		}
	}
	return result;
}

/*!	Get data from RTF.  Kind of redundant to have to do this one time per object -- oh well.
*/

- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(int)anIndex;
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
		// EASIER THAN THIS:
		//        NSArray *arrayFromData = [pboard propertyListForType:NSURLPboardType];
		//        urlString = [arrayFromData objectAtIndex:0];
    }
	
    
    if ( nil != urlString )
    {
        if ( nil != urlTitle )
        {
            [aDictionary setValue:urlTitle forKey:kKTDataSourceTitle];
        }
		
		// Same logic here as Delicious Source
		
		// http://www.amazon.com/exec/obidos/ASIN/0385504209/
		NSRange whereASIN = [urlString rangeBetweenString:@"ASIN/" andString:@"/"];
		NSString *ASIN = @"";
		if (NSNotFound != whereASIN.location)
		{
			// NOTE: This will convert a foreign Amazon URL to a US one ... we could preserve the domain, but what about the URL format and associates string?
			ASIN = [urlString substringWithRange:whereASIN];
			NSString *imageURLString = [NSString stringWithFormat:@"http://images.amazon.com/images/P/%@.01.MZZZZZZZ.jpg", ASIN];
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			NSString *linkURLString = [NSString stringWithFormat:@"http://www.amazon.com/exec/obidos/ASIN/%@/ref=nosim/%@", ASIN, [defaults objectForKey:@"AmazonAssociatesToken"]];
																		//			[aDictionary setValue:[NSString stringWithFormat:@"<a href=\"%@\"><img src=\"%@\" alt=\"%@\" /></a>",
																		//				[linkURLString escapedEntities],
																		//				[imageURLString escapedEntities],
																		//				[title escapedEntities]] forKey:kKTDataSourceString];
			[aDictionary setValue:imageURLString forKey:kKTDataSourceImageURLString];		// image @ amazon
			[aDictionary setValue:linkURLString forKey:kKTDataSourceURLString];		// link to amazon, rebuilt for sandvox
			[aDictionary setValue:[NSNumber numberWithBool:YES] forKey:@"kKTDataSourcePreferExternalImageFlag"];
	        result = YES;
		}
		else
		{
			NSLog(@"Unable to find Amazon ASIN in URL: %@", urlString);
		}
    }
    return result;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.LinkPage";
}
- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.PhotoPagelet";
}

@end
