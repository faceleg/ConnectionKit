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

@property(nonatomic, retain, readonly) CALayer *scrollLayer;

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
    
    
    // Create a CALayer for drawing
    CALayer *layer = [[CALayer alloc] init];
    [self setLayer:layer];
    [self setWantsLayer:YES];
    
    
    // Mask rect
    _scrollLayer = [[CAScrollLayer alloc] init];
    [_scrollLayer setAutoresizingMask:(kCALayerWidthSizable | kCALayerHeightSizable)];
    [self setContentRect:[self bounds]];
    [layer addSublayer:_scrollLayer];
    
    
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
    
    [_scrollLayer release];
    
    [_contentView release];
    
    [super dealloc];
}

#pragma mark Content/Document View

@synthesize contentView = _contentView;

- (NSRect)contentRect
{
    CGRect result = [[self scrollLayer] frame];
    return NSRectFromCGRect(result);
}

- (void)setContentRect:(NSRect)clipRect
{
    [[self scrollLayer] setFrame:NSRectToCGRect(clipRect)];
}

@synthesize scrollLayer = _scrollLayer;

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
        [[self scrollLayer] addSublayer:border];
        
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
    // Does the point correspond to an item? If so, we're the target; otherwise fall back to standard behaviour
    NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
    
    NSView *result;
    if ([self selectionBorderAtPoint:point] || [self itemAtPoint:point])
    {
        result = self;
    }
    else
    {
        result = [super hitTest:aPoint];
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

