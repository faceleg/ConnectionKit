//
//  PageCounterInspector.m
//  PageCounterElement
//
//  Copyright 2006-2011 Karelia Software. All rights reserved.
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

#import "PageCounterInspector.h"
#import "PageCounterPlugIn.h"


@implementation PageCounterInspector

- (void)awakeFromNib
{
	[oThemePopUp removeAllItems];
	
	NSEnumerator *themeEnum = [[[PageCounterPlugIn class] themes] objectEnumerator];
	NSDictionary *themeDict;
	BOOL hasDoneGraphicsYet = NO;
	int tag = 0;
	
	while ((themeDict = [themeEnum nextObject]) != nil)
	{
		NSString *themeTitle = [themeDict objectForKey:PCThemeKey];
        if ( !themeTitle ) continue; // skip separator
        
		if ([[themeDict objectForKey:PCTypeKey] unsignedIntegerValue] == PC_GRAPHICS)
		{
			if (!hasDoneGraphicsYet)
			{
				hasDoneGraphicsYet = YES;
				[[oThemePopUp menu] addItem:[NSMenuItem separatorItem]];
                [[oThemePopUp lastItem] setTag:-1];
			}
			[oThemePopUp addItemWithTitle:@""];	// ADD THE MENU
            
			NSImage *sampleImage = [themeDict objectForKey:PCSampleImageKey];
			if (sampleImage)
			{
				[[oThemePopUp lastItem] setImage:sampleImage];
			}
			[[oThemePopUp lastItem] setTag:tag++];
		}
		else
		{
			[oThemePopUp addItemWithTitle:themeTitle];	// ADD THE MENU
			[[oThemePopUp lastItem] setAttributedTitle:	// make it small system font since pop-up size is normal
				[[[NSAttributedString alloc]
					initWithString:themeTitle
						attributes:[NSDictionary dictionaryWithObjectsAndKeys:
										[NSFont systemFontOfSize:[NSFont smallSystemFontSize]],
										NSFontAttributeName,
										nil]
					] autorelease]];
			[[oThemePopUp lastItem] setTag:tag++];
		}
	}
    
    [oThemePopUp setBordered:NO];
}

@end
