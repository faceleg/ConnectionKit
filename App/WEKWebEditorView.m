//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "WEKWebEditorView.h"

#import "WEKWebView.h"
#import "WEKRootItem.h"
#import "WEKWebKitPrivate.h"

#import "KTApplication.h"
#import "SVDocWindow.h"
#import "SVPasteboardItemInternal.h"
#import "SVEditingController.h"

#import "KSSelectionBorder.h"

#import "DOMElement+Karelia.h"
#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSEvent+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "KSSortedMutableArray.h"


NSString *SVWebEditorViewDidChangeSelectionNotification = @"SVWebEditingOverlaySelectionDidChange";
NSString *kSVWebEditorViewWillChangeNotification = @"SVWebEditorViewWillChange";
NSString *kSVWebEditorViewDidChangeNotification = @"SVWebEditorViewDidChange";


typedef enum {  // this copied from WebPreferences+Private.h
    WebKitEditableLinkDefaultBehavior,
    WebKitEditableLinkAlwaysLive,
    WebKitEditableLinkOnlyLiveWithShiftKey,
    WebKitEditableLinkLiveWhenNotFocused,
    WebKitEditableLinkNeverLive
} WebKitEditableLinkBehavior;


#pragma mark -


@interface DOMNode (KSHTMLWriter)
- (BOOL)ks_isDescendantOfDOMNode:(DOMNode *)possibleAncestor;
@end


#pragma mark -


@interface WEKWebEditorView ()

@property(nonatomic, retain, readonly) WEKWebView *webView; // publicly declared as a plain WebView, but we know better


#pragma mark Selection

- (void)setFocusedText:(id <SVWebEditorText>)text notification:(NSNotification *)notification;

- (BOOL)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection isUIAction:(BOOL)isUIAction;
- (BOOL)deselectItem:(WEKWebEditorItem *)item isUIAction:(BOOL)isUIAction;

// Monster method for updating the selection
// For a WebView-initiated change, specify the new DOM range. Otherwise, pass nil and the WebView's selection will be updated to match.
- (BOOL)changeSelectionByDeselectingAll:(BOOL)deselectAll
                         orDeselectItem:(WEKWebEditorItem *)itemToDeselect
                            selectItems:(NSArray *)itemsToSelect
                               DOMRange:(DOMRange *)domRange
                             isUIAction:(BOOL)consultDelegateFirst;

- (void)finishChangingSelectionByDeselectingItem:(WEKWebEditorItem *)itemToDeselect DOMRange:(DOMRange *)domRange;
- (void)changeFirstResponderAndWebViewSelectionToSelectItem:(WEKWebEditorItem *)item;
- (NSArray *)editingItemsForDOMRange:(DOMRange *)range selectedItem:(WEKWebEditorItem *)item;

@property(nonatomic, copy, readwrite) NSArray *editingItems;


// Event handling
- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector cachedTargetView:(NSView *)targetView;
- (void)moveItemForEvent:(NSEvent *)event;
- (void)dragImageForEvent:(NSEvent *)event;

#pragma mark Resizing
- (void)resizeItem:(WEKWebEditorItem *)item usingHandle:(SVGraphicHandle)handle withEvent:(NSEvent *)event;


#pragma mark Guides
@property(nonatomic, copy, readwrite) NSNumber *xGuide;
@property(nonatomic, copy, readwrite) NSNumber *yGuide;


// Undo
- (NSUndoManager *)webViewUndoManager;

@end


#pragma mark -


@implementation WEKWebEditorView

#pragma mark Lifecycle

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // Starter items
    _rootItem = [[WEKRootItem alloc] init];
    [_rootItem setWebEditor:self];
    
    WEKWebEditorItem *contentItem = [[WEKWebEditorItem alloc] init];
    [self setContentItem:contentItem];
    [contentItem release];
    
    
    // other ivars
    _selectedItems = [[NSMutableArray alloc] init];
    _itemsToDisplay = [[NSMutableArray alloc] init];
    
    
    // WebView
    _webView = [[WEKWebView alloc] initWithFrame:[self bounds]];
    [_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_webView setShouldCloseWithWindow:YES];    // seems correct for a doc-based app
    [_webView setMaintainsBackForwardList:NO];
    
    if ([_webView respondsToSelector:@selector(setAlwaysShowVerticalScroller:)])
    {
        [_webView setBool:YES forKey:@"alwaysShowVerticalScroller"];
    }
    
#ifndef VARIANT_RELEASE
    if ([_webView respondsToSelector:@selector(_setCatchesDelegateExceptions:)])
    {
        [_webView _setCatchesDelegateExceptions:NO];
    }
#endif
    
    [_webView setFrameLoadDelegate:self];
    [_webView setPolicyDelegate:self];
    [_webView setResourceLoadDelegate:self];
    [_webView setUIDelegate:self];
    [_webView setEditingDelegate:self];
    
    [self addSubview:_webView];
    
    
    // Editing Controller
    _editingController = [[SVEditingController alloc] init];
    [_editingController setWebView:[self webView]];
    [_editingController insertIntoResponderChainAfterWebView:[self webView]];
    
    
    // Behaviour
    [self setLiveEditableAndSelectableLinks:YES];
    
    WebPreferences *prefs = [[self webView] preferences];
    if ([prefs respondsToSelector:@selector(setShrinksStandaloneImagesToFit:)])
    {
        [prefs setValue:NSBOOL(YES) forKey:@"shrinksStandaloneImagesToFit"];
    }
    
    
    // Tracking area
    NSTrackingAreaOptions options = (NSTrackingMouseMoved | NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect);
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
    [self unbind:@"liveEditableAndSelectableLinks"];
    
    [_rootItem setWebEditor:nil];
    [_rootItem release];
    
    [_focusedText release];
    [_selectedItems release];
    [_selectionParentItems release];
    [_itemsToDisplay release];
    [_changingTextControllers release];
    
    [_webView close];
    [_webView release];
    [_editingController release];
    [_undoManager release];
    
    [super dealloc];
}

#pragma mark Window Tracking

- (void)viewDidMoveToWindow
{
    if ([self window])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(updateMouseoverWithFakeEvent)
                                                     name:KTApplicationDidSendFlagsChangedEvent
                                                   object:[KTApplication sharedApplication]];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(windowDidBecomeKey:)
                                                     name:NSWindowDidBecomeKeyNotification
                                                   object:[self window]];
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if ([self window])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:KTApplicationDidSendFlagsChangedEvent
                                                      object:[KTApplication sharedApplication]];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSWindowDidBecomeKeyNotification
                                                      object:[self window]];
    }
}

- (void)windowDidBecomeKey:(NSNotification *)notification;
{
    [_editingController updateLinkManager];
}

#pragma mark Document

@synthesize webView = _webView;

- (DOMDocument *)HTMLDocument
{
    return [[[self webView] mainFrame] DOMDocument];    // -mainFrameDocument isn't as reliable
}

- (NSView *)documentView { return [[[[self webView] mainFrame] frameView] documentView]; }

- (void)scrollToPoint:(NSPoint)point;
{
    [[self documentView] scrollPoint:point];
}

#pragma mark Loading Data

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
{
    _isStartingLoad = YES;
    @try
    {
        // Text can't be focused after the webview loads, so tell it so, hopefully resolving #134847
        [self setFocusedText:nil notification:nil];
        [self setContentItem:nil];
        [[[self webView] mainFrame] loadHTMLString:string baseURL:URL];
    }
    @finally
    {
        _isStartingLoad = NO;
    }
}

@synthesize startingLoad = _isStartingLoad;

- (BOOL)loadUntilDate:(NSDate *)date;
{
    BOOL result = NO;
    
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    while (!result && [date timeIntervalSinceNow] > 0)
    {
        [runLoop runUntilDate:[NSDate distantPast]];
        result = ![self isStartingLoad];
    }
    
    return result;
}

#pragma mark Items

@synthesize contentItem = _contentItem;
- (void)setContentItem:(WEKWebEditorItem *)item;
{
    // No existing controllers need drawing. #95073
    [_itemsToDisplay removeAllObjects];
    [self changeSelectionByDeselectingAll:YES orDeselectItem:nil selectItems:nil DOMRange:nil isUIAction:NO];
    
    if ([self contentItem])
    {
        if (item)
        {
            [_rootItem replaceChildWebEditorItem:[self contentItem] with:item];
        }
        else
        {
            [[self contentItem] removeFromParentWebEditorItem];
        }
    }
    else if (item)
    {
        [_rootItem addChildWebEditorItem:item];
    }
    
    _contentItem = item;    // _rootItem will retain it for us
}

- (void)willRemoveItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    [[self delegate] webEditor:self willRemoveItem:item];
    
    
    // Make sure it or a descendant is no longer selected
    NSArray *selection = [[self selectedItems] copy];
    for (WEKWebEditorItem *anItem in selection)
    {
        if ([anItem isDescendantOfWebEditorItem:item])
        {
            [self deselectItem:anItem];
            [self setEditingItems:nil]; // have to force this one sadly
            [_itemsToDisplay removeObjectIdenticalTo:anItem];
        }
    }
    [selection release];
    
    
    // If item is or contains focused text, this can no longer be true. #111365
    if ([item isDescendantOfWebEditorItem:[self focusedText]])
    {
        [self setFocusedText:nil notification:nil];
    }
    
    
    // No longer need to display item or descendants
    for (WEKWebEditorItem *anItem in [self itemsToDisplay])
    {
        if ([anItem isDescendantOfWebEditorItem:item]) [_itemsToDisplay removeObjectIdenticalTo:anItem];
    }
}

#pragma mark Text Selection

- (DOMRange *)selectedDOMRange
{
    DOMRange *result = [[self webView] selectedDOMRange];
    return result;
}

- (void)setSelectedDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)selectionAffinity;
{
    if (range)
    {
        // It's not a good idea to give Web Editor DOM selection while it's not in the responder chain.
        NSWindow *window = [self window];
        OBASSERT([self ks_followsResponder:[window firstResponder]]);
        
        
        // If we're the first responder, need to shift that over to the document view
        if ([window firstResponder] == self)
        {
            [window makeFirstResponder:[[range commonAncestorContainer] documentView]];
        }
    }
    
    
    // Set selected items first
    if (!_isChangingSelectedItems)
    {
        NSArray *items = (range ? [self selectableItemsInDOMRange:range] : nil);
        
        [self changeSelectionByDeselectingAll:YES
                               orDeselectItem:nil
                                  selectItems:items
                                     DOMRange:range
                                   isUIAction:NO];
    }
    
    
    // Apply selection to WebView
    [[self webView] setSelectedDOMRange:range affinity:selectionAffinity];
}

@synthesize focusedText = _focusedText;

// Notification is optional as it's just a nicety to pass onto text object
- (void)setFocusedText:(id <SVWebEditorText>)text notification:(NSNotification *)notification
{
    // Ignore identical text as it would send unwanted editing messages to the text in question
    if (text == _focusedText) return;
    
    [self willChangeValueForKey:@"focusedText"];
    
    // Let the old text know it's done
    [[self focusedText] webEditorTextDidEndEditing:notification];
    [[self webViewUndoManager] removeAllActions];
    
    // Store the new text
    [text webEditorTextDidBeginEditing];
    [_focusedText release], _focusedText = [text retain];
    
    [self didChangeValueForKey:@"focusedText"];
}

#pragma mark Selected Items

@synthesize selectedItems = _selectedItems;

- (WEKWebEditorItem *)selectedItem
{
    return [[self selectedItems] lastObject];
}

- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
{
    [self selectItems:items byExtendingSelection:extendSelection isUIAction:NO];
}

- (void)deselectItem:(WEKWebEditorItem *)item;
{
    [self deselectItem:item isUIAction:NO];
}

/*!
 @method selectItem:event:
 @abstract The user tried to select the item using event. Add/remove it to the selection appropriately
 */
- (void)selectItem:(WEKWebEditorItem *)item event:(NSEvent *)event
{
    
    
    // Depending on the command key, add/remove from the selection, or become the selection. 
    if ([event modifierFlags] & NSCommandKeyMask)
    {
        NSArray *currentSelection = [self selectedItems];
        BOOL itemIsSelected = [currentSelection containsObjectIdenticalTo:item];
        
        if (itemIsSelected)
        {
            [self deselectItem:item isUIAction:YES];
        }
        else
        {
            // Is it embedded in some editable text? Can't select multiple embedded items this way, must select the text range enclosing them instead.
            BOOL isEmbedded = [[item HTMLElement] isContentEditable];
            
            // Weed out embedded items from the existing selection
            if (!isEmbedded)
            {
                for (WEKWebEditorItem *anItem in currentSelection)
                {
                    if ([[anItem HTMLElement] isContentEditable])
                    {
                        [self deselectAll:self];
                        break;
                    }
                }
            }
            
            [self selectItems:[NSArray arrayWithObject:item]
         byExtendingSelection:!isEmbedded
                   isUIAction:YES];
        }
    }
    else
    {
        // Is it possible for this event to start editing of the item?
        DOMRange *currentSelection = [self selectedDOMRange];
        DOMRange *selectableRange = [item selectableDOMRange];
        
        BOOL canBeginEditing = NO;
        if (selectableRange)
        {
            canBeginEditing = [[currentSelection commonAncestorContainer]
                               ks_isDescendantOfElement:[item HTMLElement]];
        }
        else
        {
            canBeginEditing = [[self selectedItems] isEqualToArray:[NSArray arrayWithObject:item]];
        }
        
        
        // Select the item
        [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO isUIAction:YES];
        
        
        // Done all we can?
        if (!event || [item allowsDirectAccessToWebViewWhenSelected]) return;
        
        
        // Consider as start of drag?
        NSPoint mouseDownLocation = [event locationInWindow];
        
        NSView *view = [[item HTMLElement] documentView];
        
        NSEvent *mouseDown = event;
        event = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        
        while ([event type] != NSLeftMouseUp)
        {
            // Calculate change from event
            [view autoscroll:event];
            
            NSSize offset = NSMakeSize([event locationInWindow].x - mouseDownLocation.x,
                                       [event locationInWindow].y - mouseDownLocation.y);
            
            if (offset.width > 4.0f || offset.width < -4.0f || offset.height > 4.0f || offset.height < -4.0f)
            {
                if ([self dragSelectionWithEvent:event offset:offset slideBack:YES])
                {
                    return;
                }
            }
            
            event = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        }

        
        // Start editing the item? Needs the item to be sole selection, and mouse up to be quick enough
        if (canBeginEditing &&
            ([event timestamp] - [mouseDown timestamp] < 0.5))
        {
            // Is the item at that location supposed to be for editing?
            // This is true if the clicked child item is either:
            //  A)  selectable
            //  B)  editable text
            //
            // Actually, trying out ignoring that! Mike. #84932
            
            
            NSPoint location = [self convertPoint:[mouseDown locationInWindow] fromView:nil];
            NSDictionary *elementInfo = [[self webView] elementAtPoint:location];
            DOMElement *element = [elementInfo objectForKey:WebElementDOMNodeKey];
            if (!element) return;   // happens if mouse up was somehow outside doc rect
            
            /*
             if (([item isSelectable] && item != [self selectedItem]) ||
             ([item conformsToProtocol:@protocol(SVWebEditorText)] && [(id)item isEditable]) ||
             [node isKindOfClass:[DOMHTMLObjectElement class]])*/
            
            
            // Inline images don't want to be edited inside since they're already fully accessible for dragging etc. Basically applies to all images
            if (![[[item HTMLElement] tagName] isEqualToString:@"IMG"])
            {
                NSArray *items = [[self selectedItems] copy];
                [self selectItems:nil byExtendingSelection:NO];
                [self setEditingItems:items];    // should only be 1
                [items release];
                
                [self updateMouseoverWithFakeEvent];
                
                
                /*  Generally, repost equivalent events (unless a link or object) so they go to their correct target.
                 */
                
                // Don't send event to live links
                if ([elementInfo objectForKey:WebElementLinkURLKey])
                {
                    NSNumber *live = [elementInfo objectForKey:@"WebElementLinkIsLive"];
                    if (!live || [live boolValue]) return;
                }
                
                // Don't send event to buttons
                DOMNode *aNode = element;
                while (aNode)
                {
                    if ([aNode isKindOfClass:[DOMHTMLButtonElement class]]) return;
                    aNode = [aNode parentNode];
                }
                
                // Don't send event through to video-like things as they would misinterpret it
                item = [self selectableItemForDOMNode:element];
                if ([items lastObject] == item &&
                    [element isKindOfClass:[DOMElement class]]) // could actually be any DOMNode subclass
                {
                    NSString *tagName = [element tagName];
                    if ([tagName isEqualToString:@"OBJECT"] ||
                        [tagName isEqualToString:@"EMBED"] ||
                        [tagName isEqualToString:@"VIDEO"] ||
                        [tagName isEqualToString:@"AUDIO"])
                    {
                        return;
                    }
                }
                
                // Can't call -sendEvent: as that doesn't update -currentEvent.
                // Post in reverse order since I'm placing onto the front of the queue
                [NSApp postEvent:[event ks_eventWithClickCount:1] atStart:YES];
                [NSApp postEvent:[mouseDown ks_eventWithClickCount:1] atStart:YES];
            }
        }
    }
}

- (IBAction)deselectAll:(id)sender;
{
    [self selectItems:nil byExtendingSelection:NO isUIAction:YES];
}


/*  Support methods to do the real work of all our public selection methods
 */

- (BOOL)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection isUIAction:(BOOL)isUIAction;
{
    return [self changeSelectionByDeselectingAll:!extendSelection
                                  orDeselectItem:nil
                                     selectItems:items
                                   DOMRange:nil
                                      isUIAction:isUIAction];
}

- (BOOL)deselectItem:(WEKWebEditorItem *)item isUIAction:(BOOL)isUIAction;
{
    return [self changeSelectionByDeselectingAll:NO
                                  orDeselectItem:item
                                     selectItems:nil
                                   DOMRange:nil
                                      isUIAction:isUIAction];
}

#pragma mark Overall Selection

- (BOOL)changeSelectionByDeselectingAll:(BOOL)deselectAll
                         orDeselectItem:(WEKWebEditorItem *)itemToDeselect
                            selectItems:(NSArray *)itemsToSelect
                               DOMRange:(DOMRange *)domRange
                             isUIAction:(BOOL)consultDelegateFirst;
{
    // Bracket the whole operation so no-one else gets the wrong idea
    OBPRECONDITION(_isChangingSelectedItems == NO);
    _isChangingSelectedItems = YES;
@try
{
    
    //  Calculate proposed selection
    NSMutableArray *proposedSelection = [_selectedItems mutableCopy];
    
    NSArray *itemsToDeselect = nil;
    if (deselectAll)
    {
        itemsToDeselect = [self selectedItems];
    }
    else if (itemToDeselect)
    {
        itemsToDeselect = [NSArray arrayWithObject:itemToDeselect];
    }
    
    if (itemsToDeselect)
    {
        [proposedSelection removeObjectsInArray:itemsToDeselect];
    }
    
    if (itemsToSelect)
    {
        // Slightly odd looking logic here, but handles possibility of _selectedItems being nil
        if (proposedSelection)
        {
            [proposedSelection addObjectsFromArray:itemsToSelect];
        }
        else
        {
            proposedSelection = [itemsToSelect mutableCopy];
        }
    }
    
    
    
    //  If needed, check the new selection with the delegate.
    if (consultDelegateFirst)
    {
        if (![[self delegate] webEditor:self
           shouldChangeSelectedDOMRange:[self selectedDOMRange] // could be inefficient
                             toDOMRange:domRange
                               affinity:[[self webView] selectionAffinity]  // yes, I'm kinda making this up
                                  items:proposedSelection
                         stillSelecting:NO])
        {
            [proposedSelection release];
            return NO;
        }
    }
    
    
    
    //  Remove items, which will mark them for display
    [itemsToDeselect setBool:NO forKey:@"selected"];
    
    
    
    //  Store new selection. MUST be performed after marking deselected items for display otherwise itemsToDeselect loses its objects somehow
    [_selectedItems release]; _selectedItems = proposedSelection;
    
    
    // Draw new selection
    for (WEKWebEditorItem *anItem in itemsToSelect)
    {
        [anItem setSelected:YES];
    }
    
    
    // Other work
    [self finishChangingSelectionByDeselectingItem:itemToDeselect DOMRange:domRange];
}
@finally
{
    // Finish bracketing
    _isChangingSelectedItems = NO;
}   
    
    
    // Alert observers.
    // If the change is from the user selecting something in WebView, we're not ready to post the notification yet; -webViewDidChangeSelection: will take care of that for us
    if (!domRange)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditorViewDidChangeSelectionNotification
                                                            object:self];
    }
    
    
    return YES;
}

- (void)finishChangingSelectionByDeselectingItem:(WEKWebEditorItem *)itemToDeselect DOMRange:(DOMRange *)domRange;
{
    // Update WebView selection to match. Selecting the node would be ideal, but WebKit ignores us if it's not in an editable area
    WEKWebEditorItem *selectedItem = [self selectedItem];
    if (!domRange)
    {
        if (selectedItem)
        {
            [self changeFirstResponderAndWebViewSelectionToSelectItem:selectedItem];
        }
        
        // There's no selected items left, so move cursor to left of deselected item. Don't want to do this though if the item is being deselected due to removal from the Web Editor
        else if ([itemToDeselect webEditor] == self)
        {
            DOMElement *element = [itemToDeselect HTMLElement];
            if ([element ks_isDescendantOfDOMNode:[element ownerDocument]] &&
                [self ks_followsResponder:[[self window] firstResponder]])
            {
                DOMRange *range = [[element ownerDocument] createRange];
                [range setStartBefore:element];
                [range collapse:YES];
                [self setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
            }
        }
    }
    
    
    // Update editingItems list
    NSArray *parentItems = [self editingItemsForDOMRange:domRange selectedItem:selectedItem];
    [self setEditingItems:parentItems];
}

- (void)changeFirstResponderAndWebViewSelectionToSelectItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    
    
    // First Responder is going to have be self or a subview (e.g. webview)
    NSResponder *firstResponder = [[self window] firstResponder];
    if (!firstResponder || ![self ks_followsResponder:firstResponder])
    {
        if ([[self window] makeFirstResponder:self]) firstResponder = self;
    }
    
    
    // Try to match WebView selection to item when reasonable
    if ([item shouldTrySelectingInline])
    {
        DOMRange *range = [item selectableDOMRange];
        DOMRange *selection = [self selectedDOMRange];
        
        // If the selection's already as we want it, no point changing
        if (![selection isEqualToDOMRange:range])
        {
            [self setSelectedDOMRange:range affinity:NSSelectionAffinityUpstream];
            
            // Did it work out as we wanted?
            if (![[self selectedDOMRange] isEqualToDOMRange:range])
            {
                // Get sneaky. WebKit doesn't like the range of linked, floated images and changes the selection to something odd that partially covers the link. But we can fool it by faking keyboard commands
                //[[self webView] moveForward:self];
                //[[self webView] moveBackwardAndModifySelection:self];
            }
        }
        
        
        // Was it a success though?
        if (![[self selectedDOMRange] collapsed]) return;
    }
    else
    {
        if (firstResponder != self)
        {
            [[self window] makeFirstResponder:self];
        }
    }
}

@synthesize editingItems = _selectionParentItems;
- (void)setEditingItems:(NSArray *)items
{
    if (KSISEQUAL(items, [self editingItems])) return;  // KSISEQUAL handles nil array
    
    // Let them know
    [[self editingItems] setBool:NO forKey:@"editing"];
    [items setBool:YES forKey:@"editing"];
    
    // Store items
    [_selectionParentItems release]; _selectionParentItems = [items copy];
    
    // All but editing item should be darkened
    [self setNeedsDisplay:YES];
}

- (NSArray *)editingItemsForDOMRange:(DOMRange *)range selectedItem:(WEKWebEditorItem *)item;
{
    NSArray *result = nil;
    
    if (item)
    {
        result = [item selectableAncestors];
    }
    else
    {
        // When selecting nothing significant while editing, it's probably because we want to continue editing
        if (!range || [range collapsed])
        {
            result = [self editingItems];
        }
        else
        {
            DOMNode *selectionNode = [range commonAncestorContainer];
            if (selectionNode)
            {
                WEKWebEditorItem *parent = [self selectableItemForDOMNode:selectionNode];
                if (parent)
                {
                    result = [item selectableAncestors];
                    result = (result ? [result arrayByAddingObject:parent] : [NSArray arrayWithObject:parent]);
                }
            }
        }
    }
    
    return result;
}

- (WEKWebEditorItem *)firstResponderItem;
{
    WEKWebEditorItem *result = [self selectedItem];
    if (!result) result = [[self editingItems] lastObject];
    
    DOMRange *selection = [self selectedDOMRange];
    if (selection)
    {
        WEKWebEditorItem *item = [[self contentItem] hitTestDOMNode:[selection commonAncestorContainer]];
        if (!result || [item isDescendantOfWebEditorItem:result]) result = item;
    }
    
    return result;
}

#pragma mark Links

#pragma mark Editing

- (BOOL)canEditText;
{
    //  Editing is only supported while the WebView is First Responder. Otherwise there is no selection to indicate what is being edited. We can work around the issue a bit by forcing there to be a selection, or refusing the edit if not
    BOOL result = [[self webView] isFirstResponder];
    if (!result)
    {
        result = [[self window] makeFirstResponder:[self webView]];
    }
    return result;
}

@synthesize liveEditableAndSelectableLinks = _liveLinks;
- (void)setLiveEditableAndSelectableLinks:(BOOL)liveLinks;
{
    _liveLinks = liveLinks;
    
    WebKitEditableLinkBehavior behaviour = (liveLinks ? WebKitEditableLinkAlwaysLive :WebKitEditableLinkOnlyLiveWithShiftKey);
    [[[self webView] preferences] setInteger:behaviour forKey:@"editableLinkBehavior"];
}

- (BOOL)shouldChangeTextInDOMRange:(DOMRange *)range;
{
    OBPRECONDITION(range);
    
    
    // Dissallow edits outside the current text area
    BOOL result = YES;
    
    /*
     DOMRange *selection = [self selectedDOMRange];
    if (selection)  // allow any edit if there is no selection
     TURNED THIS OFF BECAUSE IT BREAKS DRAG & DROP. DON'T THINK WE NEED IT ANYHOW
    {
        WEKWebEditorItem *textController = [self textItemForDOMRange:[self selectedDOMRange]];
        
        DOMNode *editingNode = [range commonAncestorContainer];
        result = [editingNode isDescendantOfNode:[textController HTMLElement]];
    }*/
    
    
    if (result)
    {
        // See if the there is a controller to check with
        WEKWebEditorItem <SVWebEditorText> *textController = [self textItemForDOMRange:range];
        
        if (textController) result = [self shouldChangeText:textController];
    }
    
    return result;
}

- (BOOL)shouldChangeText:(WEKWebEditorItem <SVWebEditorText> *)textController;
{
    OBPRECONDITION(textController);
    
    // The change is going to go ahead, so let's handle it. Woo!
    [[NSNotificationCenter defaultCenter]
     postNotificationName:kSVWebEditorViewWillChangeNotification object:self];
    
    
    // Mark the controller that's changing. Be lazy about it!
    if (!_changingTextControllers) _changingTextControllers = [[NSMutableArray alloc] initWithCapacity:1];
    OBASSERT(_changingTextControllers);
    
    if (![_changingTextControllers containsObjectIdenticalTo:textController])
    {
        [_changingTextControllers addObject:textController];
    }
    
    
    return YES;
}

- (void)didChangeText;  // posts kSVWebEditorViewDidChangeNotification
{
    if (![_changingTextControllers count])
    {
        // No changes were recorded as about to happen, so assume the change was where the current selection is
        DOMRange *selection = [self selectedDOMRange];
        if (selection) [self shouldChangeTextInDOMRange:selection];
    }
    
    
    [_changingTextControllers makeObjectsPerformSelector:@selector(webEditorTextDidChange)];
    [_changingTextControllers removeAllObjects];
    
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:kSVWebEditorViewDidChangeNotification object:self];
}

- (NSPasteboard *)insertionPasteboard;
{
    NSPasteboard *result = nil;
    
    if ([[self webView] respondsToSelector:@selector(_insertionPasteboard)])
    {
        result = [[self webView] performSelector:@selector(_insertionPasteboard)];
    }
    
    if (!result) result = _insertionPasteboard;
    
    return result;
}

#pragma mark Guides

@synthesize xGuide = _xGuide;
@synthesize yGuide = _yGuide;

- (NSRect)xGuideRect;
{
    NSRect bounds = [[self documentView] bounds];
    
    NSRect result = NSMakeRect([[self xGuide] floatValue],
                               bounds.origin.y,
                               1.0f,
                               bounds.size.height);
    return result;
}

- (NSRect)yGuideRect;
{
    NSRect bounds = [[self documentView] bounds];
    
    NSRect result = NSMakeRect(bounds.origin.x,
                               [[self yGuide] floatValue],
                               bounds.size.width,
                               1.0f);
    
    return result;
}

- (void)setXGuide:(NSNumber *)x yGuide:(NSNumber *)y;
{
    NSView *view = [self documentView];
    
    if (!KSISEQUAL(x, [self xGuide]))
    {
        if ([self xGuide]) [view setNeedsDisplayInRect:[self xGuideRect]];
        [self setXGuide:x];
        if ([self xGuide]) [view setNeedsDisplayInRect:[self xGuideRect]];
    }
    
    if (!KSISEQUAL(y, [self yGuide]))
    {
        if ([self yGuide]) [view setNeedsDisplayInRect:[self yGuideRect]];
        [self setYGuide:y];
        if ([self yGuide]) [view setNeedsDisplayInRect:[self yGuideRect]];
    }
}

- (void)drawGuidesInView:(NSView *)view;
{
    [[NSColor yellowColor] set];    // lemon
    
    if ([self xGuide]) NSRectFill([self xGuideRect]);
    if ([self yGuide])  NSRectFill([self yGuideRect]);
}

#pragma mark Undo

- (NSUndoManager *)webViewUndoManager
{
    if (!_undoManager)
    {
        _undoManager = [[NSUndoManager alloc] init];
    }
    return _undoManager;
}

#pragma mark Getting Item Information

- (WEKWebEditorItem *)selectableItemAtPoint:(NSPoint)point;
{
    //  To answer the question: what item (if any) would be selected if you clicked at that point?
    
    
    WEKWebEditorItem *result = nil;
    
    // If the element is a link of some kind, and we have live links turned on, ignore the possibility of selection
    NSDictionary *element = [[self webView] elementAtPoint:point];
    
    if ([element objectForKey:WebElementLinkURLKey])
    {
        if ([self liveEditableAndSelectableLinks] ||
            [[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
        {
            return nil;
        }
    }
    
    
    // Use the DOM node to find the item
    DOMNode *domNode = [element objectForKey:WebElementDOMNodeKey];
    if (domNode)
    {
        result = [self selectableItemForDOMNode:domNode];
    }
    
    return result;
}

- (WEKWebEditorItem *)selectableItemForDOMNode:(DOMNode *)node;
{
    OBPRECONDITION(node);
    WEKWebEditorItem *result = nil;
    
    
    // Node in question might be in a different frame. #84559
    DOMHTMLElement *frameElement = [[[node ownerDocument] webFrame] frameElement];
    while (frameElement)
    {
        node = frameElement;
        frameElement = [[[node ownerDocument] webFrame] frameElement];
    }
    
    
    // Look for children at the deepest possible level (normally top-level). Keep backing out until we find something of use
    
    result = [[self contentItem] hitTestDOMNode:node];
    while (result && ![result isSelectable])
    {
        result = [result parentWebEditorItem];
    }
    
    
    // We've found the deepest selectable item, but does it have a parent that should be selected instead?
    /*WEKWebEditorItem *parent = [result parentWebEditorItem];
    while (parent)
    {
        // Give up searching if we've hit the selection's parent items
        if ([[self editingItems] containsObjectIdenticalTo:parent]) break;
        
        if ([parent isSelectable]) result = parent;
        parent = [parent parentWebEditorItem];
    }*/
    
    
    return result;
}

- (id)selectableDescendantOfItem:(WEKWebEditorItem *)anItem forRepresentedObject:(id)anObject;
{
    WEKWebEditorItem *result = nil;
    for (result in [anItem childWebEditorItems])
    {
        result = [result hitTestRepresentedObject:anObject];
        if (result && ![result isSelectable])
        {
            result = [self selectableDescendantOfItem:result forRepresentedObject:anObject];
        }
        
        if (result) break;
    }
    
    return result;
}

- (id)selectableItemForRepresentedObject:(id)anObject;
{
    WEKWebEditorItem *result = [[self contentItem] hitTestRepresentedObject:anObject];
    if (![result isSelectable])
    {
        // If it's not selectable, root around the descendants
        result = [self selectableDescendantOfItem:result forRepresentedObject:anObject];
    }
    
    return result;
}

- (NSArray *)selectableItemsInDOMRange:(DOMRange *)range
{
    OBPRECONDITION(range);
    if ([range collapsed]) return nil;  // shortcut
    
    
    // Locate the controller for the text area so we can query it for selectable stuff
    WEKWebEditorItem <SVWebEditorText> *textController = [self textItemForDOMRange:range];
    
    if (textController)
    {
        NSMutableArray *result = [NSMutableArray array];
        
        DOMNode *commonNode = [range commonAncestorContainer];
        DOMTreeWalker *walker = [[commonNode ownerDocument] createTreeWalker:commonNode
                                                                  whatToShow:DOM_SHOW_ALL
                                                                      filter:nil
                                                      expandEntityReferences:NO];
        
        [walker setCurrentNode:[range ks_startNode:NULL]];
        while ([walker currentNode] != [range ks_endNode:NULL])
        {
            DOMNode *aNode = [walker currentNode];
            if ([aNode nodeType] == DOM_ELEMENT_NODE)
            {
                WEKWebEditorItem *item = [self selectableItemForDOMNode:aNode];
                if (item && item != textController && [item isDescendantOfWebEditorItem:textController])
                {
                    [result addObject:item];
                }
            }
            
            if (![walker nextNode]) break;
        }
        
        return result;
    }
    
    return nil;
}

- (WEKWebEditorItem *)selectedItemAtPoint:(NSPoint)point handle:(SVGraphicHandle *)outHandle;
{
    // Like -selectableItemAtPoint:, but only looks at selection, and takes graphic handles into account
    
    KSSelectionBorder *border = [[[KSSelectionBorder alloc] init] autorelease];
    [border setMinSize:NSMakeSize(5.0f, 5.0f)];
    
    WEKWebEditorItem *result = nil;
    for (result in [self selectedItems])
    {
        [border setResizingMask:[result resizingMask]];
        
        NSView *docView = [[result HTMLElement] documentView];
        NSRect frame = [border frameRectForGraphicBounds:[result selectionFrame]];
        
        if ([border mouse:[docView convertPoint:point fromView:self]
                isInFrame:frame
                   inView:docView
                   handle:outHandle])
        {
            break;
        }
    }
    
    return result;
}

#pragma mark Drawing

- (void)drawOverlayRect:(NSRect)dirtyRect inView:(NSView *)view
{
    // Draw drop highlight if there is one. 1px inset from bounding box, "Aqua" colour
    if (_dragHighlightNode)
    {
        WEKWebEditorItem *item = [[self contentItem] hitTestDOMNode:_dragHighlightNode];
        NSRect dropRect = (item ? [item frame] : [_dragHighlightNode boundingBox]);    // pretending it's a node
        
        [[NSColor aquaColor] setFill];
        NSFrameRectWithWidth(dropRect, 1.0f);
    }
    
    
    // Draw selection
    [self drawItemsRect:dirtyRect inView:view];
    
    
    // Draw drag caret
    [self drawDragCaretInView:view];
    
    // Guides
    [self drawGuidesInView:view];
    
    // Finally, fake cursor
    if (_cursor)
    {
        [_cursor ks_drawAtPoint:_cursorPoint];
    }
}

- (void)drawItemsRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    // Draw items
    for (WEKWebEditorItem *anItem in [self itemsToDisplay])
    {
        // Ignore items that can't be displayed. #95073
        if (![anItem isDescendantOfWebEditorItem:[self contentItem]])
        {
            [_itemsToDisplay removeObjectIdenticalTo:anItem];
            continue;
        }
        
        // Is the item actually for drawing?
        NSRect drawingRect = [anItem drawingRect];
        if (drawingRect.size.width == 0.0f && drawingRect.size.height == 0.0f)
        {
            [_itemsToDisplay removeObjectIdenticalTo:anItem];
        }
        else
        {
            // Only draw if the item is in the dirty rect (otherwise can get pretty pricey). Use -displayRect: to target descendants as well
            if ([view needsToDrawRect:drawingRect]) [anItem displayRect:dirtyRect inView:view];
        }
    }
}

- (NSSet *)itemsToDisplay;
{
    return [NSSet setWithArray:_itemsToDisplay];
}

- (void)setNeedsDisplayForItem:(WEKWebEditorItem *)item;
{
    OBPRECONDITION(item);
    
    NSRect drawingRect = [item drawingRect];
    [[self documentView] setNeedsDisplayInRect:drawingRect];
    
    BOOL markedForDisplay = NO;
    
    NSUInteger i;
    for (i = 0; i < [_itemsToDisplay count]; i++)
    {
        WEKWebEditorItem *anItem = [_itemsToDisplay objectAtIndex:i];
        
        // Is the item already present? Or covered by an ancestor? If so, can ignore request
        if ([item isDescendantOfWebEditorItem:anItem]) return;
        
        // Remove/replace any descendants of the item since they're now covered by item
        if ([anItem isDescendantOfWebEditorItem:item])
        {
            if (markedForDisplay)
            {
                [_itemsToDisplay removeObjectAtIndex:i];
                i--;
            }
            else
            {
                [_itemsToDisplay replaceObjectAtIndex:i withObject:item];
                markedForDisplay = YES;
            }
        }
    }
    
    // Remove/replace any descendants of the item since they're now covered by item
    if (!markedForDisplay) [_itemsToDisplay addObject:item];
}

- (BOOL)inLiveGraphicResize; { return _resizingGraphic; }

#pragma mark Event Handling

// Will simulate this returning YES when clicking on a non-inline item
- (BOOL)acceptsFirstResponder { return NO; }

#ifdef ACCEPTS_FIRST_MOUSE
- (BOOL)acceptsFirstMouse:(NSEvent *)theEvent { return YES; }
#endif

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
    
    if ([result isDescendantOf:[self documentView]])
    {
        NSPoint point = [self convertPoint:aPoint fromView:[self superview]];
        
        // Normally, we want to target self if there's an item at that point but not if the item is the parent of a selected item.
        SVGraphicHandle handle;
        WEKWebEditorItem *item = [self selectedItemAtPoint:point handle:&handle];
        
        
        // Handles should *always* be selectable, but otherwise, pass through to -selectableItemAtPoint: so as to take hyperlinks into account
        if (!item || handle == kSVGraphicNoHandle) 
        {
            item = [self selectableItemAtPoint:point];
            
            // Images only want to capture events on their selection handles
            /*if ([item allowsDirectAccessToWebViewWhenSelected])
            {
                return result;
            }*/
        }
        
        if (item)
        {
            if (![[self editingItems] containsObject:item])
            {
                result = self;
            }
        }
        else if ([[self editingItems] count] > 0)
        {
            result = self;
        }
    }


    
    //NSLog(@"Hit Test: %@", result);
    return result;
}

- (WEKWebEditorItem *)itemHitTest:(NSPoint)location handle:(SVGraphicHandle *)outHandle;
{
    SVGraphicHandle handle;
    WEKWebEditorItem *result = [self selectedItemAtPoint:location handle:&handle];
    if (result)
    {
		if (outHandle) *outHandle = handle;
    }
    else
    {
        if (outHandle) *outHandle = kSVGraphicNoHandle;
        result = [self selectableItemAtPoint:location];
    }
    
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

- (NSMenu *)menuForEvent:(NSEvent *)theEvent;
{
    NSMenu *result = nil;
    
    // Where's the click? Is it a selection handle? They don't want a menu
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    
    SVGraphicHandle handle;
    WEKWebEditorItem *item = [self itemHitTest:location handle:&handle];
    if (!item || handle == kSVGraphicNoHandle)
    {
        result = [item menuForEvent:theEvent];
        if (!result) result = [super menuForEvent:theEvent];
    }
    
    return result;
}

- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector cachedTargetView:(NSView *)targetView;
{
    // If content also decides it's not interested in the event, we will be given it again as part of the responder chain. So, keep track of whether we're processing and ignore the event in such cases.
    if (_isProcessingEvent)
    {
        [[self nextResponder] performSelector:selector withObject:theEvent];
    }
    else
    {
        if (!targetView)
        {
            NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
            targetView = [[self webView] hitTest:location];
        }
        
        _isProcessingEvent = YES;
        [targetView performSelector:selector withObject:theEvent];
        _isProcessingEvent = NO;
    }
}

#pragma mark Tracking the Mouse

- (void)moveItemForEvent:(NSEvent *)event;
{
    NSPoint eventLocation = [event locationInWindow];
    WEKWebEditorItem *item = [self selectedItemAtPoint:[self convertPoint:eventLocation fromView:nil]
                                                handle:NULL];
    if(!item) return;
    
    
    NSView *docView = [[item HTMLElement] documentView];
    NSPoint dragLocation = [docView convertPoint:eventLocation fromView:nil];
    CGPoint position = [item position];
    
    NSSize offset = NSMakeSize(position.x - dragLocation.x, position.y - dragLocation.y);
    
    while ([event type] != NSLeftMouseUp)
    {
        // Calculate change from event
        event = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        [docView autoscroll:event];
        
        dragLocation = [docView convertPoint:[event locationInWindow] fromView:nil];
        position = CGPointMake(dragLocation.x + offset.width, dragLocation.y + offset.height);
        
        [item moveToPosition:position event:event];
    }
    
    
    // Reset position/appearance
    [item moveEnded];
    [self setXGuide:nil yGuide:nil];
}

- (void)dragImageForEvent:(NSEvent *)event;
{
    return;
    
    
    NSPoint eventLocation = [event locationInWindow];
    WEKWebEditorItem *item = [self selectedItemAtPoint:[self convertPoint:eventLocation fromView:nil]
                                                handle:NULL];
    if (!item) return;
    
    
    //  Ideally, we'd place onto the pasteboard:
    //      Sandvox item info, everything, else, WebKit, does, normally
    //
    //  -[WebView writeElement:withPasteboardTypes:toPasteboard:] would seem to be ideal for this, but it turns out internally to fall back to trying to write the selection to the pasteboard, which is definitely not what we want. Fortunately, it boils down to writing:
    //      Sandvox item info, WebArchive, RTF, plain text
    //
    //  Furthermore, there arises the question of how to handle multiple items selected. WebKit has no concept of such a selection so couldn't help us here, even if it wanted to. Should we try to string together the HTML/text sections into one big lump? Or use 10.6's ability to write multiple items to the pasteboard?
    
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    
    if ([self selectedDOMRange])
    {
        WebView *webView = [self webView];
        NSArray *types = [webView pasteboardTypesForSelection];
        [pboard declareTypes:types owner:self];
        [webView writeSelectionWithPasteboardTypes:types toPasteboard:pboard];
    }
    else
    {
        [pboard declareTypes:nil owner:nil];
    }    
    
    
    NSArray *items = [self selectedItems];
         
    if ([[self dataSource] webEditor:self writeItems:items toPasteboard:pboard])
    {
        // Now let's start a-dragging!
        
        NSDragOperation op = ([item draggingSourceOperationMaskForLocal:NO] |
                              [item draggingSourceOperationMaskForLocal:YES]);
        if (op)
        {
            //NSPoint dragLocation;
            //NSImage *dragImage = [self dragImageForSelectionFromItem:item location:&dragLocation];
            
            //if (dragImage)
            {
                @try
                {
                    [[self documentView] dragImageForItem:item
                                                    event:event
                                               pasteboard:pboard
                                                   source:self];                    
                    /*[self dragImage:dragImage
                     at:dragLocation
                     offset:NSZeroSize
                     event:_mouseDownEvent
                     pasteboard:pboard
                     source:self
                     slideBack:YES];*/
                }
                @finally    // in case the drag throws an exception
                {
                    [self forgetDraggedItems];
                }
            }
        }
    }
}

/*  Actions we could take from this:
 *      - Deselect everything
 *      - Change selection to new item
 *      - Start editing selected item (actually happens upon -mouseUp:)
 *      - Add to the selection
 */
- (void)mouseDown:(NSEvent *)event;
{
    // Direct to target item
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    
    SVGraphicHandle handle;
    WEKWebEditorItem *item = [self itemHitTest:location handle:&handle];
    
    
    // Where's the click? Is it a selection handle? They trigger special resize event
    if (item && handle != kSVGraphicNoHandle)
    {
		[self resizeItem:item usingHandle:handle withEvent:event];
        return;
    }
    
    
    // Feed event through item if there is one
    if (item)
    {
        if (!_forwardedWebViewCommand)
        {
            // If no item chooses to handle it, want the event to fall through to appropriate bit of the webview
            NSView *fallbackView = [[self webView] hitTest:location];
            NSResponder *oldResponder = [_rootItem nextResponder];
            [_rootItem setNextResponder:fallbackView];
            @try
            {
                _forwardedWebViewCommand = _cmd;
                @try
                {
                    [item mouseDown:event]; // calls back through to this method if no item traps the event
                }
                @finally
                {
                    _forwardedWebViewCommand = NULL;
                }
            }
            @finally
            {
                [_rootItem setNextResponder:oldResponder];
            }
        }
        else
        {
            [self selectItem:item event:event];
            
            // If the item is non-inline, simulate -acceptsFirstResponder by making self the first responder
            if (![item shouldTrySelectingInline] || ![[item HTMLElement] isContentEditable])
            {
                [[self window] makeFirstResponder:self];
            }
        }
    }
    else
    {
        // If editing inside an item, the click needs to go straight through to the WebView; we were just claiming ownership of that area in order to gain control of the cursor
        if ([[self editingItems] count] > 0)
        {
            [self setEditingItems:nil];
            [NSApp sendEvent:event];    // this time round it'll go through to the WebView
            return;
        }
        else
        {
            // Don't really expect to hit this point. Since if there is no item at the location, we should never have hit-tested positively in the first place
            [super mouseDown:event];
        }
    }
}

- (void)mouseUp:(NSEvent *)theEvent;
{
    // Pass through to WebView if needed
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    WEKWebEditorItem *item = [self itemHitTest:location handle:NULL];
    
    if ([item allowsDirectAccessToWebViewWhenSelected])
    {
        [self forwardMouseEvent:theEvent selector:_cmd cachedTargetView:nil];
    }
    else
    {
        [super mouseUp:theEvent];
    }
}

- (void)mouseMoved:(NSEvent *)theEvent;
{
    NSPoint location = [self convertPoint:[theEvent locationInWindow] fromView:nil];
    
    
    // Is it a selection handle?
    SVGraphicHandle handle;
    WEKWebEditorItem *item = [self selectedItemAtPoint:location handle:&handle];
    if (item)
    {
        if (handle == kSVGraphicNoHandle)
        {
            [[NSCursor arrowCursor] set];
            
            
            // Continue with the event, but to WebView perhaps?
            if ([item allowsDirectAccessToWebViewWhenSelected])
            {
                [self forwardMouseEvent:theEvent selector:_cmd cachedTargetView:nil];
            }
            else
            {
                [super mouseMoved:theEvent];
            }
        }
        else
        {
            [[KSSelectionBorder cursorWithHandle:handle] set];
        }
    }
    else
    {
        // The event should really be targeted at WebView, so forward on there. It will probably bubble back up through us to superview. #101583
        [self forwardMouseEvent:theEvent selector:_cmd cachedTargetView:nil];
    }
}

- (void)mouseDragged:(NSEvent *)theEvent;
{
    // Send on to WebView. #98886
    [self forwardMouseEvent:theEvent selector:_cmd cachedTargetView:nil];
}

- (void)scrollWheel:(NSEvent *)theEvent
{
    // We're not personally interested in scroll events.
    // Want the main frame to handle them; NOT subframes as they're supposed to be contained by a graphic which isn't editing
    NSView *targetView = [[[[[self webView] mainFrame] frameView] documentView] enclosingScrollView];
    [self forwardMouseEvent:theEvent selector:_cmd cachedTargetView:targetView];
}

- (void)updateMouseoverWithFakeEvent;
{
    // WebKit doesn't seem to notice a flags changed event for editable links. We can force it to here
    if ([[self documentView] respondsToSelector:@selector(_updateMouseoverWithFakeEvent)])
    {
        [[self documentView] performSelector:@selector(_updateMouseoverWithFakeEvent)];
    }
}

- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)userData
{
    return NSLocalizedString(@"This image is a placeholder. Drag a new media file here to replace it.",
                             "tooltip");
}

#pragma mark Resizing

- (void)resizeItem:(WEKWebEditorItem *)item usingHandle:(SVGraphicHandle)handle withEvent:(NSEvent *)event;
{
    OBPRECONDITION(handle != kSVGraphicNoHandle);
    
    NSView *docView = [[item HTMLElement] documentView];
    KSSelectionBorder *border = [item newSelectionBorder];
    
    
    // Tell controllers not to draw selected during resize
    [self setNeedsDisplayForItem:item];
    
    
    BOOL resizeInline = [item shouldResizeInline];
    if (resizeInline)
    {
        // Take over drawing the cursor
        [_cursor release]; _cursor = [[KSSelectionBorder cursorWithHandle:handle] retain];
        _cursorPoint = [border locationOfHandle:handle frameRect:[item selectionFrame]];
        [docView setNeedsDisplayInRect:[_cursor ks_drawingRectForPoint:_cursorPoint]];
        
        CGAssociateMouseAndMouseCursorPosition(false);
        [NSCursor hide];
    }
    
    
    // Start the resize
    _resizingGraphic = YES;
    @try
    {
        while ([event type] != NSLeftMouseUp)
        {
            // Grab the next event
            event = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
            
            // Handle the event
            [docView autoscroll:event];
            handle = [item resizeUsingHandle:handle event:event];
            
            
            // Redraw the cursor in new position
            if (resizeInline)
            {
                [docView setNeedsDisplayInRect:[_cursor ks_drawingRectForPoint:_cursorPoint]];
                _cursorPoint = [border locationOfHandle:handle frameRect:[item selectionFrame]];
                [docView setNeedsDisplayInRect:[_cursor ks_drawingRectForPoint:_cursorPoint]];
            }
        }
    }
    @finally
    {
        _resizingGraphic = NO;
        
        if (resizeInline)
        {
            [_cursor release]; _cursor = nil;
            
            // Place the cursor in the right spot
            NSPoint point = [border locationOfHandle:handle frameRect:[item selectionFrame]];
            NSPoint basePoint = [[docView window] convertBaseToScreen:[docView convertPoint:point toView:nil]];
            
            NSScreen *screen = [[NSScreen screens] objectAtIndex:0];
            basePoint.y = [screen frame].size.height - basePoint.y;
            
            CGWarpMouseCursorPosition(NSPointToCGPoint(basePoint));
            
            CGAssociateMouseAndMouseCursorPosition(true);
            [NSCursor unhide];
        }
        else
        {
            // Update cursor for finish location
            [[NSCursor arrowCursor] set];
            [self mouseMoved:event];
        }
        
        [border release];
    }
    [self setNeedsDisplayForItem:item];
}

#pragma mark Dispatching Messages

- (void)forceWebViewToPerform:(SEL)action withObject:(id)sender;
{
    OBPRECONDITION(!_forwardedWebViewCommand);
    _forwardedWebViewCommand = action;
    @try
    {
        WebFrame *frame = [[self webView] selectedFrame];
        NSView *view = [[frame frameView] documentView];
        [view doCommandBySelector:action];
    }
    @finally
    {
        _forwardedWebViewCommand = NULL;
    }
}

#pragma mark Setting the DataSource/Delegate

@synthesize dataSource = _dataSource;

@synthesize delegate = _delegate;
- (void)setDelegate:(id <WEKWebEditorDelegate>)delegate
{
    if ([self delegate])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:[self delegate]
                                                        name:SVWebEditorViewDidChangeSelectionNotification
                                                      object:self];
        
        [[NSNotificationCenter defaultCenter] removeObserver:[self delegate]
                                                        name:kSVWebEditorViewWillChangeNotification
                                                      object:self];
    }
    
    _delegate = delegate;
    
    if (delegate)
    {
        [[NSNotificationCenter defaultCenter] addObserver:delegate
                                                 selector:@selector(webEditorDidChangeSelection:)
                                                     name:SVWebEditorViewDidChangeSelectionNotification
                                                   object:self];
        
        [[NSNotificationCenter defaultCenter] addObserver:delegate
                                                 selector:@selector(webEditorWillChange:)
                                                     name:kSVWebEditorViewWillChangeNotification
                                                   object:self];
    }
}

@synthesize draggingDestinationDelegate = _dragDelegate;

#pragma mark NSUserInterfaceValidations

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
	VALIDATION((@"%s %@",__FUNCTION__, anItem));
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
    
    // You can cut or copy as long as there is a selection (just hope the datasource comes through for us!)
    else if (action == @selector(cut:) || action == @selector(copy:))
    {
        result = ([[self selectedItems] count] >= 1 || [self selectedDOMRange]);
    }
    
    else if (action == @selector(alignLeft:) ||
             action == @selector(alignCenter:) ||
             action == @selector(alignRight:) ||
             action == @selector(alignJustified:))
    {
        id target = [[self firstResponderItem] ks_targetForAction:action];
        if (!target || target == self) return NO;
        
        result = YES;
        if ([target respondsToSelector:@selector(validateUserInterfaceItem:)])
        {
            result = [target validateUserInterfaceItem:anItem];
        }
    }
    
    else if ([self respondsToSelector:action])
    {
        result = (_forwardedWebViewCommand == NULL);
    }
    
    
    return result;
}

@end


#pragma mark -


@implementation WEKWebEditorView (WebDelegates)

#pragma mark WebFrameLoadDelegate

- (void)webView:(WebView *)sender didCommitLoadForFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        // The document has been created, DOM controllers can begin to be hooked up
        [[self contentItem] setAncestorNode:[frame DOMDocument] recursive:YES];
    }
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditor:self didReceiveTitle:title];
    }
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditorViewDidFinishLoading:self];
    }
}

- (void)webView:(WebView *)sender didClearWindowObject:(WebScriptObject *)windowObject forFrame:(WebFrame *)frame
{
	VALIDATION((@"%s %@",__FUNCTION__, frame));
	
	[windowObject setValue:self forKey:@"WEKWebEditorView"];

}


- (id)objectForWebScript
{
	VALIDATION((@"%s",__FUNCTION__));
    return self;
}

+ (NSString *)webScriptNameForSelector:(SEL)aSelector
{
	VALIDATION((@"%s %@",__FUNCTION__, NSStringFromSelector(aSelector)));
	if (aSelector == @selector(deselectDOMRange))
	{
		return @"deselectDOMRange";
	}
	return @"";
}

+ (BOOL)isSelectorExcludedFromWebScript:(SEL)aSelector
{
	VALIDATION((@"%s %@",__FUNCTION__, NSStringFromSelector(aSelector)));
    return (aSelector != @selector(deselectDOMRange));
}

- (void)deselectDOMRange
{
	VALIDATION((@"%s",__FUNCTION__));
    [self setEditingItems:nil];
	//[self setSelectedDOMRange:nil affinity:NSSelectionAffinityUpstream];
	//[[NSNotificationCenter defaultCenter] postNotificationName:WebViewDidChangeSelectionNotification object:self.webView];
}

#pragma mark WebFrameLoadDelegatePrivate

- (void)webView:(WebView *)sender didFirstLayoutInFrame:(WebFrame *)frame;
{
    OBPRECONDITION(sender == [self webView]);
    
    if (frame == [sender mainFrame])
    {
        [[self delegate] webEditorViewDidFirstLayout:self];
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
	[listener ignore];
    [[self delegate] webEditor:self handleNavigationAction:actionInformation request:request];
}

/*  We don't allow navigation, but our delegate may then decide to
 */
- (void)webView:(WebView *)sender decidePolicyForNavigationAction:(NSDictionary *)actionInformation
		request:(NSURLRequest *)request
		  frame:(WebFrame *)frame decisionListener:(id <WebPolicyDecisionListener>)listener
{
    if (frame != [sender mainFrame] || [self isStartingLoad])
    {
        // We want to allow initial loading of the webview…
        [listener use];
    }
    else
    {
        // …but after that navigation is undesireable
        [listener ignore];
        [[self delegate] webEditor:self handleNavigationAction:actionInformation request:request];
    }
}

#pragma mark WebResourceDelegate

- (NSURLRequest *)webView:(WebView *)sender resource:(id)identifier willSendRequest:(NSURLRequest *)request redirectResponse:(NSURLResponse *)redirectResponse fromDataSource:(WebDataSource *)dataSource
{
    return [[self delegate] webEditor:self
                      willSendRequest:request
                     redirectResponse:redirectResponse
                       fromDataSource:dataSource];
}

- (void)webView:(WebView *)sender resource:(id)identifier didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge fromDataSource:(WebDataSource *)dataSource
{
    // Don't ever want to prompt user for password. #99710
    [[challenge sender] continueWithoutCredentialForAuthenticationChallenge:challenge];
}

#pragma mark WebUIDelegate

- (NSArray *)webView:(WebView *)sender contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems
{
    NSArray *result = defaultMenuItems;
    
    // Ask editing item if it wants to do anything about this
    DOMNode *node = [element objectForKey:WebElementDOMNodeKey];
    WEKWebEditorItem *controller = [[self contentItem] hitTestDOMNode:node];
    if (controller)
    {
        result = [controller contextMenuItemsForElement:element defaultMenuItems:result];
    }
    
    return result;
}

/*  Generally the only drop action we support is for text editing. BUT, for an area of the WebView which our datasource has claimed for its own, need to disallow all actions
 */
- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)dragInfo
{
    //NSLog(@"-%@ dragInfo: %@", NSStringFromSelector(_cmd), dragInfo);
    
    
    NSUInteger result = WebDragDestinationActionNone;
    
    if (![[self webView] delegateWillHandleDraggingInfo])
    {
        result = WebDragDestinationActionDHTML | WebDragDestinationActionEdit;
                
        // Don't drop graphics into text areas which don't support it
        id source = [dragInfo draggingSource];
        if ([source isKindOfClass:[NSResponder class]] &&
            [self ks_followsResponder:source] &&
            [self selectedItem])
        {
            NSPoint location = [sender convertPointFromBase:[dragInfo draggingLocation]];
            DOMRange *range = [sender editableDOMRangeForPoint:location];
            if (range)
            {
                id <SVWebEditorText> controller = [self textItemForDOMRange:range];
                if (![controller webEditorTextValidateDrop:dragInfo])
                {
                    result = result - WebDragDestinationActionEdit;
                }
            }
        }
    }
    
    return result;
}

- (NSUInteger)webView:(WebView *)sender dragSourceActionMaskForPoint:(NSPoint)point;
{
    // #95354
    return (WebDragSourceActionDHTML | WebDragSourceActionSelection);
}

- (BOOL)webView:(WebView *)webView shouldPerformAction:(SEL)command fromSender:(id)fromObject;
{
    BOOL result = YES;
    
    
    // _forwardedWebViewCommand indicates that the command is already being processed by the Web Editor, so it's now up to the WebView to handle. Otherwise it's easy to get stuck in an infinite loop.
    if (_forwardedWebViewCommand) return result;
    
    
    
    // Does the text view want to take command?
    result = ![_focusedText webEditorTextDoCommandBySelector:command];
    
    // Is it a command which we handle? (our implementation may well call back through to the WebView when appropriate)
    if (result)
    {
        if (command == @selector(moveUp:) || command == @selector(moveDown:))
        {   // don't want these to go to self
        }
        
        else if (command == @selector(moveLeft:) || command == @selector(moveRight:))
        {
            // Handle ourselves
            [self doCommandBySelector:command];
            result = NO;
        }
        
        else if (command == @selector(cancelOperation:))
        {
            // End editing
            if ([[self editingItems] count])
            {
                [self setEditingItems:nil];
                //result = YES; // still let webkit do its default action too
            }
        }
        
        else if (command == @selector(removeFormat:))
        {
            // Get no other delegate method warning of impending change, so fake one here
            DOMRange *range = [self selectedDOMRange];
            if (!range || ![self shouldChangeTextInDOMRange:range])
            {
                result = NO;
                NSBeep();
            }
        }
        
        else if (command == @selector(delete:))
        {
            // For text, generally want WebView to handle it. But if there's an empty selection, nothing for WebKit to do so see if we can take over
            DOMRange *selection = [self selectedDOMRange];
            if ([selection collapsed])
            {
                [self delete:nil];
                result = NO;
            }
            else if (selection)
            {
                // WebKit BUG: -delete: doesn't ask permission of the delegate, so we must do so here
                [self webView:webView shouldDeleteDOMRange:selection];
            }
        }
        
        // Treat Shift-Return to insert a linebreak. #102658
        else if (command == @selector(insertNewline:) &&
                 [[[self window] currentEvent] modifierFlags] & NSShiftKeyMask)
        {
            [webView insertNewlineIgnoringFieldEditor:self];
            result = NO;
        }

        // Default Indent and Outdent implementations don't send -should… notifications, only -didChange…
        else if (command == @selector(indent:) || command == @selector(outdent:))
        {
            result = NO;

            DOMRange *range = [self selectedDOMRange];
            if (range) result = [self shouldChangeTextInDOMRange:[self selectedDOMRange]];

            if (!result) NSBeep();
        }
    }
    
    return result;
}

- (BOOL)webView:(WebView *)sender validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item defaultValidation:(BOOL)defaultValidation
{
	VALIDATION((@"%s %@",__FUNCTION__, item));
    //  On the whole, let WebKit get on with it. But, if WebKit can't handle the message, and we can, override to do so
    BOOL result = defaultValidation;
    SEL action = [item action];
    
    
    id target = [[self firstResponderItem] ks_targetForAction:action];
    if (target && target != self)
    {
        if ([target conformsToProtocol:@protocol(NSUserInterfaceValidations)])
        {
            result = [target validateUserInterfaceItem:item];
        }
    }
    else
    {
        if (!defaultValidation && [self respondsToSelector:action])
        {
            return [self validateUserInterfaceItem:item];
        }
        else if (result)
        {
            if (action == @selector(indent:) || action == @selector(outdent:))
            {
                // Seek out the list containing the selection
                if (action == @selector(indent:))
                {
                    NSNumber *shallow = [_editingController deepestListIndentLevel];
                    if ([shallow isKindOfClass:[NSNumber class]])
                    {
                        result = [shallow unsignedIntegerValue] < 9;
                    }
                }
                else
                {
                    NSNumber *shallow = [_editingController shallowestListIndentLevel];
                    if ([shallow isKindOfClass:[NSNumber class]])
                    {
                        result = [shallow unsignedIntegerValue] > 1;
                    }
                }
            }
        }
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
    
    // Only want to draw overlay in main frame
    WebFrame *mainFrame = [sender mainFrame];
    if ([drawingView isDescendantOf:[mainFrame frameView]])
    {
        for (WebFrame *aFrame in [mainFrame childFrames])
        {
            if ([drawingView isDescendantOf:[aFrame frameView]]) return; 
        }
        
        NSRect dirtyDrawingRect = [drawingView convertRect:dirtyRect fromView:sender];
        [self drawOverlayRect:dirtyDrawingRect inView:drawingView];
    }
}

- (void)webView:(WebView *)sender dragImage:(NSImage *)anImage at:(NSPoint)viewLocation offset:(NSSize)initialOffset event:(NSEvent *)event pasteboard:(NSPasteboard *)pboard source:(id)sourceObj slideBack:(BOOL)slideFlag forView:(NSView *)view;
{
    
    // Bulk up the pasteboard with any extra data
    NSArray *items = [self selectedItems];
    if ([items count])
    {
        [[self dataSource] webEditor:self writeItems:items toPasteboard:pboard];
    }
    
    
    // Also declare image
    DOMRange *selection = [self selectedDOMRange];
    if ([[selection text] length] == 0 &&
        [[self selectedItems] count] == 1)
    {
        WEKWebEditorItem *item = [self selectedItem];
        OBASSERT(item);
        
        DOMHTMLImageElement *image = (DOMHTMLImageElement*)[item HTMLElement];
        if ([image isKindOfClass:[DOMHTMLImageElement class]])
        {
            NSURL *URL = [image absoluteImageURL];
            if ([URL isFileURL])
            {
                [pboard addTypes:NSARRAY((NSString *)kUTTypeFileURL) owner:nil];
                [pboard setString:[URL absoluteString] forType:(NSString *)kUTTypeFileURL];
            }
        }
    }
    
    
    WEKWebEditorItem *selectedItem = [self selectedItem];
    if ([items count] == 1 &&
        [[self selectedDOMRange] ks_selectsNode:[selectedItem HTMLElement]])
    {
        [view dragImageForItem:selectedItem
                         event:event
                    pasteboard:pboard
                        source:sourceObj];
    }
    else
    {
        // Call to get _draggedItems populated
        [self draggedImage:anImage beganAt:viewLocation];
        
        @try
        {
            [view dragImage:anImage
                         at:viewLocation
                     offset:initialOffset
                      event:event 
                 pasteboard:pboard 
                     source:sourceObj
                  slideBack:slideFlag];
        }
        @finally
        {
            [self forgetDraggedItems];
        }
    }
}

#pragma mark WebEditingDelegate

- (BOOL)webView:(WebView *)webView shouldApplyStyle:(DOMCSSStyleDeclaration *)style toElementsInDOMRange:(DOMRange *)range
{
    return (range ? [self shouldChangeTextInDOMRange:range] : NO);
}

- (BOOL)webView:(WebView *)webView shouldBeginEditingInDOMRange:(DOMRange *)range
{
    id <SVWebEditorText> text = [self textItemForDOMRange:range];
    [self setFocusedText:text notification:nil];
    
    return YES;
}

- (BOOL)webView:(WebView *)webView shouldChangeSelectedDOMRange:(DOMRange *)currentRange
     toDOMRange:(DOMRange *)proposedRange affinity:(NSSelectionAffinity)selectionAffinity
 stillSelecting:(BOOL)stillSelecting;
{
    BOOL result = YES;
    BOOL rangeEdited = NO;
    DOMRange *range = proposedRange;
    
    
    
    // Select image if skipping over one. #77696
    if (_forwardedWebViewCommand == @selector(moveRight:) && currentRange && [currentRange collapsed])
    {
        DOMNode *oldNode = [currentRange ks_endNode:NULL];
        DOMNode *newNode = [proposedRange ks_startNode:NULL];
        if (oldNode != newNode)
        {
            DOMTreeWalker *walker = [[oldNode ownerDocument] createTreeWalker:[[oldNode parentNode] parentNode]
                                                                   whatToShow:DOM_SHOW_ALL
                                                                       filter:nil
                                                       expandEntityReferences:NO];
            [walker setCurrentNode:oldNode];
            
            // Walk to the proposed range, looking for images to select
            DOMNode *aNode = [walker nextNode];
            while (aNode && aNode != newNode)
            {
                WEKWebEditorItem *item = [self selectableItemForDOMNode:aNode];
                if (item)
                {
                    if ([item shouldTrySelectingInline])
                    {
                        [range selectNode:aNode]; rangeEdited = YES;
                        break;
                    }
                    
                    aNode = [walker nextSibling];
                }
                else
                {
                    aNode = [walker nextNode];
                }
            }
        }
    }
    else if (_forwardedWebViewCommand == @selector(moveLeft:) && currentRange && [currentRange collapsed])
    {
        DOMNode *oldNode = [currentRange ks_startNode:NULL];
        DOMNode *newNode = [proposedRange ks_endNode:NULL];
        if (oldNode != newNode)
        {
            DOMTreeWalker *walker = [[oldNode ownerDocument] createTreeWalker:[[oldNode parentNode] parentNode]
                                                                   whatToShow:DOM_SHOW_ALL
                                                                       filter:nil
                                                       expandEntityReferences:NO];
            [walker setCurrentNode:oldNode];
            
            // Walk to the proposed range, looking for images to select
            DOMNode *aNode = [walker previousNode];
            while (aNode && aNode != newNode)
            {
                WEKWebEditorItem *item = [self selectableItemForDOMNode:aNode];
                if (item)
                {
                    if ([item shouldTrySelectingInline])
                    {
                        [range selectNode:aNode]; rangeEdited = YES;
                        break;
                    }
                    
                    aNode = [walker previousSibling];   // not interested in child nodes
                }
                else
                {
                    aNode = [walker previousNode];
                }
            }
        }
    }
    
    
    
    // We only want a collapsed range to be selected by the mouse if it's within the bounds of the text (showing the text cursor)
    if (!proposedRange || [proposedRange collapsed])
    {
        NSEvent *event = [NSApp currentEvent];
        if ([event type] == NSLeftMouseDown ||
            [event type] == NSRightMouseDown ||
            [event type] == NSOtherMouseDown)
        {
            DOMNode *oldNode = [proposedRange startContainer];
            if (!oldNode || ![oldNode enclosingContentEditableElement])
            {
                range = nil;
                
                if ([oldNode nodeType] != DOM_TEXT_NODE)
                {
                    oldNode = [[oldNode childNodes] item:[proposedRange startOffset]];
                }
                
                if (oldNode)
                {
                    NSRect textBox = [oldNode boundingBox];

                    NSView *view = [oldNode documentView];
                    NSPoint location = [view convertPointFromBase:[event locationInWindow]];
                    
                    if ([view mouse:location inRect:textBox])
                    {
                        // There's no good text to select, so fall back to body
                        range = proposedRange;
                    }
                }
            }
        }
    }
    else
    {
        // When editing, constrain range to that item. #98052
        WEKWebEditorItem *editedItem = [[self editingItems] lastObject];
        if (editedItem)
        {
            // Build a total allowed range for selection during editing.
            // -[editedItem DOMRange] is undesireable as we only want *contents*
            // If the item contains a iframe, it's likely the proposed selection is for a different document to the item itself. If so, can't compare boundary points, so just go ahead and allow the selection. #102267
            
            DOMElement *element = [editedItem HTMLElement]; 
            DOMDocument *doc = [element ownerDocument];
            
            if (doc == [[range startContainer] ownerDocument])
            {
                DOMRange *editRange = [doc createRange];
                [editRange selectNodeContents:element];
                
                if ([editRange compareBoundaryPoints:DOM_END_TO_END sourceRange:range] >= 0)    // selection ends before/with item
                {
                    if ([editRange compareBoundaryPoints:DOM_START_TO_START sourceRange:range] <= 0)    // item encloses range
                    {
                        
                    }
                    else
                    {
                        if ([editRange compareBoundaryPoints:DOM_END_TO_START sourceRange:range] > 0)   // two non-intersecting ranges
                        {
                            
                        }
                        else
                        {
                            // Constrain range to start with item
                            [range setStart:[editRange startContainer] offset:[editRange startOffset]];
                            rangeEdited = YES;
                        }
                    }
                }
                else
                {
                    if ([editRange compareBoundaryPoints:DOM_START_TO_END sourceRange:range] > 0)   // two non-intersecting ranges
                    {
                        // Constrain range to start with item
                        [range setEnd:[editRange endContainer] offset:[editRange endOffset]];
                        rangeEdited = YES;
                    }
                }
            }
        }
    }
    
    
    // Ask text controller's permission
    if (result && range)
    {
        id <SVWebEditorText> textController = [self textItemForDOMRange:range];
        if (textController)
        {
            range = [textController webEditorSelectionDOMRangeForProposedSelection:range
                                                                          affinity:selectionAffinity
                                                                    stillSelecting:stillSelecting];
        }
    }
    
        
    
    //  Update -selectedItems to match. Make sure not to try and change the WebView's selection in turn or it'll all end in tears. It doesn't make sense to bother doing this if the selection change was initiated by ourself.
    if (!_isChangingSelectedItems && result)
    {
        NSArray *items = (range) ? [self selectableItemsInDOMRange:range] : nil;
        
        result = [self changeSelectionByDeselectingAll:YES
                                        orDeselectItem:nil
                                           selectItems:items
                                              DOMRange:range
                                            isUIAction:YES];
    }
    
    
    
    if (result)
    {
        // Did we adjust the range? If so, make that the one actually selected
        if (rangeEdited || range != proposedRange)
        {
            [self setSelectedDOMRange:range affinity:selectionAffinity];
            return NO;
        }
    }
    else
    {
        // If the selection is refused, revert back to no selection
        if (range && ![self textItemForDOMRange:range])
        {
            [self setSelectedDOMRange:nil affinity:0];
        }
    }
    
    
    return result;
}

- (BOOL)webView:(WebView *)webView shouldChangeTypingStyle:(DOMCSSStyleDeclaration *)currentStyle toStyle:(DOMCSSStyleDeclaration *)proposedStyle
{
    return [self shouldChangeTextInDOMRange:[self selectedDOMRange]];
}

- (BOOL)webView:(WebView *)webView shouldDeleteDOMRange:(DOMRange *)range
{
    // WebKit will quite happily delete embedded graphics when there is a collapsed selection, which we don't want. #95681
    DOMRange *selection = [self selectedDOMRange];
    if (selection && [selection collapsed])
    {
        // Forward delete?
        DOMNode *startNode = [range ks_startNode:NULL];
        if (startNode == [selection ks_endNode:NULL])
        {
            NSArray *items = [self selectableItemsInDOMRange:range];
            if ([items count])
            {
                WEKWebEditorItem *startItem = [items objectAtIndex:0];
                if ([startItem HTMLElement] == startNode)
                {
                    
                }
                else
                {
                    // Ony delete up to the start item please
                    [range setEndBefore:[startItem HTMLElement]];
                    
                    if ([self shouldChangeTextInDOMRange:range])
                    {
                        [range deleteContents];
                        [self didChangeText];
                        
                        [self changeSelectionByDeselectingAll:YES
                                               orDeselectItem:nil
                                                  selectItems:[NSArray arrayWithObject:startItem]
                                                     DOMRange:nil
                                                   isUIAction:YES];
                    }
                    
                    return NO;
                }
            }
        }
    }
    
    
    
    return [self shouldChangeTextInDOMRange:range];
}

- (BOOL)tryToPopulateNode:(DOMNode *)node withImagesFromPasteboard:(NSPasteboard *)pboard;
{
    // TODO: Could any of logic be shared with how media system imports images?
    
    BOOL result = NO;
    
    NSArray *items = [pboard sv_pasteboardItems];
    for (id <SVPasteboardItem> anItem in items)
    {
        NSURL *URL = [anItem URL];
        
        if ([URL isFileURL] &&
            [KSWORKSPACE ks_type:[KSWORKSPACE ks_typeOfFileAtURL:URL]
            conformsToOneOfTypes:[NSBitmapImageRep imageTypes]])
        {
            if (!result) [[node mutableChildDOMNodes] removeAllObjects];
            
            DOMHTMLImageElement *image = (DOMHTMLImageElement *)[[node ownerDocument] createElement:@"IMG"];
            [image setSrc:[URL absoluteString]];
            
            [node appendChild:image];
            result = YES;
        }
        else if ([anItem availableTypeFromArray:[NSBitmapImageRep imageTypes]])
        {
            // FIXME: Import as subresource using fake URL
        }
    }
    
    
    
    return result;
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)node replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEditText];
    
    
    // In the case of dragging text within the editor, WebKit should ask our permission to edit the source range too, but doesn't in my testing. #92432. We'll have to fake it until Apple make it!
    if (result)
    {
        NSPasteboard *pboard = nil;
        if (action == WebViewInsertActionDropped) pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
        if (action == WebViewInsertActionPasted) pboard = [NSPasteboard generalPasteboard];
        
        if (pboard)
        {
            DOMRange *selection = [self selectedDOMRange];
            if (selection) result = [self webView:webView shouldDeleteDOMRange:selection];
            
            if (result)
            {
                // Import images off the pboard. #103882
                // But not if there's a web archive there, because WebKit will handle that right
                if (![pboard availableTypeFromArray:NSARRAY((NSString *)kUTTypeWebArchive, WebArchivePboardType)])
                {
                    [self tryToPopulateNode:node withImagesFromPasteboard:pboard];
                }
            }
        }
    }
     
    
    if (result)
    {
        id <SVWebEditorText> text = [self textItemForDOMRange:range];
        
        // Let the text object decide
        result = [text webEditorTextShouldInsertNode:node
                                   replacingDOMRange:range
                                         givenAction:action];
    }
    
    
    // Check if the change is generally OK
    if (result) result = [self shouldChangeTextInDOMRange:range];
    
    
    return result;
}

- (BOOL)webView:(WebView *)webView shouldInsertText:(NSString *)string replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEditText];
    
    
    // In the case of dragging text within the editor, WebKit should ask our permission to edit the source range too, but doesn't in y testing. #92432. We'll have to fake it until Apple make it!
    if (result)
    {
        if (action == WebViewInsertActionDropped)
        {
            result = [self webView:webView shouldDeleteDOMRange:[self selectedDOMRange]];
        }
    }
    
    
    if (result)
    {
        id <SVWebEditorText> text = [self textItemForDOMRange:range];
        if (text)
        {
            // Let the text object decide
            result = [text webEditorTextShouldInsertText:string
                                       replacingDOMRange:range
                                             givenAction:action];
        }
    }
    
    if (result) result = [self shouldChangeTextInDOMRange:range];;
    return result;
}

- (void)webViewDidChange:(NSNotification *)notification;
{
    // Process change
    [self didChangeText];
    
    // Bring the change into view #80762
    //[[self webView] centerSelectionInVisibleArea:self];
}

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    WebView *webView = [self webView];
    OBPRECONDITION([notification object] == webView);
    
    
    // Let focused text know its selection has changed
    [[self focusedText] webEditorTextDidChangeSelection:notification];
    
    
    // Alert observers
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditorViewDidChangeSelectionNotification
                                                        object:self];
}

- (void)webViewDidEndEditing:(NSNotification *)notification
{
    [self setFocusedText:nil notification:notification];
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)command
{
    return ![self webView:webView shouldPerformAction:command fromSender:nil];
}

#pragma mark WebEditingDelegate Private

- (void)webView:(WebView *)webView didSetSelectionTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    [[self focusedText] webEditorTextDidSetSelectionTypesForPasteboard:pasteboard];
}

- (void)webView:(WebView *)webView didWriteSelectionToPasteboard:(NSPasteboard *)pasteboard
{
    [[self focusedText] webEditorTextDidWriteSelectionToPasteboard:pasteboard];
}

@end


/*  SEP - Somebody Else's Problem
*/