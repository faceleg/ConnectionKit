//
//  SVWebEditorWebView.h
//  Sandvox
//
//  Created by Mike on 23/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Main purpose is to pass any unhandled drags up to the superview to deal with

#import <WebKit/WebKit.h>


@protocol SVWebEditorWebUIDelegate;
@interface SVWebEditorWebView : WebView
{
    BOOL    _superviewWillHandleDrop;
}

@property(nonatomic, assign) id <SVWebEditorWebUIDelegate> UIDelegate;

@end


@protocol SVWebEditorWebUIDelegate <NSObject>

@end
