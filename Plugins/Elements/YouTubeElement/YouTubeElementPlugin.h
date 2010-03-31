//
//  YouTubeElementPlugin.h
//  YouTubeElement
//
//  Created by Dan Wood on 2/23/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SandvoxPlugin.h"

typedef enum {
	YouTubeVideoSizeSidebar = 0,	// 200x150	WS:	200x113 + 25 + border
	YouTubeVideoSizeTiny,			// 320x240	WS: 320x180 + 25 + border
	YouTubeVideoSizeClassic,		// 425x319  WS: 425x239 + 25 + border
	YouTubeVideoSizeSmall,			// 480x360	WS: 480x270 + 25 + border
	YouTubeVideoSizeMedium,			// 560x420	WS: 560x315 + 25 + border
	YouTubeVideoSizeLarge,			// 640x480	WS: 640x360 + 25 + border		full 360P
	YouTubeVideoSizeOversize,		// 853x640	WS: 853x480 + 25 + border		full 480P
	YouTubeVideoSize720p,			//1280x960  WS:	1280x720 + 25 + border
} YouTubeVideoSize;

#define NUMBER_OF_VIDEO_SIZES 8

// Wouldn't it be cool to have a way to click on a YouTube video and have it then fill up your page with a lightbox of a larger video?
// "autoplay=1" parameter would allow this, but it's probably not a good idea to give the user access to this without a lightbox.

@interface YouTubeElementPlugin : SVPageletPlugIn <KTDataSource>
{
  @private
	BOOL myAutomaticallyUpdatingSecondaryColorFlag;
	
	NSString *_userVideoCode;
	NSString *_videoID;
	NSColor *_color2;
	NSColor *_color1;
	unsigned _videoSize;
	unsigned _videoWidth;
	unsigned _videoHeight;
	BOOL _showBorder;
	BOOL _widescreen;
	BOOL _privacy;
	BOOL _playHD;
	BOOL _includeRelatedVideos;
	BOOL _useCustomSecondaryColor;
	
}

@property (copy) NSString *userVideoCode;
@property (copy) NSString *videoID;
@property (copy) NSColor *color2;
@property (copy) NSColor *color1;
@property (assign) unsigned videoSize;
@property (assign, readonly) unsigned videoWidth;
@property (assign, readonly) unsigned videoHeight;
@property (assign) BOOL showBorder;
@property (assign) BOOL widescreen;
@property (assign) BOOL playHD;
@property (assign) BOOL privacy;
@property (assign) BOOL includeRelatedVideos;
@property (assign) BOOL useCustomSecondaryColor;
@property (readonly) NSString *sizeToolTip;

+ (NSColor *)defaultPrimaryColor;
- (void)resetColors;

@end
