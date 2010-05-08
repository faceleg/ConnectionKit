//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"

#import "SVHTMLTextBlock.h"
#import "WEKWebEditorView.h"
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

@synthesize textHTMLElement = _textElement;
- (DOMHTMLElement *)textHTMLElement
{
    [self HTMLElement]; // make sure it's loaded
    return _textElement;
}

- (void)loadHTMLElementFromDocument:(DOMDocument *)document
{
    DOMElement *element = [document getElementById:[[self textBlock] DOMNodeID]];
    [self setHTMLElement:(DOMHTMLElement *)element];
    
    [self setEditable:[[self textBlock] isEditable]];
}

#pragma mark Attributes

- (BOOL)isEditable
{
    BOOL result = [[self HTMLElement] isContentEditable];
    return result;
}

- (void)setEditable:(BOOL)flag
{
    // Annoyingly, calling -setContentEditable:nil or similar does not remove the attribute
    if (flag)
    {
        [[self HTMLElement] setContentEditable:@"true"];
    }
    else
    {
        [[self HTMLElement] removeAttribute:@"contentEditable"];
    }
}

// Note that it's only a property for controlling editing by the user, it does not affect the existing HTML or stop programmatic editing of the HTML.
@synthesize isRichText = _isRichText;

@synthesize isFieldEditor = _isFieldEditor;

@synthesize textBlock = _textBlock;

#pragma mark Editing

@synthesize editing = _isEditing;

- (void)webEditorTextDidChange; { }

- (void)didEndEditingTextWithMovement:(NSNumber *)textMovement;
{
    // Notify delegate/others
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidEndEditingNotification
                                                        object:self];
    
    
    _isEditing = NO;
    
    
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

- (void)webEditorDidChange:(NSNotification *)notification;
{
    WEKWebEditorView *webEditor = [self webEditor];
    if ([notification object] != webEditor) return;
    
    
    // Handle the edit
    [self webEditorTextDidChange];
    
    
    // Wait until after -didChangeText so subclass has done its work
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

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
{
    [self didEndEditingTextWithMovement:nil];
}

- (BOOL)webEditorTextDoCommandBySelector:(SEL)selector
{
    BOOL result = NO;
    
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

#pragma mark Pasteboard

// Up to subclasses to add custom types
- (void)addSelectionTypesToPasteboard:(NSPasteboard *)pasteboard; { }

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

#pragma mark Dragging

- (BOOL)webEditorTextValidateDrop:(id <NSDraggingInfo>)info
                proposedOperation:(NSDragOperation *)proposedOperation;
{
    // I wish I knew why I wrote this code in the first place! What is it for? – Mike
    if ([info draggingSource] == [self webEditor])
    {
        *proposedOperation = NSDragOperationNone;
    }
    
    return NO;
}

@end



