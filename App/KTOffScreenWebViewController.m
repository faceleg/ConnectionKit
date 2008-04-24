//
//  KTOffScreenWebViewController.m
//  KTComponents
//
//  Copyright (c) 2005 Biophony LLC. All rights reserved.
//

// Some of this logic is adapted from techniques courtesy of xenon of colloquy,
// their method of +[NSAttributedString attributedStringWithHTMLFragment:baseURL:]


#import "KTOffScreenWebViewController.h"

#import "KT.h"
#import "Debug.h"

static NSConditionLock *sRenderingFragmentLock = nil;
static WebView *sOffscreenWebView = nil;

@implementation KTOffScreenWebViewController

+ (DOMDocument *)DOMDocumentForHTMLString:(NSString *)inHTML baseURL:(NSURL *)aURL
{
	DOMDocument *result = nil;
	OBPRECONDITION(inHTML != nil);
	
	if (  nil == sRenderingFragmentLock )
	{
		sRenderingFragmentLock = [[NSConditionLock alloc] initWithCondition:2];
	}
	OBASSERT(nil != sRenderingFragmentLock);
	
	// wait until any other call to this method finishes; timeout after 7 seconds
	if ( [sRenderingFragmentLock lockWhenCondition:2 beforeDate:[NSDate dateWithTimeIntervalSinceNow:7.]] )
	{
		[sRenderingFragmentLock unlockWithCondition:0];
		
		[NSThread detachNewThreadSelector:@selector(renderHTMLFragment:) 
								 toTarget:self 
							   withObject:[NSDictionary dictionaryWithObjectsAndKeys:inHTML, @"fragment", aURL, @"url", nil]];
		
		// wait until the rendering is done; timeout after 7 seconds
		if ( [sRenderingFragmentLock lockWhenCondition:1 beforeDate:[NSDate dateWithTimeIntervalSinceNow:7.]] )
		{
			result = [[sOffscreenWebView mainFrame] DOMDocument];
			
			 // we are done, safe for releasing sOffscreenWebView
			[sRenderingFragmentLock unlockWithCondition:2];
		}
		else 
		{
			NSLog(@"error: unable to obtain inner +DOMDocumentForHTMLString lock while processing RTFD import");
	}

	}
	else
	{
		NSLog(@"error: unable to obtain outer +DOMDocumentForHTMLString lock while processing RTFD import");
	}
	
	return result;
}

/*!	This part renders in the background thread
*/
+ (void)renderHTMLFragment:(NSDictionary *)info
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[sRenderingFragmentLock lockWhenCondition:0]; // start the rendering, makes parent thread block
	
	[NSThread setThreadPriority:1.0];
	
	NSString	*fragment = [info objectForKey:@"fragment"];
	NSURL		*url = [info objectForKey:@"url"];
	
	if ( nil == sOffscreenWebView )
	{
		sOffscreenWebView = [[WebView alloc] initWithFrame:NSMakeRect( 0., 0., 2000., 100. ) frameName:nil groupName:nil];
	}
	OBASSERT(nil != sOffscreenWebView);
	
	[sOffscreenWebView setFrameLoadDelegate:self];	// will this be OK, to have delegate be the class?
	[[sOffscreenWebView mainFrame] loadHTMLString:fragment baseURL:url];
	
	[[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.25]]; // why 0.25??
	
	// why are we locking again with condition 2, when we just locked with condition 0, above?
	[sRenderingFragmentLock lockWhenCondition:2]; // wait until it is safe to release
	[sRenderingFragmentLock unlockWithCondition:2];
	
	[pool release];
}

/*!	Callback unlocks the lock so the foreground thread can proceed
*/
+ (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	extern NSConditionLock *sRenderingFragmentLock;
	[sRenderingFragmentLock unlockWithCondition:1]; // rendering is complete
	[sender setFrameLoadDelegate:nil];
}

@end
