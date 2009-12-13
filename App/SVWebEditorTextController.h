//
//  SVWebEditorTextController.h
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An HTML element controller specialised to deal with text, generally of the editable variety. In a way, a bit like how NSText is too abstract to do anything on its own, but central to the operation of NSTextView and NSTextField. So check out the subclasses for more advanced stuff.


#import "KSDOMController.h"
#import "SVWebEditorTextProtocol.h"
#import "KSKeyValueBinding.h"


@class SVPagelet;


@interface SVWebEditorTextController : KSDOMController <SVWebEditorText, KSEditor>
{
  @private
    NSString    *_HTMLString;
    BOOL        _isRichText;
    BOOL        _isFieldEditor;
    
    // Editing
    BOOL    _isEditing;
    
    // Undo
    BOOL        _isCoalescingUndo;
    NSEvent     *_inProgressEventSuitableForUndoCoalescing;
    NSUInteger  _undoCoalescingActionIdentifier;
    DOMRange    *_undoCoalescingSelection;
}


#pragma mark Properties

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


#pragma mark Graphics
// The default implementation just returns NO since it doesn't know how to handle pagelets. Subclasses should override to return YES and handle the pagelet if they can.
- (BOOL)insertPagelet:(SVPagelet *)pagelet;


#pragma mark Undo

// The basic idea is that after every -didChange notification, the change should be pushed down to the model. BUT, if both the change and the previous one was a simple bit of typing, we don't want two separate undo operations recorded. So the undo is coalesced. That is to say, we take advantage of Core Data's behaviour by disabling undo registration during the change, which means the change effectively gets tacked onto the end of the previous one.

- (void)breakUndoCoalescing;

//  To implement this is actually a bit painful. We need some cooperation from subclasses and other infrastructure, which are:
//  
//      -   reference to the MOC so as to process changes when suits us, and access from there to undo manager
//
//      -   cooperation of the undo manager. NSTextView does its undo coalescing by inspecting the undo stack to see if the last op registered was by itself. We don't have that access, but can request that somebody else (*cough* the document) supply a suitable NSUndoManager subclass which gives an identifer for the item on top of the stack.

- (NSManagedObjectContext *)managedObjectContext;   // subclasses should provide one


@end



#pragma mark -


// See comments above for why this is necessary. You MUST supply a NSUndoManager subclass that implements this API properly for undo coalescing to work.
@interface NSUndoManager (SVWebEditorTextControllerUndoCoalescing)
- (NSUInteger)lastRegisteredActionIdentifier;
@end


@interface SVWebEditorTextControllerUndoManager : NSUndoManager
{
    NSUInteger  _lastRegisteredActionIdentifier;
}
- (NSUInteger)lastRegisteredActionIdentifier;
@end

