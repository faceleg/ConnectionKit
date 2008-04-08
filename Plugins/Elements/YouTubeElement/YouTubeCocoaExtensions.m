//
//  YouTubeCocoaExtensions.m
//  YouTubeElement
//
//  Created by Mike on 08/04/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "YouTubeCocoaExtensions.h"
#import <SandvoxPlugin.h>


@implementation NSString (YouTubeExtensions)

/*	To be a valid YouTube ID the string must be 11 characters, all alphanumeric
 */
- (BOOL)isYouTubeVideoID
{
	BOOL result = NO;
	
	if ([self length] == 11)
	{
		NSCharacterSet *characters = [NSCharacterSet characterSetWithCharactersInString:self];
		NSCharacterSet *validCharacters = [NSCharacterSet alphanumericASCIICharacterSet];
		result = [validCharacters isSupersetOfSet:characters];
	}
	
	return result;
}

@end


@implementation NSURL (YouTubeExtensions)

/*	Searches the URL for a video ID. If none is found, returns nil
 */
- (NSString *)youTubeVideoID;
{
	NSString *result = nil;
	
	// Check it's actually a YouTube website!
	NSString *host = [self host];
	if (host && ([host hasPrefix:@"youtube."] || [host rangeOfString:@".youtube."].location != NSNotFound))
	{
		NSDictionary *query = [self queryDictionary];
		
		NSString *videoID = [query objectForKey:@"v"];		// For invalid URLs this will be nil
		if (videoID && [videoID isYouTubeVideoID])
		{
			result = videoID;
		}
	}
	
	return result;
}

@end