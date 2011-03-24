//
//  TwitterFeedPlugIn.m
//  TwitterElement
//
//  Copyright (c) 2006-2011 Karelia Software. All rights reserved.
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
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "TwitterFeedPlugIn.h"
#import "NSURL+Twitter.h"


// SVLocalizedString(@"Tweet Permalink", "String_On_JavaScript_Template")
// SVLocalizedString(@"less than a minute ago", "String_On_JavaScript_Template")
// SVLocalizedString(@"about a minute ago", "String_On_JavaScript_Template")
// SVLocalizedString(@"%d minutes ago", "String_On_JavaScript_Template")
// SVLocalizedString(@"about an hour ago", "String_On_JavaScript_Template")
// SVLocalizedString(@"about %d hours ago", "String_On_JavaScript_Template")
// SVLocalizedString(@"1 day ago", "String_On_JavaScript_Template")
// SVLocalizedString(@"%d days ago", "String_On_JavaScript_Template")


@interface TwitterFeedPlugIn ()
- (void)writeScriptToEndBodyMarkup:(NSString *)uniqueID context:(id<SVPlugInContext>)context;
@end


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


#pragma mark -
#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // check for a location
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    NSURL *URL = [location URL];
    if ( URL  )
    {
        if ( [URL twitterUsername] )
        {
            self.username = [URL twitterUsername];
            if ( [location title] )
            {
                self.title = [location title];
            }
        }
    }
    
    // initial properties
    self.openLinksInNewWindow = NO;
    self.includeTimestamp = YES;
    self.count = 5;
}


#pragma mark -
#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"username" ofObject:self];
    [context addDependencyForKeyPath:@"count" ofObject:self];
    [context addDependencyForKeyPath:@"includeTimestamp" ofObject:self];
    [context addDependencyForKeyPath:@"openLinksInNewWindow" ofObject:self];
    [context addDependencyForKeyPath:@"language" ofObject:[context page]];
    
    // add resources
    NSString *resourcePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"twittercallbacktemplate" ofType:@"js"];
    NSURL *resourceURL = [NSURL fileURLWithPath:resourcePath];
    [context addJavascriptResourceWithTemplateAtURL:resourceURL object:self];
    
    NSString *uniqueID = @"twitter_div";
    
    if ( self.username )
    {
        if ( [context liveDataFeeds] )
        {
            // write a div with callback script
            uniqueID = [context startElement:@"div"
                             preferredIdName:@"twitter_div"
                                   className:nil
                                  attributes:nil];
            
            
            [context endElement]; // </div>
        }
        else
        {
            [context writePlaceholderWithText:SVLocalizedString(@"This is a placeholder for a Twitter feed. It will appear here once published or if you enable live data feeds in Preferences.", "WebView Placeholder")
                                      options:0];
        }
        
        [self writeScriptToEndBodyMarkup:uniqueID context:context];            
    }
    else if ( [context isForEditing] )
    {
        // write placeholder message to sign up for account
        [context startElement:@"div" className:@"svx-placeholder"];
        [context writeCharacters:SVLocalizedString(@"Please enter your Twitter username or ", "WebView prompt fragment")];
        [context startAnchorElementWithHref:@"https://twitter.com/signup"
                                                   title:SVLocalizedString(@"Twitter Signup", "WebView link title") 
                                                  target:nil 
                                                     rel:nil];
        [context writeCharacters:SVLocalizedString(@"sign up", "WebView prompt fragment")];
        [context endElement]; // </a>
        [context writeCharacters:SVLocalizedString(@" for a Twitter account", "WebView prompt fragment")];
        [context endElement]; // </div>
    }
}

- (void)writeScriptToEndBodyMarkup:(NSString *)uniqueID context:(id<SVPlugInContext>)context
{
    if ([context liveDataFeeds])
    {
        NSString *linksFlag = (self.openLinksInNewWindow) ? @"true" : @"false";
        NSString *timestampFlag = (self.includeTimestamp) ? @"true" : @"false";
        NSString *script1 = [NSString stringWithFormat:
                            @"<script type=\"text/javascript\">\n"
                            @"function twitterCallback_%@(obj)\n"
                            @"{\n"
                            @"    twitterCallback_withOptions(obj, '%@', %@, %@);\n"
                            @"}\n"
                            @"</script>\n",
                            uniqueID, uniqueID, linksFlag, timestampFlag];
        [context addMarkupToEndOfBody:script1];
        
        NSString *script2 = [NSString stringWithFormat:
                             @"<script type=\"text/javascript\" src=\"http://twitter.com/statuses/user_timeline/%@.json?callback=twitterCallback_%@&amp;count=%lx\">\n</script>\n",
                             self.username, uniqueID, self.count];
        [context addMarkupToEndOfBody:script2];
    }
}


#pragma mark -
#pragma mark SVPlugInPasteboardReading

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

+ (SVPasteboardPriority)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( [URL twitterUsername] )
    {
        return SVPasteboardPriorityIdeal;
    }
    
	return SVPasteboardPriorityNone;
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    if ( items && [items count] )
    {
        id <SVPasteboardItem>item = [items objectAtIndex:0];
        
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
                
                // initial properties
                self.openLinksInNewWindow = NO;
                self.includeTimestamp = YES;
                self.count = 5;
            }
        }
        
        return YES;
    }
    
    return NO;    
}

@end
