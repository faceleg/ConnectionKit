//
//  FlickrPageletDelegate.m
//  FlickrPagelet
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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

#import "FlickrPageletDelegate.h"

// LocalizedStringInThisBundle(@"Flickr (Placeholder)", "String_On_Page_Template")



@implementation FlickrPageletDelegate

/*
 Plugin Properties we use:
 
	flickrID
	tag
	number
	flashStyle
	random
	showInfo
 
 See:   http://www.flickr.com/badge_new.gne
 
 */

// Lots of work to make a nice colorful logo!

- (void)awakeFromNib
{
	NSString *poweredByString = [oFlickrButton title];
	
	NSDictionary *attr = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSFont boldSystemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
        nil];
	NSMutableAttributedString *ms = [[[NSMutableAttributedString alloc] initWithString:poweredByString attributes:attr] autorelease];
	NSRange flickrRange = [poweredByString rangeOfString:@"flickr" options:NSCaseInsensitiveSearch];
	if (NSNotFound != flickrRange.location)
	{
		[ms addAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSColor colorWithCalibratedRed:0.0 green:.39 blue:.86 alpha:1.0], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(flickrRange.location, 5)];
		[ms addAttributes:
			[NSDictionary dictionaryWithObjectsAndKeys:
				[NSColor colorWithCalibratedRed:1.0 green:0.0 blue:.52 alpha:1.0], NSForegroundColorAttributeName, nil]
					range:NSMakeRange(flickrRange.location+5, 1)];
	}
	[oFlickrButton setAttributedTitle:ms];
}


- (IBAction) openFlickr:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.flickr.com/"]];
}

// If we are using flickr badge in flash style, it uses iframe, so we can't be strict.
// Called via recursiveComponentPerformSelector
- (void) findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	if ([[self delegateOwner] boolForKey:@"flashStyle"])
	{
		int *docType = (int *)aDocTypePointer;
		
		if (*docType > KTXHTMLTransitionalDocType)
		{
			*docType = KTXHTMLTransitionalDocType;
		}
	}
}



@end
