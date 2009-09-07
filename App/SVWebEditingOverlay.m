//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditingOverlay.h"
#import "SVSelectionBorder.h"
#import <QuartzCore/QuartzCore.h>   // for CoreAnimation – why isn't it pulled in by default?


@implementation SVWebEditingOverlay

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // ivars
    _selection = [[NSMutableArray alloc] init];
    
    
    // Create a CALayer for drawing
    CALayer *layer = [[CALayer alloc] init];
    [self setLayer:layer];
    [self setWantsLayer:YES];
    
    
    return self;
}

- (void)dealloc
{
    [_selection release];
    
    [super dealloc];
}

#pragma mark Basic Accessors

@synthesize dataSource = _dataSource;

#pragma mark Selection

@synthesize selectedBorders = _selection;

- (void)insertObject:(SVSelectionBorder *)border inSelectedBordersAtIndex:(NSUInteger)index;
{
    [_selection insertObject:border atIndex:index];
    [[self layer] addSublayer:border];
}

- (void)removeObjectFromSelectedBordersAtIndex:(NSUInteger)index;
{
    // Remove layer
    SVSelectionBorder *border = [_selection objectAtIndex:index];
    [border removeFromSuperlayer];
    
    [_selection removeObjectAtIndex:index];
}

#pragma mark Event Handling

- (NSView *)hitTest:(NSPoint)aPoint
{
    // Does the point correspond to one of the selections? If so, target that.
    CGPoint point = NSPointToCGPoint([self convertPointFromBase:aPoint]);
    
    for (CALayer *aLayer in [self selectedBorders]) // should we actually be running this in reverse?
    {
        CALayer *hitLayer = [aLayer hitTest:point];
        if (hitLayer)
        {
            return self;
        }
    }
    
    
    // Otherwise let our datasource decide.
    NSView *result = [[self dataSource] editingOverlay:self hitTest:aPoint];
    if (!result) result = [super hitTest:aPoint];
    
    return result;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    // Need to swallow mouse down events to stop them reaching the webview
}

#pragma mark Tracking Areas

- (void)updateTrackingAreas
{
    // Ask each selection border to manage its own tracking area
    [[self layer] updateTrackingAreasInView:self];
    
    [super updateTrackingAreas];
}

- (void)cursorUpdate:(NSEvent *)event
{
    [[NSCursor openHandCursor] set];
}

@end

