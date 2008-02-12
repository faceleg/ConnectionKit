//
//  AmazonBookURLSource.m
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

#import "AmazonBookURLSource.h"







// WE REALLY AREN'T GOING TO IMPLEMENT THIS -- THIS WAS JUST A TEST.










@implementation AmazonBookURLSource

- (int)priorityForDrag:(id <NSDraggingInfo>)draggingInfo index:(int)anIndex;
{
//	int result = [super priorityForDrag:draggingInfo index:anIndex];
//	if (result != KTSourcePriorityNone)
//	{
//		result = KTSourcePriorityNone;	// default; don't handle unless it's more specialized.
//		
//		// Now look for more details ... look for a book indication in the URL
//		NSPasteboard *pboard = [draggingInfo draggingPasteboard];
//		
//		if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"WebURLsWithTitlesPboardType"]] )
//		{
//			NSArray *root = [pboard propertyListForType:@"WebURLsWithTitlesPboardType"];
//			NSArray *nameArray = [root objectAtIndex:1];	// first one .... should be the nth one
//			if ([nameArray count] > 0)
//			{
//				NSString *name = [nameArray objectAtIndex:0];
//				// TODO: HAVE A BETTER WAY OF MATCHING ALL POSSIBLE STRING
//				if (NSNotFound != [name rangeOfString:@": Books:"].location
//					|| NSNotFound != [name rangeOfString:@": English Books:"].location
//					|| NSNotFound != [name rangeOfString:@": Livres en anglais:"].location
//					|| NSNotFound != [name rangeOfString:@": Livres:"].location
//					)
//				{
//					result = KTSourcePrioritySpecialized;
//				}
//			}
//		}
//	}
	return KTSourcePriorityNone;
}

@end
