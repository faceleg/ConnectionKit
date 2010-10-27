//
//  FeedPlugIn.m
//  Sandvox SDK
//
//  Copyright 2004-2010 Karelia Software. All rights reserved.
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

#import "FeedPlugIn.h"
#import <SVURLFormatter.h>
#import <SVWebLocation.h>


//FIXME: is this still needed/valid?
#define kNetNewsWireString @"CorePasteboardFlavorType 0x52535373"



// LocalizedStringInThisBundle(@"Please specify the URL of the feed using the Inspector.", "String_On_Page_Template")

@interface FeedPlugIn ()
- (BOOL)isPage;
@end



@implementation FeedPlugIn


#pragma mark -
#pragma mark SVPlugin

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"feedURL", 
            @"max", 
            @"key", 
            @"openLinksInNewWindow", 
            @"summaryChars", 
            nil];
}


#pragma mark -
#pragma mark Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
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

//[[if isPage]]
//<h3><a href="#">[[=&host]] [['example no.]] 1</a></h3>[[if summaryChars]]<p>[['item summary]]</p>[[endif4]]
//<h3><a href="#">[[=&host]] [['example no.]] 2</a></h3>[[if summaryChars]]<p>[['item summary]]</p>[[endif4]]
//<h3><a href="#">[[=&host]] [['example no.]] 3</a></h3>[[if summaryChars]]<p>[['item summary]]</p>[[endif4]]
//<h3><a href="#">[[=&host]] [['example no.]] 4</a></h3>[[if summaryChars]]<p>[['item summary]]</p>[[endif4]]
//[[else3]]
//<ul>
//<li><a href="#">[[=&host]] [['example no.]] 1</a>[[if summaryChars]]<br />[['item summary]][[endif4]]</li>
//<li><a href="#">[[=&host]] [['example no.]] 2</a>[[if summaryChars]]<br />[['item summary]][[endif4]]</li>
//<li><a href="#">[[=&host]] [['example no.]] 3</a>[[if summaryChars]]<br />[['item summary]][[endif4]]</li>
//<li><a href="#">[[=&host]] [['example no.]] 4</a>[[if summaryChars]]<br />[['item summary]][[endif4]]</li>
//</ul>
//[[endif3]]

- (void)writeOfflinePreviews
{
    id<SVPlugInContext> context = [SVPlugIn currentContext];
    
    NSString *exampleText = LocalizedStringInThisBundle(@"example no.", "String_On_Page_Template- followed by a number");
    
    NSString *itemText = LocalizedStringInThisBundle(@"item summary", "String_On_Page_Template - example of a summary of an RSS item");
    
    NSInteger writeMax = (self.max > 0) ? self.max : 4;
    NSString *host = (nil != [self.feedURL host]) ? [self.feedURL host] : @"example.com";
    
    if ( ![self isPage] ) [[context HTMLWriter] startElement:@"ul"];    
    
    for ( NSInteger i = 0; i < writeMax; i++ )
    {
        if ( [self isPage] )
        {
            [[context HTMLWriter] startElement:@"h3"];
        }
        else
        {
            [[context HTMLWriter] startElement:@"li"];
        }
        
        NSString *exampleLink = [NSString stringWithFormat:@"<a href=\"#\">%@ %@ %d</a>", host, exampleText, i];
        [[context HTMLWriter] writeHTMLString:exampleLink];
        
        if ( ![self isPage] ) [[context HTMLWriter] endElement]; // </h3>
        
        if ( self.summaryChars )
        {
            if ( [self isPage] )
            {
                [[context HTMLWriter] startElement:@"p"];
            }
            else
            {
                [[context HTMLWriter] writeHTMLString:@"<br />"];
            }
            
            [[context HTMLWriter] writeText:itemText];
            
            if ( [self isPage] ) [[context HTMLWriter] endElement]; // </p>    
        }

    }
    
    if ( ![self isPage] ) [[context HTMLWriter] endElement]; // </ul>    
    

}

-(BOOL)validateURL:(id *)ioValue error:(NSError **)outError
{
    BOOL result = YES;
    NSURL *URL = *ioValue;
    
    if ( URL )
    {
        //FIXME: do we need to convert all schemes to feed? waiting for info from Dan...
        
        //    // If there is no URL prefix, use feed://
        //    if (*ioValue && ![*ioValue isEqualToString:@""] && [*ioValue rangeOfString:@"://"].location == NSNotFound)
        //    {
        //        *ioValue = [@"feed://" stringByAppendingString:*ioValue];
        //    }
        //    // Convert http:// to feed://
        //    else if ([*ioValue hasPrefix:@"http://"])
        //    {
        //        *ioValue = [NSString stringWithFormat:@"feed://%@", [*ioValue substringFromIndex:7]];
        //    }
        
        // we're now using KSURLFormatter to make sure that we're passed a valid URL,
        // so the top half of the original code is no longer applicable
        
        // but, do we need to switch any other scheme to feed:// ?
        NSString *scheme = [URL scheme];
        if ( ![scheme isEqualToString:@"feed"] )
        {
            
        }
    }

    return result;
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

- (BOOL)isPage
{
//	id container = [self delegateOwner];
//	return ( [container isKindOfClass:[KTPage class]] );
    
    //FIXME: no longer doable, just return NO for now
    return NO;
}


#pragma mark -
#pragma mark SVPlugInPasteboardReading

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

+ (NSUInteger)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( URL )
    {
        //FIXME: what about kNetNewsWireString pboard types? still needed?
        
        NSString *scheme = [URL scheme];
        if ([scheme isEqualToString:@"feed"])
        {
            return KTSourcePriorityIdeal;	// Yes, a feed URL is what we want
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
                return KTSourcePriorityIdeal;
            }
            
            // some hostnames indicate this is likely a feed
            NSString *host = [URL host];
            if ( [host isEqualToString:@"feeds.feedburner.com"] )
            {
                return KTSourcePriorityIdeal;
            }
        }
    }
    
	return KTSourcePriorityNone;
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    if ( items && [items count] )
    {
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


#pragma mark -
#pragma mark Properties

@synthesize openLinksInNewWindow = _openLinksInNewWindow;
@synthesize max = _max;
@synthesize summaryChars = _summaryChars;
@synthesize key = _key;
@synthesize feedURL = _feedURL;
@end
