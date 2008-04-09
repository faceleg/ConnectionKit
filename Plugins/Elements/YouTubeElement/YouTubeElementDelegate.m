//
//  YouTubeElementDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
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

#import "YouTubeElementDelegate.h"
#import <SandvoxPlugin.h>

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


@implementation YouTubeElementDelegate

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if (isNewObject)
	{
		// Try to load video from web browser
		NSURL *URL = nil;
		[NSAppleScript getWebBrowserURL:&URL title:NULL source:NULL];
		if (URL && [URL youTubeVideoID])
		{
			[[self delegateOwner] setValue:[URL absoluteString] forKey:@"userVideoCode"];
		}
		
		// Prepare initial colors
		[self resetColors:self];
	}
}

// TODO: Rewrite for YouTube URLs
/*
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	// grab media
	KTMediaContainer *video =
		[[[self delegateOwner] mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
	
	[[self delegateOwner] setValue:video forKey:@"video"];
	
	// set title
	NSString *title = [aDataSourceDictionary valueForKey:kKTDataSourceTitle];
	if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		title = [[aDataSourceDictionary valueForKey:kKTDataSourceFileName] stringByDeletingPathExtension];
	}
	
	// set caption
	if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceCaption])
	{
		[[self delegateOwner] setObject:[[aDataSourceDictionary objectForKey:kKTDataSourceCaption] escapedEntities]
									forKey:@"captionHTML"];
	}
}
*/

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

@end

