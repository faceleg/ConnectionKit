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
                          givenAction:(WebViewInsertAction)action
                           pasteboard:(NSPasteboard *)pasteboard;

- (BOOL)webEditorTextShouldInsertText:(NSString *)text
                    replacingDOMRange:(DOMRange *)range
                          givenAction:(WebViewInsertAction)action
                           pasteboard:(NSPasteboard *)pasteboard;


// Informs the receiver that it is about to gain focus.
- (void)webEditorTextWillGainFocus;

// Conceptually the same as how NSTextField is informed editing ended by the field editor. The notification is the same as a WebView will have dished out (could well be nil too)
- (void)webEditorTextDidEndEditing:(NSNotification *)notification;

// Return YES if you will handle the selector yourself. Return NO to have the Web Editor do its own thing
- (BOOL)webEditorTextDoCommandBySelector:(SEL)selector;

- (void)webEditorTextDidChangeSelection:(NSNotification *)notification;

@end
