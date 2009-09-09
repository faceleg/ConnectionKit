//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVEditingOverlay.h"
#import "SVSelectionBorder.h"
#import "SVSelectionHandleLayer.h"

#import <QuartzCore/QuartzCore.h>   // for CoreAnimation – why isn't it pulled in by default?


NSString *SVWebEditingOverlaySelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVEditingOverlay ()

// Selection
@property(nonatomic, copy, readonly) NSArray *selectionBorders;
- (void)postSelectionChangedNotification;

@end


#pragma mark -


@implementation SVEditingOverlay

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // ivars
    _selectedItems = [[NSMutableArray alloc] init];
    
    
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
    [_selectionBorders release];
    [_selectedItems release];
    
    [super dealloc];
}

#pragma mark Data Source

@synthesize dataSource = _dataSource;

#pragma mark Selection

@synthesize selectedItems = _selectedItems;
- (void)setSelectedItems:(NSArray *)items
{
    [self selectItems:items byExtendingSelection:NO];
}

- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
{
    // Reset layers
    if (!extendSelection)
    {
        [_selectionBorders makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    }
    
    
    // Store new selection
    NSArray *oldSelection = _selectedItems;
    _selectedItems = (extendSelection ?
                      [[_selectedItems arrayByAddingObjectsFromArray:items] retain] :
                      [items copy]);
    [oldSelection release];
    
    
    // Create layers for the new selection
    NSMutableArray *layers = nil;
    if (extendSelection) layers = [_selectionBorders mutableCopy];
    if (!layers) layers = [[NSMutableArray alloc] init];
    
    for (id <SVEditingOverlayItem> anItem in items)
    {
        CALayer *border = [[SVSelectionBorder alloc] init];
        [border setFrame:NSRectToCGRect([anItem rect])];
        
        [layers addObject:border];
        [[self layer] addSublayer:border];
        
        [border release];
    }
    
    [_selectionBorders release];
    _selectionBorders = [layers copy];
    [layers release];
    
    
    // Alert observers
    [self postSelectionChangedNotification];
}

@synthesize selectionBorders = _selectionBorders;

- (SVSelectionBorder *)selectionBorderAtPoint:(NSPoint)point;
{
    SVSelectionBorder *result = nil;
    
    // Should we actually be running this in reverse instead?
    CGPoint cgPoint = NSPointToCGPoint(point);
    for (SVSelectionBorder *aLayer in [self selectionBorders])
    {
        if ([aLayer hitTest:cgPoint])
        {
            result = aLayer;
            break;
        }
    }
    
    return result;
}

- (void)postSelectionChangedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditingOverlaySelectionDidChangeNotification
                                                        object:self];
}

#pragma mark Getting Item Information

- (id <SVEditingOverlayItem>)itemAtPoint:(NSPoint)point;
{
    return [[self dataSource] editingOverlay:self itemAtPoint:point];
}

#pragma mark Event Handling

- (BOOL)acceptsFirstResponder { return YES; }

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
    if ([self selectionBorderAtPoint:point])
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
 *      - Start editing selected item (actually happens upon -mouseUp:)
 *      - Add to the selection
 */
- (void)mouseDown:(NSEvent *)event
{
    // What was clicked?
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    id <SVEditingOverlayItem> item = [self itemAtPoint:location];
        
    
    if (item)
    {
        // Depending on the command key, add/remove from the selection, or become the selection
        [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO];
    }
    else
    {
        // Nothing is selected. Wha-hey
        [self setSelectedItems:nil];
        
        [super mouseDown:event];
        return;
        
        // Pass through to the webview any events that we didn't directly act upon. This is the equivalent of NSResponder's usual behaviour of passing such events up the chain
        NSPoint hitTestPoint = [self convertPoint:location toView:[self superview]];  // yes, hit testing is supposed to be in the superview's co-ordinate system
        NSView *target = [[self dataSource] editingOverlay:self hitTest:hitTestPoint];
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
    else
    {
        [super mouseMoved:event];
    }
}

@end

