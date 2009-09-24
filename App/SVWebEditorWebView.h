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
{
    BOOL    _delegateWillHandleDrop;
}

@property(nonatomic, assign) id <SVWebEditorWebUIDelegate> UIDelegate;

@end


@protocol SVWebEditorWebUIDelegate <NSObject>

/*  These methods allow one to hook in an supplement WebKit's default drag and drop handling. Whenever the WebView itself rejects a drop, the delegate is allowed to give it a second chance. But if the WebView does accept the drop then you won't even get a look-in, so be sure to use the standard WebUIDelegate methods to refuse any drops that you want this delegate method to then receive.
 */

- (void)webView:(WebView *)webView willValidateDrop:(id <NSDraggingInfo>)dragInfo;

- (NSDragOperation)webView:(WebView *)webView
              validateDrop:(id <NSDraggingInfo>)dragInfo
         proposedOperation:(NSDragOperation)operation;

- (BOOL)webView:(WebView *)webView acceptDrop:(id <NSDraggingInfo>)dragInfo;

@end
