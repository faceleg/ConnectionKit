//
//  SVBodyParagraphDOMAdapter.h
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Keeps an HTML element in sync with a matching SVBodyParagraph object.


#import "SVWebTextArea.h"


@class SVBodyParagraph, SVBodyElement;

@interface SVBodyParagraphDOMAdapter : SVWebTextArea <DOMEventListener>
{
  @private    
    WebView         *_webView;
    NSTimeInterval  _editTimestamp;
    BOOL            _isUpdatingModel;
    
    DOMDocument *_DOMDocument;
}

// When -HTMLElement is first called, it will create an appropriate element
- (id)initWithBodyElement:(SVBodyElement *)element DOMDocument:(DOMDocument *)document;

- (void)updateParagraphFromDOM;
- (void)updateDOMFromParagraph;
@property(nonatomic, retain) WebView *webView;

@end
