//
//  SVWebViewContainerView.h
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  A Web Editing View is used to contain a WebView so that it can gain early access to hit testing in order to deny certain events reaching the WebView. By doing so it can create a UI paradigm whereby areas of the WebView becme "selectable" – that is, a click will place a selection border around an object rather than performing the normal action. The selected object can then be mainpulated (e.g. change size, reposition), or a second click will allow access to WebKit's usual behaviour for the content.


#import <WebKit/WebKit.h>


@protocol SVWebEditingOverlayDataSource;


@interface SVWebEditingOverlay : NSView
{
  @private
    WebView                             *_webView;
    id <SVWebEditingOverlayDataSource>  _dataSource;    // weak ref as you'd expect
    
    NSMutableArray  *_selection;
}

@property(nonatomic, retain) IBOutlet WebView *webView;
@property(nonatomic, assign) id <SVWebEditingOverlayDataSource> dataSource;

@property(nonatomic, copy, readonly) NSArray *selectedNodes;
- (void)insertObject:(DOMNode *)node inSelectedNodesAtIndex:(NSUInteger)index;
- (void)removeObjectFromSelectedNodesAtIndex:(NSUInteger)index;


@end


@protocol SVWebEditingOverlayDataSource <NSObject>
- (BOOL)webEditingView:(SVWebEditingOverlay *)view nodeIsSelectable:(DOMNode *)node;
@end