//
//  SVAudioVisualPlugIn.h
//  Sandvox
//
//  Created by Dan Wood on 9/28/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVMediaPlugIn.h"

typedef enum {
	kPreloadMeta = -1,	// we don't really support this in the UI, but let's provide for it in the data model.
	kPreloadNone = 0,
	kPreloadAuto = 1
} PreloadState;


@interface SVAudioVisualPlugIn : SVMediaPlugIn {

	BOOL _autoplay;
	BOOL _loop;
	BOOL _controller;
	
	PreloadState _preload;
}

@property  BOOL autoplay;
@property  BOOL loop;
@property  BOOL controller;
@property  PreloadState preload;

// Determined from file's UTI, or by further analysis. NOT KVO-compliant. Will reload plug-in if needed
@property(nonatomic, copy) NSString *codecType;


@end
