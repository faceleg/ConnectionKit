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
		NSStringPboardType,
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
    
	NSArray *URLs = nil;
	[NSURL getURLs:&URLs
		 andTitles:NULL
	fromPasteboard:[draggingInfo draggingPasteboard]
   readWeblocFiles:YES
	ignoreFileURLs:YES];
	
	if (URLs && [URLs count] > 0)
	{
		result = KTSourcePriorityReasonable;
	}
	
	return result;
}
	
- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    BOOL result = NO;
    
    NSArray *URLs = nil;	NSArray *titles = nil;
	[NSURL getURLs:&URLs
		 andTitles:&titles
	fromPasteboard:[draggingInfo draggingPasteboard]
   readWeblocFiles:YES
	ignoreFileURLs:YES];
	
	if (URLs && [URLs count] > 0)
	{
		NSURL *URL = [URLs firstObject];
		NSString *title = [titles firstObjectOrNilIfEmpty];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (title && (id)title != [NSNull null])
		{
			[aDictionary setValue:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.LinkElement";
}
- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.LinkListElement";
}




@end
