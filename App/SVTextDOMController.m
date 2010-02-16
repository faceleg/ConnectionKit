//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"

#import "SVWebEditorView.h"
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
    
    // Editing
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webEditorDidChange:)
                                                 name:kSVWebEditorViewDidChangeNotification
                                               object:nil];
    
    
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kSVWebEditorViewDidChangeNotification
                                                  object:nil];
    
    [_textElement release];
    
    [super dealloc];
}

#pragma mark DOM Node

@synthesize textHTMLElement = _textElement;
- (DOMHTMLElement *)textHTMLElement
{
    [self HTMLElement]; // make sure it's loaded
    return _textElement;
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

#pragma mark Editing

@synthesize editing = _isEditing;

- (void)webViewDidChange; { }

- (void)didChangeText;  // Call this once your subclass has determined a change really took place
{
    [[self webEditorViewController] textDOMControllerDidChangeText:self];
}

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
                          givenAction:(WebViewInsertAction)action
                           pasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = YES;
    return YES;
    
    
    
    // We don't want to allow drops of anything other than basic text styling. How to implement this is tricky. The best I can think of is a whitelist of allowed elements. Anything outside the whitelist we will attempt to rescue a plain text version from the pasteboard to use instead
    NSSet *whitelist = [NSSet setWithObjects:@"SPAN", @"B", @"I", nil];
    if ([node containsElementWithTagNameNotInSet:whitelist])
    {
        result = NO;
        
        if ([[pasteboard types] containsObject:NSStringPboardType])
        {
            NSString *text = [pasteboard stringForType:NSStringPboardType];
            if (text)
            {
                result = YES;
                
                [[node mutableChildNodesArray] removeAllObjects];
                DOMText *textNode = [[node ownerDocument] createTextNode:text];
                [node appendChild:textNode];
            }
        }
    }
    
    return result;
}

- (BOOL)webEditorTextShouldInsertText:(NSString *)text
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action
                           pasteboard:(NSPasteboard *)pasteboard;
{
    BOOL result = YES;
    
    // Note the event for the benefit of -textDidChange:
    if (action == WebViewInsertActionTyped)
    {
        [self willMakeTextChangeSuitableForUndoCoalescing];
    }
    
    return result;
}

- (void)webEditorTextWillGainFocus;
{
    // A bit crude, but we don't want WebKit's usual focus ring
    [[[self HTMLElement] style] setProperty:@"outline" value:@"none" priority:@""];
}

- (void)webEditorDidChange:(NSNotification *)notification;
{
    SVWebEditorView *webEditor = [self webEditor];
    if ([notification object] != webEditor) return;
    
    
    _isCoalescingUndo = NO;
    NSUndoManager *undoManager = [webEditor undoManager];
    
    
    // So was this a typing change?
    BOOL isTypingChange = [_inProgressEventSuitableForUndoCoalescing isEqual:[NSApp currentEvent]];
    [_inProgressEventSuitableForUndoCoalescing release]; _inProgressEventSuitableForUndoCoalescing = nil; // reset event monitor
    
    if (isTypingChange)
    {
        // Does it put us into coalescing mode?
        if ([undoManager respondsToSelector:@selector(lastRegisteredActionIdentifier)])
        {
            if ([undoManager lastRegisteredActionIdentifier] == [self undoCoalescingActionIdentifier])
            {
                // Go for coalescing
                _isCoalescingUndo = YES;
                
                // Push through any pending changes. (MOCs observe this notification and call -processPendingChanges)
                [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification object:undoManager];
                [undoManager disableUndoRegistration];
            }
        }
    }
    
    
    // Handle the edit
    [self webViewDidChange];
    
    
    // Wait until after -didChangeText so subclass has done its work
    if (isTypingChange)
    {
        // Process the change so that nothing is scheduled to be added to the undo manager        
        if ([undoManager respondsToSelector:@selector(lastRegisteredActionIdentifier)])
        {
            // Push through any pending changes. (MOCs observe this notification and call -processPendingChanges)
            [[NSNotificationCenter defaultCenter]
             postNotificationName:NSUndoManagerCheckpointNotification
             object:undoManager];
            
            if (_isCoalescingUndo) [undoManager enableUndoRegistration];
            
            // Record the action identifier and DOM selection so we know whether to coalesce the next change
            [self setUndoCoalescingActionIdentifier:[undoManager lastRegisteredActionIdentifier]
                                   selectedDOMRange:[[webEditor selectedDOMRange] copy]];
        }
    }
    
    
    // Tidy up
    _isCoalescingUndo = NO;
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

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification; { }

#pragma mark Undo

- (void)breakUndoCoalescing;
{
    [self setUndoCoalescingActionIdentifier:NSNotFound selectedDOMRange:nil];
}

- (void)willMakeTextChangeSuitableForUndoCoalescing;
{
    // At this point we know the TYPE of change will be suitable for undo calescing, but not whether the specific event is.
    // In practice this means that we want to ignore the change if the insertion point has been moved
    WebView *webView = [[[[self HTMLElement] ownerDocument] webFrame] webView];
    if (![[webView selectedDOMRange] isEqualToDOMRange:[self undoCoalescingSelectedDOMRange]])
    {
        [self breakUndoCoalescing];
    }
    
    // Store the event so we can identify the change after it happens
    [_inProgressEventSuitableForUndoCoalescing release]; _inProgressEventSuitableForUndoCoalescing = [[NSApp currentEvent] retain];
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


@implementation SVWebEditorTextControllerUndoManager

- (NSUInteger)lastRegisteredActionIdentifier;
{
    return _lastRegisteredActionIdentifier;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    _lastRegisteredActionIdentifier++;
    return [super forwardInvocation:anInvocation];
}

- (void)registerUndoWithTarget:(id)target selector:(SEL)aSelector object:(id)anObject
{
    _lastRegisteredActionIdentifier++;
    return [super registerUndoWithTarget:target selector:aSelector object:anObject];
}

- (void)undoNestedGroup
{
    _lastRegisteredActionIdentifier++;
    return [super undoNestedGroup];
}

- (void)redo
{
    _lastRegisteredActionIdentifier++;
    return [super redo];
}

@end



