//
//  SVWebEditorTextBlock.h
//  Sandvox
//
//  Created by Mike on 06/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVWebEditorText <NSObject>

// These MIGHT be received before editing the DOM
- (BOOL)webEditorTextShouldInsertNode:(DOMNode *)node
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;

- (BOOL)webEditorTextShouldInsertText:(NSString *)text
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action;


// Sent when the text gains focus. NOT upon the first change (how NSTextView behaves)
- (void)webEditorTextDidBeginEditing;

// Conceptually the same as how NSTextField is informed editing ended by the field editor. The notification is the same as a WebView will have dished out (could well be nil too)
- (void)webEditorTextDidEndEditing:(NSNotification *)notification;

- (void)webEditorTextDidChange;

// Return YES if you will handle the selector yourself. Return NO to have the Web Editor do its own thing
- (BOOL)webEditorTextDoCommandBySelector:(SEL)action;

- (BOOL)webEditorTextShouldChangeSelectedDOMRange:(DOMRange *)currentRange
                                       toDOMRange:(DOMRange *)proposedRange
                                         affinity:(NSSelectionAffinity)selectionAffinity
                                   stillSelecting:(BOOL)flag;
- (void)webEditorTextDidChangeSelection:(NSNotification *)notification;


#pragma mark Dragging

// Return YES if you want to take over dragging. NO if you want usual dragging behaviour, just influence over operation
- (BOOL)webEditorTextValidateDrop:(id <NSDraggingInfo>)info
                proposedOperation:(NSDragOperation *)proposedOperation;


@end
