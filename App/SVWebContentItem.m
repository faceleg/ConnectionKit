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
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize pagelet = _pagelet;

#pragma mark Editing Overlay Item

- (void)trackerDidDetectDOMNodeBoundsChange:(NSNotification *)notification;
{
    
}

@end
