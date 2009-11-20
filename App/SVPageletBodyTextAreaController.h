//
//  SVPageletBodyTextAreaController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVWebTextArea.h"


@class SVBodyElement;
@protocol SVElementController <NSObject>
- (SVBodyElement *)bodyElement;
- (DOMHTMLElement *)HTMLElement;
@end


@class SVPageletBody;


@interface SVPageletBodyTextAreaController : NSObject <SVWebTextAreaDelegate, DOMEventListener>
{
    SVWebTextArea   *_textArea;
    SVPageletBody   *_pageletBody;
        
    NSMutableArray  *_elementControllers;
}

- (id)initWithTextArea:(SVWebTextArea *)textArea content:(SVPageletBody *)pageletBody;

@property(nonatomic, retain, readonly) SVWebTextArea *textArea;
@property(nonatomic, retain, readonly) SVPageletBody *content;

- (id <SVElementController>)controllerForHTMLElement:(DOMHTMLElement *)element;

@end


#import "SVWebContentItem.h"
@interface SVWebContentItem (SVElementController) <SVElementController>
@end