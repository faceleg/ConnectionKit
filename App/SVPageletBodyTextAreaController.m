//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBodyTextAreaController.h"


@implementation SVPageletBodyTextAreaController

- (id)initWithTextArea:(SVWebTextArea *)textArea content:(SVPageletBody *)pageletBody;
{
    [self init];
    
    _textArea = [textArea retain];
    _pageletBody = [pageletBody retain];
    [textArea setDelegate:self];
    
    return self;
}

- (void)dealloc
{
    [_textArea setDelegate:nil];
    [_textArea release];
    [_pageletBody release];
    
    [super dealloc];
}

- (NSArray *)editorItems { return nil; }

@end
