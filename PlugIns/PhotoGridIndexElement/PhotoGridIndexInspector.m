//
//  PhotoGridIndexInspector.m
//  PhotoGridIndex
//
//  Created by Dan Wood on 3/29/11.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "PhotoGridIndexInspector.h"


@implementation PhotoGridIndexInspector

- (void)loadView;
{
	[super loadView];
	[NSColor setIgnoresAlpha:NO];		// Need to make sure color picker is going to handle alpha
	[[NSColorPanel sharedColorPanel] setShowsAlpha:YES];
	
}

@end
