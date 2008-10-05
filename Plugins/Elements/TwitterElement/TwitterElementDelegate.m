//
//  DiggPageletDelegate.m
//  DiggPagelet
//
//  Copyright (c) 2006, Karelia Software. All rights reserved.
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

#import "TwitterElementDelegate.h"
#import "SandvoxPlugin.h"


// LocalizedStringInThisBundle(@"Digg example no.", "String_On_Page_Template - followed by a number")


@implementation TwitterElementDelegate

+ (NSString *)scriptTemplate
{
	static NSString *result;
	
	if (!result)
	{
		NSString *path = [[NSBundle bundleForClass:self] pathForResource:@"scripttemplate" ofType:@"html"];
		OBASSERT(path);
		
		result = [[NSString alloc] initWithContentsOfFile:path usedEncoding:NULL error:NULL];
	}
	
	return result;
}

- (IBAction)openTwitter:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://twitter.com"]];
}

/*	If the user has requested it, add the product preview popups javascript to the end of the page
 */
- (void)addLevelTextToEndBody:(NSMutableString *)ioString forPage:(KTPage *)aPage	// level, since we don't want this on all pages on the site!
{
	if ([[self delegateOwner] valueForKey:@"username"])
	{
		NSString *template = [[self class] scriptTemplate];
		KTTemplateParser *parser = [[KTTemplateParser alloc] initWithTemplate:template component:[self delegateOwner]];
		NSString *script = [parser parseTemplate];
		
		if (script)
		{
			// Only append the script if it's not already there (e.g. if there's > 1 element)
			if ([ioString rangeOfString:script].location == NSNotFound) {
				[ioString appendString:script];
			}
		}
		
		[parser release];
	}
}

@end
