//
//  SVWebViewController.h
//  Marvel
//
//  Created by Mike on 17/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "KTHTMLParser.h"

@class WebView, KTPage, SVTextBlockDOMController;


@interface SVWebViewController : NSViewController <KTHTMLParserDelegate>
{
    WebView *_webView;
    
    KTPage  *_page;
    BOOL    _isLoading;
    
    NSMutableArray  *_textBlocks;
    NSArray         *_textBlockControllers;
}

@property(nonatomic, retain) WebView *webView;


// These should all be KVO-compliant
@property(nonatomic, retain) KTPage *page;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;


#pragma mark Text Blocks

// An array of SVTetBlockController objects, one per text block created when setting up the page
@property(nonatomic, copy, readonly) NSArray *textBlockControllers;
// A series of methods for retrieving the Text Block DOM Controller to go with a bit of the webview
- (SVTextBlockDOMController *)controllerForDOMNode:(DOMNode *)node;
- (SVTextBlockDOMController *)controllerForDOMRange:(DOMRange *)range;
- (SVTextBlockDOMController *)controllerForSelection;

@end
