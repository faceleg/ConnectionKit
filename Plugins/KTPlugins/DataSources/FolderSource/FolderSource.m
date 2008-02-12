//
//  FolderSource.m
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

#import "FolderSource.h"

@implementation FolderSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	if (isPagelet)
	{
		return nil;		// can't make a pagelet out of a folder
	}
	else
	{
		return [NSArray arrayWithObjects:
			NSFilenamesPboardType,
			nil];
	}
}

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
	NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	
	NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
	if (anIndex < [fileNames count])
	{
		NSString *fileName = [fileNames objectAtIndex:anIndex];
		NSFileManager *fm = [NSFileManager defaultManager];
		if ( nil != fileName )
		{
			BOOL isDir = NO;
			(void) [fm fileExistsAtPath:fileName isDirectory:&isDir];
			if (isDir)
			{
				return KTSourcePriorityTypical;	// Low priority, a folder is probably more specialized somewhere
			}
		}
	}
	return KTSourcePriorityNone;		// For a truly generic file.
}

- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	NSArray *filePaths = [pboard propertyListForType:NSFilenamesPboardType];
	if (anIndex < [filePaths count])
	{
		NSString *filePath = [filePaths objectAtIndex:anIndex];

		[aDictionary setValue:[[NSFileManager defaultManager] resolvedAliasPath:filePath]
					   forKey:kKTDataSourceFilePath];
		[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
		[aDictionary setValue:[NSNumber numberWithBool:YES] forKey:kKTDataSourceRecurse];
	}
    return YES;
}

/*!	page to make for the collection
*/
- (NSString *)pageBundleIdentifier
{
	return @"sandvox.RichTextElement";
}


@end
