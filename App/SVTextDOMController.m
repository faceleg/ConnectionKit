//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"

#import "SVHTMLTextBlock.h"
#import "WebEditingKit.h"
#import "SVWebEditorViewController.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"


@interface SVTextDOMController ()

#pragma mark Undo
- (void)willMakeTextChangeSuitableForUndoCoalescing;

@property(nonatomic, readonly) NSUInteger undoCoalescingActionIdentifier;
@property(nonatomic, copy, readonly) DOMRange *undoCoalescingSelectedDOMRange;
- (void)setUndoCoalescingActionIdentifier:(NSUInteger)identifer selectedDOMRange:(DOMRange *)selection;

@end


#pragma mark -


@implementation SVTextDOMController

#pragma mark Init & Dealloc

- (id)init
{
    self = [super init];
    
    _editable = YES;    // default
    
    // Undo
    _undoCoalescingActionIdentifier = NSNotFound;
    
    return self;
}

- (void)dealloc
{
    [_textElement release];
    [_textBlock release];
    
    [super dealloc];
}

#pragma mark DOM Node

- (DOMHTMLElement *)textHTMLElement
{
    [self HTMLElement]; // make sure it's loaded
    return _textElement;
}

- (void)setTextHTMLElement:(DOMHTMLElement *)element;
{
    [element retain];
    [_textElement release]; _textElement = element;
    
    [self setEditable:[self isEditable]];
}

#pragma mark Hierarchy

- (SVTextDOMController *)textDOMController; { return self; }

#pragma mark Attributes

- (BOOL)isEditable
{
    return _editable;
}

- (void)setEditable:(BOOL)flag
{
    _editable = flag;
    
    // Annoyingly, calling -setContentEditable:nil or similar does not remove the attribute
    if (flag)
    {
        [[self textHTMLElement] setContentEditable:@"true"];
    }
    else
    {
        [[self textHTMLElement] removeAttribute:@"contentEditable"];
    }
}

// Note that it's only a property for controlling editing by the user, it does not affect the existing HTML or stop programmatic editing of the HTML.
@synthesize isRichText = _isRichText;

@synthesize isFieldEditor = _isFieldEditor;

@synthesize textBlock = _textBlock;

#pragma mark Editing

- (void)webEditorTextDidChange;
{
    // Wait until after -didChangeText so subclass has done its work
    WEKWebEditorView *webEditor = [self webEditor];
    NSUndoManager *undoManager = [webEditor undoManager];
    
    if (_nextChangeIsSuitableForUndoCoalescing)
    {
        _nextChangeIsSuitableForUndoCoalescing = NO;
        
        // Process the change so that nothing is scheduled to be added to the undo manager        
        if ([undoManager respondsToSelector:@selector(lastRegisteredActionIdentifier)])
        {
            // Push through any pending changes. (MOCs observe this notification and call -processPendingChanges)
            [[NSNotificationCenter defaultCenter]
             postNotificationName:NSUndoManagerCheckpointNotification
             object:undoManager];
            
            // Record the action identifier and DOM selection so we know whether to coalesce the next change
            [self setUndoCoalescingActionIdentifier:[undoManager lastRegisteredActionIdentifier]
                                   selectedDOMRange:[[webEditor selectedDOMRange] copy]];
        }
    }
    
    
    // Tidy up
    if (_isCoalescingUndo)
    {
        [undoManager enableUndoRegistration];
        _isCoalescingUndo = NO;
    }
}

- (void)didEndEditingTextWithMovement:(NSNumber *)textMovement;
{
    // Notify delegate/others
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidEndEditingNotification
                                                        object:self];
    
    
    // Like NSTextField, we want the return key to select the field's contents
    if ([self isFieldEditor] && [textMovement intValue] == NSReturnTextMovement)
    {
        [[[self HTMLElement] documentView] selectAll:self];
    }
}

#pragma mark SVWebEditorText

- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    BOOL result = YES;
    return YES;
    
    
    
    // We don't want to allow drops of anything other than basic text styling. How to implement this is tricky. The best I can think of is a whitelist of allowed elements. Anything outside the whitelist we will attempt to rescue a plain text version from the pasteboard to use instead
    NSSet *whitelist = [NSSet setWithObjects:@"SPAN", @"B", @"I", nil];
    if ([node containsElementWithTagNameNotInSet:whitelist])
    {
        result = NO;
        
        NSPasteboard *pasteboard = [[self webEditor] insertionPasteboard];
        if ([[pasteboard types] containsObject:NSStringPboardType])
        {
            NSString *text = [pasteboard stringForType:NSStringPboardType];
            if (text)
            {
                result = YES;
                
                [[node mutableChildDOMNodes] removeAllObjects];
                DOMText *textNode = [[node ownerDocument] createTextNode:text];
                [node appendChild:textNode];
            }
        }
    }
    
    return result;
}

- (BOOL)webEditorTextShouldInsertText:(NSString *)text
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;
{
    BOOL result = YES;
    
    // Note the event for the benefit of -textDidChange:
    if (action == WebViewInsertActionTyped)
    {
        [self willMakeTextChangeSuitableForUndoCoalescing];
    }
    
    return result;
}

- (void)webEditorTextDidBeginEditing; { }

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
{
    [self didEndEditingTextWithMovement:nil];
}

- (BOOL)webEditorTextDoCommandBySelector:(SEL)selector
{
    BOOL result = NO;
    
    
    if (selector == @selector(deleteBackward:) ||
        selector == @selector(deleteWordBackward:) ||
        selector == @selector(deleteToBeginningOfLine:) ||
        selector == @selector(deleteBackwardByDecomposingPreviousCharacter:))
    {
        // Bit of a bug in WebKit that means when you delete backwards in an empty text area, the empty paragraph object gets deleted. Fair enough, but WebKit doesn't send you a delegate message asking permission! #71489 #75402
        NSString *text = [[self textHTMLElement] innerText];
        if (![text length] || [text isEqualToString:@"\n"])
        {
            return YES;
        }
    }
    
    
    if (selector == @selector(deleteBackward:))
    {
        // A sequence of |type, backspace, type| should be coalesced. But if deleting a non-collapsed selection, that's not applicable
        WebView *webView = [[[[self HTMLElement] ownerDocument] webFrame] webView];
        if ([[webView selectedDOMRange] collapsed])
        {
            [self willMakeTextChangeSuitableForUndoCoalescing];
        }
    }
    else if (selector == @selector(insertNewline:) && [self isFieldEditor])
	{
		// Return key ends editing
        [self didEndEditingTextWithMovement:[NSNumber numberWithInt:NSReturnTextMovement]];
		result = YES;
	}
    else if (selector == @selector(insertNewlineIgnoringFieldEditor:))
	{
		// When the user hits option-return insert a line break.
        [[[self HTMLElement] documentView] insertLineBreak:self];
		result = YES;
	}
    else
    {
        result = [self tryToPerform:selector with:nil];
    }
	
	return result;
}

- (BOOL)webEditorTextShouldChangeSelectedDOMRange:(DOMRange *)currentRange
                                       toDOMRange:(DOMRange *)proposedRange
                                         affinity:(NSSelectionAffinity)selectionAffinity
                                   stillSelecting:(BOOL)flag;
{
    return YES;
}

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification; { }

#pragma mark Pasteboard / Drag

// Up to subclasses to add custom types
- (void)addSelectionTypesToPasteboard:(NSPasteboard *)pasteboard; { }

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    return NSDragOperationNone;
}

#pragma mark Undo

- (void)breakUndoCoalescing;
{
    [self setUndoCoalescingActionIdentifier:NSNotFound selectedDOMRange:nil];
}

- (void)willMakeTextChangeSuitableForUndoCoalescing;
{
    // At this point we know the TYPE of change will be suitable for undo coalescing, but not whether the specific event is.
    // In practice this means that we want to ignore the change if the insertion point has been moved
    WEKWebEditorView *webEditor = [self webEditor];
    if (![[webEditor selectedDOMRange] isEqualToDOMRange:[self undoCoalescingSelectedDOMRange]])
    {
        [self breakUndoCoalescing];
    }
    
    
    // Store the event so we can identify the change after it happens
    _nextChangeIsSuitableForUndoCoalescing = YES;
    OBASSERT(!_isCoalescingUndo);
    
    
    // Does it put us into coalescing mode?
    NSUndoManager *undoManager = [webEditor undoManager];
    if ([undoManager respondsToSelector:@selector(lastRegisteredActionIdentifier)])
    {
        if ([undoManager lastRegisteredActionIdentifier] == [self undoCoalescingActionIdentifier])
        {
            // Go for coalescing. Push through any pending changes. (MOCs observe this notification and call -processPendingChanges)
            [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification object:undoManager];
            
            [undoManager disableUndoRegistration];
            _isCoalescingUndo = YES;
        }
    }
}

@synthesize undoCoalescingActionIdentifier = _undoCoalescingActionIdentifier;
@synthesize undoCoalescingSelectedDOMRange = _undoCoalescingSelection;
- (void)setUndoCoalescingActionIdentifier:(NSUInteger)identifier selectedDOMRange:(DOMRange *)selection;
{
    _undoCoalescingActionIdentifier = identifier;
    
    selection = [selection copy];
    [_undoCoalescingSelection release]; _undoCoalescingSelection = selection;
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVTextDOMController)

- (SVTextDOMController *)textDOMController; // seeks the closest ancestor text controller
{
    return [[self parentWebEditorItem] textDOMController];
}

@end



