//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"
#import "SVEditingOverlay+Drawing.h"

#import <QuartzCore/QuartzCore.h>   // for CoreAnimation – why isn't it pulled in by default?


NSString *SVWebEditorViewSelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVWebEditorView ()

// Document

// Selection
@property(nonatomic, copy, readonly) NSArray *selectionBorders;
- (void)postSelectionChangedNotification;

// Event handling
- (void)forwardEvent:(NSEvent *)theEvent toWebViewWithSelector:(SEL)selector;

@end


#pragma mark -


@implementation SVWebEditorView

#pragma mark Initialization & Deallocation

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // ivars
    _selectedItems = [[NSMutableArray alloc] init];
    
    
    // WebView
    _webView = [[WebView alloc] initWithFrame:[self bounds]];
    [_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_webView setUIDelegate:self];
    [self addSubview:_webView];
    
    
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
    [_webView release];
        
    [super dealloc];
}

#pragma mark Document

@synthesize webView = _webView;

#pragma mark Data Source

@synthesize dataSource = _dataSource;

#pragma mark Drawing

- (void)webView:(WebView *)sender didDrawRect:(NSRect)dirtyRect
{
    NSArray *selectedItems = [self selectedItems];
    if ([selectedItems count] > 0)
    {
        [[NSColor blackColor] setFill];
        
        for (id <SVEditingOverlayItem> anItem in [self selectedItems])
        {
            NSFrameRectWithWidthUsingOperation([anItem rect], 1.0, NSCompositeSourceOver);
        }
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
    NSView *docView = [[[[self webView] mainFrame] frameView] documentView];
    
    // Reset layers
    if (!extendSelection)
    {
        for (id <SVEditingOverlayItem> anItem in [self selectedItems])
        {
            [docView setNeedsDisplayInRect:[anItem rect]];
        }
        
        [_selectionBorders makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    }
    
    
    // Store new selection
    NSArray *oldSelection = _selectedItems;
    _selectedItems = (extendSelection ?
                      [[_selectedItems arrayByAddingObjectsFromArray:items] retain] :
                      [items copy]);
    [oldSelection release];
    
    
    // Draw new selection
    for (id <SVEditingOverlayItem> anItem in items)
    {
        [docView setNeedsDisplayInRect:[anItem rect]];
    }
    
    
    // Create layers for the new selection
    NSMutableArray *layers = nil;
    if (extendSelection) layers = [_selectionBorders mutableCopy];
    if (!layers) layers = [[NSMutableArray alloc] init];
    
    for (id <SVEditingOverlayItem> anItem in items)
    {
        CALayer *border = [[SVSelectionBorder alloc] init];
        //NSRect itemRect = [anItem rect];
        //[border setFrame:[self convertDocumentRectToDrawingLayer:itemRect]];
        
        [layers addObject:border];
        //[[[self drawingView] scrollLayer] addSublayer:border];
        
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
    
    // TODO: Re-enable this method
    /*
    CGPoint cgPoint = [self convertPointToContent:point];
    
    for (SVSelectionBorder *aLayer in [self selectionBorders])
    {
        if ([aLayer hitTest:cgPoint])
        {
            result = aLayer;
            break;
        }
    }
    */
    return result;
}

- (void)postSelectionChangedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditorViewSelectionDidChangeNotification
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

- (void)scrollWheel:(NSEvent *)theEvent
{
    // We're not personally interested in scroll events, let content have a crack at them.
    [self forwardEvent:theEvent toWebViewWithSelector:_cmd];
}

- (void)forwardEvent:(NSEvent *)theEvent toWebViewWithSelector:(SEL)selector
{
    // If content also decides it's not interested in the event, we will be given it again as part of the responder chain. So, keep track of whether we're processing and ignore the event in such cases.
    if (_isProcessingEvent)
    {
        [super scrollWheel:theEvent];
    }
    else
    {
        NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
        NSView *targetView = [[self webView] hitTest:location];
        
        _isProcessingEvent = YES;
        [targetView performSelector:selector withObject:theEvent];
        _isProcessingEvent = NO;
    }
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

@end

