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
    
    NSArray *_editorItems;
    
    NSMutableArray  *_paragraphControllers;
}

- (id)initWithTextArea:(SVWebTextArea *)textArea content:(SVPageletBody *)pageletBody;

@property(nonatomic, retain, readonly) SVWebTextArea *textArea;
@property(nonatomic, retain, readonly) SVPageletBody *content;

// There should be one item per content object. Update by observing model
@property(nonatomic, readonly) NSArray *editorItems;
- (void)updateEditorItems;

@end
