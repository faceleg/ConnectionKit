//
//  SVWebEditorTextBlock.h
//  Sandvox
//
//  Created by Mike on 06/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVWebEditorText <NSObject>

// Conceptually the same as how NSTextField is informed editing ended by the field editor.
- (void)textDidEndEditing;

// Return YES if you will handle the selector yourself. Return to have the Web Editor do its own thing
- (BOOL)doCommandBySelector:(SEL)selector;

@end
