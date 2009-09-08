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


NSString *SVWebEditingOverlaySelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVWebEditingOverlay ()
- (void)postSelectionChangedNotification;
@end


#pragma mark -


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
    
    [self postSelectionChangedNotification];
}

- (void)removeObjectFromSelectedBordersAtIndex:(NSUInteger)index;
{
    // Remove layer
    SVSelectionBorder *border = [_selection objectAtIndex:index];
    [border removeFromSuperlayer];
    
    [_selection removeObjectAtIndex:index];
    
    [self postSelectionChangedNotification];
}

- (void)postSelectionChangedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditingOverlaySelectionDidChangeNotification
                                                        object:self];
}

#pragma mark Getting Item Information

- (SVSelectionBorder *)selectionBorderForItemAtPoint:(NSPoint)point;
{
    SVSelectionBorder *result = nil;
    
    // Should we actually be running this in reverse instead?
    CGPoint cgPoint = NSPointToCGPoint(point);
    for (SVSelectionBorder *aLayer in [self selectedBorders])
    {
        if ([aLayer hitTest:cgPoint])
        {
            result = aLayer;
            break;
        }
    }
    
    return result;
}

#pragma mark Event Handling

- (NSView *)hitTest:(NSPoint)aPoint
{
    // Mouse down events ALWAYS go through us so we can handle selection
    NSEvent *event = [[self window] currentEvent];
    NSView *result = ([event type] == NSLeftMouseDown) ? self : [self editingOverlayHitTest:aPoint];
    return result;
}

- (NSView *)editingOverlayHitTest:(NSPoint)aPoint;
{
    // Does the point correspond to one of the selections? If so, target that.
    NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
    
    NSView *result;
    if ([self selectionBorderForItemAtPoint:point])
    {
        result = self;
    }
    else
    {
        result = [[self dataSource] editingOverlay:self hitTest:aPoint];
        if (!result) result = [super hitTest:aPoint];
    }
    
    
    //NSLog(@"Hit Test: %@", result);
    return result;
}

#pragma mark Tracking the Mouse

/*  Actions we could take from this:
 *      - Deselect everything
 *      - Change selection to new item
 *      - Start editing selected item
 */
- (void)mouseDown:(NSEvent *)event
{
    // Where was the mouse down?
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    
    
    
    BOOL eventHandled = NO;
    
    
    // Need to swallow mouse down events to stop them reaching the webview
    
    
    
    // Pass through to the webview any events that we didn't directly act upon. This is the equivalent of NSResponder's usual behaviour of passing such events up the chain
    if (!eventHandled)
    {
        NSPoint point = [[self superview] convertPoint:[event locationInWindow] fromView:nil];  // yes, hit testing is supposed to be in the superview's co-ordinate system
        NSView *target = [[self dataSource] editingOverlay:self hitTest:point];
        [target mouseDown:event];
    }
}

- (void)mouseMoved:(NSEvent *)event
{
    // Does the point correspond to a selection handle? If so, target that.
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    CALayer *myLayer = [self layer];
    CALayer *layer = [myLayer hitTest:NSPointToCGPoint(point)];
    
    if (layer != myLayer)
    {
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
}

@end

