//
//  DesignSwitcherPageletDelegate.m
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
//  Community Note: This code is distrubuted under the BSD License. We encourage 
//  you to share your Sandvox Plugins similarly.
//

#import "DesignSwitcherPageletDelegate.h"

@implementation DesignSwitcherPageletDelegate

// Called via recursivePerformSelectorOnPageAndChildren
- (void) addDesignsToSet:(NSMutableSet *)aSet forPage:(KTPage *)aPage
{
#warning FIXME -- should really be set by the user!
	LOG((@"adding lots of designs to the set"));
	
	NSArray *designs = [NSArray arrayWithObjects:
		@"sandvox.Cathedral",
		@"sandvox.Glass Box",
		@"sandvox.Iris Spring",
		@"sandvox.No Parking Anytime",
		@"sandvox.This Modern Life",
		nil];
	[aSet addObjectsFromArray:designs];
}

// add this to every page on the site.
// Contrast with addSitewideTextToHead, addLevelTextToHead

// Called via recursivePerformSelectorOnPageAndChildren
- (void) addSitewideTextToHead:(NSMutableString *)aString forPage:(KTPage *)aPage
{
	NSArray *designs = [NSArray arrayWithObjects:
		@"sandvox.Cathedral",
		@"sandvox.Glass Box",
		@"sandvox.Iris Spring",
		@"sandvox.No Parking Anytime",
		@"sandvox.This Modern Life",
		nil];
	
	if ([designs count])
	{

		NSEnumerator *theEnum = [designs objectEnumerator];
		id object;

		while (nil != (object = [theEnum nextObject]) )
		{
			// FIXME: Quick and dirty -- just use file title.  Ideally, you'd look in the bundle
			// and get the localized name.
			
			[aString appendFormat:@"<link rel=\"alternate stylesheet\" type=\"text/css\" href=\"%@\" title=\"%@\" media=\"screen\" />\n", 
				[[self document] cssPathRelativeTo:aPage forDesignBundleIdentifier:object],
				[[self document] titleForDesignBundleIdentifier:object]];
		}
		NSBundle *bundle = [[self delegateOwner] bundle];
		if ([[bundle pluginResourcesNeeded] count])
		{
			NSString *resourceFileName = [[bundle pluginResourcesNeeded] objectAtIndex:0];
			NSString *resourcePath = [[bundle resourcePath] stringByAppendingPathComponent:resourceFileName];
			
			[aString appendFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>",
				[[self document] pathRelativeTo:aPage forResourceFile:resourcePath]];
		}
	}
}

@end
