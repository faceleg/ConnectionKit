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
@property(nonatomic, readwrite) BOOL isEditingSelection;
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

- (void)webView:(WebView *)sender didDrawRect:(NSRect)dirtyWebViewRect
{
    NSArray *selectedItems = [self selectedItems];
    if ([selectedItems count] > 0)
    {
        NSView *view = [NSView focusView];
        NSRect dirtyRect = [view convertRect:dirtyWebViewRect fromView:sender];
        
        SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
        [border setEditing:[self isEditingSelection]];
        
        for (id <SVEditingOverlayItem> anItem in [self selectedItems])
        {
            // Draw the item if it's in the dirty rect (otherwise drawing can get pretty pricey)
            NSRect frameRect = [[anItem DOMElement] boundingBox];
            NSRect drawingRect = [border drawingRectForFrame:frameRect];
            if (NSIntersectsRect(drawingRect, dirtyRect))
            {
                [border drawWithFrame:frameRect inView:view];
            }
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

@synthesize isEditingSelection = _isEditingSelection;
- (void)setIsEditingSelection:(BOOL)editing
{
    _isEditingSelection = editing;
    
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    for (id <SVEditingOverlayItem> anItem in [self selectedItems])
    {
        DOMElement *element = [anItem DOMElement];
        NSRect drawingRect = [border drawingRectForFrame:[element boundingBox]];
        NSView *docView = [[[[element ownerDocument] webFrame] frameView] documentView];
        [docView setNeedsDisplayInRect:drawingRect];
    }
    
    [border release];
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

/*  There are 2 reasons why you might resign first responder:
 *      1)  The user generally selected some different bit of the UI. If so, the selection is no longer relevant, so throw it away.
 *      2)  A selected border was clicked in a manner suitable to start editing its contents. This means resigning first responder status to let WebKit take over and so we don't want to affect the selection as it will already have been taken care of.
 */
- (BOOL)resignFirstResponder
{
    BOOL result = [super resignFirstResponder];
    if (result && ![self isEditingSelection])
    {
        [self setSelectedItems:nil];
    }
    
    return result;
}

/*  AppKit uses hit-testing to drill down into the view hierarchy and figure out just which view it needs to target with a mouse event. We can exploit this to effectively "hide" some portions of the webview from the standard event handling mechanisms; all such events will come straight to us instead. We have 2 different behaviours depending on current mode:
 *
 *      1)  Usually, any portion of the webview designated as "selectable" (e.g. pagelets) overrides hit-testing so that clicking selects them rather than the standard WebKit behaviour.
 *
 *      2)  But with -isEditingSelection set to YES, the role is flipped. The user has scoped in on the selected portion of the webview. They have normal access to that, but everything else we need to take control of so that clicking outside the box ends editing.
 */
- (NSView *)hitTest:(NSPoint)aPoint
{
    NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
    
    NSView *result = self;
    if ([self isEditingSelection])
    {
        //  2)
        for (id <SVEditingOverlayItem> anItem in [self selectedItems])
        {
            DOMElement *element = [anItem DOMElement];
            NSView *docView = [[[[element ownerDocument] webFrame] frameView] documentView];
            NSPoint mousePoint = [self convertPoint:point toView:docView];
            if ([docView mouse:mousePoint inRect:[element boundingBox]])
            {
                result = [super hitTest:aPoint];
            }
        }
    }
    else
    {
        //  1)
        if ([self selectionBorderAtPoint:point] || [self itemAtPoint:point])
        {
            result = self;
        }
        else
        {
            result = [super hitTest:aPoint];
        }
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
        BOOL itemIsSelected = [[self selectedItems] containsObjectIdenticalTo:item];
        
        // Depending on the command key, add/remove from the selection, or become the selection
        if ([event modifierFlags] & NSCommandKeyMask)
        {
            if (itemIsSelected)
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
            if (itemIsSelected)
            {
                // If you click an aready selected item quick enough, it will start editing
                _possibleBeginEditingMouseDownEvent = [event retain];
            }
            else
            {
                [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO];
            }
        }
    }
    else
    {
        // Nothing is selected. Wha-hey
        [self setSelectedItems:nil];
        
        [super mouseDown:event];
    }
}

- (void)mouseUp:(NSEvent *)theEvent
{
    if (_possibleBeginEditingMouseDownEvent)
    {
        // Was the mouse up quick enough to start editing?
        if ([theEvent timestamp] - [_possibleBeginEditingMouseDownEvent timestamp] < 0.5)
        {
            // If so, it's time to hand off to the webview for editing.
            [self setIsEditingSelection:YES];
            
            NSPoint location = [self convertPoint:[_possibleBeginEditingMouseDownEvent locationInWindow]
                                         fromView:nil];
            NSView *targetView = [[self webView] hitTest:location];
            [[targetView window] makeFirstResponder:targetView];
            
            [self forwardMouseEvent:_possibleBeginEditingMouseDownEvent
                           selector:@selector(mouseDown:)];
            [self forwardMouseEvent:theEvent selector:_cmd];
        }
        
        // Select the underlying content please!
        [_possibleBeginEditingMouseDownEvent release],  _possibleBeginEditingMouseDownEvent = nil;
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    // A drag of the mouse automatically removes the possibility that editing might commence
    [_possibleBeginEditingMouseDownEvent release],  _possibleBeginEditingMouseDownEvent = nil;
}

@end

