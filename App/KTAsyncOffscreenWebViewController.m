//
//  KTAsyncOffscreenWebViewController.m
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

// works in conjunction with KTDocWebViewController+Refreshing.m refreshWebViewComponent:

#import "KTAsyncOffscreenWebViewController.h"
#import "KTDocWebViewController.h"
#import "NSApplication+Karelia.h"

@implementation KTAsyncOffscreenWebViewController

- (id) init
{
	self = [super init];
	if (self != nil) {

		NSRect frame = NSMakeRect(0.0, 0.0, 800,800);
		
		_window = [[NSWindow alloc]
							initWithContentRect:frame styleMask:NSBorderlessWindowMask
// |NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
					backing:NSBackingStoreBuffered defer:NO];

		[_window setReleasedWhenClosed:NO];
		
		_webView = [[WebView alloc] initWithFrame:frame];
		[_window setContentView:_webView];
		
		[_webView setFrameLoadDelegate:self];
		
//		[myWindow orderFront:nil]; 
	}
	return self;
}


- (void)dealloc
{
    [_webView release];
	[_window release];
    [super dealloc];
}


- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
{
	[_webView setApplicationNameForUserAgent:[NSApplication applicationName]];
	
	// Create the webview. It must be in an offscreen window to do this properly.
	
	// Go ahead and begin building the thumbnail
	[[_webView mainFrame] loadHTMLString:anHTMLFragment baseURL:nil];
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
		body = (DOMHTMLElement *)[bodyList item:0];
	}
	[_delegate spliceElement:body];
}

- (void)stopLoading
{
	[_webView stopLoading:nil];
}

- (id)delegate
{
    return _delegate; 
}
- (void)setDelegate:(id)aDelegate
{
    _delegate = aDelegate;
}

@end
