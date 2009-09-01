//
//  SVTextBoxController.h
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Between them, SVTextBlock & SVWebViewController create a system like NSView & NSWindow for handling display and editing of text via the webview. SVTextBlock's main aim is to provide an NSTextView-like API for the text (i.e. all properties/methods should have a "live" effect on the DOM).


#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>


@interface SVTextBlock : NSObject
{
  @private
    DOMHTMLElement      *_element;
    //SVWebViewController *_controller;   // weak ref
    WebView             *_webView;
    
    BOOL    _isRichText;
    BOOL    _isFieldEditor;
    
    BOOL    _isEditing;
}

- (id)initWithDOMElement:(DOMHTMLElement *)element;// controller:(SVWebViewController *)controller;


@property(nonatomic, retain, readonly) DOMHTMLElement *DOMElement;
//@property(nonatomic, assign, readonly) SVWebViewController *webViewController;
@property(nonatomic, retain) WebView *webView;  // only ever need to change if -DOMElement moves to a new webview

// Returns whatever is entered into the text box right now. This is what gets used for the "value" binding. You want to use this rather than querying the DOM Element for its -innerHTML directly as it takes into account the presence of any inner tags like a <span class="in">
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSString *string;


// NSTextView-like properties for controlling editing behaviour. Some are stored as part of the DOM, others as ivars. Note that some can only really take effect if properly hooked up to another controller that forwards on proper editing delegation methods from the WebView.
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, setter=setRichText) BOOL isRichText;
@property(nonatomic, setter=setFieldEditor) BOOL isFieldEditor;




@end


@interface SVTextBlock (Support)

// Editing.
// We follow the same pattern (and notifications) as NSText/NSTextView
- (void)didChangeText;
- (void)didBeginEditingText;    // should be no need to call yourself, -didChangeText will call it for you
- (BOOL)shouldEndEditing;   // provided for webview's delegate to signal when editing is done

- (BOOL)webView:(WebView *)aWebView doCommandBySelector:(SEL)selector;

@end

