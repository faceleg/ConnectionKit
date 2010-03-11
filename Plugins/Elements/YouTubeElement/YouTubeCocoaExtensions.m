//
//  YouTubeCocoaExtensions.m
//  YouTubeElement
//
//  Copyright 2008-2009 Karelia Software. All rights reserved.
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

#import "YouTubeCocoaExtensions.h"
#import "SandvoxPlugin.h"


@implementation NSString (YouTubeExtensions)

/*	To be a valid YouTube ID the string must be 11 characters, all alphanumeric
 */
- (BOOL)isYouTubeVideoID
{
	BOOL result = NO;
	
	if ([self length] == 11)
	{
		// There doesn't seem to be a prebuilt characterset that does what we want, so build our own
		static NSCharacterSet *validCharacters;
		if (!validCharacters)
		{
			validCharacters = [NSCharacterSet characterSetWithCharactersInString:
				@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890-_"];
			[validCharacters retain];
		}
		
		
		NSCharacterSet *characters = [NSCharacterSet characterSetWithCharactersInString:self];
		result = [validCharacters isSupersetOfSet:characters];
	}
	
	return result;
}


/*	Searches the receiver for an <embed> tag whose source is a YouTube video.
 *	Returns nil if no suitable URL was found.
 */
- (NSURL *)HTMLEmbedYouTubeVideoURL
{
	NSURL *result = nil;
	
	// Look for the open of such a tag
	NSScanner *scanner = [[NSScanner alloc] initWithString:
self];
	[scanner scanUpToString:@"<embed src=\"" intoString:NULL];
	if (![scanner isAtEnd])
	{
		[scanner setScanLocation:([scanner scanLocation] + [@"<embed src=\"" length])];
		
		// Scan in the URL string
		NSString *URLString;
		if ([scanner scanUpToString:@"\"" intoString:&URLString])
		{
			NSURL *URL = [NSURL URLWithString:URLString];
			if ([URL youTubeVideoID]) result = URL;
		}
	}
	
	// Tidy up
	[scanner release];
	return result;
}

@end


@implementation NSURL (YouTubeExtensions)

+ (NSURL *)youTubeVideoURLWithID:(NSString *)videoID;
{
	NSParameterAssert(videoID);
	
	NSString *URLString = [@"http://youtube.com/watch?v=" stringByAppendingString:videoID];
	NSURL *result = [NSURL URLWithString:URLString];
	return result;
}

/*	Searches the URL for a video ID. If none is found, returns nil
 */
- (NSString *)youTubeVideoID;
{
	NSString *result = nil;
	
	// Check it's actually a YouTube website!
	NSString *host = [self host];
	if (host && ([host hasPrefix:@"youtube."]
			|| [host rangeOfString:@".youtube."].location != NSNotFound
			|| [host rangeOfString:@".youtube-nocookie."].location != NSNotFound
				 ))
	{
		// The video could be referenced as a "/watch?" or "/v/" style URL
		NSArray *pathComponents = [[self path] pathComponents];
		
		
		// "/watch?" URLs
		if (pathComponents &&
			[pathComponents count] == 2 &&
			[[pathComponents objectAtIndex:1] isEqualToString:@"watch"])
		{
			NSDictionary *query = [self queryDictionary];
			
			NSString *videoID = [query objectForKey:@"v"];		// For invalid URLs this will be nil
			if (videoID && [videoID isYouTubeVideoID])
			{
				result = videoID;
			}
		}
		
		
		// "/v/" URLs
		else if (pathComponents &&
				 [pathComponents count] == 3 &&
				 [[pathComponents objectAtIndex:1] isEqualToString:@"v"])
		{
			NSString *queryishString = [pathComponents objectAtIndex:2];
			if ([queryishString length] >= 11)
			{
				NSString *videoID = [queryishString substringToIndex:11];
				if (videoID && [videoID isYouTubeVideoID])
				{
					result = videoID;
				}
			}
		}
	}
	
	return result;
}

@end


@implementation NSColor (YouTubeExtensions)

/*	Constructs a six-hexadecimal-character representation of the color.
 *	-htmlString then builds on this to make a regular HTML string.
 */
- (NSString *)youTubeVideoColorString
{
	NSString *result = @"";
	
	NSColor *rgbColor = [self colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
	if (nil != rgbColor)
	{
		float red,green,blue,alpha;
		[rgbColor getRed:&red green:&green blue:&blue alpha:&alpha];
        
		int r = 0.5 + red	* 255.0;
		int g = 0.5 + green	* 255.0;
		int b = 0.5 + blue	* 255.0;
		result = [[NSString stringWithFormat:@"0x%02X%02X%02X",r,g,b] lowercaseString];
    }
	
	return result;
}

@end

