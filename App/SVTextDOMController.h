//
//  SVTextDOMController.h
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An HTML element controller specialised to deal with text, generally of the editable variety. In a way, a bit like how NSText is too abstract to do anything on its own, but central to the operation of NSTextView and NSTextField. So check out the subclasses for more advanced stuff.


#import "SVDOMController.h"
#import "SVWebEditorTextProtocol.h"
#import "KSKeyValueBinding.h"


@class SVHTMLTextBlock;


@interface SVTextDOMController : SVDOMController <SVWebEditorText>
{
  @private
    DOMHTMLElement  *_textElement;
    
    SVHTMLTextBlock *_textBlock;
    
    BOOL        _isRichText;
    BOOL        _isFieldEditor;
    
    // Editing
    BOOL    _isEditing;
    
    // Undo
    BOOL        _isCoalescingUndo;
    BOOL        _nextChangeIsSuitableForUndoCoalescing;
    NSUInteger  _undoCoalescingActionIdentifier;
    DOMRange    *_undoCoalescingSelection;
}


#pragma mark DOM Node
@property(nonatomic, retain) DOMHTMLElement *textHTMLElement;


#pragma mark Properties

// NSTextView-like properties for controlling editing behaviour. Some are stored as part of the DOM, others as ivars. Note that some can only really take effect if properly hooked up to another controller that forwards on proper editing delegation methods from the WebView.
@property(nonatomic, getter=isEditable) BOOL editable;
@property(nonatomic, setter=setRichText:) BOOL isRichText;
@property(nonatomic, setter=setFieldEditor:) BOOL isFieldEditor;

@property(nonatomic, retain) SVHTMLTextBlock *textBlock;


#pragma mark Editing

@property(nonatomic, readonly, getter=isEditing) BOOL editing;

// There has been a change somewhere in the corresponding WebView (there's no direct API for querying whereabouts the change was). Subclasses should implement to check if they know of a change being made and act accordingly.
- (void)webViewDidChange;

// e.g. Movement might be NSReturnTextMovement. Nil if we don't know
- (void)didEndEditingTextWithMovement:(NSNumber *)textMovement;


#pragma mark Undo

// The basic idea is that after every -didChange notification, the change should be pushed down to the model. BUT, if both the change and the previous one was a simple bit of typing, we don't want two separate undo operations recorded. So the undo is coalesced. That is to say, we take advantage of Core Data's behaviour by disabling undo registration during the change, which means the change effectively gets tacked onto the end of the previous one.

- (void)breakUndoCoalescing;

//  To implement this is actually a bit painful. We need some cooperation from subclasses and other infrastructure, which are:
//  
//      -   reference to the MOC so as to process changes when suits us, and access from there to undo manager
//
//      -   cooperation of the undo manager. NSTextView does its undo coalescing by inspecting the undo stack to see if the last op registered was by itself. We don't have that access, but can request that somebody else (*cough* the document) supply a suitable NSUndoManager subclass which gives an identifier for the item on top of the stack.


@end



#pragma mark -


// See comments above for why this is necessary. You MUST supply a NSUndoManager subclass that implements this API properly for undo coalescing to work. Uses unsigned so that it can *never* reach NSNotFound, but will roll back round again instead
@interface NSUndoManager (SVWebEditorTextControllerUndoCoalescing)
- (unsigned short)lastRegisteredActionIdentifier;
@end


@interface SVWebEditorTextControllerUndoManager : NSUndoManager
{
    unsigned short _lastRegisteredActionIdentifier;
}
@end

