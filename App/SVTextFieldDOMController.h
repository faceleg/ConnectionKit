//
//  SVWebEditorTextFieldController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Like NSTextField before it, SVWebEditorTextFieldController takes SVTextDOMController and applies it to small chunks of text in the DOM. You can even use NSValueBinding just like a text field. Also, SVWebEditorTextFieldController is designed to be a selectable web editor item, much like how Keynote operates.


#import "SVTextDOMController.h"


@interface SVTextFieldDOMController : SVTextDOMController <NSUserInterfaceValidations>
{
  @private
    NSString    *_HTMLString;
    NSString    *_placeholder;
    
    // Bindings
    NSString        *_uneditedValue;
    BOOL            _isCommittingEditing;
}

#pragma mark Properties

// Returns whatever is entered into the text box right now. This is what gets used for the "value" binding. You want to use this rather than querying the DOM Element for its -innerHTML directly as it takes into account the presence of any inner tags like a <span class="in">
@property(nonatomic, copy) NSString *HTMLString;
@property(nonatomic, copy) NSString *string;


@property(nonatomic, copy) NSString *placeholderString;


@end
