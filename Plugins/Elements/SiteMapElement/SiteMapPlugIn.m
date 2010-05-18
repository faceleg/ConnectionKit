//
//  SiteMapPlugIn.m
//  Sandvox SDK: SiteMapElement
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

//  NOTE: No LocalizedStrings in this plugin, so no genstrings build phase needed


#import "SiteMapPlugIn.h"


@implementation SiteMapPlugIn


#pragma mark -
#pragma mark HTML Generation


- (NSString *)siteMap
{	
	NSMutableString *result = [NSMutableString string];
    
    SVHTMLContext *context = [SVPageletPlugIn currentContext];
	
	KTPage *thisPage = [context page];
	KTPage *rootPage = [thisPage rootPage];
	
	if ( self.showHome )
	{
		// Note: if site map IS home, it will still be shown regardless of show site map checkbox
		[result appendString:(self.sections ? @"<h3>" : @"<p>")];
		if (rootPage == thisPage)	// not likely but maybe possible
		{
			NSString *title = [rootPage titleHTMLString];
            if ( title )
            {
                [result appendString:title];
            }
		}
		else
		{
            NSString *path = [context relativeURLStringOfPage:rootPage];
            if (!path) path = @"";  // Happens for a site with no -siteURL set yet
            
            NSString *title = [rootPage titleHTMLString];
            
            [result appendFormat:@"<a href=\"%@\">%@</a>", path, title];
		}
		[result appendString:(self.sections ? @"</h3>\n" : @"</p>\n")];
	}

	if (!self.sections)
	{
		[result appendString:@"<ul>\n"];
	}
    
    for ( KTPage *topLevelPage in [rootPage childPages] )
    {
		[self appendMapOfPage:topLevelPage 
               relativeToPage:thisPage 
                     toBuffer:result
                  wantCompact:self.compact 
                   topSection:self.sections 
                       indent:YES];
    }

	if (!self.sections)
	{
		[result appendString:@"</ul>\n"];
	}
	
	return result;
}


#pragma mark -
#pragma mark Properties

@synthesize sections = _sections;
@synthesize showHome = _showHome;
@synthesize compact = _compact;
@end
