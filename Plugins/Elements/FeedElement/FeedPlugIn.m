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
#import "KSURLFormatter.h"


//FIXME: is this still needed/valid?
#define kNetNewsWireString @"CorePasteboardFlavorType 0x52535373"


// LocalizedStringInThisBundle(@"example no.", "String_On_Page_Template- followed by a number")
// LocalizedStringInThisBundle(@"Please specify the URL of the feed using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"item summary", "String_On_Page_Template - example of a summary of an RSS item")


@implementation FeedPlugIn


#pragma mark -
#pragma mark SVPlugin

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:
            @"feedURL", 
            @"max", 
            @"key", 
            @"openLinksInNewWindow", 
            @"summaryChars", 
            nil];
}


#pragma mark -
#pragma mark Initialization

- (void)awakeFromInsert;
{
    [super awakeFromInsert];
    
    NSURL *URL = nil;
    NSString *title = nil;
    if ([NSAppleScript safariFrontmostFeedURL:&URL title:&title])
    {
        if ( URL )
        {
            self.feedURL = URL;
            if ( title )
            {
                [[self container] setTitle:title];
            }
        }
    }
}


#pragma mark -
#pragma mark HTML Generation

- (void)writeHTML:(SVHTMLContext *)context
{
    if ( self.openLinksInNewWindow )
    {
        // target=_blank requires Transitional doc type
        [context limitToMaxDocType:KTXHTMLTransitionalDocType];
    }
    [super writeHTML:context];
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
        result = [KSURLFormatter URLFromString:string];
	}
	return result;
}

- (NSString *)host
{
    NSString *result = [self.feedURL host];
    if ( !result )
    {
        result = @"";
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

// returns an array of UTI strings of data types the receiver can read from the pasteboard and be initialized from. (required)
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

// returns options for reading data of a specified type from a given pasteboard. (required)
+ (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type 
                                         pasteboard:(NSPasteboard *)pasteboard
{
    return SVPlugInPasteboardReadingAsWebLocation;
}

+ (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type
{
    id <SVWebLocation> location = contents;
    if ( [location conformsToProtocol:@protocol(SVWebLocation)] )
    {
        NSURL *URL = [location URL];
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
                NSString *extension = [[[URL path] pathExtension] lowercaseString];
                if ([extension isEqualToString:@"xml"]
                    || [extension isEqualToString:@"rss"]
                    || [extension isEqualToString:@"rdf"]
                    || [extension isEqualToString:@"atom"])	// we support reading of atom, not generation.
                {
                    return KTSourcePriorityIdeal;
                }
            }
        }
    }
    
	return KTSourcePriorityNone;
}

// returns an object initialized using the data in propertyList. (required since we're not using keyed archiving)
- (void)awakeFromPasteboardContents:(id)propertyList ofType:(NSString *)type
{
    id <SVWebLocation> location = propertyList;
    if ( [location conformsToProtocol:@protocol(SVWebLocation)] )
    {
        NSURL *URL = [location URL];
        if ( URL )
        {
            self.feedURL = URL;
            NSString *title = [location title];
            if ( title )
            {
                [[self container] setTitle:title];
            }
        }
    }
}


#pragma mark -
#pragma mark Properties

@synthesize openLinksInNewWindow = _openLinksInNewWindow;
@synthesize max = _max;
@synthesize summaryChars = _summaryChars;
@synthesize key = _key;
@synthesize feedURL = _feedURL;
@end
