//
//  SVWebEditorItem.h
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//
//  Concrete implementation of the SVWebEditorItem protocol


#import <Cocoa/Cocoa.h>
#import "SVWebEditorItemProtocol.h"


@interface SVWebEditorItem : NSObject <SVWebEditorItem>
{
  @private
    DOMElement  *_DOMElement;
}

- (id)initWithDOMElement:(DOMElement *)element;
@property(nonatomic, retain, readonly) DOMElement *DOMElement;

@end
