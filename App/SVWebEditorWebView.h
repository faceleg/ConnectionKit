//
//  SVWebEditorWebView.h
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Main purpose is to pass any unhandled drags up to the superview to deal with

#import <WebKit/WebKit.h>


@class SVWebEditorView;
@protocol SVWebEditorWebUIDelegate;


@interface SVWebEditorWebView : WebView


@property(nonatomic, readonly) SVWebEditorView *webEditorView;

@end


@protocol SVWebEditorWebUIDelegate <NSObject>

@end
