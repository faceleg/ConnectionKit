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

}

- (unsigned)videoWidthForSize:(YouTubeVideoSize)size;
- (unsigned)videoHeightForSize:(YouTubeVideoSize)size;

- (IBAction)resetColors;

@end
