//
//  SVAudioVisualPlugIn.m
//  Sandvox
//
//  Created by Dan Wood on 9/28/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVAudioVisualPlugIn.h"

#import "SVMediaGraphic.h"


@interface SVMediaPlugIn (InheritedPrivate)
@property(nonatomic, readonly) SVMediaGraphic *container;
@end


@implementation SVAudioVisualPlugIn

#pragma mark Source

- (BOOL)validatePosterFrame:(SVMediaRecord *)posterFrame;
{
    // Ideally have a poster frame, but can live without
    return YES;
}

@synthesize autoplay	= _autoplay;
@synthesize loop		= _loop;
@synthesize controller	= _controller;
@synthesize preload		= _preload;

- (NSString *)codecType; { return [[self container] codecType]; }
- (void)setCodecType:(NSString *)type;
{
    [[self container] setCodecType:type];
    
    // Ignore reload flag and check 
    [[self container] reloadPlugInIfNeeded];
}

#pragma mark Properties

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

+ (NSArray *)plugInKeys;
{
    return [[super plugInKeys] arrayByAddingObjectsFromArray:
			[NSArray arrayWithObjects:
			 @"autoplay",
			 @"loop",
			 @"preload",
			 @"controller",
			 nil]];
}

#pragma mark HTML

// 1.x rendered all non-images as video in one form or another, so we have to do the same for backwards compat.
+ (NSString *) elementClassName; { return @"VideoElement"; }
+ (NSString *) contentClassName; { return @"video"; }

#pragma mark Migration

- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
	NSLog(@"%@", properties);
}

@end
