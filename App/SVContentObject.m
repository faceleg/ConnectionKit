//
//  SVWebContentItem.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVContentObject.h"


@implementation SVContentObject

#pragma mark Init & Dealloc

- (id)init
{
    return [self initWithDOMElement:nil];
}

- (id)initWithDOMElement:(DOMHTMLElement *)element;
{
    OBPRECONDITION(element);
    
    self = [super init];
    
    _element = [element retain];
    
    _nodeTracker = [[SVDOMNodeBoundsTracker alloc] initWithDOMNode:element];
    [_nodeTracker setDelegate:self];
    
    return self;
}

- (void)dealloc
{
    [_nodeTracker stopTracking];
    [_nodeTracker setDelegate:nil];
    [_nodeTracker release];
    
    [_element release];
    
    [super dealloc];
}

#pragma mark DOM

@synthesize DOMElement = _element;

#pragma mark Editing Overlay Item

- (NSRect)rect
{
    DOMElement *element = [self DOMElement];
    NSRect elementRect = [element boundingBox];
    WebFrame *frame = [[element ownerDocument] webFrame];
    NSView *elementView = [[frame frameView] documentView];
    WebView *webView = [frame webView];
    
    NSRect result = [webView convertRect:elementRect fromView:elementView];
    return result;
}

- (void)trackerDidDetectDOMNodeBoundsChange:(NSNotification *)notification;
{
    
}

@end
