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

@property(nonatomic, retain, readonly) CALayer *drawingLayer;
@property(nonatomic, retain, readonly) NSWindow *overlayWindow;

// Selection
@property(nonatomic, copy, readonly) NSArray *selectionBorders;
- (void)postSelectionChangedNotification;

@end


#pragma mark -


@implementation SVEditingOverlay

#pragma mark Initialization & Deallocation

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // ivars
    _selectedItems = [[NSMutableArray alloc] init];
    
    
    // Create overlay window
    _overlayWindow = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                                 styleMask:NSBorderlessWindowMask
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
    [_overlayWindow setOpaque:NO];
    [_overlayWindow setBackgroundColor:[[NSColor redColor] colorWithAlphaComponent:0.2]];
    [_overlayWindow setIgnoresMouseEvents:YES];
    
    
    // Create a layer for drawing
    NSView *overlayView = [_overlayWindow contentView];
    _drawingLayer = [[CAScrollLayer alloc] init];
    
    [overlayView setLayer:_drawingLayer];
    [overlayView setWantsLayer:YES];
    
    
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
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [_selectionBorders release];
    [_selectedItems release];
    
    [_overlayWindow release];
    
    [super dealloc];
}

#pragma mark Document

- (NSRect)contentFrame
{
    return [self bounds];
}

- (void)setContentFrame:(NSRect)clipRect
{
    
}

#pragma mark Data Source

@synthesize dataSource = _dataSource;

#pragma mark Drawing

@synthesize drawingLayer = _drawingLayer;

#pragma mark Overlay Window

@synthesize overlayWindow = _overlayWindow;

- (void)viewDidMove:(NSNotification *)notification
{
    // Move the overlay window to be in exactly the same location as our content. Use -disableScreenUpdatesUntilFlush otherwise we can get untidily out of sync with the main window
    NSWindow *window = [self window];
    NSWindow *overlayWindow = [self overlayWindow];
    
    NSRect contentRect = [self convertRectToBase:[self contentFrame]];
    contentRect.origin = [window convertBaseToScreen:contentRect.origin];
    NSRect overlayFrame = [overlayWindow frameRectForContentRect:contentRect];
    
    [overlayWindow disableScreenUpdatesUntilFlush];
    [overlayWindow setFrame:overlayFrame display:NO];
}

- (void)viewDidMoveToWindow
{
    [super viewDidMoveToWindow];
    
    
    // Stop observing old views
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    for (NSView *aView in _trackedViews)
    {
        [notificationCenter removeObserver:self
                                      name:NSViewFrameDidChangeNotification
                                    object:aView];
        [notificationCenter removeObserver:self
                                      name:NSViewBoundsDidChangeNotification
                                    object:aView];
    }
    [_trackedViews release], _trackedViews = nil;
    
    
    // Position window. There might be nowhere to display it, so just wait till we come back onscreen
    NSWindow *window = [self window];
    NSWindow *overlayWindow = [self overlayWindow];
    
    if (window)
    {
        [self viewDidMove:nil];
    
        if (![window parentWindow])
        {
            [window addChildWindow:overlayWindow ordered:NSWindowAbove];
        }
    }
    else
    {
        [[overlayWindow parentWindow] removeChildWindow:overlayWindow];
        [overlayWindow orderOut:self];
    }
    
    
    // Observe our new superviews for signs of movement
    if ([self window])
    {
        NSMutableArray *superviews = [[NSMutableArray alloc] init];
        
        NSView *aView = self;
        while (aView)
        {
            [superviews insertObject:aView atIndex:0];
            
            [notificationCenter addObserver:self 
                                   selector:@selector(viewDidMove:)
                                       name:NSViewFrameDidChangeNotification
                                     object:aView];
            
            [notificationCenter addObserver:self
                                   selector:@selector(viewDidMove:)
                                       name:NSViewBoundsDidChangeNotification 
                                     object:aView];
            
            aView = [aView superview];
        }
        
        
        // Store new observed superviews
        _trackedViews = superviews;
    }
}

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
        [[self drawingLayer] addSublayer:border];
        
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

- (BOOL)resignFirstResponder
{
    BOOL result = [super resignFirstResponder];
    if (result)
    {
        // Before I was trying to handle this by intercepting -mouseDown: and then passing the event along. This was DUMB, instead the AppKit will take care of telling us whether a mouse down should really remove the selection.
        [self setSelectedItems:nil];
    }
    
    return result;
}

- (NSView *)hitTest:(NSPoint)aPoint
{
    // Does the point correspond to one of the selections? If so, target that.
    NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
    
    NSView *result = nil;
    if ([self selectionBorderAtPoint:point] || [self itemAtPoint:point])
    {
        result = self;
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
   }
}

- (void)mouseMoved:(NSEvent *)event
{
    // Does the point correspond to a selection handle? If so, target that.
    NSPoint point = [self convertPoint:[event locationInWindow] fromView:nil];
    CALayer *myLayer = [self drawingLayer];
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

