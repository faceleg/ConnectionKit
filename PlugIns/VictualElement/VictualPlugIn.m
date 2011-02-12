//
//  VictualPlugIn.m
//  VictualElement
//
//  Created by Terrence Talbot on 1/5/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "VictualPlugIn.h"


// http://www.zazar.net/developers/zrssfeed/
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


@implementation VictualPlugIn


#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"feedURL", 
            @"limit", 
            nil];
}


#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    self.limit = 5;
    self.feedURL = [NSURL URLWithString:@"http://www.karelia.com/news/index.xml"];
    //FIXME: setting a default URL for quick testing, should be changed to handle
    //both nothing set and/or no live feed
    
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
                      @"	$('#%@').rssfeed('%@', {limit:%@,header:false,titletag:'h4',date:false,content:true,snippet:true,showerror:true,errormsg:'',key:null});\n"
                      @"});\n"
                      @"</script>\n",
                      idName,
                      self.feedURL,
                      [[NSNumber numberWithUnsignedInt:self.limit] stringValue]];
    [context addMarkupToEndOfBody:feed];
    
    // add dependencies
    [context addDependencyForKeyPath:@"feedURL" ofObject:self];
    [context addDependencyForKeyPath:@"limit" ofObject:self];
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


@end
