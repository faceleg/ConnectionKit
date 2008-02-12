//
//  ImageSource.m
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

#import "ImageSource.h"
#import <WebKit/WebKit.h>

@interface ImageSource ( Private )
- (NSDictionary *)cachedIPhotoInfoDict;
- (void)setCachedIPhotoInfoDict:(NSDictionary *)aCachedIPhotoInfoDict;

- (void)buildCachedIPhotoInfoDictFromImageDataList:(NSDictionary *)aDict;
@end

// #define WebArchivePboardType @"Apple Web Archive pasteboard type"
@implementation ImageSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:
		WebArchivePboardType,	// drags from safari, includes links and such
		NSFilenamesPboardType,
		NSTIFFPboardType,
		NSPICTPboardType,
		NSPDFPboardType,
//		@"Apple PNG pasteboard type",		// not defined in headers, but it's on screenshots!
		nil];
}

/* To handle dragged images from firefox:  
	Image will have to come from TIFF or PICT
	get URL from
"Apple URL pasteboard type",
	get alt text from
"CorePasteboardFlavorType 0x75726C64",
	get image source URL, seems to be utf16 format ... if different from URL, it's a hyperlink
"CorePasteboardFlavorType 0x4D5A0004",
*/

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
				// check to see if it's an image file
				NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible

				if ( [NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeImage] )
				{
					return KTSourcePriorityIdeal;
				}
				else if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"ImageDataListPboardType"]])
				{
					return KTSourcePriorityFallback;	// doesn't look like there's an image, but there is image metadata, this must be an image.
				}
				else
				{
					return KTSourcePriorityNone;	// not an image
				}
			}
		}
	}
	else if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSTIFFPboardType]])
	{
		return KTSourcePriorityTypical;	// there is an image, so it's probably OK
	}
		
    return KTSourcePriorityNone;	// doesn't actually have any image data
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.ImageElement";
}
- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.ImageElement";
}

- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
	BOOL result = [KTImageView populateDictionary:aDictionary
						orderedImageTypesAccepted:[self acceptedDragTypesCreatingPagelet:isAPagelet]
								 fromDraggingInfo:draggingInfo
											index:anIndex];
    return result;
}

/*!	Called when drag is done.  This will clear out the cache.
*/
- (void) doneProcessingDrag
{
	[KTImageView clearCachedIPhotoInfoDict];
}



@end
