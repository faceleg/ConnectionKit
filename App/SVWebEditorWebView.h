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
    DOMNode *_draggingDestinationNode;
    
    BOOL    _superviewWillHandleDrop;
}

#pragma mark NSDraggingDestination
// Sender might be nil to signify a drag exiting
- (void)viewDidValidate:(NSDragOperation)op drop:(id <NSDraggingInfo>)sender;


#pragma mark Drawing
- (void)didDrawRect:(NSRect)dirtyRect;

//@property(nonatomic, assign) id <SVWebEditorWebUIDelegate> UIDelegate;

@end


@protocol SVWebEditorWebUIDelegate <NSObject>

@end
