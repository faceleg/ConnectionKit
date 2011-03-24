//
//  YouTubeVideoIDFormatter.m
//  YouTubeElement
//
//  Copyright 2008-2011 Karelia Software. All rights reserved.
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
			*anObject = [[NSURL youTubeVideoURLWithID:videoID] absoluteString];
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
