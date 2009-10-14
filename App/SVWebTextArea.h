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
#import "SVWebEditorTextProtocol.h"
#import "KSKeyValueBinding.h"


@protocol SVWebTextAreaDelegate;
@interface SVWebTextArea : NSObject <SVWebEditorText, KSEditor>
{
  @private
    DOMHTMLElement      *_element;
    
    BOOL    _isRichText;
    BOOL    _isFieldEditor;
    
    // Editing
    BOOL            _isEditing;
    NSString        *_uneditedValue;
    
    // Delegate
    id <SVWebTextAreaDelegate>  _delegate;
    
    // Bindings
    id <KSEditorRegistration>   _controller;  // weak ref
    BOOL                        _isCommittingEditing;
}

- (id)initWithDOMElement:(DOMHTMLElement *)element;// controller:(SVWebViewController *)controller;


@property(nonatomic, retain, readonly) DOMHTMLElement *DOMElement;


// Returns whatever is entered into the text box right now. This is what gets used for the "value" binding. You want to use this rather than querying the DOM Element for its -innerHTML directly as it takes into account the presence of any inner tags like a <span class="in">
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSString *string;


// NSTextView-like properties for controlling editing behaviour. Some are stored as part of the DOM, others as ivars. Note that some can only really take effect if properly hooked up to another controller that forwards on proper editing delegation methods from the WebView.
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, setter=setRichText:) BOOL isRichText;
@property(nonatomic, setter=setFieldEditor:) BOOL isFieldEditor;


#pragma mark Editing

@property(nonatomic, readonly, getter=isEditing) BOOL editing;

- (void)didBeginEditing;

// Calls -didBeginEditing if needed
- (void)webEditorTextDidChange:(NSNotification *)notification;

// e.g. Movement might be NSReturnTextMovement. Nil if we don't know
- (void)didEndEditingWithMovement:(NSNumber *)textMovement;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebTextAreaDelegate> delegate;

@end


#pragma mark -

#if !defined MAC_OS_X_VERSION_10_6 || MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_6
@protocol NSTextDelegate <NSObject> @end
#endif

@protocol SVWebTextAreaDelegate <NSTextDelegate>
@end

