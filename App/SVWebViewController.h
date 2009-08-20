//
//  SVWebViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class WebView, KTPage;


@interface SVWebViewController : NSViewController
{
    WebView *_webView;
    
    KTPage  *_page;
    BOOL    _isLoading;
}

@property(nonatomic, retain) WebView *webView;


// These should all be KVO-compliant
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;

@end
