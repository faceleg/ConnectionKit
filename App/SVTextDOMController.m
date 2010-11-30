//
//  SVTextBoxController.m
//  Marvel
//
//  Created by Mike on 22/08/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVTextDOMController.h"

#import "SVHTMLTextBlock.h"
#import "SVTitleBox.h"
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
    // If there's an old element stop it being editable 
    [[self textHTMLElement] removeAttribute:@"contentEditable"];
    
    
    // Store new
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
    DOMHTMLElement *element = [self textHTMLElement];
    if (element)
    {
        if (flag)
        {
            [element setContentEditable:@"true"];
        }
        else
        {
            [element removeAttribute:@"contenteditable"];
        }
    }
}

// Note that it's only a property for controlling editing by the user, it does not affect the existing HTML or stop programmatic editing of the HTML.
@synthesize isRichText = _isRichText;

@synthesize isFieldEditor = _isFieldEditor;

@synthesize textBlock = _textBlock;
- (void)setTextBlock:(SVHTMLTextBlock *)textBlock;
{
    textBlock = [textBlock retain];
    [_textBlock release]; _textBlock = textBlock;
    
    [self setEditable:[textBlock isEditable]];
}

#pragma mark Selection

- (DOMRange *)selectedDOMRange;
{
    DOMRange *result = [[self webEditor] selectedDOMRange];
    if (result)
    {
        if (![[result commonAncestorContainer] ks_isDescendantOfElement:[self textHTMLElement]])
        {
            result = nil;
        }
    }
    
    return result;
}

- (void)delete;
{
    SVTitleBox *text = [self representedObject];
    [text setHidden:NSBOOL(YES)];
}

- (SVSelectionBorder *)newSelectionBorder;
{
    SVSelectionBorder *result = [super newSelectionBorder];
    [result setBorderColor:[NSColor grayColor]];
    return result;
}

#pragma mark Resizing

// Right now, no text is resizeable
- (unsigned int)resizingMask; { return 0; }

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
    return YES;
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
        // Bit of a bug in WebKit that means when you delete backwards from start of a text area, the empty paragraph object gets deleted. Fair enough, but WebKit doesn't send you a delegate message asking permission! #71489 #75402
        DOMRange *range = [self selectedDOMRange];
        [range setStart:[self textHTMLElement] offset:0];
        
        NSString *text = [range text];
        if ([text length] == 0)
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
        // Generally don't want to pass up the responder chain. #94455
        result = [self respondsToSelector:selector];
        if (result) [self doCommandBySelector:selector];
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
- (void)webEditorTextDidSetSelectionTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal;
{
    return NSDragOperationNone;
}

- (BOOL)webEditorTextValidateDrop:(id <NSDraggingInfo>)dragInfo;
{
    // Don't allow dragged graphics. It seems I actually do, but not sure why! #92311
    NSArray *types = [[dragInfo draggingPasteboard] types];
    BOOL result = (//![types containsObject:kSVGraphicPboardType] &&
                   ![types containsObject:@"com.karelia.html+graphics"]);
    
    return result;
}

- (void)handleEvent:(DOMEvent *)evt;
{
    
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

#pragma mark Moving

- (void)moveGraphicWithDOMController:(SVDOMController *)graphicController
                          toPosition:(CGPoint)position
                               event:(NSEvent *)event;
{
}

@end


#pragma mark -


@implementation WEKWebEditorItem (SVTextDOMController)

- (SVTextDOMController *)textDOMController; // seeks the closest ancestor text controller
{
    return [[self parentWebEditorItem] textDOMController];
}

@end



