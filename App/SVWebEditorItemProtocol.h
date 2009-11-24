//
//  SVWebEditorItemProtocol.h
//  Sandvox
//
//  Created by Mike on 09/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@protocol SVWebEditorItem <NSObject>

- (DOMElement *)DOMElement; // just returns HTML element
- (BOOL)isEditable; // return YES if the user is able to start selecting content inside the element

@end
