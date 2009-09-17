//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"
#import "SVSelectionBorder.h"

#import "NSArray+Karelia.h"


NSString *SVWebEditorViewSelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVWebEditorView ()

// Document

// Selection
- (void)postSelectionChangedNotification;

// Event handling
- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector;

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
    
    [_selectedItems release];
    [_webView release];
        
    [super dealloc];
}

#pragma mark Document

@synthesize webView = _webView;

- (DOMDocument *)DOMDocument { return [[self webView] mainFrameDocument]; }

#pragma mark Content

@synthesize dataSource = _dataSource;

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
{
    [[[self webView] mainFrame] loadHTMLString:string baseURL:URL];
}

#pragma mark Drawing

- (void)webView:(WebView *)sender didDrawRect:(NSRect)dirtyRect
{
    NSArray *selectedItems = [self selectedItems];
    if ([selectedItems count] > 0)
    {
        SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
        
        for (id <SVEditingOverlayItem> anItem in [self selectedItems])
        {
            [border drawWithFrame:[[anItem DOMElement] boundingBox]
                           inView:[NSView focusView]];
        }
        
        [border release];
    }
}

#pragma mark Selection

- (DOMRange *)selectedDOMRange { return [[self webView] selectedDOMRange]; }

@synthesize selectedItems = _selectedItems;
- (void)setSelectedItems:(NSArray *)items
{
    [self selectItems:items byExtendingSelection:NO];
}

- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
{
    NSView *docView = [[[[self webView] mainFrame] frameView] documentView];
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    
    // Remove old frames
    if (!extendSelection)
    {
        for (id <SVEditingOverlayItem> anItem in [self selectedItems])
        {
            NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
            [docView setNeedsDisplayInRect:drawingRect];
        }
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
        NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
        [docView setNeedsDisplayInRect:drawingRect];
    }
    
    
    // Alert observers
    [self postSelectionChangedNotification];
}

- (void)deselectItem:(id <SVEditingOverlayItem>)item;
{
    // Remove item
    NSMutableArray *newSelection = [[self selectedItems] mutableCopy];
    [newSelection removeObjectIdenticalTo:item];
    [_selectedItems release];   _selectedItems = newSelection;
    
    
    // Redraw
    NSView *docView = [[[[self webView] mainFrame] frameView] documentView];
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    NSRect drawingRect = [border drawingRectForFrame:[[item DOMElement] boundingBox]];
    [docView setNeedsDisplayInRect:drawingRect];
}

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
    [self forwardMouseEvent:theEvent selector:_cmd];
}

- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector
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
        if ([event modifierFlags] & NSCommandKeyMask)
        {
            if ([[self selectedItems] containsObjectIdenticalTo:item])
            {
                [self deselectItem:item];
            }
            else
            {
                [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:YES];
            }
        }
        else
        {
            [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO];
        }
    }
    else
    {
        // Nothing is selected. Wha-hey
        [self setSelectedItems:nil];
        
        [super mouseDown:event];
    }
}

@end

