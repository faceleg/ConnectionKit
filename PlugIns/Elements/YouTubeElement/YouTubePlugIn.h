//
//  YouTubePlugIn.h
//  YoutTubeElement
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

// Wouldn't it be cool to have a way to click on a YouTube video and have it then fill up your page with a lightbox of a larger video?
// "autoplay=1" parameter would allow this, but it's probably not a good idea to give the user access to this without a lightbox.

@interface YouTubePlugIn : SVPlugIn <SVPlugInPasteboardReading, IMBImageItem>
{
  @private
	BOOL myAutomaticallyUpdatingSecondaryColorFlag;
	
	NSString *_userVideoCode;
	NSString *_videoID;
	NSColor *_color2;
	NSColor *_color1;
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

@property (nonatomic) BOOL showBorder;
@property (nonatomic) BOOL widescreen;
@property (nonatomic) BOOL playHD;
@property (nonatomic) BOOL privacy;
@property (nonatomic) BOOL includeRelatedVideos;
@property (nonatomic) BOOL useCustomSecondaryColor;

+ (NSColor *)defaultPrimaryColor;
- (void)resetColors;

@end
