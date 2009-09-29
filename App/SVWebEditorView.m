//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebEditorView.h"
#import "SVWebEditorWebView.h"
#import "SVSelectionBorder.h"

#import "DOMNode+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSWorkspace+Karelia.h"


#define WebDragImageAlpha 0.5f // name is copied from WebKit, but we use 0.5 instead of 0.75 which I felt obscured destination too much

NSString *SVWebEditorViewSelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVWebEditorView () <SVWebEditorWebUIDelegate>

@property(nonatomic, retain, readonly) SVWebEditorWebView *webView; // publicly declared as a plain WebView, but we know better

// Selection
@property(nonatomic, readwrite) SVWebEditingMode mode;
- (void)postSelectionChangedNotification;

// Event handling
- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector;

@end

@interface SVWebEditorView (Internal)
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
    _webView = [[SVWebEditorWebView alloc] initWithFrame:[self bounds]];
    [_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_webView setPolicyDelegate:self];
    [_webView setUIDelegate:self];
    [_webView setEditingDelegate:self];
    
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
    [_webView setPolicyDelegate:nil];
    [_webView setUIDelegate:nil];
    [_webView setEditingDelegate:nil];
    
    [_selectedItems release];
    [_webView release];
        
    [super dealloc];
}

#pragma mark Document

@synthesize webView = _webView;

- (DOMDocument *)DOMDocument { return [[self webView] mainFrameDocument]; }

#pragma mark Loading Data

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
{
    _isLoading = YES;
    [[[self webView] mainFrame] loadHTMLString:string baseURL:URL];
    _isLoading = NO;
}

@synthesize loading = _isLoading;

#pragma mark Drawing

- (void)drawOverlayRect:(NSRect)dirtyRect inView:(NSView *)view
{
    // Draw drop highlight if there is one. 3px inset from bounding box, "Aqua" colour
    if (_dragHighlightNode)
    {
        NSRect dropRect = [_dragHighlightNode boundingBox];
        
        [[NSColor aquaColor] setFill];
        NSFrameRectWithWidth(dropRect, 3.0f);
    }
    
    
    // Nothing to draw during a drag op
    if ([self mode] != SVWebEditingModeDragging)
    {
        NSArray *selectedItems = [self selectedItems];
        if ([selectedItems count] > 0)
        {
            SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
            [border setEditing:([self mode] == SVWebEditingModeEditing)];
            
            for (id <SVWebEditorItem> anItem in [self selectedItems])
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
        for (id <SVWebEditorItem> anItem in [self selectedItems])
        {
            NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
            [docView setNeedsDisplayInRect:drawingRect];
        }
    }
    
    
    // Store new selection. Odd looking logic I know, but should handle edge cases like _selectedItems being nil
    NSArray *oldSelection = _selectedItems;
    _selectedItems = ((extendSelection && _selectedItems) ?
                      [[_selectedItems arrayByAddingObjectsFromArray:items] retain] :
                      [items copy]);
    [oldSelection release];
    
    
    // Draw new selection
    for (id <SVWebEditorItem> anItem in items)
    {
        NSRect drawingRect = [border drawingRectForFrame:[[anItem DOMElement] boundingBox]];
        [docView setNeedsDisplayInRect:drawingRect];
    }
    
    
    // Alert observers
    [self postSelectionChangedNotification];
}

- (void)deselectItem:(id <SVWebEditorItem>)item;
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

/*  When beginning a drag, you want to drag all the selected items. I haven't quite decided how to do this yet – one big image containing them all or an image for the item under the mouse and a numeric overlay? – so this is fairly temporary. Also return by reference the origin of the image within our own coordinate system.
 */
- (NSImage *)dragImageForSelectionFromItem:(id <SVWebEditorItem>)item
                                  location:(NSPoint *)outImageLocation
{
    // The core items involved
    DOMElement *element = [item DOMElement];
    NSRect itemRect = NSInsetRect([element boundingBox], -1.0f, -1.0f);  // Expand by 1px to capture border
    NSImage *result = [[[NSImage alloc] initWithSize:itemRect.size] autorelease];
    
    WebFrameView *frameView = [[[element ownerDocument] webFrame] frameView];
    NSView <WebDocumentView> *docView = [frameView documentView];
    
    
    // Try to capture straight from WebKit. This is a private method so may not always be available
    if ([element respondsToSelector:@selector(renderedImage)])
    {
        NSImage *elementImage = [element performSelector:@selector(renderedImage)];
        if (elementImage)
        {
            NSRect drawingRect; drawingRect.origin = NSZeroPoint;   drawingRect.size = [elementImage size];
            
            [result lockFocus];
            
            [elementImage drawInRect:NSInsetRect(drawingRect, 1.0f, 1.0f)
                            fromRect:NSZeroRect
                           operation:NSCompositeCopy
                            fraction:WebDragImageAlpha];
            
            [[[NSColor grayColor] colorWithAlphaComponent:WebDragImageAlpha] setFill];
            NSFrameRect(drawingRect);
            
            [result unlockFocus];
        }
    }
    
    
    // Otherwise, fall back to caching display. Don't forget to be semi-transparent!
    if (!result)
    {
        NSRect imageDrawingRect = [frameView convertRect:itemRect fromView:docView];
        NSBitmapImageRep *bitmap = [frameView bitmapImageRepForCachingDisplayInRect:imageDrawingRect];
        [frameView cacheDisplayInRect:imageDrawingRect toBitmapImageRep:bitmap];
        
        NSImage *image = [[NSImage alloc] initWithSize:itemRect.size];
        [image addRepresentation:bitmap];
        
        [result lockFocus];
        [image drawAtPoint:NSZeroPoint
                  fromRect:NSZeroRect
                 operation:NSCompositeCopy
                  fraction:WebDragImageAlpha];
        [result unlockFocus];
        
        [image release];
    }
    
    
    // Also return rect if requested
    if (result && outImageLocation)
    {
        NSRect imageRect = [self convertRect:itemRect fromView:docView];
        *outImageLocation = imageRect.origin;
    }
    
    
    return result;
}

- (void)postSelectionChangedNotification
{
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditorViewSelectionDidChangeNotification
                                                        object:self];
}

#pragma mark Editing

@synthesize mode = _mode;
- (void)setMode:(SVWebEditingMode)mode
{
    _mode = mode;
    
    // The whole selection will need redrawing
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    for (id <SVWebEditorItem> anItem in [self selectedItems])
    {
        DOMElement *element = [anItem DOMElement];
        NSRect drawingRect = [border drawingRectForFrame:[element boundingBox]];
        [[element documentView] setNeedsDisplayInRect:drawingRect];
    }
    
    [border release];
}

- (void)selectionDidChangeWhileEditing
{
    [[NSRunLoop currentRunLoop] performSelector:@selector(checkIfEditingDidEnd)
                                         target:self
                                       argument:nil
                                          order:0
                                          modes:[NSArray arrayWithObject:NSRunLoopCommonModes]];
}

- (void)checkIfEditingDidEnd
{
    NSResponder *firstResponder = [[self window] firstResponder];
    if (!firstResponder ||
        ![firstResponder isKindOfClass:[NSView class]] ||
        ![(NSView *)firstResponder isDescendantOf:self])
    {
        [self setSelectedItems:nil];
        [self setMode:SVWebEditingModeNormal];
    }
}

#pragma mark Getting Item Information

- (id <SVWebEditorItem>)itemAtPoint:(NSPoint)point;
{
    return [[self dataSource] editingOverlay:self itemAtPoint:point];
}

#pragma mark Event Handling

/*  Normally, we're quite happy to become first responder; that's what governs whether we have a selection. But when in editing mode, the role is reversed, and we don't want to become first responder unless the user clicks another item.
 */
- (BOOL)acceptsFirstResponder
{
    BOOL result = ([self mode] != SVWebEditingModeEditing);
    return result;
}

/*  There are 2 reasons why you might resign first responder:
 *      1)  The user generally selected some different bit of the UI. If so, the selection is no longer relevant, so throw it away.
 *      2)  A selected border was clicked in a manner suitable to start editing its contents. This means resigning first responder status to let WebKit take over and so we don't want to affect the selection as it will already have been taken care of.
 */
- (BOOL)resignFirstResponder
{
    BOOL result = [super resignFirstResponder];
    if (result && [self mode] != SVWebEditingModeEditing)
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
    // First off, we'll only consider special behaviour if targeting the document
    NSView *result = [super hitTest:aPoint];
    if ([result isDescendantOf:[[[[self webView] mainFrame] frameView] documentView]])
    {
        NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
        
        if ([self mode] == SVWebEditingModeEditing)
        {
            //  2)
            BOOL targetSelf = YES;
            for (id <SVWebEditorItem> anItem in [self selectedItems])
            {
                DOMElement *element = [anItem DOMElement];
                NSView *docView = [element documentView];
                NSPoint mousePoint = [self convertPoint:point toView:docView];
                if ([docView mouse:mousePoint inRect:[element boundingBox]])
                {
                    targetSelf = NO;
                }
            }
            if (targetSelf) result = self;
        }
        else
        {
            //  1)
            if ([self selectionBorderAtPoint:point] || [self itemAtPoint:point])
            {
                result = self;
            }
        }
    }
    
    
    
        
    
    //NSLog(@"Hit Test: %@", result);
    return result;
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
    // Store the event for a bit (for draging, editing, etc.)
    _mouseDownEvent = [event retain];
    
    
    // While editing, we enter into a bit of special mode where a click anywhere outside the editing area is targetted to ourself. This is done so we can take control of the cursor. A click outside the editing area will end editing, but also handle the event as per normal. Easiest way to achieve this I reckon is to end editing and then simply refire the event, arriving at its real target. Very re-entrant :)
    if ([self mode] == SVWebEditingModeEditing)
    {
        [self setSelectedItems:nil];
        [self setMode:SVWebEditingModeNormal];
        [NSApp sendEvent:event];
        return;
    }
    
    
    
    
    // What was clicked?
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    id <SVWebEditorItem> item = [self itemAtPoint:location];
        
    
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
            [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO];
            
            if (itemIsSelected)
            {
                // If you click an aready selected item quick enough, it will start editing
                _mouseUpMayBeginEditing = YES;
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
    if (_mouseDownEvent)
    {
        NSEvent *mouseDownEvent = [_mouseDownEvent retain];
        [_mouseDownEvent release],  _mouseDownEvent = nil;
        
        
        if (_mouseUpMayBeginEditing)
        {
            // Was the mouse up quick enough to start editing? If so, it's time to hand off to the webview for editing.
            if ([theEvent timestamp] - [mouseDownEvent timestamp] < 0.5)
            {
                // There might be multiple items selected. If so, 
                // Switch to editing mode; as this changes our hit testing behaviour (and thereby event handling path)
                [self setMode:SVWebEditingModeEditing];
                
                // Refire events, this time they'll go to their correct target.
                [NSApp sendEvent:mouseDownEvent];
                [NSApp sendEvent:theEvent];
            }
        }
        
        
        // Tidy up
        [mouseDownEvent release];
        _mouseUpMayBeginEditing = NO;
    }
}

- (void)mouseDragged:(NSEvent *)theEvent
{
    if (!_mouseDownEvent) return;   // otherwise we initiate a drag multiple times!
    
    
    
    
    //  Ideally, we'd place onto the pasteboard:
    //      Sandvox item info, everything, else, WebKit, does, normally
    //
    //  -[WebView writeElement:withPasteboardTypes:toPasteboard:] would seem to be ideal for this, but it turns out internally to fall back to trying to write the selection to the pasteboard, which is definitely not what we want. Fortunately, it boils down to writing:
    //      Sandvox item info, WebArchive, RTF, plain text
    //
    //  Furthermore, there arises the question of how to handle multiple items selected. WebKit has no concept of such a selection so couldn't help us here, even if it wanted to. Should we try to string together the HTML/text sections into one big lump? Or use 10.6's ability to write multiple items to the pasteboard?
    
    NSArray *selection = [self selectedItems];
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    
    if ([[self dataSource] webEditorView:self writeItems:selection toPasteboard:pboard])
    {
        // Now let's start a-dragging!
        id <SVWebEditorItem> item = [selection lastObject]; // FIXME: use the item actually being dragged
        
        NSPoint dragImageRect;
        NSImage *dragImage = [self dragImageForSelectionFromItem:item location:&dragImageRect];
        
        if (dragImage)
        {
            [self dragImage:dragImage
                         at:dragImageRect
                     offset:NSZeroSize
                      event:_mouseDownEvent
                 pasteboard:pboard
                     source:self
                  slideBack:YES];
        }
    }
    
    
    // A drag of the mouse automatically removes the possibility that editing might commence
    [_mouseDownEvent release],  _mouseDownEvent = nil;
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // We're not personally interested in scroll events, let content have a crack at them.
    [self forwardMouseEvent:theEvent selector:_cmd];
}

#pragma mark Drag Types

/*  All this sort of stuff we really want to target the webview with
 */

- (void)registerForDraggedTypes:(NSArray *)pboardTypes
{
    [[self webView] registerForDraggedTypes:pboardTypes];
}

- (NSArray *)registeredDraggedTypes
{
    return [[self webView] registeredDraggedTypes];
}

- (void)unregisterDraggedTypes
{
    [[self webView] unregisterDraggedTypes];
}

#pragma mark Dragging Destination

- (id <NSDraggingInfo>)willValidateDrop:(id <NSDraggingInfo>)sender;
{
    return sender;
}

- (NSDragOperation)validateDrop:(id <NSDraggingInfo>)sender proposedOperation:(NSDragOperation)op;
{
    DOMNode *dropNode = nil;
    if (op > NSDragOperationNone)
    {
        NSPoint point = [self convertPointFromBase:[sender draggingLocation]];
        DOMRange *editingRange = [[self webView] editableDOMRangeForPoint:point];
        dropNode = [[editingRange startContainer] containingContentEditableElement];
    }
    
    
    // Mark for redraw if needed
    [self moveDragHighlightToNode:dropNode];
    
    
    return op;
}

- (void)moveDragHighlightToNode:(DOMNode *)node
{
    if (node != _dragHighlightNode)
    {
        [self removeDragHighlight];
        _dragHighlightNode = [node retain];
        [node setDocumentViewNeedsDisplayInBoundingBoxRect];
    }
}

- (void)removeDragHighlight
{
    [_dragHighlightNode setDocumentViewNeedsDisplayInBoundingBoxRect];
    [_dragHighlightNode release];   _dragHighlightNode = nil;
}

- (BOOL)useDefaultBehaviourForDrop:(id <NSDraggingInfo>)dragInfo { return YES; }

#pragma mark Dragging Source

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    NSDragOperation result = NSDragOperationCopy;
    if (isLocal) result = (result | NSDragOperationMove);
    return result;
}

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)aPoint
{
    // Hide the dragged items so it looks like a proper drag
    [self setMode:SVWebEditingModeDragging];    // will redraw without selection borders
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
    // Make the dragged items visible again
    [self setMode:SVWebEditingModeNormal];
    
    for (id <SVWebEditorItem> anItem in [self selectedItems])
    {
        DOMElement *element = [anItem DOMElement];
        [[element style] removeProperty:@"visibility"];
    }
}

#pragma mark Setting the DataSource/Delegate

@synthesize dataSource = _dataSource;

@synthesize delegate = _delegate;

#pragma mark WebPolicyDelegate

/*	We don't want to allow navigation within Sandvox! Open in web browser instead
 */
- (void)webView:(WebView *)sender decidePolicyForNewWindowAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
   newFrameName:(NSString *)frameName
decisionListener:(id <WebPolicyDecisionListener>)listener
{
	// Open the URL in the user's web browser
	[listener ignore];
	
	NSURL *URL = [request URL];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:URL];
}

/*  We don't allow navigation, but our delegate may then decide to
 */
- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
    if ([self isLoading])
    {
        // We want to allow initial loading of the webview…
        [listener use];
    }
    else
    {
        // …but after that navigation is undesireable
        [listener ignore];
        [[self delegate] webEditorView:self handleNavigationAction:actionInformation request:request];
    }
}

#pragma mark WebUIDelegate

- (void)webView:(WebView *)sender didDrawRect:(NSRect)dirtyRect
{
    NSView *drawingView = [NSView focusView];
    NSRect dirtyDrawingRect = [drawingView convertRect:dirtyRect fromView:sender];
    [self drawOverlayRect:dirtyDrawingRect inView:drawingView];
}

/*  Generally the only drop action we support is for text editing. BUT, for an area of the WebView which our datasource has claimed for its own, need to dissallow all actions
 */
- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)dragInfo
{
    return ([self useDefaultBehaviourForDrop:dragInfo]) ? WebDragDestinationActionEdit : WebDragDestinationActionNone;
}

#pragma mark WebEditingDelegate

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    OBPRECONDITION([notification object] == [self webView]);
    
    // Changing selection while editing is a pretty good indication that the webview will end editing, even including by losing first responder status. However, at this point, the webview is still first responder, so we have to delay our check fractionally
    if ([self mode] == SVWebEditingModeEditing)
    {
        [self selectionDidChangeWhileEditing];
    }
}

@end

