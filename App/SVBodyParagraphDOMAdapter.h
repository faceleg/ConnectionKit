//
//  SVBodyParagraphDOMAdapter.h
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Keeps an HTML element in sync with a matching SVBodyParagraph object.


#import "SVWebEditorTextController.h"


@class SVBodyParagraph, SVBodyElement;

@interface SVBodyParagraphDOMAdapter : SVWebEditorTextController <DOMEventListener>
{
  @private    
    WebView         *_webView;
    NSTimeInterval  _editTimestamp;
    BOOL            _isUpdatingModel;
}

- (void)updateParagraphFromDOM;
- (void)updateDOMFromParagraph;
@property(nonatomic, retain) WebView *webView;

@end
