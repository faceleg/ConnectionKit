//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVEditingOverlay.h"
#import "SVEditingOverlay+Drawing.h"

#import <QuartzCore/QuartzCore.h>   // for CoreAnimation – why isn't it pulled in by default?


NSString *SVWebEditingOverlaySelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVEditingOverlay ()

// Document

// Drawing Layer
@property(nonatomic, retain, readonly) SVEditingOverlayDrawingView *drawingView;
- (CGRect)convertDocumentRectToDrawingLayer:(NSRect)rect;

// Overlay window
@property(nonatomic, retain, readonly) NSWindow *overlayWindow;
- (void)viewDidMove:(NSNotification *)notification;

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
    _contentFrame = [self bounds];
    _selectedItems = [[NSMutableArray alloc] init];
    
    
    // Create overlay window
    _overlayWindow = [[NSWindow alloc] initWithContentRect:NSZeroRect
                                                 styleMask:NSBorderlessWindowMask
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
    [_overlayWindow setOpaque:NO];
    [_overlayWindow setBackgroundColor:[NSColor clearColor]];
    [_overlayWindow setIgnoresMouseEvents:YES];
    
    
    // Create drawing view
    NSView *contentView = [_overlayWindow contentView];
    _drawingView = [[SVEditingOverlayDrawingView alloc]
                    initWithFrame:[contentView bounds]];
    
    [_drawingView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [contentView addSubview:_drawingView];
    
    
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

@synthesize contentFrame = _contentFrame;
- (void)setContentFrame:(NSRect)clipRect
{
    _contentFrame = clipRect;
    
    [self viewDidMove:nil];
}

- (void)setFrame:(NSRect)frameRect
{
    NSRect oldFrame = [self frame];
    [super setFrame:frameRect];
    
    // Need to update content frame accordingly. It behaves just like the springs/struts mechanism to stretch size
    NSRect contentFrame = [self contentFrame];
    contentFrame.size.width += frameRect.size.width - oldFrame.size.width;
    contentFrame.size.height += frameRect.size.height - oldFrame.size.height;
    [self setContentFrame:contentFrame];
}

- (void)scrollToPoint:(NSPoint)aPoint;
{
    [[self drawingView] scrollToPoint:aPoint];
}

- (CGPoint)convertPointToContent:(NSPoint)aPoint;
{
    // Should be enough to offset it by content rect's origin
    NSPoint offset = [self contentFrame].origin;
    aPoint.x -= offset.x;
    aPoint.y -= offset.y;
    
    return NSPointToCGPoint(aPoint);
}

- (CGRect)convertRectToContent:(NSRect)aRect;
{
    CGRect result = NSRectToCGRect(aRect);
    result.origin = [self convertPointToContent:aRect.origin];
    return result;
}

#pragma mark Data Source

@synthesize dataSource = _dataSource;

#pragma mark Drawing

@synthesize drawingView = _drawingView;

- (CGRect)convertDocumentRectToDrawingLayer:(NSRect)rect;
{
    CGRect result = NSRectToCGRect(rect);
    result.origin.y = -rect.origin.y;
    result.size.height = -rect.size.height;
    return result;
}

#pragma mark Overlay Window

@synthesize overlayWindow = _overlayWindow;

- (void)viewDidMove:(NSNotification *)notification
{
    // Place the overlay window in exactly the same location as our content. Use -disableScreenUpdatesUntilFlush otherwise we can get untidily out of sync with the main window
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
        
        NSView *aView = [self superview];   // we'll take care directly of our own frame changes
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
        NSRect itemRect = [anItem rect];
        [border setFrame:[self convertDocumentRectToDrawingLayer:itemRect]];
        
        [layers addObject:border];
        [[[self drawingView] scrollLayer] addSublayer:border];
        
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
    CGPoint cgPoint = [self convertPointToContent:point];
    
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
    CALayer *myLayer = [[self drawingView] scrollLayer];
    CALayer *layer = [myLayer hitTest:[self convertPointToContent:point]];
    
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

/*  Trap -mouseDragged: events otherwise they pass through to the webview which reclaims the cursor
 */
- (void)mouseDragged:(NSEvent *)theEvent
{
}

@end

