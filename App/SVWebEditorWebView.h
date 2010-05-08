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
{
    BOOL    _delegateWillHandleDraggingInfo;
}

@property(nonatomic, readonly) SVWebEditorView *webEditorView;

@property(nonatomic, readonly) BOOL delegateWillHandleDraggingInfo;

// Returns YES if the first responder is a subview of the receiver
@property(nonatomic, readonly) BOOL isFirstResponder;

@end


@protocol SVWebEditorWebUIDelegate <NSObject>

@end
