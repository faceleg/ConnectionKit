//
//  FeedPlugIn.m
//  Sandvox SDK
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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

#import "FeedPlugIn.h"

#import "KSSHA1Stream.h"


//FIXME: is this still needed/valid?
#define kNetNewsWireString @"CorePasteboardFlavorType 0x52535373"



@implementation FeedPlugIn


#pragma mark -
#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"feedURL", 
            @"max", 
//            @"key", 
            @"openLinksInNewWindow", 
            @"summaryChars", 
            nil];
}


#pragma mark -
#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    self.max = 0;
    
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


#pragma mark -
#pragma mark HTML Generation

- (void)writeOfflinePreviews
{
    id<SVPlugInContext> context = [self currentContext];
    
    NSString *exampleText = SVLocalizedString(@"example no.", "String_On_Page_Template - followed by a number");
    
    NSString *itemText = SVLocalizedString(@"item summary", "String_On_Page_Template - example of a summary of an RSS item");
    
    NSInteger writeMax = (self.max > 0) ? self.max : 4;
    NSString *host = (nil != [self.feedURL host]) ? [self.feedURL host] : @"example.com";
    
    [context startElement:@"ul"]; // <ul>
    
    for ( NSInteger i = 1; i <= writeMax; i++ )
    {        
        [context startElement:@"li"]; // <li>
        
        NSString *exampleLink = [NSString stringWithFormat:@"<a href=\"#\">%@ %@ %d</a>", host, exampleText, i];
        [context writeHTMLString:exampleLink];
                
        if ( self.summaryChars )
        {
            [context writeHTMLString:@"<br />"];
            [context writeCharacters:itemText];
        }
        
        [context endElement]; // </li>    
    }
    
    [context endElement]; // </ul>    
}

- (void)writePlaceholder
{
    id <SVPlugInContext> context = [self currentContext];
    [context writePlaceholderWithText:SVLocalizedString(@"Drag feed URL here", "String_On_Page_Template - placeholder")
                              options:0];
}

- (NSURL *)URLAsHTTP		// server requires http:// scheme
{
    NSURL *result = self.feedURL;
	if ( [[result scheme] isEqualToString:@"feed"] )	// convert feed://
	{
        NSString *string = [NSString stringWithFormat:@"http://%@", [[result absoluteString] substringFromIndex:7]];
        result = [SVURLFormatter URLFromString:string];
	}
	return result;
}

/*!	We make a digest of a the "h" parameter so that our server will be less likely to be 
	bogged down with non-Sandvox uses of our feed -> HTML gateway.
*/
- (NSString *)key
{
    NSString *URLAsString = [[self URLAsHTTP] absoluteString];
    NSString *stringToDigest = [NSString stringWithFormat:@"%@:NSString", URLAsString];
    NSData *data = [stringToDigest dataUsingEncoding:NSUTF8StringEncoding];
    return [data sha1DigestString];
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
    if ( URL )
    {
        //FIXME: what about kNetNewsWireString pboard types? still needed?
        
        NSString *scheme = [URL scheme];
        if ([scheme isEqualToString:@"feed"])
        {
            return SVPasteboardPriorityIdeal;	// Yes, a feed URL is what we want
        }
        
        //FIXME: what about https? waiting on answer from Dan (case?)
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
        self.max = 0;
        
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

- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
    [super awakeFromSourceProperties:properties];
    // handle Feed Element
    if ( [[properties objectForKey:@"pluginIdentifier"] isEqualToString:@"sandvox.FeedElement"] )
    {
        if ( [properties objectForKey:@"openLinksInNewWindow"] )
        {
            self.openLinksInNewWindow = [[properties objectForKey:@"openLinksInNewWindow"] boolValue];
        }
        if ( [properties objectForKey:@"max"] )
        {
            self.max = [[properties objectForKey:@"max"] unsignedIntegerValue];
        }
        if ( [properties objectForKey:@"summaryChars"] )
        {
            self.summaryChars = [[properties objectForKey:@"summaryChars"] unsignedIntegerValue];
        }
        if ( [properties objectForKey:@"url"] )
        {
            self.feedURL = [NSURL URLWithString:[properties objectForKey:@"url"]];
        }
    }
    // handle Digg Element
    if ( [[properties objectForKey:@"pluginIdentifier"] isEqualToString:@"sandvox.DiggElement"] )
    {
        NSLog(@"Digg Elements are not yet converted.");
    }
}

// available things we can set
//@property(nonatomic) BOOL openLinksInNewWindow;
//@property(nonatomic) NSUInteger max;
//@property(nonatomic) NSUInteger summaryChars;
//@property(nonatomic, copy) NSString *key;
//@property(nonatomic, copy) NSURL *feedURL;

// sample import of RSS feed
//2011-02-27 13:05:30.419 Sandvox[82677:9f03] awakeFromSourceProperties: {
//    introductionHTML = <null>;
//    location = 1;
//    max = 20;
//    openLinksInNewWindow = 1;
//    ordering = 0;
//    plugin = <null>;
//    pluginIdentifier = "sandvox.FeedElement";
//    pluginVersion = "1.6.8";
//    prefersBottom = 0;
//    shouldPropagate = 1;
//    showBorder = 0;
//    summaryChars = 15;
//    titleHTML = "RSS Feed";
//    titleLinkURLPath = <null>;
//    uniqueID = ED177128E4464FDCBCC3;
//    url = "feed://www.karelia.com/news/index.xml";
//}

// sample import of Digg pagelet
//2011-02-27 12:50:49.346 Sandvox[82677:5f03] awakeFromSourceProperties: {
//    diggCategory = "all stories";
//    diggCount = 1;
//    diggDescriptions = 1;
//    diggStoryPromotion = 0;
//    diggType = 0;
//    diggUser = kevin;
//    diggUserOptionString = popular;
//    diggUserOptions = 0;
//    introductionHTML = <null>;
//    location = 1;
//    maximumStories = 10;
//    openLinksInNewWindow = 1;
//    ordering = 0;
//    plugin = <null>;
//    pluginIdentifier = "sandvox.DiggElement";
//    pluginVersion = "1.6.8";
//    prefersBottom = 0;
//    shouldPropagate = 1;
//    showBorder = 0;
//    titleHTML = "My Digg Links";
//    titleLinkURLPath = <null>;
//    uniqueID = 1B0F673AF0AF49E0AEE5;
//    }
//    
//

#pragma mark -
#pragma mark Properties

@synthesize openLinksInNewWindow = _openLinksInNewWindow;
@synthesize max = _max;
@synthesize summaryChars = _summaryChars;
@synthesize feedURL = _feedURL;
@end
