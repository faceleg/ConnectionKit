//
//  SVWebEditorTextBlock.h
//  Sandvox
//
//  Created by Mike on 06/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVWebEditorTextBlock <NSObject>

// Received when focus in the Web Editor moves away from an edited text block, ending editing. Implementors should use this as an opportunity to persist the text
- (void)didEndEditing;

// Return YES if you will handle the selector yourself. Return to have the Web Editor do its own thing
- (BOOL)doCommandBySelector:(SEL)selector;

@end
