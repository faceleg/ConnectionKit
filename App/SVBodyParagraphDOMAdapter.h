//
//  SVBodyParagraphDOMAdapter.h
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Keeps an HTML element in sync with a matching SVBodyParagraph object.


#import "SVWebTextArea.h"


@class SVBodyParagraph;

@interface SVBodyParagraphDOMAdapter : SVWebTextArea <DOMEventListener>
{
  @private    
    BOOL            _isObserving;
    WebView         *_webView;
    NSTimeInterval  _editTimestamp;
    BOOL            _isUpdatingModel;
}

// It's assumed the element already contains the right HTML to match paragraph. Paragraph is stored in representedObject
- (id)initWithHTMLElement:(DOMHTMLElement *)domElement paragraph:(SVBodyParagraph *)paragraph;
- (void)stop;

- (void)updateParagraphFromDOM;
- (void)updateDOMFromParagraph;
@property(nonatomic, retain) WebView *webView;

@end
