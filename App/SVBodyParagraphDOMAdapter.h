//
//  SVBodyParagraphDOMAdapter.h
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Keeps an HTML element in sync with a matching SVBodyParagraph object.


#import "SVWebTextArea.h"
#import "SVBodyTextArea.h"


@class SVBodyParagraph;

@interface SVBodyParagraphDOMAdapter : SVWebTextArea <SVElementController, DOMEventListener>
{
  @private
    SVBodyParagraph *_paragraph;
    
    BOOL            _isObserving;
    WebView         *_webView;
    NSTimeInterval  _editTimestamp;
    BOOL            _isUpdatingModel;
}

// It's assumed the element already contains the right HTML to match paragraph
- (id)initWithHTMLElement:(DOMHTMLElement *)domElement paragraph:(SVBodyParagraph *)paragraph;
- (void)stop;

@property(nonatomic, retain, readonly) SVBodyParagraph *paragraph;

- (void)updateParagraphFromDOM;
- (void)updateDOMFromParagraph;
@property(nonatomic, retain) WebView *webView;

@end
