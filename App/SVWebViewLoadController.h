//
//  SVWebViewLoadingController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"


@class SVWebViewController, KTPage;


@interface SVWebViewLoadController : KSTabViewController
{
  @private
    SVWebViewController *_primaryController;    // loaded & probably on-screen
    SVWebViewController *_secondaryController;  // offscreen, ready to load into
    NSViewController    *_webViewLoadingPlaceholder;
    
    KTPage  *_page;
    
    BOOL    _needsLoad;
}

// You should use this to create a controller as it will internally create the correct subcontrollers
- (id)init;

@property(nonatomic, readonly) SVWebViewController *primaryWebViewController;
@property(nonatomic, readonly) SVWebViewController *secondaryWebViewController;

// Setting the page will automatically mark controller as needsLoad = YES
@property(nonatomic, retain) KTPage *page;


#pragma mark Loading
@property(nonatomic) BOOL needsLoad;
- (void)load;
- (IBAction)updateWebView:(id)sender;
- (void)loadIfNeeded;

@end
