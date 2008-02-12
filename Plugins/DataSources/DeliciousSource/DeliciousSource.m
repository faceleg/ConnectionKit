//
//  DeliciousSource.m
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

#import "DeliciousSource.h"

#define kDeliciousString @"Delicious Library: Media Unique Identifier Type v1.0"


@implementation DeliciousSource

/*!	Return an array of accepted drag types, with best/richest types first
*/
- (NSArray *)acceptedDragTypesCreatingPagelet:(BOOL)isPagelet;
{
	return [NSArray arrayWithObjects:kDeliciousString, nil];
}

- (unsigned int)numberOfItemsFoundInDrag:(id <NSDraggingInfo>)draggingInfo
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	NSArray *ids = [pboard propertyListForType:kDeliciousString];
	return [ids count];
}

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(unsigned int)anIndex;
{
	return KTSourcePriorityIdeal;
}

/*!	Get data from RTF.  Kind of redundant to have to do this one time per object -- oh well.
*/

- (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
				forPagelet:(BOOL)isAPagelet
		  fromDraggingInfo:(id <NSDraggingInfo>)draggingInfo
					 index:(unsigned int)anIndex;
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
	NSData *rtfData = [pboard dataForType:NSRTFPboardType];
	NSAttributedString *attrStr = [[[NSAttributedString alloc] initWithRTF:rtfData documentAttributes:nil] autorelease];
	
	NSRange limitRange;
	NSRange effectiveRange;
	NSURL *urlValue = nil;
	limitRange = NSMakeRange(0, [attrStr length]);
	unsigned int i = 0;
	while (limitRange.length > 0) {
		urlValue = [attrStr attribute:NSLinkAttributeName
									atIndex:limitRange.location longestEffectiveRange:&effectiveRange
									inRange:limitRange];
		if (nil != urlValue)
		{
			if (i++ == anIndex)
			{
				break;
			}
		}		
		
		limitRange = NSMakeRange(NSMaxRange(effectiveRange),
								 NSMaxRange(limitRange) - NSMaxRange(effectiveRange));
	}
	
	if (nil != urlValue)
	{
		NSString *title = [[attrStr string] substringWithRange:effectiveRange];
		[aDictionary setValue:title forKey:kKTDataSourceTitle];
		// http://www.amazon.com/exec/obidos/ASIN/0385504209/
		NSRange whereASIN = [[urlValue absoluteString] rangeBetweenString:@"ASIN/" andString:@"/"];
		NSString *ASIN = @"";
		if (NSNotFound != whereASIN.location)
		{
			// NOTE: This will convert a foreign Amazon URL to a US one ... we could preserve the domain, but what about the URL format and associates string?
			ASIN = [[urlValue absoluteString] substringWithRange:whereASIN];
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
		}
		else
		{
			NSLog(@"Unable to find Amazon ASIN in URL: %@", urlValue);
		}
	}
	
    return YES;
}

- (NSString *)pageBundleIdentifier
{
	return @"sandvox.LinkPage";
}
- (NSString *)pageletBundleIdentifier
{
	return @"sandvox.ImageElement";
}



@end

/*
  
 TODO:
 
 type = Delicious Library: Media Unique Identifier Type v1.0
 contains a UUID that we can't make use of ... but it's there so we can identify the source as delicous!
but you can parse it as an array of strings, from which you can figure out how many items in the drag
 
 type = NSStringPboardType
 val=http://www.amazon.com/exec/obidos/ASIN/0595278205/ref=nosim/deliciousmons-20
 
 From this, we can extract the Amazon URL, and from that, the ASIN
 (comman separated if multiple; might be problematic)

 

 type = CorePasteboardFlavorType 'TEXT'  a.k.a.     "CorePasteboardFlavorType 0x54455854"
 sval=Tongues of Angels
 PROBLEM: WHEN MULTIPLE TITLES -- IF THERE'S A COMMA IN THE TITLE, YOU CAN'T TELL.
 
 type = NeXT Rich Text Format v1.0 pasteboard type
 This contains RTF of the hyperlinked titles.  Useful to parse titles out of above.
 
 
 So this is enough to make an Amazon pagelet, or at the least, a custom HTML pagelet
 */
