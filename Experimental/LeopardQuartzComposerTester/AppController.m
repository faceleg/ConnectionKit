//
//  AppController.m
//  LeopardQuartzComposerTester
//
//  Created by Mike on 28/10/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "AppController.h"

#import "KTStringRenderer.h"


@implementation AppController

- (NSImage *)stringImage { return myStringImage; }

- (void)setStringImage:(NSImage *)image
{
	[image retain];
	[myStringImage release];
	myStringImage = image;
}

- (IBAction)renderFile:(id)sender
{
	// Ask the user for a file
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:NO];
	[panel setTreatsFilePackagesAsDirectories:YES];
	
	[panel runModalForTypes:[NSArray arrayWithObject:@"qtz"]];
	NSString *file = [panel filename];
	
	// Render the image
	NSDictionary *inputs = [NSDictionary dictionaryWithObjectsAndKeys:
		@"test", @"String",
		[NSNumber numberWithFloat:0.5], @"Size",
		nil];
		
	KTStringRenderer *renderer = [KTStringRenderer rendererWithFile:file];
	NSImage *result = [renderer imageWithInputs:inputs];
	
	// Display the finished result to the user
	[self setStringImage:result];
}

@end
