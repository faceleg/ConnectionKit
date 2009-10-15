//
//  SVPageletBodyTextAreaController.h
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVWebTextArea.h"


@class SVPageletBody;


@interface SVPageletBodyTextAreaController : NSObject <SVWebTextAreaDelegate>
{
    SVWebTextArea   *_textArea;
    SVPageletBody   *_pageletBody;
}

- (id)initWithTextArea:(SVWebTextArea *)textArea content:(SVPageletBody *)pageletBody;

@property(nonatomic, readonly) NSArray *editorItems;

@end
