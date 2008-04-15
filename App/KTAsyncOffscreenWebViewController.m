//
//  KTAsyncOffscreenWebViewController.m
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

// works in conjunction with KTDocWebViewController+Refreshing.m refreshWebViewComponent:

#import "KTAsyncOffscreenWebViewController.h"


@implementation KTAsyncOffscreenWebViewController

- (id) init
{
	self = [super init];
	if (self != nil) {

		NSRect frame = NSMakeRect(0.0, 0.0, 800,800);
		
		myWindow = [[NSWindow alloc]
							initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
		[myWindow setReleasedWhenClosed:NO];	// Otherwise we crash upon quitting - I guess NSApplication closes all windows when termintating?
		
		myWebView = [[WebView alloc] initWithFrame:frame];	// Both window and webview will be released later
		[myWindow setContentView:myWebView];
		
		[myWebView setFrameLoadDelegate:self];
	}
	return self;
}


- (void)dealloc
{
    [myWebView release];
	[myWindow release];
    [super dealloc];
}


- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
{
	
	// Create the webview. It must be in an offscreen window to do this properly.
	
	// Go ahead and begin building the thumbnail
	[[myWebView mainFrame] loadHTMLString:anHTMLFragment baseURL:nil];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	DOMNodeList *bodyList = [[frame DOMDocument] getElementsByTagName:@"BODY"];
	DOMHTMLElement *body = nil;
	if (0 == [bodyList length])
	{
		NSLog(@"unable to get results of load because DOMNode did not have a BODY tag");
	}
	else
	{
		body = [bodyList item:0];
	}
	[myDelegate spliceElement:body];
}

- (void)stopLoading
{
	[myWebView stopLoading:nil];
}

- (id)delegate
{
    return myDelegate; 
}
- (void)setDelegate:(id)aDelegate
{
    myDelegate = aDelegate;
}

@end
