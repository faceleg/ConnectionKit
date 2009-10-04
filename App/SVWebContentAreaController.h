//
//  SVDocContentViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"
#import "SVWebViewLoadController.h"


@interface SVWebContentAreaController : KSTabViewController <SVWebViewLoadControllerDelegate>
{
  @private
    SVWebViewLoadController *_webViewController;
    NSViewController        *_placeholderViewController;
    
    NSArray *_selectedPages;
}

// Set this and the webview/source list view will be updated to match. Can even bind it!
@property(nonatomic, copy) NSArray *selectedPages;

@property(nonatomic, readonly) SVWebViewLoadController *webViewLoadController;


@end
