//
//  SVLinkInspectorView.m
//  Sandvox
//
//  Created by Mike on 24/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVLinkInspectorView.h"

#import "NSColor+Karelia.h"


@implementation SVLinkInspectorView

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

@synthesize draggingDestinationDelegate = _delegate;

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
    
    if (_dropping)
    {
        [[NSColor aquaColor] set];
        NSFrameRectWithWidth([self bounds], 2.0f);
    }
}

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)sender;
{
    NSDragOperation result = [[self draggingDestinationDelegate] draggingEntered:sender];
    
    if (result)
    {
        _dropping = YES;
        [self setNeedsDisplay:YES];
    }
    
    return result;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    NSObject *delegate = [self draggingDestinationDelegate];
    if ([delegate respondsToSelector:_cmd])
    {
        [delegate performSelector:_cmd withObject:sender];
    }
    
    _dropping = NO;
    [self setNeedsDisplay:YES];
}

- (BOOL)performDragOperation:(id <NSDraggingInfo>)sender;
{
    NSObject *delegate = [self draggingDestinationDelegate];
    if ([delegate respondsToSelector:_cmd])
    {
        return [delegate performDragOperation:sender];
    }
    
    return NO;
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender;
{
    NSObject *delegate = [self draggingDestinationDelegate];
    if ([delegate respondsToSelector:_cmd])
    {
        [delegate performSelector:_cmd withObject:sender];
    }
    
    _dropping = NO;
    [self setNeedsDisplay:YES];
}

@end
