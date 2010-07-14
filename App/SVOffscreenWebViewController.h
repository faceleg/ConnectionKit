//
//  KTAsyncOffscreenWebViewController.h
//  Marvel
//
//  Created by Dan Wood on 4/15/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <WebKit/Webkit.h>

@protocol KTAsyncOffscreenWebViewControllerDelegate

- (void)bodyLoaded:(DOMHTMLElement *)loadedBody;

@end


@interface SVOffscreenWebViewController : NSWindowController
{
  @private
	WebView     *_webView;
	
	id <KTAsyncOffscreenWebViewControllerDelegate> _delegate;
}

+ (DOMDocument *)DOMDocumentForHTMLString:(NSString *)inHTML baseURL:(NSURL *)aURL;

@property(nonatomic, retain, readonly) WebView *webView;
@property(nonatomic, assign) id <KTAsyncOffscreenWebViewControllerDelegate> delegate;


- (void)loadHTMLFragment:(NSString *)anHTMLFragment;
- (void) stopLoading;

@end
