//
//  KTAsyncOffscreenWebViewController.h
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/Webkit.h>


@protocol SVOffscreenWebViewControllerDelegate;


@interface SVOffscreenWebViewController : NSWindowController
{
  @private
	WebView     *_webView;
	
	id <SVOffscreenWebViewControllerDelegate> _delegate;
}

+ (DOMDocument *)DOMDocumentForHTMLString:(NSString *)inHTML baseURL:(NSURL *)aURL;

@property(nonatomic, retain, readonly) WebView *webView;
@property(nonatomic, assign) id <SVOffscreenWebViewControllerDelegate> delegate;


- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
- (void) stopLoading;

@end


#pragma mark -


@protocol SVOffscreenWebViewControllerDelegate
- (void)offscreenWebViewController:(SVOffscreenWebViewController *)controller
                       didLoadBody:(DOMHTMLElement *)loadedBody;
@end
