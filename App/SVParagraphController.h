//
//  SVParagraphController.h
//  Sandvox
//
//  Created by Mike on 19/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebTextArea.h"
#import "SVBodyTextArea.h"


@class SVBodyParagraph;

@interface SVParagraphController : SVWebTextArea <SVElementController, DOMEventListener>
{
  @private
    SVBodyParagraph *_paragraph;
    
    WebView         *_webView;
    NSTimeInterval  _editTimestamp;
}

- (id)initWithHTMLElement:(DOMHTMLElement *)domElement paragraph:(SVBodyParagraph *)paragraph;
@property(nonatomic, retain, readonly) SVBodyParagraph *paragraph;

- (void)updateModelFromDOM;
@property(nonatomic, retain) WebView *webView;

@end
