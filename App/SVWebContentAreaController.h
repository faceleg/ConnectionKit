//
//  SVDocContentViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"


@class SVWebViewLoadController;


@interface SVWebContentAreaController : KSTabViewController
{
  @private
    SVWebViewLoadController *_webViewController;
    
    NSArray *_selectedPages;
}

// Set this and the webview/source list view will be updated to match. Can even bind it!
@property(nonatomic, copy) NSArray *selectedPages;

@property(nonatomic, readonly) SVWebViewLoadController *webViewLoadController;

// Reloads all subcontrollers
- (IBAction)updateWebView:(id)sender;

@end
