//
//  YouTubeVideoIDFormatter.m
//  YouTubeElement
//
//  Created by Mike on 08/04/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "YouTubeVideoIDFormatter.h"

#import "YouTubeCocoaExtensions.h"


@implementation YouTubeVideoIDFormatter

/*	We allow the superclass to do the usual trimming behaviour. Then, try to convert IDs or <embed> codes
 *	to a standardised URL.
 */
- (BOOL)getObjectValue:(id *)anObject forString:(NSString *)string errorDescription:(NSString **)error
{
	BOOL result = [super getObjectValue:anObject forString:string errorDescription:error];
	
	if (result)
	{
		// We prefer a plain URL
		NSURL *URL = [NSURL URLWithString:string];
		NSString *videoID = [URL youTubeVideoID];
		
		// Second preference is a simple ID string
		if (!videoID && [string isYouTubeVideoID])
		{
			videoID = string;
			*anObject = [NSURL youTubeVideoURLWithID:videoID];
		}
		
		// Lastly look for an  <embed> code
		if (!videoID)
		{
			URL = [string HTMLEmbedYouTubeVideoURL];
			if (URL) *anObject = [URL absoluteString];
		}
	}
	
	return result;
}

@end
