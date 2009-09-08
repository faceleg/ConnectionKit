//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditingOverlay.h"
#import "SVSelectionBorder.h"
#import "SVSelectionHandleLayer.h"

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
    
    
    // Tracking area
    NSTrackingAreaOptions options = (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect);
    NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                                options:options
                                                                  owner:self
                                                               userInfo:nil];
    
    [self addTrackingArea:trackingArea];
    [trackingArea release];
    
    
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
    NSView *result = nil;
    
    
    // Mouse down events ALWAYS go through us so we can handle selection
    NSEvent *event = [[self window] currentEvent];
    if ([event type] == NSLeftMouseDown)
    {
        result = self;
    }
    else
    {
        // Does the point correspond to one of the selections? If so, target that.
        CGPoint point = NSPointToCGPoint([self convertPoint:aPoint fromView:[self superview]]);
        
        for (CALayer *aLayer in [self selectedBorders]) // should we actually be running this in reverse?
        {
            CALayer *hitLayer = [aLayer hitTest:point];
            if (hitLayer)
            {
                result = self;
                break;
            }
        }
    }
    
    
    // Otherwise let our datasource decide.
    if (!result)
    {
        result = [[self dataSource] editingOverlay:self hitTest:aPoint];
        if (!result) result = [super hitTest:aPoint];
    }
    
    
    //NSLog(@"Hit Test: %@", result);
    return result;
}

- (void)mouseDown:(NSEvent *)theEvent
{
    // Need to swallow mouse down events to stop them reaching the webview
}

#pragma mark Cursor

- (void)mouseMoved:(NSEvent *)event
{
    // Does the point correspond to a selection handle? If so, target that.
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    CALayer *layer = [[self layer] hitTest:NSPointToCGPoint(point)];
    NSCursor *cursor = [layer webEditingOverlayCursor];
    
    if (cursor)
    {
        // We need to fractionally delay setting the cursor otherwise WebKit jumps in and changes it back
        [[NSRunLoop currentRunLoop] performSelector:@selector(set)
                                             target:cursor
                                           argument:nil
                                              order:0
                                              modes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
    }
    else
    {
        [[NSCursor arrowCursor] set];
    }
}

@end

