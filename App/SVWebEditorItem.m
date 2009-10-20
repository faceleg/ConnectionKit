//
//  SVWebEditorItem.m
//  Sandvox
//
//  Created by Mike on 24/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorItem.h"


@implementation SVWebEditorItem

#pragma mark Init & Dealloc

- (id)init
{
    return [self initWithDOMElement:nil];
}

- (id)initWithDOMElement:(DOMHTMLElement *)element;
{
    OBPRECONDITION(element);
    
    self = [super init];
    
    _DOMElement = [element retain];
    
    return self;
}

- (void)dealloc
{
    [_DOMElement release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize DOMElement = _DOMElement;

- (BOOL)isEditable { return NO; }

@end
