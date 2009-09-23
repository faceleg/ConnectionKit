//
//  SVWebEditorWebView.h
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <WebKit/WebKit.h>


@protocol SVWebEditorWebUIDelegate;
@interface SVWebEditorWebView : WebView

@property(nonatomic, assign) id <SVWebEditorWebUIDelegate> UIDelegate;

@end


@protocol SVWebEditorWebUIDelegate <NSObject>

- (void)webView:(WebView *)webView willValidateDrop:(id <NSDraggingInfo>)dragInfo;

- (NSDragOperation)webView:(WebView *)webView
              validateDrop:(id <NSDraggingInfo>)dragInfo
         proposedOperation:(NSDragOperation)operation;

@end