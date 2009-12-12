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

@interface SVBodyParagraphDOMAdapter : SVDOMController <DOMEventListener>
{
  @private    
    WebView         *_webView;
    NSTimeInterval  _editTimestamp;
    BOOL            _isUpdatingModel;
}

// The receiver itself will not call this method. Instead, is designed such that the owning body text controller will call it after a change, and the receiver will commit any changes it might have.
- (void)enclosingBodyControllerDidChangeText;

@property(nonatomic, retain) WebView *webView;

@end
