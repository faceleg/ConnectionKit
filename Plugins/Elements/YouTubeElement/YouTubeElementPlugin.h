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
	YouTubeVideoSizePageletWidth,
	YouTubeVideoSizeNatural,
	YouTubeVideoSizeDefault,
	YouTubeVideoSizeSidebarPageWidth,
} YouTubeVideoSize;


@interface YouTubeElementPlugin : SVElementPlugIn {

	BOOL myAutomaticallyUpdatingSecondaryColorFlag;

	
	NSString *_userVideoCode;
	NSString *_videoID;
	NSColor *_color2;
	NSColor *_color1;
	int _videoSize;
	int _videoWidth;
	int _videoHeight;
	BOOL _showBorder;
	BOOL _includeRelatedVideos;
	BOOL _useCustomSecondaryColor;
	
}

@property (copy) NSString *userVideoCode;
@property (copy) NSString *videoID;
@property (copy) NSColor *color2;
@property (copy) NSColor *color1;
@property (assign) int videoSize;
@property (assign) int videoWidth;
@property (assign) int videoHeight;
@property (assign) BOOL showBorder;
@property (assign) BOOL includeRelatedVideos;
@property (assign) BOOL useCustomSecondaryColor;

- (unsigned)videoWidthForSize:(YouTubeVideoSize)size;
- (unsigned)videoHeightForSize:(YouTubeVideoSize)size;

- (IBAction)resetColors;

@end
