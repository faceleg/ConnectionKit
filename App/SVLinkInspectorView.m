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
    _dropping = YES;
    [self setNeedsDisplay:YES];
    
    return NSDragOperationLink;
}

- (void)draggingExited:(id <NSDraggingInfo>)sender;
{
    _dropping = NO;
    [self setNeedsDisplay:YES];
}

- (void)draggingEnded:(id <NSDraggingInfo>)sender;
{
    _dropping = NO;
    [self setNeedsDisplay:YES];
}

@end
