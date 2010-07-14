//
//  KTAsyncOffscreenWebViewController.h
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/Webkit.h>


@interface KTAsyncOffscreenWebViewController : NSWindowController
{
  @private
	WebView     *_webView;
	
	id _delegate;
}

@property (readonly, nonatomic, retain) WebView *webView;
@property (assign) id delegate;


- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
- (void) stopLoading;

@end
