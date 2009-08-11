//
//  YouTubeElementDelegate.m
//  Sandvox SDK
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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


//	LocalizedStringInThisBundle(@"This is a placeholder for the YouTube video at:", "Live data feeds are disabled");
//	LocalizedStringInThisBundle(@"To see the video in Sandvox, please enable live data feeds in the Preferences.", "Live data feeds are disabled");
//	LocalizedStringInThisBundle(@"Sorry, but no YouTube video was found for the code you entered.", "User entered an invalid YouTube code");
//	LocalizedStringInThisBundle(@"Please use the Inspector to specify a YouTube video.", "No video code has been entered yet");


#import "YouTubeElementDelegate.h"
#import "SandvoxPlugin.h"

#import "YouTubeCocoaExtensions.h"


/*
Services it'd be nice to support eventually:
 
MetaCafe
Vimeo
Revver
Viddler
http://v.youku.com/v_show/id_cf00XOTc3MzgwNA==.html
video.aol.com
blip.tv
Flickr

Brightcove.tv,
ClipShack,
Crackle,
DailyMotion,
Sony eyeVio,
Google Video,
Megavideo,
Motionbox,
Spike (ifilm),
Stage6,
Veoh,
Vimeo,
Yahoo Video,
LiveLeak,
LiveVideo,
SoapBox,
Break
 */


@interface YouTubeElementDelegate ()
- (KTMediaContainer *)defaultThumbnail;
@end


@implementation YouTubeElementDelegate

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	KTAbstractElement *element = [self delegateOwner];
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if (isNewObject)
	{
		// Try to load video from web browser
		NSURL *URL = nil;
		[NSAppleScript getWebBrowserURL:&URL title:NULL source:NULL];
		if (URL && [URL youTubeVideoID])
		{
			[element setValue:[URL absoluteString] forKey:@"userVideoCode"];
		}
		
		// Initial size depends on our location
		YouTubeVideoSize videoSize = ([element isKindOfClass:[KTPagelet class]]) ? YouTubeVideoSizePageletWidth : YouTubeVideoSizeDefault;
		[element setInteger:videoSize forKey:@"videoSize"];
		
		// Prepare initial colors
		[self resetColors:self];
	}
	
	
	// Pagelets cannot adjust their size
	if ([element isKindOfClass:[KTPagelet class]])
	{
		[videoSizeSlider setEnabled:NO];
	}
	// Pages should have a thumbnail
	else
	{
		if (![(KTPage *)element thumbnail])
		{
			[(KTPage *)element setThumbnail:[self defaultThumbnail]];
		}
	}
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	// Look for a YouTube URL
	NSString *URLString = [aDataSourceDictionary valueForKey:kKTDataSourceURLString];
	if (URLString)
	{
		NSURL *URL = [NSURL URLWithString:URLString];
		if (URL && [URL youTubeVideoID])
		{
			[[self delegateOwner] setValue:URLString forKey:@"userVideoCode"];
		}
	}
}

- (void)awakeFromNib
{
	// Pagelets cannot adjust their size
	if ([[self delegateOwner] isKindOfClass:[KTPagelet class]])
	{
		[videoSizeSlider setEnabled:NO];
	}
}

- (IBAction)openYouTubeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://youtube.com/"]];
}

#pragma mark -
#pragma mark Plugin

- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;
{
	// When the user sets a video code, figure the ID from it
	if ([key isEqualToString:@"userVideoCode"])
	{
		NSString *videoID = nil;
		if (value) videoID = [[NSURL URLWithString:value] youTubeVideoID];
		
		[plugin setValue:videoID forKey:@"videoID"];
	}
	
	
	// Update video width & height to match chosen size
	else if ([key isEqualToString:@"videoSize"] || [key isEqualToString:@"showBorder"])
	{
		YouTubeVideoSize videoSize = [plugin integerForKey:@"videoSize"];
		unsigned videoWidth = [self videoWidthForSize:videoSize];
		[plugin setInteger:videoWidth forKey:@"videoWidth"];
		[plugin setInteger:[self videoHeightForSize:videoSize] forKey:@"videoHeight"];
	}
	
	
	// When the user adjusts the main colour WITHOUT having adjusted the secondary color, re-generate
	// a new second colour from it
	else if ([key isEqualToString:@"color2"] && ![plugin boolForKey:@"useCustomSecondaryColor"])
	{
		NSColor *lightenedColor = [[NSColor whiteColor] blendedColorWithFraction:0.5 ofColor:value];
		
		myAutomaticallyUpdatingSecondaryColorFlag = YES;	// The flag is needed to stop us
		[plugin setValue:lightenedColor forKey:@"color1"];	// mis-interpeting the setter
		myAutomaticallyUpdatingSecondaryColorFlag = NO;
	}
	
	
	// When the user sets their own secondary color mark it so no future changes are made by accident
	else if ([key isEqualToString:@"color1"] && !myAutomaticallyUpdatingSecondaryColorFlag)
	{
		[plugin setBool:YES forKey:@"useCustomSecondaryColor"];
	}
}


/*	Cut a strict down -- we shouldn't have strict with the 'embed' tag
*/
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	
	if (*docType > KTXHTMLTransitionalDocType)
	{
		*docType = KTXHTMLTransitionalDocType;
	}
}

#pragma mark -
#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }

#pragma mark -
#pragma mark Thumbnail

/*	Instead of clearing the thumbnail, reset it to the default.
 */
- (BOOL)pageShouldClearThumbnail:(KTPage *)page
{
	[page setThumbnail:[self defaultThumbnail]];
	return NO;
}

- (KTMediaContainer *)defaultThumbnail
{
	NSString *iconPath = [[self bundle] pathForImageResource:@"YouTube"];
	OBASSERT(iconPath);
	
	KTMediaContainer *result = [[self mediaManager] mediaContainerWithPath:iconPath];
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Width

- (unsigned)videoWidthForSize:(YouTubeVideoSize)size
{
	unsigned result = 425;
	
	switch (size)
	{
		case YouTubeVideoSizePageletWidth:
			result = 200;	// width regardless of border size
			break;
		case YouTubeVideoSizeNatural:
			result = ([[self delegateOwner] boolForKey:@"showBorder"]) ? 347 : 320;
			break;
		case YouTubeVideoSizeDefault:
			result = 425;	// Do what YouTube does, fixed width regardless of border
			break;
		case YouTubeVideoSizeSidebarPageWidth:
			result = 480;
			break;
		default:
			OBASSERT_NOT_REACHED("Unknown YouTube video size");
	}
	
	return result;
}

- (unsigned)videoHeightForSize:(YouTubeVideoSize)size;
{
	unsigned result = 0;
	
	if ([[self delegateOwner] boolForKey:@"showBorder"])
	{
		switch (size)
		{
			case YouTubeVideoSizePageletWidth:
				result = 178;
				break;
			case YouTubeVideoSizeNatural:
				result = 308;
				// empirical width to force video itself to be exactly 320 pixels wide
				break;
			case YouTubeVideoSizeDefault:
				result = 373;
				break;
			case YouTubeVideoSizeSidebarPageWidth:
				result = 414;
				break;
			default:
				OBASSERT_NOT_REACHED("Unknown YouTube video size");
		}
	}
	else
	{
		switch (size)
		{
			case YouTubeVideoSizePageletWidth:
				result = 169;
				break;
			case YouTubeVideoSizeNatural:
				result = 269;
				break;
			case YouTubeVideoSizeDefault:
				result = 355;
				break;
			case YouTubeVideoSizeSidebarPageWidth:
				result = 397;
				break;
			default:
				OBASSERT_NOT_REACHED("Unknown YouTube video size");
		}
	}
	return result;
}

#pragma mark -
#pragma mark Colors

+ (NSColor *)defaultPrimaryColor
{
	return [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
}

- (IBAction)resetColors:(id)sender
{
	KTAbstractElement *element = [self delegateOwner];
	[element setBool:NO forKey:@"useCustomSecondaryColor"];
	[element setValue:[[self class] defaultPrimaryColor] forKey:@"color2"];
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
	return [KSWebLocation webLocationPasteboardTypes];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)sender
{
    return 1;
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
	KTSourcePriority result = KTSourcePriorityNone;
    
	NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > dragIndex)
	{
		NSURL *URL = [[webLocations objectAtIndex:dragIndex] URL];
		if ([URL youTubeVideoID])
		{
			result = KTSourcePrioritySpecialized;
		}
	}
	
	return result;
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;
{
	BOOL result = NO;
    
	NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pasteboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > dragIndex)
	{
		NSURL *URL = [[webLocations objectAtIndex:dragIndex] URL];
		NSString *title = [[webLocations objectAtIndex:dragIndex] title];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (!KSISNULL(title))
		{
			[aDictionary setObject:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}

@end

