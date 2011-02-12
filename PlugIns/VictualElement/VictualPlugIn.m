//
//  VictualPlugIn.m
//  VictualElement
//
//  Created by Terrence Talbot on 1/5/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "VictualPlugIn.h"


// Karelia's feed: <http://www.karelia.com/news/index.xml>

// <http://www.zazar.net/developers/zrssfeed/>
// This plugin will read RSS feeds from any website url using the Google Feeds API. It produces structured HTML with in-built CSS classes for styling. Simple and easy to use.

//Parameter Default	Description
//limit     10      The number of feeds to return.
//header	true	If true, includes the header section containing the feed name and link.
//titletag	h4      Specifies the HTML tag for the feed title.
//date      true	If true, includes the feed date section.
//content	true	If true, includes the feed description.
//snippet	true	If true, the snippet short description is shown available when available.
//showerror	true	If true and an error is returned from the Google Feeds API, the error message is shown.
//errormsg	-       Replaces the default friendly message when an error occurs.
//key       null	Optionally use a Google API key.


#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]


@implementation VictualPlugIn


#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"feedURL", 
            @"limit",
            @"showHeader",
            @"showDate",
            @"showContent",
            @"showSnippet",
            @"showError",
            @"titleTag",
            @"googleAPIKey",
            @"errorMessage",
            nil];
}


#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // make some initial guesses at params
    self.limit = 5;             // limit feed to last 5 entries
    self.showSnippet = YES;
    
    // no UI for these (should there be?)
    self.showContent = YES;         // showContent is FULL content, so we don't want that
                                    // but showSnippet requires it to be YES, too, to show any snippets
    
    self.showDate = NO;             // shows posting date, but we can't format it, so turn it off
    self.showHeader = NO;           // do not show feed name, Sandvox prefers this to be the object title
    self.titleTag = @"null";        // show no titles, could use h3 instead
    self.showError = YES;           // always show error messages returned by server
    self.errorMessage = @"";        // empty, show whatever message Google returns
    self.googleAPIKey = @"null";    // no API key, could check defaults for this
    
    
    // set feedURL, if we can
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    if ( [location URL] )
    {
        self.feedURL = [location URL];
        if ( [location title] )
        {
            [self setTitle:[location title]];
        }
    }
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    if ( self.feedURL )
    {
        // write div to context
        NSString *idName = [context startElement:@"div"
                                 preferredIdName:@"victual"
                                       className:nil
                                      attributes:nil];
        //FIXME: #107815 -- this writeText: shouldn't be needed
        [context writeText:@"Help Me"];
        [context endElement]; // </div>
        
        // append zRSSFeed jquery functions to end body (assumes jquery is already loaded)
        NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"jquery.zrssfeed.min" ofType:@"js"];
        NSURL *URL = [context addResourceWithURL:[NSURL fileURLWithPath:path]];
        NSString *script = [NSString stringWithFormat:@"<script type=\"text/javascript\" src=\"%@\"></script>\n", [URL absoluteURL]];
        [context addMarkupToEndOfBody:script];
        
        // append zRSSFeed <script> to end body
        NSString *feed = [NSString stringWithFormat:
                          @"<script type=\"text/javascript\">\n"
                          @"$(document).ready(function () {\n"
                          @"	$('#%@').rssfeed('%@', {limit:%@,header:%@,titletag:'%@',date:%@,content:%@,snippet:%@,showerror:%@,errormsg:'%@',key:%@});\n"
                          @"});\n"
                          @"</script>\n",
                          idName,
                          self.feedURL,
                          [[NSNumber numberWithUnsignedInt:self.limit] stringValue],
                          ((self.showHeader) ? @"true" : @"false"),
                          self.titleTag,
                          ((self.showDate) ? @"true" : @"false"),
                          ((self.showSnippet) ? @"true" : @"false"), // we tie showContent to showSnippet, otherwise we get FULL feeds
                          ((self.showSnippet) ? @"true" : @"false"),
                          ((self.showError) ? @"true" : @"false"),
                          self.errorMessage,
                          self.googleAPIKey];
        [context addMarkupToEndOfBody:feed];
        
        // add dependencies
        [context addDependencyForKeyPath:@"feedURL" ofObject:self];
        [context addDependencyForKeyPath:@"limit" ofObject:self];
        [context addDependencyForKeyPath:@"showHeader" ofObject:self];
        [context addDependencyForKeyPath:@"showDate" ofObject:self];
        [context addDependencyForKeyPath:@"showContent" ofObject:self];
        [context addDependencyForKeyPath:@"showSnippet" ofObject:self];
        
        // dependencies not currently exposed in UI, commented out for performance
        //[context addDependencyForKeyPath:@"showError" ofObject:self];
        //[context addDependencyForKeyPath:@"titleTag" ofObject:self];
        //[context addDependencyForKeyPath:@"googleAPIKey" ofObject:self];
        //[context addDependencyForKeyPath:@"errorMessage" ofObject:self];
    }
    else 
    {
        [context writePlaceholderWithText:LocalizedStringInThisBundle(@"Enter an RSS Feed URL in the Inspector.", "no URL placeholder")];
    }
}


#pragma mark SVPlugInPasteboardReading

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

+ (SVPasteboardPriority)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( URL )
    {
        NSString *scheme = [URL scheme];
        if ([scheme isEqualToString:@"feed"])
        {
            return SVPasteboardPriorityIdeal;	// Yes, a feed URL is what we want
        }
        
        if ([scheme hasPrefix:@"http"])	// http or https -- see if it has 
        {
            // some extensions indicate this is a feed
            NSString *extension = [[[URL path] pathExtension] lowercaseString];
            if ([extension isEqualToString:@"xml"]
                || [extension isEqualToString:@"rss"]
                || [extension isEqualToString:@"rdf"]
                || [extension isEqualToString:@"atom"])	// we support reading of atom, not generation.
            {
                return SVPasteboardPriorityIdeal;
            }
            
            // some hostnames indicate this is likely a feed
            NSString *host = [URL host];
            if ( [host isEqualToString:@"feeds.feedburner.com"] )
            {
                return SVPasteboardPriorityIdeal;
            }
        }
    }
    
	return SVPasteboardPriorityNone;
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    if ( items && [items count] )
    {
        self.limit = 5;
        
        id <SVPasteboardItem>item = [items objectAtIndex:0];
        NSURL *URL = [item URL];
        if ( URL )
        {
            self.feedURL = URL;
            NSString *title = [item title];
            if ( title )
            {
                [self setTitle:title];
            }
            
            return YES;
        }
    }
    
    return NO;    
}


#pragma mark Properties

@synthesize feedURL = _feedURL;
@synthesize limit = _limit;
@synthesize showHeader = _showHeader;
@synthesize showDate = _showDate;
@synthesize showContent = _showContent;
@synthesize showSnippet = _showSnippet;
@synthesize titleTag = _titleTag;
@synthesize showError = _showError;
@synthesize googleAPIKey = _googleAPIKey;
@synthesize errorMessage = _errorMessage;

@end
