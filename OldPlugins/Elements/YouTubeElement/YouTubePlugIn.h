//
//  YouTubePlugIn.h
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

@interface YouTubePlugIn : SVPageletPlugIn <SVPlugInPasteboardReading, IMBImageItem>
{
  @private
	BOOL myAutomaticallyUpdatingSecondaryColorFlag;
	
	NSString *_userVideoCode;
	NSString *_videoID;
	NSColor *_color2;
	NSColor *_color1;
	NSUInteger _videoSize;
	BOOL _showBorder;
	BOOL _widescreen;
	BOOL _privacy;
	BOOL _playHD;
	BOOL _includeRelatedVideos;
	BOOL _useCustomSecondaryColor;
}

@property (nonatomic, copy) NSString *userVideoCode;
@property (nonatomic, copy) NSString *videoID;

@property (nonatomic, copy) NSColor *color2;
@property (nonatomic, copy) NSColor *color1;

@property (nonatomic) NSUInteger videoSize;
@property (nonatomic, readonly) NSUInteger videoWidth;
@property (nonatomic, readonly) NSUInteger videoHeight;

@property (nonatomic) BOOL showBorder;
@property (nonatomic) BOOL widescreen;
@property (nonatomic) BOOL playHD;
@property (nonatomic) BOOL privacy;
@property (nonatomic) BOOL includeRelatedVideos;
@property (nonatomic) BOOL useCustomSecondaryColor;

@property (nonatomic, readonly) NSString *sizeToolTip;

+ (NSColor *)defaultPrimaryColor;
- (void)resetColors;

@end
