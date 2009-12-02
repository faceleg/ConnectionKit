//
//  SVWebEditorTextController.h
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An HTML element controller specialised to deal with text, generally of the editable variety. In a way, a bit like how NSText is too abstract to do anything on its own, but central to the operation of NSTextView and NSTextField. So check out the subclasses for more advanced stuff.


#import "SVHTMLElementController.h"
#import "SVWebEditorTextProtocol.h"
#import "KSKeyValueBinding.h"


@protocol SVWebTextAreaDelegate;
@interface SVWebEditorTextController : SVHTMLElementController <SVWebEditorText, KSEditor>
{
  @private
    NSString    *_HTMLString;
    BOOL        _isRichText;
    BOOL        _isFieldEditor;
    
    // Editing
    BOOL    _isEditing;
    
    // Undo
    NSEvent *_lastTypingEvent;
    
    // Delegate
    id <SVWebTextAreaDelegate>  _delegate;
}


// Returns whatever is entered into the text box right now. This is what gets used for the "value" binding. You want to use this rather than querying the DOM Element for its -innerHTML directly as it takes into account the presence of any inner tags like a <span class="in">
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSString *string;


// NSTextView-like properties for controlling editing behaviour. Some are stored as part of the DOM, others as ivars. Note that some can only really take effect if properly hooked up to another controller that forwards on proper editing delegation methods from the WebView.
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, setter=setRichText:) BOOL isRichText;
@property(nonatomic, setter=setFieldEditor:) BOOL isFieldEditor;


#pragma mark Editing

@property(nonatomic, readonly, getter=isEditing) BOOL editing;

- (void)didBeginEditingText;
- (void)didChangeText;
// e.g. Movement might be NSReturnTextMovement. Nil if we don't know
- (void)didEndEditingTextWithMovement:(NSNumber *)textMovement;


#pragma mark Undo

// The basic idea is that after every -didChange notification, the change should be pushed down to the model. BUT, if both the change and the previous one was a simple bit of typing, we don't want two separate undo operations recorded. So the undo is coalesced. That is to say, we take advantage of Core Data's behaviour by disabling undo registration during the change, which means the change effectively gets tacked onto the end of the previous one.

@property(nonatomic, readonly) BOOL isCoalescingUndo;
- (void)breakUndoCoalescing;


#pragma mark Delegate
@property(nonatomic, assign) id <SVWebTextAreaDelegate> delegate;

@end


#pragma mark -

#if !defined MAC_OS_X_VERSION_10_6 || MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_6
@protocol NSTextDelegate <NSObject> @end
#endif

@protocol SVWebTextAreaDelegate <NSTextDelegate>
@end

