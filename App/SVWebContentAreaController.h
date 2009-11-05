//
//  SVDocContentViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KSTabViewController.h"
#import "SVWebEditorLoadController.h"


@protocol SVWebContentAreaControllerDelegate;


@interface SVWebContentAreaController : KSTabViewController <SVWebViewLoadControllerDelegate>
{
  @private
    SVWebEditorLoadController *_webViewController;
    NSViewController        *_placeholderViewController;
    
    NSArray *_selectedPages;
    
    id <SVWebContentAreaControllerDelegate> _delegate;  // weak ref
}

// Set this and the webview/source list view will be updated to match. Can even bind it!
@property(nonatomic, copy) NSArray *selectedPages;

@property(nonatomic, readonly) SVWebEditorLoadController *webViewLoadController;

@property(nonatomic, assign) id <SVWebContentAreaControllerDelegate> delegate;

@end


@protocol SVWebContentAreaControllerDelegate

- (void)webContentAreaControllerDidChangeTitle:(SVWebContentAreaController *)controller;
@end