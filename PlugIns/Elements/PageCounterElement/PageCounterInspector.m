//
//  PageCounterInspector.m
//  PageCounterElement
//
//  Copyright 2006-2010 Karelia Software. All rights reserved.
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
	[oTheme removeAllItems];
	
	NSEnumerator *themeEnum = [[[self class] themes] objectEnumerator];
	NSDictionary *themeDict;
	BOOL hasDoneGraphicsYet = NO;
	int tag = 0;
	
	while ((themeDict = [themeEnum nextObject]) != nil)
	{
		NSString *theme = [themeDict objectForKey:PCThemeKey];
        
		if ([[themeDict objectForKey:PCTypeKey] intValue] == PC_GRAPHICS)
		{
			if (!hasDoneGraphicsYet)
			{
				hasDoneGraphicsYet = YES;
				//[[oTheme menu] addItem:[NSMenuItem separatorItem]];		// PROBLEMS WITH TAG BINDING?
			}
			[oTheme addItemWithTitle:@""];	// ADD THE MENU
            
			NSImage *sampleImage = [themeDict objectForKey:PCSampleImageKey];
			if (sampleImage)
			{
				[[oTheme lastItem] setImage:sampleImage];
			}
			[[oTheme lastItem] setTag:tag++];
		}
		else
		{
			[oTheme addItemWithTitle:theme];	// ADD THE MENU
                                                /// baseline is wonky here!
                                                //			[[oTheme lastItem] setAttributedTitle:	// make it bold, small system font
                                                //				[[[NSAttributedString alloc]
                                                //					initWithString:theme
                                                //						attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                //										[NSFont boldSystemFontOfSize: [NSFont smallSystemFontSize]],
                                                //										NSFontAttributeName,
                                                //										nil]
                                                //					] autorelease]];
			[[oTheme lastItem] setTag:tag++];
		}
	}
	int index = [[[self delegateOwner] objectForKey:@"selectedTheme"] unsignedIntValue];
	[oTheme setBordered:(index < 2)];
}

#pragma mark Selected Theme

- (void)setDelegateOwner:(id)newOwner
{
	// We keep an eye on "selected theme" so we can add or remove the border from the popup button
	[[self delegateOwner] removeObserver:self forKeyPath:@"selectedTheme"];
	[super setDelegateOwner:newOwner];
	[newOwner addObserver:self forKeyPath:@"selectedTheme" options:0 context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if ([keyPath isEqualToString:@"selectedTheme"])
	{
		// Add or remove the popup button's border as appropriate
		int index = [[[self delegateOwner] objectForKey:@"selectedTheme"] unsignedIntValue];
		[oTheme setBordered:(index < 2)];
	}
	else
	{
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


@end
