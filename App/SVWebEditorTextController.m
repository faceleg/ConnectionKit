//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorTextController.h"

#import "DOMNode+Karelia.h"


@interface SVWebEditorTextController ()
- (void)setHTMLString:(NSString *)html updateDOM:(BOOL)updateDOM;
@end


#pragma mark -


@implementation SVWebEditorTextController

#pragma mark Init & Dealloc

- (void)dealloc
{
    [_HTMLString release];
    
        
    [super dealloc];
}

#pragma mark Contents

@synthesize HTMLString = _HTMLString;
- (void)setHTMLString:(NSString *)html
{
    [self setHTMLString:html updateDOM:YES];
}

- (void)setHTMLString:(NSString *)html updateDOM:(BOOL)updateDOM
{
    // Store HTML
    html = [html copy];
    [_HTMLString release]; _HTMLString = html;
    
    // Update DOM to match
    [[self HTMLElement] setInnerHTML:html];
}

- (NSString *)string
{
    NSString *result = [[self HTMLElement] innerText];
    return result;
}

- (void)setString:(NSString *)string
{
    [[self HTMLElement] setInnerText:string];
}

#pragma mark Attributes

- (BOOL)isEditable
{
    BOOL result = [[self HTMLElement] isContentEditable];
    return result;
}

- (void)setEditable:(BOOL)flag
{
    [[self HTMLElement] setContentEditable:(flag ? @"true" : nil)];
}

// Note that it's only a property for controlling editing by the user, it does not affect the existing HTML or stop programmatic editing of the HTML.
@synthesize isRichText = _isRichText;

@synthesize isFieldEditor = _isFieldEditor;

#pragma mark Editing

@synthesize editing = _isEditing;

- (void)didBeginEditingText;
{
    // Mark as editing
    OBPRECONDITION(_isEditing == NO);
    _isEditing = YES;
    
    // Notify delegate/others
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidBeginEditingNotification
                                                        object:self];
}

- (void)didChangeText;
{
    // Notify that editing began if this is the case
    if (![self isEditing])
    {
        [self didBeginEditingText];
    }
    
    
    // Copy HTML across to ourself
    [self setHTMLString:[[self HTMLElement] innerHTML] updateDOM:NO];
    
    
    // Notify delegate/others
    [[NSNotificationCenter defaultCenter] postNotificationName:NSTextDidChangeNotification
                                                        object:self];
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
                
                [node removeAllChildNodes];
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
        [_lastTypingEvent release]; _lastTypingEvent = [NSApp currentEvent];
    }
    
    return result;
}

- (void)webEditorTextWillGainFocus; { }

- (void)webEditorTextDidChange:(NSNotification *)notification;
{
    [self didChangeText];
}

- (void)webEditorTextDidEndEditing:(NSNotification *)notification;
{
    [self didEndEditingTextWithMovement:nil];
}

- (BOOL)doCommandBySelector:(SEL)selector
{
    BOOL result = NO;
    
    if (selector == @selector(insertNewline:) && [self isFieldEditor])
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
	
	return result;
}

#pragma mark Undo

- (BOOL)isCoalescingUndo { return NO; }

- (void)breakUndoCoalescing;
{
}

#pragma mark Delegate

@synthesize delegate = _delegate;
- (void)setDelegate:(id <SVWebTextAreaDelegate>)delegate
{
    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    
    // Dump old delegate
    if ([_delegate respondsToSelector:@selector(textDidChange:)])
    {
        [center removeObserver:_delegate name:NSTextDidChangeNotification object:self];
    }
    if ([_delegate respondsToSelector:@selector(textDidBeginEditing:)])
    {
        [center removeObserver:_delegate name:NSTextDidBeginEditingNotification object:self];
    }
    if ([_delegate respondsToSelector:@selector(textDidEndEditing:)])
    {
        [center removeObserver:_delegate name:NSTextDidEndEditingNotification object:self];
    }
    
    // Store new delegate
    _delegate = delegate;
    
    if ([_delegate respondsToSelector:@selector(textDidChange:)])
    {
        [center addObserver:_delegate selector:@selector(textDidChange:) name:NSTextDidChangeNotification object:self];
    }
    if ([_delegate respondsToSelector:@selector(textDidBeginEditing:)])
    {
        [center addObserver:_delegate selector:@selector(textDidBeginEditing:) name:NSTextDidBeginEditingNotification object:self];
    }
    if ([_delegate respondsToSelector:@selector(textDidEndEditing:)])
    {
        [center addObserver:_delegate selector:@selector(textDidEndEditing:) name:NSTextDidEndEditingNotification object:self];
    }
}

@end


