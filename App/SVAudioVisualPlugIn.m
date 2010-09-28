//
//  SVAudioVisualPlugIn.m
//  Sandvox
//
//  Created by Dan Wood on 9/28/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAudioVisualPlugIn.h"


@implementation SVAudioVisualPlugIn

@synthesize autoplay	= _autoplay;
@synthesize loop		= _loop;
@synthesize controller	= _controller;
@synthesize preload		= _preload;
@synthesize codecType	= _codecType;


- (void) setAutoplay: (BOOL) flag
{
    _autoplay = flag;
	if (_autoplay)	// if we turn on autoplay, we also turn on preload
	{
		self.preload = kPreloadAuto;
	}
}

- (void) setController: (BOOL) flag
{
    _controller = flag;
	
	if (!_controller)	// if we turn off controller, we turn on autoplay so we can play!
	{
		self.autoplay = YES;
	}
	
}







@end
