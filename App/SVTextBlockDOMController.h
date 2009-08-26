//
//  SVTextBoxController.h
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  A Text Box Controller is a special kind of DOM Controller that manages a block of editable text in the webview. Its aim is to provide an NSTextView-like API for the text (i.e. all properties/methods should have a "live" effect on the DOM). You can even bind it to a model object (or object controller) like you would a standard Cocoa control.

// Available bindings:
//  value - should be bound an NSString which will be displayed as a single lump of text
//  HTMLString - like NSTextView has an "attributedString" binding, so we have one for HTML


#import "SVDOMController.h"


@interface SVTextBlockDOMController : SVDOMController
{
    BOOL    _isRichText;
    BOOL    _isFieldEditor;
    
    WebView     *_webView;
    NSString    *_elementID;
}

- (id)initWithWebView:(WebView *)webView elementID:(NSString *)elementID;


// Returns whatever is entered into the text box right now. This is what gets used for the "value" binding. You want to use this rather than querying the DOM Element for its -innerHTML directly as it takes into account the presence of any inner tags like a <span class="in">
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSString *string;


// NSTextView-like properties for controlling editing behaviour. Some are stored as part of the DOM, others as ivars. Note that some can only really take effect if properly hooked up to another controller that forwards on proper editing delegation methods from the WebView.
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, setter=setRichText) BOOL isRichText;
@property(nonatomic, setter=setFieldEditor) BOOL isFieldEditor;


// Editing.
// We follow the same pattern (and notifications) as NSText/NSTextView
- (void)didChangeText;
- (void)didBeginEditingText;
- (void)didEndEditingText;

- (BOOL)webView:(WebView *)aWebView doCommandBySelector:(SEL)selector;


@end

