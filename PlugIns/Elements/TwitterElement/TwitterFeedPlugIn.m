//
//  TwitterFeedPlugIn.m
//  TwitterElement
//
//  Copyright (c) 2006-2010, Karelia Software. All rights reserved.
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

#import "TwitterFeedPlugIn.h"
#import "NSURL+Twitter.h"


@implementation TwitterFeedPlugIn


#pragma mark -
#pragma mark SVPlugIn

@synthesize username = _username;
@synthesize count = _count;
@synthesize includeTimestamp = _includeTimestamp;
@synthesize openLinksInNewWindow = _openLinksInNewWindow;

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"username", 
            @"count", 
            @"includeTimestamp", 
            @"openLinksInNewWindow", 
            nil];
}

#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"username" ofObject:self];
    [context addDependencyForKeyPath:@"count" ofObject:self];
    [context addDependencyForKeyPath:@"includeTimestamp" ofObject:self];
    [context addDependencyForKeyPath:@"openLinksInNewWindow" ofObject:self];
    
//    [[if username]]
//    [[if parser.liveDataFeeds]]
//    <div id="twitter_div_[[=uniqueID]]">
//    </div>
//    <script type="text/javascript" src="[[resourcepath delegate.twitterCallbackScriptPath]]"></script>
//    [[else2]]
//    <div class="svx-placeholder">
//	[['This is a placeholder for a Twitter feed. It will appear here once published or if you enable live data feeds in Preferences.]]
//      </div>
//      [[endif2]]
//      
//      [[else]]
//      [[if parser.HTMLGenerationPurpose==0]]
//      <div class="svx-placeholder">
//      [['Please enter your Twitter username or]] <a href="http://twitter.com/signup">[['sign up]]</a> [['for a Twitter account]]
//    </div>
//    [[endif2]]
//    [[endif]]
    
    if ( self.username )
    {
        if ( [context liveDataFeeds] )
        {
            // write a div with the call back script
            NSString *uniqueID = [[context HTMLWriter] startElement:@"div"
                                                    preferredIdName:@"twitter_div"
                                                          className:nil
                                                         attributes:nil];
            [[context HTMLWriter] endElement];
            
        }
        else
        {
            // write placeholder message
            [[context HTMLWriter] writeText:LocalizedStringInThisBundle(@"This is a placeholder for a Twitter feed. It will appear here once published or if you enable live data feeds in Preferences.", "WebView Placeholder")];
        }
    }
    else if ( [context isForEditing] )
    {
        // write placeholder message to sign up for account
        [[context HTMLWriter] writeText:LocalizedStringInThisBundle(@"Please enter your Twitter username or ", "WebView prompt fragment")];
        [[context HTMLWriter] startAnchorElementWithHref:@"https://twitter.com/signup"
                                                   title:LocalizedStringInThisBundle(@"Twitter Signup", "WebView link title") 
                                                  target:nil 
                                                     rel:nil];
        [[context HTMLWriter] writeText:LocalizedStringInThisBundle(@"sign up", "WebView prompt fragment")];
        [[context HTMLWriter] endElement];
        [[context HTMLWriter] writeText:LocalizedStringInThisBundle(@" for a Twitter account", "WebView prompt fragment")];
    }
}

#pragma mark -
#pragma mark Class Methods

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

#pragma mark -
#pragma mark Other

- (NSString *)uniqueID
{
    return @"73";
}

- (NSString *)twitterCallbackScriptPath
{
	NSString *result = [[self bundle] pathForResource:@"twittercallbacktemplate" ofType:@"js"];
	return result;
}

//- (void)addLevelTextToEndBody:(NSMutableString *)ioString forPage:(KTPage *)aPage
//{
//	if ([[self delegateOwner] valueForKey:@"username"])
//	{
//		// Append element-specific script
//		NSString *template = [[self class] scriptTemplate];
//		KTHTMLParser *parser = [[KTHTMLParser alloc] initWithTemplate:template component:[self delegateOwner]];
//		[parser setCurrentPage:aPage];
//		
//		NSString *script = [parser parseTemplate];
//		if (script) [ioString appendString:script];
//		
//		[parser release];
//	}
//}

#pragma mark -
#pragma mark SVPlugInPasteboardReading

+ (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( [URL twitterUsername] )
    {
        return KTSourcePriorityIdeal;
    }
    
	return KTSourcePriorityNone;
}

// returns an object initialized using the data in propertyList. (required since we're not using keyed archiving)
- (void)awakeFromPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( URL  )
    {
        if ( [URL twitterUsername] )
        {
            self.username = [URL twitterUsername];
            if ( [item title] )
            {
                self.title = [item title];
            }
        }
    }
}

@end
