//
//  SVWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
//  Concrete implementation of the SVWebEditorItem protocol


#import "SVHTMLElementController.h"
#import "SVWebEditorItemProtocol.h"


@interface SVWebEditorItem : SVHTMLElementController <SVWebEditorItem>

@property(nonatomic, retain, readonly) DOMElement *DOMElement;

- (BOOL)isEditable;

@end
