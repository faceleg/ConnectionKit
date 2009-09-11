//
//  SVEditingOverlay+Drawing.m
//  Sandvox
//
//  Created by Mike on 11/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVEditingOverlay+Drawing.h"


@implementation SVEditingOverlayDrawingView

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        _lastScrollPoint = NSZeroPoint;
        
        // Create a layer for drawing
        CALayer *layer = [[CALayer alloc] init];
        [self setLayer:layer];
        [self setWantsLayer:YES];
        [layer release];
        
        // And a scroll layer
        _scrollLayer = [[CAScrollLayer alloc] init];
        [_scrollLayer setFrame:[layer bounds]];
        [_scrollLayer setAutoresizingMask:(kCALayerWidthSizable | kCALayerHeightSizable)];
        [layer addSublayer:_scrollLayer];
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    // Drawing code here.
}

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    
    [self scrollToPoint:_lastScrollPoint];
}

@synthesize scrollLayer = _scrollLayer;

- (void)scrollToPoint:(NSPoint)aPoint
{
    CAScrollLayer *scrollLayer = [self scrollLayer];
    
    // because the only way to do flipped geometry on 10.5 is manually :(
    CGPoint scrollPoint;
    scrollPoint.x = aPoint.x;
    scrollPoint.y = -([scrollLayer bounds].size.height + aPoint.y); 
    
    [scrollLayer scrollToPoint:scrollPoint];
    
    // Store it for when resizing
    _lastScrollPoint = aPoint;
}

@end
