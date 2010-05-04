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
#import "FeedInspector.h"
#import "KSURLFormatter.h"

#define kNetNewsWireString @"CorePasteboardFlavorType 0x52535373"


// LocalizedStringInThisBundle(@"example no.", "String_On_Page_Template- followed by a number")
// LocalizedStringInThisBundle(@"Please specify the URL of the feed using the Inspector.", "String_On_Page_Template")
// LocalizedStringInThisBundle(@"item summary", "String_On_Page_Template - example of a summary of an RSS item")


@implementation FeedPlugIn


#pragma mark -
#pragma mark SVPlugin

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"URL", @"max", @"key", @"openLinksInNewWindow", @"summaryChars", nil];
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
            self.URL = theURL;
            [[self container] setTitle:theTitle];
        }
    }
}


#pragma mark -
#pragma mark Template

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
    NSURL *theURL = *ioValue;
    
    if ( nil != theURL )
    {
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
        NSString *scheme = [theURL scheme];
        if ( ![scheme isEqualToString:@"feed"] )
        {
            
        }
    }

    return result;
}

- (NSURL *)URLAsHTTP		// server requires http:// scheme
{
    NSURL *result = self.URL;
	if ( [[result scheme] isEqualToString:@"feed"] )	// convert feed://
	{
        NSString *string = [NSString stringWithFormat:@"http://%@", [[result absoluteString] substringFromIndex:7]];
        result = [KSURLFormatter URLFromString:string];
	}
	return result;
}

- (NSString *)host
{
    NSString *result = [self.URL host];
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

// returns an object initialized using the data in propertyList. (required since we're not using keyed archiving)
- (void)awakeFromPasteboardContents:(id)propertyList ofType:(NSString *)type
{
    id <SVWebLocation> location = propertyList;
    if ( location )
    {
        NSURL *URL = [location URL];
        if ( URL )
        {
            self.URL = URL;
            //FIXME: is there any way to set a title from dragging in a URL? if we could, how could we set it if we don't yet have a container?
        }
        else
        {
            [location release];
        }
    }
    else
    {
    }
}


//- (void)awakeFromDragWithDictionary:(NSDictionary *)aDictionary
//{
//	[super awakeFromDragWithDictionary:aDictionary];
//	
//	// Note: We're not using kKTDataSourceURLString  ... URL of original page .. right now.
//	
//	NSString *urlString = [aDictionary valueForKey:kKTDataSourceFeedURLString];
//	if (urlString ) {
//		[[self delegateOwner] setValue:urlString forKey:@"url"];
//	}
//	
//	NSString *title = [aDictionary valueForKey:kKTDataSourceTitle];
//	if ( nil != title ) {
//		[[self delegateOwner] setTitleHTML:[title stringByEscapingHTMLEntities]];
//	}
//}

//
//+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
//{
//    return [NSArray arrayWithObjects:
//            kNetNewsWireString,	// from NetNewsWire
//            @"WebURLsWithTitlesPboardType",
//            @"BookmarkDictionaryListPboardType",
//            NSURLPboardType,	// Apple URL pasteboard type
//            nil];
//}

//+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
//{
//	return [KSWebLocation readableTypesForPasteboard:nil];
//}
//
//+ (NSPasteboardReadingOptions)readingOptionsForType:(NSString *)type
//                                         pasteboard:(NSPasteboard *)pasteboard;
//{
//    return [KSWebLocation readingOptionsForType:type pasteboard:pasteboard];
//}
//
//- (id)initWithPasteboardPropertyList:(id)propertyList
//                              ofType:(NSString *)type;
//{
//    self = [self init];
//    
//    
//    // Only accept YouTube video URLs
//    KSWebLocation *location = [[KSWebLocation alloc] initWithPasteboardPropertyList:propertyList
//                                                                             ofType:type];
//    
//    if (location)
//    {
//        NSString *videoID = [[location URL] youTubeVideoID];
//        if (videoID)
//        {
//            [self setUserVideoCode:[[location URL] absoluteString]];
//        }
//        else
//        {
//            [self release]; self = nil;
//        }
//        
//        [location release];
//    }
//    else
//    {
//        [self release]; self = nil;
//    }
//	
//    return self;
//}
//
//
//+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)pboard
//{
//	NSArray *theArray = nil;
//    
//	if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kNetNewsWireString]]
//        && nil != (theArray = [pboard propertyListForType:kNetNewsWireString]) )
//	{
//		return [theArray count];
//	}
//	return 1;	// can't find any multiplicity
//}

//+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
//{
//    
//	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kNetNewsWireString]]
//		&& nil != [pboard propertyListForType:kNetNewsWireString])
//	{
//		return KTSourcePriorityIdeal;	// Yes, it's really a feed, from NNW
//	}
//    
//	// Check to make sure it's not file: or feed:
//	NSURL *extractedURL = [NSURL URLFromPasteboard:pboard];	// this type should be available, even if it's not the richest
//	NSString *scheme = [extractedURL scheme];
//	if ([scheme isEqualToString:@"feed"])
//	{
//		return KTSourcePriorityIdeal;	// Yes, a feed URL is what we want
//	}
//	if ([scheme hasPrefix:@"http"])	// http or https -- see if it has 
//	{
//		NSString *extension = [[[extractedURL path] pathExtension] lowercaseString];
//		if ([extension isEqualToString:@"xml"]
//			|| [extension isEqualToString:@"rss"]
//			|| [extension isEqualToString:@"rdf"]
//			|| [extension isEqualToString:@"atom"])	// we support reading of atom, not generation.
//		{
//			return KTSourcePriorityIdeal;
//		}
//	}
//    
//	// Otherwise, it doesn't look like it's a feed, so reject
//	return KTSourcePriorityNone;
//}

//+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
//                      fromPasteboard:(NSPasteboard *)pasteboard
//                             atIndex:(unsigned)dragIndex
//				  forCreatingPagelet:(BOOL)isCreatingPagelet;
//
//{
//    BOOL result = NO;
//    
//    NSString *feedURLString = nil;
//    NSString *feedTitle= nil;
//	NSString *pageURLString = nil;
//    
//    NSArray *orderedTypes = [self supportedPasteboardTypesForCreatingPagelet:isCreatingPagelet];
//    
//	
//    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
//    
//    if ( [bestType isEqualToString:@"BookmarkDictionaryListPboardType"] )
//    {
//        NSArray *arrayFromData = [pasteboard propertyListForType:@"BookmarkDictionaryListPboardType"];
//        NSDictionary *objectInfo = [arrayFromData objectAtIndex:dragIndex];
//        feedURLString = [objectInfo valueForKey:@"URLString"];
//        feedTitle = [[objectInfo valueForKey:@"URIDictionary"] valueForKey:@"title"];
//    }
//    else if ( [bestType isEqualToString:@"WebURLsWithTitlesPboardType"] )
//    {
//        NSArray *arrayFromData = [pasteboard propertyListForType:@"WebURLsWithTitlesPboardType"];
//        NSArray *urlStringArray = [arrayFromData objectAtIndex:0];
//        NSArray *urlTitleArray = [arrayFromData objectAtIndex:1];
//        feedURLString = [urlStringArray objectAtIndex:dragIndex];
//        feedTitle = [urlTitleArray objectAtIndex:dragIndex];
//    }
//    else if ( [bestType isEqualToString:kNetNewsWireString] )
//    {
//        NSArray *arrayFromData = [pasteboard propertyListForType:kNetNewsWireString];
//        NSDictionary *firstFeed = [arrayFromData objectAtIndex:dragIndex];
//        feedURLString = [firstFeed objectForKey:@"sourceRSSURL"];
//		pageURLString = [firstFeed objectForKey:@"sourceHomeURL"];
//        feedTitle = [firstFeed objectForKey:@"sourceName"];
//    }
//    else if ( [bestType isEqualToString:NSURLPboardType] )		// only one here
//    {
//		NSURL *url = [NSURL URLFromPasteboard:pasteboard];
//		feedURLString = [url absoluteString];
//		// Note: no title available from this
//    }
//    
//    if ( nil != feedURLString )
//    {
//        [aDictionary setValue:feedURLString forKey:kKTDataSourceFeedURLString];
//        if ( nil != feedTitle )
//        {
//            [aDictionary setValue:feedTitle forKey:kKTDataSourceTitle];
//        }
//		if (nil != pageURLString)	// only shows up on NNW drags
//		{
//			[aDictionary setValue:feedURLString forKey:kKTDataSourceURLString];
//		}
//        result = YES;
//    }
//    
//    return result;
//}


#pragma mark -
#pragma mark Inspector

+ (Class)inspectorViewControllerClass { return [FeedInspector class]; }


#pragma mark -
#pragma mark Properties

@synthesize openLinksInNewWindow = _openLinksInNewWindow;
@synthesize max = _max;
@synthesize summaryChars = _summaryChars;
@synthesize key = _key;
@synthesize URL = _URL;
@end
