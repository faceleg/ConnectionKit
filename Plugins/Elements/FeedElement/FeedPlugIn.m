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


#define kNetNewsWireString @"CorePasteboardFlavorType 0x52535373"


// LocalizedStringInThisBundle(@"example no.", "String_On_Page_Template- followed by a number")
// LocalizedStringInThisBundle(@"Please specify the URL of the feed using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"item summary", "String_On_Page_Template - example of a summary of an RSS item")


@implementation FeedPlugIn

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"url", @"max", @"key", @"openLinksInNewWindow", @"summaryChars", nil];
}


#pragma mark -
#pragma mark Initialization

- (void)awakeFromInsertIntoPage:(id <SVPage>)page
{
    [super awakeFromInsertIntoPage:page];
    
    NSURL *theURL = nil;
    NSString *theTitle = nil;
    if ([NSAppleScript safariFrontmostFeedURL:&theURL title:&theTitle])
    {
        if ( nil != theURL )
        {
            self.url = theURL;
            [[self container] setTitle:[theTitle stringByEscapingHTMLEntities]];
        }
    }
}


// no longer exists, use NSPasteboardReading protocol instead, look for example
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
{
	[super awakeFromDragWithDictionary:aDictionary];
	
	// Note: We're not using kKTDataSourceURLString  ... URL of original page .. right now.
	
	NSString *urlString = [aDictionary valueForKey:kKTDataSourceFeedURLString];
	if (urlString ) {
		[[self delegateOwner] setValue:urlString forKey:@"url"];
	}
	
	NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
	if ( nil != title ) {
		[[self delegateOwner] setTitleHTML:[title stringByEscapingHTMLEntities]];
	}
}

#pragma mark -
#pragma mark URL

// now irrelevant, use standard key/value validation methods, if nec., instread
- (BOOL)validatePluginValue:(id *)ioValue forKeyPath:(NSString *)inKeyPath error:(NSError **)outError;
{
	BOOL result = YES;
	
	if ([inKeyPath isEqualToString:@"url"])
	{
		// If there is no URL prefix, use feed://
		if (*ioValue && ![*ioValue isEqualToString:@""] && [*ioValue rangeOfString:@"://"].location == NSNotFound)
		{
			*ioValue = [@"feed://" stringByAppendingString:*ioValue];
		}
		// Convert http:// to feed://
		else if ([*ioValue hasPrefix:@"http://"])
		{
			*ioValue = [NSString stringWithFormat:@"feed://%@", [*ioValue substringFromIndex:7]];
		}
	}
	else
	{
		result = [super validatePluginValue:ioValue forKeyPath:inKeyPath error:outError];
	}
	
	return result;
}

// should return a URL
- (NSString *)urlAsHTTP		// server wants URL in http:// format
{
	NSString *url = [[self delegateOwner] valueForKey:@"url"];
	if ([url hasPrefix:@"feed://"])	// convert feed://
	{
		url = [NSString stringWithFormat:@"http://%@", [url substringFromIndex:7]];
	}
	return url;
}

// should return a URL
- (NSString *)host		// server wants URL in http:// format
{
	NSString *urlString = [[self delegateOwner] valueForKey:@"url"];
	NSURL *asURL = [KSURLFormatter URLFromString:urlString];
	NSString *host = [asURL host];
	if (nil == host)
	{
		host = @"";
	}
	return host;
}

/*!	We make a digest of a the "h" parameter so that our server will be less likely to be 
	bogged down with non-Sandvox uses of our feed -> HTML gateway.
*/
- (NSString *)key
{
	NSString *stringToDigest = [NSString stringWithFormat:@"%@:NSString", [self urlAsHTTP]];
	NSData *data = [stringToDigest dataUsingEncoding:NSUTF8StringEncoding];
	NSString *result = [data sha1DigestString];
	return result;
}


// no longer doable, just return NO for now
- (BOOL)isPage
{
	id container = [self delegateOwner];
	return ( [container isKindOfClass:[KTPage class]] );
}

#pragma mark -
#pragma mark Plugin

// need to tell context while generating 

// writeHTML override, figure this out, tell writeHTML which doc type is needed, then call super

/*	With links set to open in a new window, we must use transitional XHTML.
 */
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	if ([[self delegateOwner] boolForKey:@"openLinksInNewWindow"])
	{
		int *docType = (int *)aDocTypePointer;
		if (*docType > KTXHTMLTransitionalDocType)
		{
			*docType = KTXHTMLTransitionalDocType;
		}
	}
}

#pragma mark -
#pragma mark Data Source

// implement pasteboard protocol instead, look for example, youtube?
// NSPasteboardReading (back ported to 10.5)

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            kNetNewsWireString,	// from NetNewsWire
            @"WebURLsWithTitlesPboardType",
            @"BookmarkDictionaryListPboardType",
            NSURLPboardType,	// Apple URL pasteboard type
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)pboard
{
	NSArray *theArray = nil;
    
	if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kNetNewsWireString]]
        && nil != (theArray = [pboard propertyListForType:kNetNewsWireString]) )
	{
		return [theArray count];
	}
	return 1;	// can't find any multiplicity
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kNetNewsWireString]]
		&& nil != [pboard propertyListForType:kNetNewsWireString])
	{
		return KTSourcePriorityIdeal;	// Yes, it's really a feed, from NNW
	}
    
	// Check to make sure it's not file: or feed:
	NSURL *extractedURL = [NSURL URLFromPasteboard:pboard];	// this type should be available, even if it's not the richest
	NSString *scheme = [extractedURL scheme];
	if ([scheme isEqualToString:@"feed"])
	{
		return KTSourcePriorityIdeal;	// Yes, a feed URL is what we want
	}
	if ([scheme hasPrefix:@"http"])	// http or https -- see if it has 
	{
		NSString *extension = [[[extractedURL path] pathExtension] lowercaseString];
		if ([extension isEqualToString:@"xml"]
			|| [extension isEqualToString:@"rss"]
			|| [extension isEqualToString:@"rdf"]
			|| [extension isEqualToString:@"atom"])	// we support reading of atom, not generation.
		{
			return KTSourcePriorityIdeal;
		}
	}
    
	// Otherwise, it doesn't look like it's a feed, so reject
	return KTSourcePriorityNone;
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    
    NSString *feedURLString = nil;
    NSString *feedTitle= nil;
	NSString *pageURLString = nil;
    
    NSArray *orderedTypes = [self supportedPasteboardTypesForCreatingPagelet:isCreatingPagelet];
    
	
    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
    
    if ( [bestType isEqualToString:@"BookmarkDictionaryListPboardType"] )
    {
        NSArray *arrayFromData = [pasteboard propertyListForType:@"BookmarkDictionaryListPboardType"];
        NSDictionary *objectInfo = [arrayFromData objectAtIndex:dragIndex];
        feedURLString = [objectInfo valueForKey:@"URLString"];
        feedTitle = [[objectInfo valueForKey:@"URIDictionary"] valueForKey:@"title"];
    }
    else if ( [bestType isEqualToString:@"WebURLsWithTitlesPboardType"] )
    {
        NSArray *arrayFromData = [pasteboard propertyListForType:@"WebURLsWithTitlesPboardType"];
        NSArray *urlStringArray = [arrayFromData objectAtIndex:0];
        NSArray *urlTitleArray = [arrayFromData objectAtIndex:1];
        feedURLString = [urlStringArray objectAtIndex:dragIndex];
        feedTitle = [urlTitleArray objectAtIndex:dragIndex];
    }
    else if ( [bestType isEqualToString:kNetNewsWireString] )
    {
        NSArray *arrayFromData = [pasteboard propertyListForType:kNetNewsWireString];
        NSDictionary *firstFeed = [arrayFromData objectAtIndex:dragIndex];
        feedURLString = [firstFeed objectForKey:@"sourceRSSURL"];
		pageURLString = [firstFeed objectForKey:@"sourceHomeURL"];
        feedTitle = [firstFeed objectForKey:@"sourceName"];
    }
    else if ( [bestType isEqualToString:NSURLPboardType] )		// only one here
    {
		NSURL *url = [NSURL URLFromPasteboard:pasteboard];
		feedURLString = [url absoluteString];
		// Note: no title available from this
    }
    
    if ( nil != feedURLString )
    {
        [aDictionary setValue:feedURLString forKey:kKTDataSourceFeedURLString];
        if ( nil != feedTitle )
        {
            [aDictionary setValue:feedTitle forKey:kKTDataSourceTitle];
        }
		if (nil != pageURLString)	// only shows up on NNW drags
		{
			[aDictionary setValue:feedURLString forKey:kKTDataSourceURLString];
		}
        result = YES;
    }
    
    return result;
}

// test drag and drop by dragging into sidebar Area

@synthesize openLinksInNewWindow = _openLinksInNewWindow;
@synthesize max = _max;
@synthesize summaryChars = _summaryChars;
@synthesize key = _key;
@synthesize url = _url;
@end
