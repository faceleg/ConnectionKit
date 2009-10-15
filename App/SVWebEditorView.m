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
#import "NSEvent+Karelia.h"
#import "NSWorkspace+Karelia.h"


NSString *SVWebEditorViewSelectionDidChangeNotification = @"SVWebEditingOverlaySelectionDidChange";


@interface SVWebEditorView () <SVWebEditorWebUIDelegate>

@property(nonatomic, retain, readonly) SVWebEditorWebView *webView; // publicly declared as a plain WebView, but we know better

// Selection
- (void)setFocusedText:(id <SVWebEditorText>)text notification:(NSNotification *)notification;
@property(nonatomic, readwrite) SVWebEditingMode mode;
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
    _webView = [[SVWebEditorWebView alloc] initWithFrame:[self bounds]];
    [_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    
    [_webView setFrameLoadDelegate:self];
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
    [_webView setFrameLoadDelegate:nil];
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

- (BOOL)loadUntilDate:(NSDate *)date;
{
    BOOL result = NO;
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!result && [date timeIntervalSinceNow] > 0)
    {
        [runLoop runUntilDate:[NSDate distantPast]];
        result = ![self isLoading];
    }
    
    return result;
}

@synthesize loading = _isLoading;

#pragma mark Selected DOM Range

- (DOMRange *)selectedDOMRange { return [[self webView] selectedDOMRange]; }

#pragma mark Text Selection

@synthesize focusedText = _focusedText;

// Notification is optional as it's just a nicety to pass onto text object
- (void)setFocusedText:(id <SVWebEditorText>)text notification:(NSNotification *)notification
{
    // Ignore identical text as it would send unwanted editing messages to the text in question
    if (text == _focusedText) return;
    
    // Let the old text know it's done
    [[self focusedText] webEditorTextDidEndEditing:notification];
    [[self undoManager] removeAllActions];
    
    // Store the new text
    [_focusedText release], _focusedText = [text retain];
}

#pragma mark Selected Items

@synthesize selectedItems = _selectedItems;
- (void)setSelectedItems:(NSArray *)items
{
    [self selectItems:items byExtendingSelection:NO];
}

- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
{
    NSView *docView = [[[[self webView] mainFrame] frameView] documentView];
    SVSelectionBorder *border = [[[SVSelectionBorder alloc] init] autorelease];
    
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
    SVSelectionBorder *border = [[[SVSelectionBorder alloc] init] autorelease];
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

- (BOOL)canEdit;
{
    //  Editing is only supported while the WebView is First Responder. Otherwise there is no selection to indicate what is being edited. We can work around the issue a bit by forcing there to be a selection, or refusing the edit if not
    BOOL result = [[self webView] isFirstResponder];
    if (!result)
    {
        result = [[self window] makeFirstResponder:[self webView]];
    }
    return result;
}

- (void)willEditTextInDOMRange:(DOMRange *)range
{
    // Record the range ready for a -didChange notification
    OBASSERT(!_DOMRangeOfNextEdit);
    _DOMRangeOfNextEdit = [range retain];
}

- (void)didChangeTextInDOMRange:(DOMRange *)range notification:(NSNotification *)notification;
{
    OBPRECONDITION(range);
    
    // Alert the corresponding Text object that it did change
    id <SVWebEditorText> text = [[self dataSource] webEditorView:self
                                            textBlockForDOMRange:range];
    [text webEditorTextDidChange:notification];
}

#pragma mark Undo Support

- (NSUndoManager *)undoManager
{
    if (!_undoManager)
    {
        _undoManager = [[NSUndoManager alloc] init];
    }
    return _undoManager;
}

/*  This is pretty sucky: There are -undo: and -redo: actions for menu items but they are not documented anywhere. Since we're using a custom undo manager, need to implement these methods ourself
 */

- (void)undo:(id)sender
{
    [[self undoManager] undo];
}

- (void)redo:(id)sender
{
    [[self undoManager] redo];
}

/*  Covers for prviate WebKit methods
 */

- (BOOL)allowsUndo { return [(NSTextView *)[self webView] allowsUndo]; }
- (void)setAllowsUndo:(BOOL)undo { [(NSTextView *)[self webView] setAllowsUndo:undo]; }

- (void)removeAllUndoActions
{
    [[self webView] performSelector:@selector(_clearUndoRedoOperations)];
}

#pragma mark Cut, Copy & Paste

- (void)cut:(id)sender
{
    if ([self copy])
    {
        [self delete:sender];
    }
}

#warning - I think that copy is not a clipboard operation, but an object copying operation!!!!
- (void)copy:(id)sender
{
    [self copy];
}

- (BOOL)copy;
{
    // Rely on the datasource to serialize items to the pasteboard
    BOOL result = [[self dataSource] webEditorView:self 
                                        writeItems:[self selectedItems]
                                      toPasteboard:[NSPasteboard generalPasteboard]];
    if (!result) NSBeep();
    
    return result;
}

- (void)delete:(id)sender;
{
    if (![[self dataSource] webEditorView:self deleteItems:[self selectedItems]])
    {
        NSBeep();
    }
}

#pragma mark Getting Item Information

- (id <SVWebEditorItem>)itemAtPoint:(NSPoint)point;
{
    return [[self dataSource] editingOverlay:self itemAtPoint:point];
}

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
    
    
    // Draw drag caret
    [self drawDragCaretInView:view];
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

- (void)keyDown:(NSEvent *)theEvent
{
    // Interpret delete keys specially, otherwise ignore key events
    if ([theEvent isDeleteKeyEvent])
    {
        [self delete:self];
    }
    else
    {
        [super keyDown:theEvent];
    }
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
    // While editing, we enter into a bit of special mode where a click anywhere outside the editing area is targetted to ourself. This is done so we can take control of the cursor. A click outside the editing area will end editing, but also handle the event as per normal. Easiest way to achieve this I reckon is to end editing and then simply refire the event, arriving at its real target. Very re-entrant :)
    if ([self mode] == SVWebEditingModeEditing)
    {
        [self setSelectedItems:nil];
        [self setMode:SVWebEditingModeNormal];
        [NSApp sendEvent:event];
        return;
    }
    
    
    // Store the event for a bit (for draging, editing, etc.). Note that we're not interested in it while editing
    OBASSERT(!_mouseDownEvent);
    _mouseDownEvent = [event retain];
    
    
    
    
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

- (void)mouseUp:(NSEvent *)mouseUpEvent
{
    if (_mouseDownEvent)
    {
        NSEvent *mouseDownEvent = [_mouseDownEvent retain];
        [_mouseDownEvent release],  _mouseDownEvent = nil;
        
        
        if (_mouseUpMayBeginEditing)
        {
            // Was the mouse up quick enough to start editing? If so, it's time to hand off to the webview for editing.
            if ([mouseUpEvent timestamp] - [mouseDownEvent timestamp] < 0.5)
            {
                // There might be multiple items selected. If so, 
                // Switch to editing mode; as this changes our hit testing behaviour (and thereby event handling path)
                [self setMode:SVWebEditingModeEditing];
                
                // Repost equivalent events so they go to their correct target. Can't call -sendEvent: as that doesn't update -currentEvent
                // Note that they're posted in reverse order since I'm placing onto the front of the queue
                [NSApp postEvent:[mouseUpEvent eventWithClickCount:1] atStart:YES];
                [NSApp postEvent:[mouseDownEvent eventWithClickCount:1] atStart:YES];
            }
        }
        
        
        // Tidy up
        [mouseDownEvent release];
        _mouseUpMayBeginEditing = NO;
    }
}

// -mouseDragged: is over in the Dragging category

- (void)scrollWheel:(NSEvent *)theEvent
{
    // We're not personally interested in scroll events, let content have a crack at them.
    [self forwardMouseEvent:theEvent selector:_cmd];
}

#pragma mark Setting the DataSource/Delegate

@synthesize dataSource = _dataSource;

@synthesize delegate = _delegate;

#pragma mark NSUserInterfaceValidations

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = YES;
    SEL action = [anItem action];
    
    if (action == @selector(undo:))
    {
        result = [[self undoManager] canUndo];
    }
    else if (action == @selector(redo:))
    {
        result = [[self undoManager] canRedo];
    }
    
    // You can cut or copy as long as there is a suggestion (just hope the datasource comes through for us!)
    else if (action == @selector(cut:) || action == @selector(copy:))
    {
        result = ([[self selectedItems] count] >= 1);
    }
    
    return result;
}

- (BOOL)respondsToSelector:(SEL)aSelector
{
    //  And here I am forced to lie a bit to the undo manager. If we're not in the middle of editing, we want undo messages to be handled by the window as usual. Easiest way is just to claim we don't respond.
    BOOL result;
    if (aSelector == @selector(undo:))
    {
        result = [[self undoManager] canUndo];
    }
    else if (aSelector == @selector(redo:))
    {
        result = [[self undoManager] canRedo];
    }
    else
    {
        result = [super respondsToSelector:aSelector];
    }
    
    return result;
}

@end


#pragma mark -


@implementation SVWebEditorView (WebDelegates)

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditorViewDidFinishLoading:self];
    }
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditorView:self didReceiveTitle:title];
    }
}

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

/*  Generally the only drop action we support is for text editing. BUT, for an area of the WebView which our datasource has claimed for its own, need to dissallow all actions
 */
- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)dragInfo
{
    NSUInteger result = WebDragDestinationActionEdit;
    
    if ([[self dataSource] webEditorView:self dataSourceShouldHandleDrop:dragInfo])
    {
        result = WebDragDestinationActionNone;
    }
    
    return result;
}

#pragma mark WebUIDelegatePrivate

/*  Log javacript to the standard console; it may be helpful for us or for people who put javascript into their stuff.
 *  Hint originally from: http://lists.apple.com/archives/webkitsdk-dev/2006/Apr/msg00018.html
 */
- (void)webView:(WebView *)sender addMessageToConsole:(NSDictionary *)aDict
{
	if ([[NSUserDefaults standardUserDefaults] boolForKey:@"LogJavaScript"])
	{
		NSString *message = [aDict objectForKey:@"message"];
		NSString *lineNumber = [aDict objectForKey:@"lineNumber"];
		if (!lineNumber) lineNumber = @""; else lineNumber = [NSString stringWithFormat:@" line %@", lineNumber];
		// NSString *sourceURL = [aDict objectForKey:@"sourceURL"]; // not that useful, it's an applewebdata
		NSLog(@"JavaScript%@> %@", lineNumber, message);
	}
}

- (void)webView:(WebView *)sender didDrawRect:(NSRect)dirtyRect
{
    NSView *drawingView = [NSView focusView];
    NSRect dirtyDrawingRect = [drawingView convertRect:dirtyRect fromView:sender];
    [self drawOverlayRect:dirtyDrawingRect inView:drawingView];
}

#pragma mark WebEditingDelegate

- (BOOL)webView:(WebView *)webView shouldBeginEditingInDOMRange:(DOMRange *)range
{
    id <SVWebEditorText> text = [[self dataSource] webEditorView:self
                                            textBlockForDOMRange:range];
    [self setFocusedText:text notification:nil];
    
    return YES;
}

- (BOOL)webView:(WebView *)webView shouldDeleteDOMRange:(DOMRange *)range
{
    [self willEditTextInDOMRange:range];
    return YES;
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEdit];
    
    if (result)
    {
        id <SVWebEditorText> text = [[self dataSource] webEditorView:self textBlockForDOMRange:range];
        
        // Let the text object decide
        NSPasteboard *pasteboard = nil;
        if ([webView respondsToSelector:@selector(_insertionPasteboard)])
        {
            pasteboard = [webView performSelector:@selector(_insertionPasteboard)];
        }
        
        result = [text webEditorTextShouldInsertNode:node
                                        replacingDOMRange:range
                                              givenAction:action
                                               pasteboard:pasteboard];
        
        if (result)
        {
            [self willEditTextInDOMRange:range];
        }
    }
    
    return result;
}

- (BOOL)webView:(WebView *)webView shouldInsertText:(NSString *)string replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEdit];
    
    if (result)
    {
        id <SVWebEditorText> text = [[self dataSource] webEditorView:self textBlockForDOMRange:range];
        
        // Let the text object decide
        NSPasteboard *pasteboard = nil;
        if ([webView respondsToSelector:@selector(_insertionPasteboard)])
        {
            pasteboard = [webView performSelector:@selector(_insertionPasteboard)];
        }
        
        result = [text webEditorTextShouldInsertText:string
                                   replacingDOMRange:range
                                         givenAction:action
                                          pasteboard:pasteboard];
        
        if (result)
        {
            [self willEditTextInDOMRange:range];
        }
    }
    
    return result;
}

/*  The WebView sends this message whenever its content changes. Unfortunately, there is no way to know what part of the DOM changed, so we are left guessing who to send this message to. The best workaround I can think of is to trap what part of the DOM will be edited and use that.
 */
- (void)webViewDidChange:(NSNotification *)notification
{
    // During undo operations, there's no indication that a change is about to be made, only a -didChange message. I'm going to ingore such messages as I'm not sure clients are interested
    if (_DOMRangeOfNextEdit)
    {
        DOMRange *range = _DOMRangeOfNextEdit;
        _DOMRangeOfNextEdit = nil;  // I'm trying to force this back to nil asap as it's a bit of a hack
        
        [self didChangeTextInDOMRange:range notification:notification];
        [range release];
    }
    else
    {
        NSUndoManager *undoManager = [[self webView] undoManager];
        if (![undoManager isUndoing] && ![undoManager isRedoing])
        {
            OBASSERT_NOT_REACHED("No DOMRange recorded for edit");
        }
    }
}

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    OBPRECONDITION([notification object] == [self webView]);
    
    // Changing selection while editing is a pretty good indication that the webview will end editing, even including by losing first responder status. However, at this point, the webview is still first responder, so we have to delay our check fractionally
    if ([self mode] == SVWebEditingModeEditing)
    {
        [self selectionDidChangeWhileEditing];
    }
}

- (void)webViewDidEndEditing:(NSNotification *)notification
{
    [self setFocusedText:nil notification:notification];
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)command
{
    BOOL result = [_focusedText doCommandBySelector:command];
    return result;
}

@end


/*  SEP - Somebody Else's Problem
*/