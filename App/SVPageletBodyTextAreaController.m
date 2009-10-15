//
//  SVPageletBodyTextAreaController.m
//  Sandvox
//
//  Created by Mike on 14/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPageletBodyTextAreaController.h"

#import "SVWebContentItem.h"


@implementation SVPageletBodyTextAreaController

#pragma mark Init & Dealloc

- (id)initWithTextArea:(SVWebTextArea *)textArea content:(SVPageletBody *)pageletBody;
{
    [self init];
    
    _pageletBody = [pageletBody retain];
    
    _textArea = [textArea retain];
    [textArea setDelegate:self];
    [self updateEditorItems];
    
    return self;
}

- (void)dealloc
{
    [_textArea setDelegate:nil];
    [_textArea release];
    
    [_pageletBody release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize textArea = _textArea;
@synthesize content = _pageletBody;

@synthesize editorItems = _editorItems;

- (void)updateEditorItems
{
    // Generate an editor item for each -contentItem and for each <img> tag
    DOMNodeList *elements = [[[self textArea] DOMElement] getElementsByTagName:@"img"];
    NSMutableArray *editorItems = [[NSMutableArray alloc] initWithCapacity:[elements length]];
    
    for (int i = 0; i < [elements length]; i++)
    {
        DOMElement *anElement = (DOMElement *)[elements item:i];
        SVWebContentItem *anItem = [[SVWebContentItem alloc] initWithDOMElement:anElement];
        [editorItems addObject:anItem];
        [anItem release];
    }
    
    [_editorItems release]; _editorItems = editorItems;
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

@end
