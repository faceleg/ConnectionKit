//
//  KTOffScreenWebViewController.m
//  KTComponents
//
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

// Some of this logic is adapted from techniques courtesy of xenon of colloquy,
// their method of +[NSAttributedString attributedStringWithHTMLFragment:baseURL:]


#import "KTOffScreenWebViewController.h"

#import "KT.h"
#import "Debug.h"

static WebView *sOffscreenWebView = nil;
static BOOL sDoneLoading;

@implementation KTOffScreenWebViewController

+ (DOMDocument *)DOMDocumentForHTMLString:(NSString *)inHTML baseURL:(NSURL *)aURL
{
	DOMDocument *result = nil;
	OBPRECONDITION(inHTML != nil);
		
	if ( nil == sOffscreenWebView )
	{
		sOffscreenWebView = [[WebView alloc] initWithFrame:NSMakeRect( 0., 0., 2000., 100. ) frameName:nil groupName:nil];
	}
	OBASSERT(nil != sOffscreenWebView);
	
	[sOffscreenWebView setFrameLoadDelegate:self];	// will this be OK, to have delegate be the class?
	[[sOffscreenWebView mainFrame] loadHTMLString:inHTML baseURL:aURL];
	
	sDoneLoading = NO;
	NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:7.0];
	NSRunLoop *theRL = [NSRunLoop currentRunLoop];
	while (!sDoneLoading && [theRL runMode:NSDefaultRunLoopMode beforeDate:timeoutDate])
	{
		;
	}
		
	result = [[sOffscreenWebView mainFrame] DOMDocument];
	
	return result;
}

/*!	Callback unlocks the lock so the foreground thread can proceed
*/
+ (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	[sender setFrameLoadDelegate:nil];
	sDoneLoading = YES;
}

@end
