//
//  HTMLSource.m
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

#import "HTMLSource.h"

@implementation HTMLSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:
		NSFilenamesPboardType,			// We'll take a file that's HTML type
		NSStringPboardType,				// We'll take plain text with HTML contents
		nil];
}

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    [pboard types];
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (anIndex < [fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:anIndex];

			// check to see if it's an rich text file
			NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible
			if ([NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeHTML] )
			{
				return KTSourcePriorityIdeal;
			}
		}
    }
	else
	{
		NSString *string = [pboard stringForType:NSStringPboardType];
		// Do some scanning to see if it looks like HTML by trying to find some basic types
		NSScanner *scanner = [NSScanner scannerWithRealString:string];
		int confidence = 0;
		BOOL keepGoing = YES;
		while (keepGoing)
		{
			(void) [scanner scanUpToString:@"<" intoString:nil];
			keepGoing = [scanner scanString:@"<" intoString:nil];	// see if we are at a <
			if (keepGoing)
			{
				static NSArray *sTagPatterns = nil;
				
				// Quick & dirty pattern matching.
				if (nil == sTagPatterns) sTagPatterns = [[NSArray alloc] initWithObjects:
					@"html>", @"b>", @"i>", @"br>", @"br />", @"p>", @"p />", @"a href=", @"span ", @"div ",
					@"/html>", @"/b>", @"/i>", @"/p>", @"/a>", @"/span>", @"/div>",
					@"img src=", nil];
				NSEnumerator *theEnum = [sTagPatterns objectEnumerator];
				NSString *pattern;

				while (nil != (pattern = [theEnum nextObject]) )
				{
					BOOL foundPattern = [scanner scanRealString:pattern intoString:nil];
					if (foundPattern)
					{
						confidence++;	// increment confidence factor
						break;			// no need to keep scanning this tag
					}
				}
				if (confidence >= 3)
				{
					return KTSourcePriorityReasonable;	// OK, I'm convinced.   This is HTML.  (Ideal?)
					// (Perhaps some more specialized data source will scan for more specific patterns.)
				}
			}
		}
	}
    return KTSourcePriorityNone;	// one of our other types -- string, rich text ... sounds good to me!
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
    if ( [bestType isEqualToString:NSFilenamesPboardType] )
    {
		NSArray *filePaths = [pboard propertyListForType:NSFilenamesPboardType];
		if (anIndex < [filePaths count])
		{
			filePath = [filePaths objectAtIndex:anIndex];
			if ( nil != filePath )
			{
				[aDictionary setValue:[[NSFileManager defaultManager] resolvedAliasPath:filePath]
							   forKey:kKTDataSourceFilePath];
				[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
				result = YES;
			}
		}
    }
	else
	{
		NSString *string = [pboard stringForType:NSStringPboardType];
		[aDictionary setValue:string forKey:kKTDataSourceString];
		result = YES;
	}
    
    return result;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.HTMLPage";
}
- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.HTMLPagelet";
}

@end
