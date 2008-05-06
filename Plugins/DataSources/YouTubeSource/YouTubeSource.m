//
//  YouTubeSource.m
//  Sandvox Plugins
//
//  Copyright (c) 2008, Karelia Software. All rights reserved.
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

#import "YouTubeSource.h"


@implementation YouTubeSource


// YouTube URLs look like http://youtube.com/watch?v=UA7dEWKAT7Y

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:
			@"public.url",
			NSURLPboardType,	// Apple URL pasteboard type
			//@"WebURLsWithTitlesPboardType",
			//@"BookmarkDictionaryListPboardType",
			NSStringPboardType,
			nil];
}

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    [pboard types];
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"public.url"]])
	{
		return KTSourcePriorityIdeal;
	}
	else if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSURLPboardType]])
	{
		return KTSourcePriorityIdeal;	// there is an image, so it's probably OK
	}
    return KTSourcePriorityNone;	// doesn't actually have any image data
}


- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    BOOL result = NO;
    NSString *filePath = nil;
    
    NSArray *orderedTypes = [self acceptedDragTypesCreatingPagelet:isAPagelet];
    
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	
    NSString *bestType = [pboard availableTypeFromArray:orderedTypes];
    if ( [bestType isEqualToString:@"public.url"] )
    {
		;
    }
	else
	{
		; 
	}
    
    return result;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.YouTubeElement";
}

- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.YouTubeElement";
}

@end
