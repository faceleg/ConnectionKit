//
//  YouTubeElementInspector.m
//  YouTubeElement
//
//  Created by Dan Wood on 2/23/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "YouTubeElementInspector.h"
#import "YouTubeCocoaExtensions.h"
#import "YouTubeElementPlugin.h"

//	LocalizedStringInThisBundle(@"This is a placeholder for the YouTube video at:", "Live data feeds are disabled");
//	LocalizedStringInThisBundle(@"To see the video in Sandvox, please enable live data feeds in the Preferences.", "Live data feeds are disabled");
//	LocalizedStringInThisBundle(@"Sorry, but no YouTube video was found for the code you entered.", "User entered an invalid YouTube code");
//	LocalizedStringInThisBundle(@"Please use the Inspector to specify a YouTube video.", "No video code has been entered yet");


@implementation YouTubeElementInspector

- (NSString *)nibName { return @"YouTubeElement"; }

- (IBAction)openYouTubeURL:(id)sender
{
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://youtube.com/"]];
}

- (IBAction)resetColors:(id)sender
{
	[[[self inspectedObjectsController] selection] resetColors];
}


@end
