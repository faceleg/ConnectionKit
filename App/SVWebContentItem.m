//
//  SVWebContentItem.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentItem.h"


@implementation SVWebContentItem

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
    
    _nodeTracker = [[SVDOMNodeBoundsTracker alloc] initWithDOMNode:element];
    [_nodeTracker setDelegate:self];
    
    return self;
}

- (id)initWithDOMElement:(DOMElement *)element pagelet:(KTPagelet *)pagelet;
{
    self = [self initWithDOMElement:element];
    
    _pagelet = [pagelet retain];
    
    return self;
}

- (void)dealloc
{
    [_nodeTracker stopTracking];
    [_nodeTracker setDelegate:nil];
    [_nodeTracker release];
    
    [_pagelet release];
    [_DOMElement release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize DOMElement = _DOMElement;

@synthesize pagelet = _pagelet;

#pragma mark Editing Overlay Item

- (void)trackerDidDetectDOMNodeBoundsChange:(NSNotification *)notification;
{
    
}

@end
