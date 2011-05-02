//
//  ImageWebKitViewFactory.m
//  Marvel
//
//  Created by Dan Wood on 3/10/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTImageWebKitViewFactory.h"


@implementation KTImageWebKitViewFactory

+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments
{
NSLog(@"ImageWebKitViewFactory : %@", arguments);
	NSDictionary *attr = [arguments objectForKey:WebPlugInAttributesKey];
	int height = [[attr objectForKey:@"height"] intValue];
	int width = [[attr objectForKey:@"width"] intValue];
	
	/*
	 WebPlugInBaseURLKey = file:///Library/Application%20Support/Apple/Mail/Stationery/Apple/Contents/Resources/Photos/Contents/Resources/Tack%20Board.mailstationery/Contents/Resources/;
	 WebPlugInContainerKey = <WebPluginController: 0x186cce0>;
	 WebPlugInContainingElementKey = <DOMHTMLEmbedElement [EMBED]: 0xde94e40 ''>;
	 WebPlugInModeKey = 0;
	 WebPlugInShouldLoadMainResourceKey = 1;
	 */
	
	
	NSRect frame = NSMakeRect(0,0,width,height);
	NSImageView *view = [[NSImageView alloc] initWithFrame:frame];
	
	NSString *src = [[NSURL URLWithString:[attr objectForKey:@"src"]] path];
	NSString *srcName = [src lastPathComponent];
	NSString *srcBase = [src stringByDeletingLastPathComponent];
	
	NSString *descPath = [srcBase stringByAppendingPathComponent:@"Description.plist"];
	NSDictionary *plist = [NSDictionary dictionaryWithContentsOfFile:descPath];
	
	
	NSImage *im = [[[NSImage alloc] initWithContentsOfFile:src] autorelease];
	[view setImage:im];
	
#define BUTTONMARGIN 10
#define BUTTONSIZE 32
	NSButton *button;
	NSImage *img;
	
	// lower left - rotate
	button = [[[NSButton alloc] initWithFrame:NSMakeRect(BUTTONMARGIN, BUTTONMARGIN, BUTTONSIZE, BUTTONSIZE)] autorelease];
	[button setBordered:NO];
	[button setButtonType:NSMomentaryChangeButton];
	[button setImagePosition:NSImageOnly];
	img = [NSImage imageNamed:@"rotate"];
	[img setScalesWhenResized:YES];
	[img setSize:NSMakeSize(BUTTONSIZE, BUTTONSIZE)];
	[button setImage:img];
	
	[view addSubview:button];

	// upper left - corner radius (smaller margin?)
	button = [[[NSButton alloc] initWithFrame:NSMakeRect(BUTTONMARGIN, height-BUTTONMARGIN-BUTTONSIZE, BUTTONSIZE, BUTTONSIZE)] autorelease];
	[button setBordered:NO];
	[button setButtonType:NSMomentaryChangeButton];
	[button setImagePosition:NSImageOnly];
	img = [NSImage imageNamed:@"crop"];
	[img setScalesWhenResized:YES];
	[img setSize:NSMakeSize(BUTTONSIZE, BUTTONSIZE)];
	[button setImage:img];
	
	 [view addSubview:button];

	// upper right - rounded rectangle
	button = [[[NSButton alloc] initWithFrame:NSMakeRect(width-BUTTONMARGIN-BUTTONSIZE, height-BUTTONMARGIN-BUTTONSIZE, BUTTONSIZE, BUTTONSIZE)] autorelease];
	[button setBordered:NO];
	[button setButtonType:NSMomentaryChangeButton];
	[button setImagePosition:NSImageOnly];
	img = [NSImage imageNamed:@"rounded"];
	[img setScalesWhenResized:YES];
	[img setSize:NSMakeSize(BUTTONSIZE, BUTTONSIZE)];
	[button setImage:img];
	
	 [view addSubview:button];

	// lower right -- resize; no margin (?)
	button = [[[NSButton alloc] initWithFrame:NSMakeRect(width-BUTTONSIZE, 0, BUTTONSIZE, BUTTONSIZE)] autorelease];
	[button setButtonType:NSMomentaryChangeButton];
	[button setImagePosition:NSImageOnly];
	[button setBordered:NO];
	img = [NSImage imageNamed:@"grow"];
	[img setScalesWhenResized:YES];
	[img setSize:NSMakeSize(BUTTONSIZE, BUTTONSIZE)];
	[button setImage:img];
	
	 [view addSubview:button];

	return view;
}

@end
