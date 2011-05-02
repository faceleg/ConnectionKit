//
//  KTAsyncOffscreenWebViewController.m
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

// works in conjunction with KTDocWebViewController+Refreshing.m refreshWebViewComponent:

#import "SVOffscreenWebViewController.h"
#import "NSApplication+Karelia.h"


@implementation SVOffscreenWebViewController

#pragma mark Synchronous load

static SVOffscreenWebViewController *sOffscreenController = nil;
static BOOL sDoneLoading;

+ (DOMDocument *)DOMDocumentForHTMLString:(NSString *)inHTML baseURL:(NSURL *)aURL;
{
	DOMDocument *result = nil;
	OBPRECONDITION(inHTML);
    
	if (!sOffscreenController)
	{
		sOffscreenController = [[self alloc] init];
	}
	OBASSERT(sOffscreenController);
	
	[sOffscreenController setDelegate:self];
    WebFrame *frame = [[sOffscreenController webView] mainFrame];
	[frame loadHTMLString:inHTML baseURL:aURL];
	
    
	// Wait for it to load
    sDoneLoading = NO;
	NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:7.0];
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	
    while (!sDoneLoading && [theRL runMode:NSDefaultRunLoopMode beforeDate:timeoutDate]) { }
    
	result = [frame DOMDocument];
	return result;
}

/*!	Callback unlocks the lock so the foreground thread can proceed
 */
+ (void)offscreenWebViewController:(SVOffscreenWebViewController *)controller
                       didLoadBody:(DOMHTMLElement *)loadedBody;
{
	sDoneLoading = YES;
}

#pragma mark -

@synthesize webView = _webView;
@synthesize delegate = _delegate;

- (id)init;
{
	
    NSRect frame = NSMakeRect(0.0, 0.0, 800,800);
    
    NSWindow *window = [[NSWindow alloc]
                        initWithContentRect:frame styleMask:NSBorderlessWindowMask
                        // |NSTitledWindowMask|NSClosableWindowMask|NSResizableWindowMask|NSMiniaturizableWindowMask
                        backing:NSBackingStoreBuffered defer:NO];
    
    [window setReleasedWhenClosed:NO];
    
    _webView = [[WebView alloc] initWithFrame:frame];
    [window setContentView:_webView];
    
    [_webView setFrameLoadDelegate:self];
    [_webView setPolicyDelegate:self];
    
    //		[myWindow orderFront:nil]; 
    
	self = [self initWithWindow:window];
    [window release];
    return self;
}

- (void)dealloc
{
	[_webView close];
    [_webView release];
    [super dealloc];
}


- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
{
	[_webView setApplicationNameForUserAgent:[NSApplication applicationName]];
	
	// Create the webview. It must be in an offscreen window to do this properly.
	
	// Go ahead and begin building the thumbnail
	[[_webView mainFrame] loadHTMLString:anHTMLFragment baseURL:nil];
}

- (void)stopLoading
{
	[_webView stopLoading:nil];
}

#pragma mark Delegate stuff

- (void)webView:(WebView *)sender didCancelClientRedirectForFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}
- (void)webView:(WebView *)sender didChangeLocationWithinPageForFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didReceiveServerRedirectForProvisionalLoadForFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender didStartProvisionalLoadForFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender willCloseFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)sender willPerformClientRedirectToURL:(NSURL *)URL delay:(NSTimeInterval)seconds fireDate:(NSDate *)date forFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)webView didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame;
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
}

- (void)webView:(WebView *)webView windowScriptObjectAvailable:(WebScriptObject *)windowScriptObject;
{
	VALIDATION((@"%s %@",__FUNCTION__, windowScriptObject));
}


- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
	if (frame == [sender mainFrame])
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
        
        [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantPast]];
		[_delegate offscreenWebViewController:self didLoadBody:body];
	}
}

- (void)webView:(WebView *)webView decidePolicyForNavigationAction:(NSDictionary *)actionInformation request:(NSURLRequest *)request frame:(WebFrame *)frame decisionListener:(id < WebPolicyDecisionListener >)listener
{
    // Offscreen webviews only want to load the main frame. #93483
    if (frame == [webView mainFrame])
    {
        [listener use];
    }
    else
    {
        [listener ignore];
    }
}

@end
