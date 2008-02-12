//
//  FileSource.m
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

#import "FileSource.h"

@implementation FileSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:
		NSFilenamesPboardType,
		nil];
}

- (unsigned int)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)draggingInfo
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		return [fileNames count];
	}
	else
	{
		return 1;
	}
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
			if ( nil != fileName )
			{
				NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible
				
				if ( [NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeAppleProtectedMPEG4Audio] )
				{
					return KTSourcePriorityNone;	// disallow protected audio; don't try to play as audio
				}
			}
		}
		else
		{
			return KTSourcePriorityNone;	// no actual files
		}
	}
	return KTSourcePriorityMinimum;		// For a truly generic file.
}


- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    BOOL result = NO;
    if (!isAPagelet)
	{
		NSArray *orderedTypes = [self acceptedDragTypesCreatingPagelet:isAPagelet];
		NSPasteboard *pboard = [draggingInfo draggingPasteboard];
		NSString *bestType = [pboard availableTypeFromArray:orderedTypes];
		
		if ( [bestType isEqualToString:NSFilenamesPboardType] )
		{
			NSArray *arrayFromData = [pboard propertyListForType:NSFilenamesPboardType];
			if (anIndex < [arrayFromData count])
			{
				NSString *filePath = [arrayFromData objectAtIndex:anIndex];

				[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
				[aDictionary setValue:[[NSFileManager defaultManager] resolvedAliasPath:filePath]
							   forKey:kKTDataSourceFilePath];
				result = YES;
			}
		}
	}
    return result;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.FileDownload";
}



@end
