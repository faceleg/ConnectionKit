//
//  IFramePageletDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
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

#import "IFramePageletDelegate.h"

// LocalizedStringInThisBundle(@"Placeholder for:", "String_On_Page_Template- followed by a URL")

@implementation IFramePageletDelegate

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if ( isNewObject )
	{		
		// Attempt to automatically grab the URL from the user's browser
		NSURL *theURL = nil;
		NSString *theTitle = nil;
		[NSAppleScript getWebBrowserURL:&theURL title:&theTitle source:nil];
		if (nil != theURL)		[[self delegateOwner] setValue:[theURL absoluteString] forKey:@"linkURL"];
		if (nil != theTitle)	[[self delegateOwner] setTitleHTML:[theTitle stringByEscapingHTMLEntities]];
		
		// Set our "show border" checkbox from the defaults
		[[self delegateOwner] setBool:[[NSUserDefaults standardUserDefaults] boolForKey:@"iFramePageletIsBordered"]
							   forKey:@"iFrameIsBordered"];
	}
}

- (void)setDelegateOwner:(KTPage *)plugin
{
	[[self delegateOwner] removeObserver:self forKeyPath:@"iFrameIsBordered"];
	[super setDelegateOwner:plugin];
	[[self delegateOwner] addObserver:self forKeyPath:@"iFrameIsBordered" options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [self delegateOwner] && [keyPath isEqualToString:@"iFrameIsBordered"])
	{
		NSNumber *newValue = [change objectForKey:NSKeyValueChangeNewKey];
		if ([newValue isKindOfClass:[NSNumber class]])
		{
			[[NSUserDefaults standardUserDefaults] setBool:[newValue boolValue] forKey:@"iFramePageletIsBordered"];
		}
	}
}

- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError;
{
	BOOL result = YES;
	
	if ([inKeyPath isEqualToString:@"linkURL"])
	{
		// If the user attempts to set a blank url, replace it with "http://"
		if (*ioValue == nil || [*ioValue isEqualToString:@""]) {
			*ioValue = @"http://";
		}
	}
	else if ([inKeyPath isEqualToString:@"iFrameWidth"])
	{
		if (*ioValue == nil || [*ioValue isEqual:@""]) {
			*ioValue = [NSNumber numberWithFloat:0.0];
		}
	}
	else
	{
		result = [super validatePluginValue:ioValue forKeyPath:inKeyPath error:outError];
	}
	
	return result;
}

/*!	Cut a strict down to size
*/
// Called via recursiveComponentPerformSelector
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	
	if (*docType > KTXHTMLTransitionalDocType)
	{
		*docType = KTXHTMLTransitionalDocType;
	}
}

@end
