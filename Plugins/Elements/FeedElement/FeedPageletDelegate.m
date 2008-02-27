//
//  FeedPageletDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2005, Karelia Software. All rights reserved.
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

#import "FeedPageletDelegate.h"

// LocalizedStringInThisBundle(@"example no.", "String_On_Page_Template- followed by a number")
// LocalizedStringInThisBundle(@"Please specify the URL of the feed using the Pagelet Inspector.", "String_On_Page_Template")


@implementation FeedPageletDelegate

#pragma mark -
#pragma mark Initialization

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
		
	if ( isNewObject )
	{
		NSURL *theURL = nil;
		NSString *theTitle = nil;
		if ([NSAppleScript safariFrontmostFeedURL:&theURL title:&theTitle])
		{
			if (nil != theURL)	// need non-nil URL to make use of the title
			{
				[[self delegateOwner] setObject:[theURL absoluteString] forKey:@"url"];
				if (nil != theTitle)
				{
					[[self delegateOwner] setTitleHTML:[theTitle escapedEntities]];
				}
			}
		}
	}
}

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
		[[self delegateOwner] setValue:[title escapedEntities] forKey:@"titleHTML"];
	}
}

#pragma mark -
#pragma mark URL

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

- (NSString *)urlAsHTTP		// server wants URL in http:// format
{
	NSString *url = [[self delegateOwner] valueForKey:@"url"];
	if ([url hasPrefix:@"feed://"])	// convert feed://
	{
		url = [NSString stringWithFormat:@"http://%@", [url substringFromIndex:7]];
	}
	return url;
}

- (NSString *)host		// server wants URL in http:// format
{
	NSString *urlString = [[self delegateOwner] valueForKey:@"url"];
	NSURL *asURL = [NSURL URLWithString:[urlString encodeLegally]];
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

#pragma mark -
#pragma mark Plugin

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

@end
