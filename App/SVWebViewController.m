//
//  SVWebViewController.m
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebViewController.h"

#import "KTHTMLParser.h"
#import "KTPage.h"

#import "NSApplication+Karelia.h"


@interface SVWebViewController ()
- (void)loadPage:(KTPage *)page;
@property(nonatomic, readwrite, getter=isLoading) BOOL loading;
@end


#pragma mark -


@implementation SVWebViewController

- (void)dealloc
{
    [_webView release];
    [_page release];
    
    [super dealloc];
}

- (void)loadView
{
    WebView *webView = [[WebView alloc] init];
    [self setView:webView];
    [self setWebView:webView];
    [webView release];
}

- (WebView *)webView
{
    [self view];    // make sure view is loaded first
    return _webView;
}

- (void)setWebView:(WebView *)webView
{
    // Tear down old delegates
    [[self webView] setFrameLoadDelegate:nil];
    
    
    // Store new webview
    [webView retain];
    [_webView release];
    _webView = webView;
    
    
    // I don't know if it really benefits us having a custom user-agent, but seems a nice courtesy. Mike.
    [webView setApplicationNameForUserAgent:[NSApplication applicationName]];
    
    
    // Spell-checking
    // TODO: Define a constant or method for this
    BOOL spellCheck = [[NSUserDefaults standardUserDefaults] boolForKey:@"ContinuousSpellChecking"];
	[webView setContinuousSpellCheckingEnabled:spellCheck];
    
    
    // Delegation
    [webView setFrameLoadDelegate:self];
}

#pragma mark Loading

- (KTPage *)page { return _page; }

- (void)setPage:(KTPage *)page
{
    [page retain];
    [_page release];
    _page = page;
    
    if (page)
    {
        [self loadPage:page];
    }
    else
    {
        // TODO: load blank webview
    }
}

// Support
- (void)loadPage:(KTPage *)page;
{
    // Build the HTML
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:page];
	
	/*KTWebViewComponent *webViewComponent = [[KTWebViewComponent alloc] initWithParser:parser];
	[self setMainWebViewComponent:webViewComponent];
	[parser setDelegate:webViewComponent];
	[webViewComponent release];*/
	
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	//[parser setIncludeStyling:([self viewType] != KTWithoutStylesView)];
	
	NSString *pageHTML = [parser parseTemplate];
	[parser release];
	
    // Figure out the URL to use
	NSURL *pageURL = [page URL];
    if (![pageURL scheme] ||        // case 44071: WebKit will not load the HTML or offer delegate
        ![pageURL host] ||          // info if the scheme is something crazy like fttp:
        !([[pageURL scheme] isEqualToString:@"http"] || [[pageURL scheme] isEqualToString:@"https"]))
    {
        pageURL = nil;
    }
    
    // Record that the webview is being loaded with content. Otherwise, the policy delegate will refuse the request.
    [self setLoading:YES];
    
	// Load the HTML into the webview
    [[[self webView] mainFrame] loadHTMLString:pageHTML baseURL:pageURL];
}

@synthesize loading = _isLoading;

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (frame == [sender mainFrame])
	{
		[self setLoading:NO];
	}
}

// TODO: WebFrameLoadDelegate:
//  - window title

@end

