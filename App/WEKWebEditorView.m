//
//  SVWebViewContainerView.m
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "WEKWebEditorView.h"

#import "WEKWebView.h"
#import "WEKRootItem.h"
#import "SVWebEditorTextRange.h"
#import "WEKWebKitPrivate.h"

#import "KTApplication.h"
#import "SVDocWindow.h"
#import "SVLink.h"
#import "SVLinkManager.h"
#import "SVSelectionBorder.h"

#import "ESCursors.h"

#import "DOMNode+Karelia.h"
#import "DOMRange+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSEvent+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "WebView+Karelia.h"


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

@property(nonatomic, copy) NSArray *selectionParentItems;


// Getting Item Information
- (NSArray *)selectableAncestorsForItem:(WEKWebEditorItem *)item includeItem:(BOOL)includeItem;


// Event handling
- (void)forwardMouseEvent:(NSEvent *)theEvent selector:(SEL)selector;


// Undo
- (NSUndoManager *)webViewUndoManager;

@end


#pragma mark -


@implementation WEKWebEditorView

#pragma mark Initialization & Deallocation

- (id)initWithFrame:(NSRect)frameRect
{
    [super initWithFrame:frameRect];
    
    
    // ivars
    _rootItem = [[WEKRootItem alloc] init];
    [_rootItem setWebEditor:self];
    
    _selectedItems = [[NSMutableArray alloc] init];
    
    
    // WebView
    _webView = [[WEKWebView alloc] initWithFrame:[self bounds]];
    [_webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [_webView setShouldCloseWithWindow:YES];    // seems correct for a doc-based app
    
    NSScrollView *scrollView = [[[[_webView mainFrame] frameView] documentView] enclosingScrollView];
    if ([scrollView respondsToSelector:@selector(setVerticalScrollingMode:)])
    {
        [scrollView setVerticalScrollingMode:ScrollbarAlwaysOn];
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
    
    
    // Behaviour
    [self setLiveEditableAndSelectableLinks:YES];
    
    
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

- (void)viewDidMoveToWindow
{
    if ([self window])
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didSendFlagsChangedEvent:)
                                                     name:KTApplicationDidSendFlagsChangedEvent
                                                   object:[KTApplication sharedApplication]];
    }
}

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if ([self window])
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:KTApplicationDidSendFlagsChangedEvent
                                                      object:[KTApplication sharedApplication]];
    }
}

- (void)dealloc
{
    [_rootItem setWebEditor:nil];
    [_rootItem release];
    
    [_selectedItems release];
    OBASSERT(!_changingTextController);
    
    [_webView close];
    [_webView release];
        
    [super dealloc];
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
    [[[self webView] mainFrame] loadHTMLString:string baseURL:URL];
    _isStartingLoad = NO;
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

@synthesize rootItem = _rootItem;

#pragma mark Text Selection

- (DOMRange *)selectedDOMRange
{
    DOMRange *result = [[self webView] selectedDOMRange];
    return result;
}

- (void)setSelectedDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)selectionAffinity;
{
    [[self webView] setSelectedDOMRange:range affinity:selectionAffinity];
}

- (SVWebEditorTextRange *)selectedTextRange;
{
    DOMRange *domRange = [self selectedDOMRange];
    if (!domRange) return nil;
    
    
    WEKWebEditorItem *startItem = [[self rootItem] hitTestDOMNode:[domRange startContainer]];
    while (startItem && ![startItem representedObject])
    {
        startItem = [startItem parentWebEditorItem];
    }
    
    
    WEKWebEditorItem *endItem = [[self rootItem] hitTestDOMNode:[domRange endContainer]];
    while (endItem && ![endItem representedObject])
    {
        endItem = [endItem parentWebEditorItem];
    }
    
    
    SVWebEditorTextRange *result = [SVWebEditorTextRange rangeWithDOMRange:domRange
                                                              startElement:[startItem HTMLElement]
                                                                    object:[startItem representedObject]
                                                                endElement:[endItem HTMLElement]
                                                                    object:[endItem representedObject]];
    return result;
}

- (void)setSelectedTextRange:(SVWebEditorTextRange *)textRange affinity:(NSSelectionAffinity)affinity;
{
    DOMRange *domRange = [[self HTMLDocument] createRange];
    
    id startObject = [textRange startObject];
    id endObject = [textRange endObject];
    
    if (startObject && endObject)
    {
        WEKWebEditorItem *startItem = [[self rootItem] hitTestRepresentedObject:startObject];
        if (startItem)
        {
            WEKWebEditorItem *endItem = [[self rootItem] hitTestRepresentedObject:endObject];
            if (endItem)
            {
                [textRange populateDOMRange:domRange
                           withStartElement:[startItem HTMLElement]
                                 endElement:[endItem HTMLElement]];
            
                [self setSelectedDOMRange:domRange affinity:affinity];
            }
        }
    }
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
- (void)setSelectedItems:(NSArray *)items
{
    [self selectItems:items byExtendingSelection:NO];
}

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
    NSArray *currentSelection = [self selectedItems];
    BOOL itemIsSelected = [currentSelection containsObjectIdenticalTo:item];
    
    
    // Depending on the command key, add/remove from the selection, or become the selection. 
    if ([event modifierFlags] & NSCommandKeyMask)
    {
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
        [self selectItems:[NSArray arrayWithObject:item] byExtendingSelection:NO isUIAction:YES];
        
        if (itemIsSelected)
        {
            // If you click an aready selected item quick enough, it will start editing
            _mouseUpMayBeginEditing = YES;
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

- (BOOL)changeSelectedItemsFromDOMRange:(DOMRange *)proposedRange
{
    NSArray *items = (proposedRange) ? [self selectableItemsInDOMRange:proposedRange] : nil;
    
    return [self changeSelectionByDeselectingAll:YES
                                  orDeselectItem:nil
                                     selectItems:items
                                        DOMRange:proposedRange
                                      isUIAction:YES];
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
        if (proposedSelection)  // slightly odd looking logic, but handles possibility of _selectedItems being nil
        {
            [proposedSelection addObjectsFromArray:itemsToSelect];
        }
        else
        {
            proposedSelection = [itemsToSelect mutableCopy];
        }
    }
    
    
    
    //  If needed, check the new selection with the delegate.
    if (consultDelegateFirst && ![[self delegate] webEditor:self shouldChangeSelection:proposedSelection])
	{
		[proposedSelection release];
		return NO;
	}

    
    
    
    //  Remove items, including marking them for display. Could almost certainly be more efficient
    if (itemsToDeselect)
    {
        for (WEKWebEditorItem *anItem in itemsToDeselect)
        {
            [anItem setSelected:NO];
        }
    }
    
    
    
    //  Store new selection. MUST be performed after marking deselected items for display otherwise itemsToDeselect loses its objects somehow
    [_selectedItems release]; _selectedItems = proposedSelection;
    
    
    
    //  Add new items to the selection.
    if (itemsToSelect)
    {
        // Draw new selection
        for (WEKWebEditorItem *anItem in itemsToSelect)
        {
            [anItem setSelected:YES];
        }
    }
    
    
    
    // Update WebView selection to match. Selecting the node would be ideal, but WebKit ignores us if it's not in an editable area
    WEKWebEditorItem *selectedItem = [self selectedItem];
    if (!domRange)
    {
        if (selectedItem)
        {
            DOMHTMLElement *domElement = [selectedItem HTMLElement];
            
            DOMCSSStyleDeclaration *style = [[self webView] computedStyleForElement:domElement
                                                                      pseudoElement:nil];
            
            if ([[style display] isEqualToString:@"inline"] && [domElement isContentEditable])
            {
                [[self window] makeFirstResponder:[domElement documentView]];
                
                DOMRange *range = [[domElement ownerDocument] createRange];
                [range selectNode:domElement];
                [self setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
            }
            else
            {
                [[self window] makeFirstResponder:self];
            }
        }
        
        // There's no selected items left, so move cursor to left of deselected item
        else if (itemToDeselect)
        {
            DOMElement *element = [itemToDeselect HTMLElement];
            DOMRange *range = [[element ownerDocument] createRange];
            [range setStartBefore:element];
            [range collapse:YES];
            [self setSelectedDOMRange:range affinity:NSSelectionAffinityDownstream];
        }
    }
    
    
    // Update parentItems list
    NSArray *parentItems = nil;
    if (selectedItem)
    {
        parentItems = [self selectableAncestorsForItem:selectedItem includeItem:NO];
    }
    else
    {
        DOMNode *selectionNode = [domRange commonAncestorContainer];
        if (selectionNode)
        {
            WEKWebEditorItem *parent = [self selectableItemForDOMNode:selectionNode];
            if (parent)
            {
                parentItems = [self selectableAncestorsForItem:parent includeItem:YES];
            }
        }
    }
    
    [self setSelectionParentItems:parentItems];
    
    
}
@finally
{
    // Finish bracketing
    _isChangingSelectedItems = NO;
}   
    
    
    // Alert observers
    [[NSNotificationCenter defaultCenter] postNotificationName:SVWebEditorViewDidChangeSelectionNotification
                                                        object:self];
    
    
    return YES;
}

@synthesize selectionParentItems = _selectionParentItems;
- (void)setSelectionParentItems:(NSArray *)items
{
    // Let them know
    [[self selectionParentItems] setBool:NO forKey:@"editing"];
    [items setBool:YES forKey:@"editing"];
    
    // Store items
    items = [items copy];
    [_selectionParentItems release]; _selectionParentItems = items;
}

#pragma mark Keyboard-Induced selection

/*!
 These methods check to see if the move command should in fact select a graphic (like Pages does). If so, they perform that selection and return YES. Otherwise, do nothing and return NO.
 */

- (BOOL)tryToSelectItemByMovingLeft;
{
    BOOL result = NO;
    
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        // Is there a next node to select? (there isn't if selection is mid-text or the first child)
        DOMNode *previousNode = nil;
        
        DOMNode *selectionStart = [selection startContainer];
        int startOffset = [selection startOffset];
        
        if ([selectionStart nodeType] == DOM_TEXT_NODE)
        {
            if (startOffset == 0) previousNode = [selectionStart previousSibling];
        }
        else if (startOffset >= 1)  // use different technique to -tryToSelectItemByMovingRight to handle startOffset being *after*
        {                           // the last child node
            previousNode = [[selectionStart childNodes] item:(startOffset - 1)];
        }
        
        
        // Great, found a node to perhaps select – does it correspond to a selectable item?
        if (previousNode)
        {
            WEKWebEditorItem *item = [self selectableItemForDOMNode:previousNode];
            if (item)
            {
                result = [self changeSelectionByDeselectingAll:YES
                                                orDeselectItem:nil
                                                   selectItems:[NSArray arrayWithObject:item]
                                                      DOMRange:nil
                                                    isUIAction:YES];
            }
        }
    }
    
    return result;
}

- (BOOL)tryToSelectItemByMovingRight;
{
    BOOL result = NO;
    
    DOMRange *selection = [self selectedDOMRange];
    if ([selection collapsed])
    {
        // Is there a next node to select? (there isn't if selection is mid-text or the last child)
        DOMNode *nextNode = nil;
        
        DOMNode *selectionEnd = [selection endContainer];
        if ([selectionEnd nodeType] == DOM_TEXT_NODE)
        {
            if ([[selectionEnd nodeValue] length] == [selection endOffset])
            {
                nextNode = [selectionEnd nextSibling];
            }
        }
        else
        {
            nextNode = [[selectionEnd childNodes] item:[selection endOffset]];
        }
        
        
        // Great, found a node to perhaps select – does it correspond to a selectable item?
        if (nextNode)
        {
            WEKWebEditorItem *item = [self selectableItemForDOMNode:nextNode];
            if (item)
            {
                result = [self changeSelectionByDeselectingAll:YES
                                                orDeselectItem:nil
                                                   selectItems:[NSArray arrayWithObject:item]
                                                      DOMRange:nil
                                                    isUIAction:YES];
            }
        }
    }
    
    return result;
}

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

- (BOOL)shouldChangeTextInDOMRange:(DOMRange *)range;   // calls -willChange when returning YES.
{
    // Dissallow edits outside the current text area
    BOOL result = YES;
    
    DOMRange *selection = [self selectedDOMRange];
    if (selection)  // allow any edit if there is no selection
    {
        WEKWebEditorItem *textController = [self textItemForDOMRange:[self selectedDOMRange]];
        
        DOMNode *editingNode = [range commonAncestorContainer];
        result = [editingNode isDescendantOfNode:[textController HTMLElement]];
    }
    
    
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
    
    _changingTextController = textController;
    
    return YES;
}

- (void)didChangeText;  // posts kSVWebEditorViewDidChangeNotification
{
    [_changingTextController webEditorTextDidChange];
    _changingTextController = nil;
    
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

- (WEKWebEditorItem *)selectableItemForDOMNode:(DOMNode *)nextNode;
{
    OBPRECONDITION(nextNode);
    WEKWebEditorItem *result = nil;
    
    
    // Look for children at the deepest possible level (normally top-level). Keep backing out until we find something of use
    
    result = [[self rootItem] hitTestDOMNode:nextNode];
    while (result && ![result isSelectable])
    {
        result = [result parentWebEditorItem];
    }
    
    
    // We've found the deepest selectable item, but does it have a parent that should be selected instead?
    WEKWebEditorItem *parent = [result parentWebEditorItem];
    while (parent)
    {
        // Give up searching if we've hit the selection's parent items
        if ([[self selectionParentItems] containsObjectIdenticalTo:parent]) break;
        
        if ([parent isSelectable]) result = parent;
        parent = [parent parentWebEditorItem];
    }
    
    
    return result;
}

- (NSArray *)selectableItemsInDOMRange:(DOMRange *)range
{
    if ([range collapsed]) return nil;  // shortcut
    
    
    // Locate the controller for the text area so we can query it for selectable stuff
    WEKWebEditorItem <SVWebEditorText> *textController = [self textItemForDOMRange:range];
    
    if (textController)
    {
        NSMutableArray *result = [NSMutableArray array];
        
        for (WEKWebEditorItem *anItem in [textController selectableTopLevelDescendants])
        {
            DOMHTMLElement *element = [anItem HTMLElement];
            if ([element parentNode] && [range containsNode:element])   // weed out any obvious ophans
            {
                [result addObject:anItem];
            }
        }
        
        return result;
    }
    
    return nil;
}

- (NSArray *)selectableAncestorsForItem:(WEKWebEditorItem *)item includeItem:(BOOL)includeItem;
{
    OBPRECONDITION(item);
    
    NSArray *result = [item selectableAncestors];
    if (includeItem)
    {
        OBASSERT(result);
        result = [result arrayByAddingObject:item];
    }
    
    return result;
}

- (WEKWebEditorItem *)selectedItemAtPoint:(NSPoint)point handle:(SVGraphicHandle *)outHandle;
{
    // Like -selectableItemAtPoint:, but only looks at selection, and takes graphic handles into account
    
    SVSelectionBorder *border = [[[SVSelectionBorder alloc] init] autorelease];
    [border setMinSize:NSMakeSize(5.0f, 5.0f)];
    
    WEKWebEditorItem *result = nil;
    for (result in [self selectedItems])
    {
        [border setResizingMask:[result resizingMask]];
        
        NSView *docView = [[result HTMLElement] documentView];
        NSRect frame = [border frameRectForGraphicBounds:[[result HTMLElement] boundingBox]];
        
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
        WEKWebEditorItem *item = [[self rootItem] hitTestDOMNode:_dragHighlightNode];
        NSRect dropRect = [item boundingBox];    // pretending it's a node
        
        [[NSColor aquaColor] setFill];
        NSFrameRectWithWidth(dropRect, 1.0f);
    }
    
    
    // Draw selection
    [self drawSelectionRect:dirtyRect inView:view];
    
    // Draw drag caret
    [self drawDragCaretInView:view];
}

- (void)drawSelectionRect:(NSRect)dirtyRect inView:(NSView *)view;
{
    SVSelectionBorder *border = [[SVSelectionBorder alloc] init];
    [border setMinSize:NSMakeSize(5.0f, 5.0f)];
    
    
    // Draw selection parent items
    for (WEKWebEditorItem *anItem in [self selectionParentItems])
    {
        // Draw the item if it's in the dirty rect (otherwise drawing can get pretty pricey)
        [border setEditing:YES];
        NSRect frameRect = [[anItem HTMLElement] boundingBox];
        NSRect drawingRect = [border drawingRectForGraphicBounds:frameRect];
        if ([view needsToDrawRect:drawingRect])
        {
            [border drawWithGraphicBounds:frameRect inView:view];
        }
    }
    
    
    // Draw actual selection
    [border setEditing:NO];
    for (WEKWebEditorItem *anItem in [self selectedItems])
    {
        [anItem drawRect:dirtyRect inView:view];
    }
    
    
    // Tidy up
    [border release];
}

- (BOOL)inLiveGraphicResize; { return _resizingGraphic; }

#pragma mark Event Handling

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
        
        if ([item allowsDirectAccessToWebViewWhenSelected] && handle == kSVGraphicNoHandle)
		{
            
        }
        else
        {
            // Handles should *always* be selectable, but otherwise, pass through to -selectableItemAtPoint: so as to take hyperlinks into account
            if (!item || handle == kSVGraphicNoHandle) 
            {
                item = [self selectableItemAtPoint:point];
            }
            
            if (item)
            {
                if (![[self selectionParentItems] containsObject:item])
                {
                    result = self;
                }
            }
            else if ([[self selectionParentItems] count] > 0)
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

- (void)resizeItem:(WEKWebEditorItem *)item usingHandle:(SVGraphicHandle)handle withEvent:(NSEvent *)event
{
    OBPRECONDITION(handle != kSVGraphicNoHandle);
    
    
    // Tell controllers not to draw selected during resize
    _resizingGraphic = YES;
    
    NSArray *selection = [self selectedItems];
    [selection setValue:[NSNumber numberWithBool:NO] forKey:@"selected"];
    
    
    while ([event type] != NSLeftMouseUp)
    {
        // Handle the event
        event = [[self window] nextEventMatchingMask:(NSLeftMouseDraggedMask | NSLeftMouseUpMask)];
        [[self documentView] autoscroll:event];
        NSPoint handleLocation = [[[item HTMLElement] documentView] convertPoint:[event locationInWindow] 
                                                                        fromView:nil];
        handle = [item resizeByMovingHandle:handle toPoint:handleLocation];
    }
    
    _resizingGraphic = NO;
    
    // Tell controllers they're selected again
    [selection setValue:[NSNumber numberWithBool:YES] forKey:@"selected"];
    
    // Update cursor for finish location
    [[NSCursor arrowCursor] set];
    [self mouseMoved:event];
}

- (void)dragImageForEvent:(NSEvent *)theEvent
{
    if (!_mouseDownEvent) return;   // otherwise we initiate a drag multiple times!
    
    
    
    
    //  Ideally, we'd place onto the pasteboard:
    //      Sandvox item info, everything, else, WebKit, does, normally
    //
    //  -[WebView writeElement:withPasteboardTypes:toPasteboard:] would seem to be ideal for this, but it turns out internally to fall back to trying to write the selection to the pasteboard, which is definitely not what we want. Fortunately, it boils down to writing:
    //      Sandvox item info, WebArchive, RTF, plain text
    //
    //  Furthermore, there arises the question of how to handle multiple items selected. WebKit has no concept of such a selection so couldn't help us here, even if it wanted to. Should we try to string together the HTML/text sections into one big lump? Or use 10.6's ability to write multiple items to the pasteboard?
    
    NSPasteboard *pboard = [NSPasteboard pasteboardWithName:NSDragPboard];
    
    
    NSArray *types = [[self webView] pasteboardTypesForSelection];
    [pboard declareTypes:types owner:self];
    [[self webView] writeSelectionWithPasteboardTypes:types toPasteboard:pboard];
    
    
    if ([[self dataSource] webEditor:self addSelectionToPasteboard:pboard])
    {
        // Now let's start a-dragging!
        WEKWebEditorItem *item = [self selectedItem]; // FIXME: use the item actually being dragged
        
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
                                                    event:theEvent
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
    
    
    // A drag of the mouse automatically removes the possibility that editing might commence
    [_mouseDownEvent release],  _mouseDownEvent = nil;
}

/*  Actions we could take from this:
 *      - Deselect everything
 *      - Change selection to new item
 *      - Start editing selected item (actually happens upon -mouseUp:)
 *      - Add to the selection
 */
- (void)mouseDown:(NSEvent *)event;
{
    // Store the event for a bit (for draging, editing, etc.). Note that we're not interested in it while editing
    [_mouseDownEvent release];
    _mouseDownEvent = [event retain];
    
    
    
    // Where's the click?
    NSPoint location = [self convertPoint:[event locationInWindow] fromView:nil];
    
    
    // Is it a selection handle?
    SVGraphicHandle handle;
    WEKWebEditorItem *item = [self selectedItemAtPoint:location handle:&handle];
    if (item && handle != kSVGraphicNoHandle)
    {
		[self resizeItem:item usingHandle:handle withEvent:event];
        [_mouseDownEvent release]; _mouseDownEvent = nil;
		return;
    }
    
    
    // What was clicked? We want to know top-level object
    if (!item) item = [self selectableItemAtPoint:location];
      
    if (item)
    {
        [self selectItem:item event:event];
        
        // If mousing down on an image, pass the event through
        if ([item allowsDirectAccessToWebViewWhenSelected]) [NSApp postEvent:event atStart:YES];
        
        
        
        if ([[[item HTMLElement] documentView] _web_dragShouldBeginFromMouseDown:event withExpiration:[NSDate distantFuture]])
        {
            [self dragImageForEvent:event];
        }
    }
    else
    {
        // If editing inside an item, the click needs to go straight through to the WebView; we were just claiming ownership of that area in order to gain control of the cursor
        if ([[self selectionParentItems] count] > 0)
        {
            [self setSelectionParentItems:nil];
            [_mouseDownEvent release]; _mouseDownEvent = nil;
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

- (void)mouseUp:(NSEvent *)mouseUpEvent
{
    if (_mouseDownEvent)
    {
        NSEvent *mouseDownEvent = [_mouseDownEvent retain];
        [_mouseDownEvent release],  _mouseDownEvent = nil;
        
        
        // Was the mouse up quick enough to start editing? If so, it's time to hand off to the webview for editing.
        if (_mouseUpMayBeginEditing && [mouseUpEvent timestamp] - [mouseDownEvent timestamp] < 0.5)
        {
            // Is the item at that location supposed to be for editing?
            NSPoint location = [[self webView] convertPoint:[mouseUpEvent locationInWindow] fromView:nil];
            NSDictionary *element = [[self webView] elementAtPoint:location];
            DOMNode *nextNode = [element objectForKey:WebElementDOMNodeKey];
            
            WEKWebEditorItem *item = [[self selectedItem] hitTestDOMNode:nextNode];
            
            
            
            if (item != [self selectedItem] ||
                [item conformsToProtocol:@protocol(SVWebEditorText)] && [item isEditable])
            {
                // Repost equivalent events so they go to their correct target. Can't call -sendEvent: as that doesn't update -currentEvent
                // Note that they're posted in reverse order since I'm placing onto the front of the queue.
                // To stop the events being repeatedly posted back to ourself, have to indicate to -hitTest: that it should target the WebView. This can best be done by switching selected item over to editing
                NSArray *items = [[self selectedItems] copy];
                [self setSelectedItems:nil];
                [self setSelectionParentItems:items];    // should only be 1
                [items release];
                
                [NSApp postEvent:[mouseUpEvent eventWithClickCount:1] atStart:YES];
                [NSApp postEvent:[mouseDownEvent eventWithClickCount:1] atStart:YES];
            }
        }
        
        
        // Tidy up
        [mouseDownEvent release];
        _mouseUpMayBeginEditing = NO;
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
            [super mouseMoved:theEvent];
        }
        else
        {
            CGFloat radians = 0.0;
            switch(handle)
            {
                    // We might want to consider using angled size cursors  even for middle handles to show that you are resizing both dimensions?
                    
                case kSVGraphicUpperLeftHandle:		radians = M_PI_4 + M_PI_2;			break;
                case kSVGraphicUpperMiddleHandle:	radians = M_PI_2;					break;
                case kSVGraphicUpperRightHandle:	radians = M_PI_4;					break;
                case kSVGraphicMiddleLeftHandle:	radians = M_PI;						break;
                case kSVGraphicMiddleRightHandle:	radians = M_PI;						break;
                case kSVGraphicLowerLeftHandle:		radians = M_PI + M_PI_4;			break;
                case kSVGraphicLowerMiddleHandle:	radians = M_PI + M_PI_2;			break;
                case kSVGraphicLowerRightHandle:	radians = M_PI + M_PI_2 + M_PI_4;	break;
                default: break;
            }
            [[ESCursors straightCursorForAngle:radians withSize:16.0] set];
        }
    }
    else
    {
        [super mouseMoved:theEvent];
    }
}

// -mouseDragged: is over in the Dragging category

- (void)scrollWheel:(NSEvent *)theEvent
{
    // We're not personally interested in scroll events, let content have a crack at them.
    [self forwardMouseEvent:theEvent selector:_cmd];
}

- (void)didSendFlagsChangedEvent:(NSNotification *)notification
{
    // WebKit doesn't seem to notice a flags changed event for editable links. We can force it to here
    if ([[self documentView] respondsToSelector:@selector(_updateMouseoverWithFakeEvent)])
    {
        [[self documentView] performSelector:@selector(_updateMouseoverWithFakeEvent)];
    }
}

#pragma mark Dispatching Messages

- (void)forceWebViewToPerform:(SEL)action withObject:(id)sender;
{
    OBPRECONDITION(!_isForwardingCommandToWebView);
    _isForwardingCommandToWebView = YES;
    
    WebFrame *frame = [[self webView] selectedFrame];
    NSView *view = [[frame frameView] documentView];
    [view doCommandBySelector:action];
    
    _isForwardingCommandToWebView = NO;
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
                                                 selector:@selector(webEditorViewDidChangeSelection:)
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
    
    else if ([self respondsToSelector:action])
    {
        result = !_isForwardingCommandToWebView;
    }
    
    
    return result;
}

@end


#pragma mark -


@implementation WEKWebEditorView (WebDelegates)

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
        [[self delegate] webEditor:self didReceiveTitle:title];
    }
}

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
    if ([self isStartingLoad])
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

#pragma mark WebUIDelegate

/*  Generally the only drop action we support is for text editing. BUT, for an area of the WebView which our datasource has claimed for its own, need to dissallow all actions
 */
- (NSUInteger)webView:(WebView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)dragInfo
{
    //NSLog(@"-%@ dragInfo: %@", NSStringFromSelector(_cmd), dragInfo);
    
    
    NSUInteger result = WebDragDestinationActionNone;
    
    if (![[self webView] delegateWillHandleDraggingInfo])
    {
       result = [[self dataSource] webEditor:self dragDestinationActionMaskForDraggingInfo:dragInfo];
        
        
        // Update drag highlight to match
        DOMNode *dropNode = nil;
        if (result & WebDragDestinationActionEdit)
        {
            // Locate the DOM controller/item for the destination
            NSPoint point = [sender convertPointFromBase:[dragInfo draggingLocation]];
            DOMRange *editingRange = [sender editableDOMRangeForPoint:point];
            
            if (editingRange)
            {
                WEKWebEditorItem <SVWebEditorText> *controller =
                [self textItemForDOMRange:editingRange];
                
                
                // Controller's HTML element determines where to draw the drop highlight
                if (result > NSDragOperationNone) dropNode = [controller HTMLElement];
            }
        }
        [self moveDragHighlightToDOMNode:dropNode];
    }
    
    return result;
}

- (BOOL)webView:(WebView *)sender shouldPerformAction:(SEL)action fromSender:(id)fromObject;
{
    // Give focused text a chance
    BOOL result = ![_focusedText tryToPerform:action with:fromObject];
    return result;
}

- (BOOL)webView:(WebView *)sender validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)item defaultValidation:(BOOL)defaultValidation
{
    //  On the whole, let WebKit get on with it. But, if WebKit can't handle the message, and we can, override to do so
    BOOL result = defaultValidation;
    SEL action = [item action];
    
    
    id target = [_focusedText ks_targetForAction:action];
    if (target)
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

- (BOOL)webView:(WebView *)webView shouldApplyStyle:(DOMCSSStyleDeclaration *)style toElementsInDOMRange:(DOMRange *)range
{
    return [self shouldChangeTextInDOMRange:range];
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
    DOMRange *range = currentRange;
    
    //id article = [[[self dataSource] page] article];
    //WEKWebEditorItem *item = [[self rootItem] hitTestRepresentedObject:article];
    //[proposedRange selectNodeContents:[item HTMLElement]];
    
    
    // We only want a collapsed range to be selected by the mouse if it's within the bounds of the text (showing the text cursor)
    if ([proposedRange collapsed])
    {
        NSEvent *event = [NSApp currentEvent];
        if ([event type] == NSLeftMouseDown ||
            [event type] == NSRightMouseDown ||
            [event type] == NSOtherMouseDown)
        {
            DOMNode *node = [proposedRange startContainer];
            if (![node enclosingContentEditableElement])
            {
                if ([node nodeType] != DOM_TEXT_NODE)
                {
                    node = [[node childNodes] item:[proposedRange startOffset]];
                }
                NSRect textBox = [node boundingBox];

                NSView *view = [node documentView];
                NSPoint location = [view convertPointFromBase:[event locationInWindow]];
                
                if (![view mouse:location inRect:textBox])
                {
                    // There's no good text to select, so fall back to body
                    range = [[self delegate] webEditor:self fallbackDOMRangeForNoSelection:event];
                }
            }
        }
    }
    
        
    
    //  Update -selectedItems to match. Make sure not to try and change the WebView's selection in turn or it'll all end in tears. It doesn't make sense to bother doing this if the selection change was initiated by ourself.
    if (!_isChangingSelectedItems && result)
    {
            // Ensure user can't select part of a text area *enclosing* the current text
            if (range && proposedRange)
            {
                WEKWebEditorItem <SVWebEditorText> *currentText = [self textItemForDOMRange:range];
            
               DOMNode *proposedNode = [proposedRange commonAncestorContainer];
                if (![proposedNode isDescendantOfNode:[currentText HTMLElement]])
                {
                    WEKWebEditorItem *proposedText = [self textItemForDOMRange:proposedRange];
                    result = ![[currentText HTMLElement] isDescendantOfNode:[proposedText HTMLElement]];
                }
                
                
                // For change *within* a text area, let the controller decide
                if (result && currentText)
                {
                    result = [currentText webEditorTextShouldChangeSelectedDOMRange:range
                                                                         toDOMRange:proposedRange
                                                                           affinity:selectionAffinity
                                                                     stillSelecting:stillSelecting];
                }
            }
        
        
        // Let delegate know what's happening
        if (result)
        {
            result = [self changeSelectedItemsFromDOMRange:range];
        }
    }
    
    
    
    if (result)
    {
        // Did we adjust the range? If so, make that the one actually selected
        if (range != currentRange)
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
    return [self shouldChangeTextInDOMRange:range];
}

- (BOOL)webView:(WebView *)webView shouldInsertNode:(DOMNode *)nextNode replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEditText];
    
    if (result)
    {
        id <SVWebEditorText> text = [self textItemForDOMRange:range];
        
        // Let the text object decide
        result = [text webEditorTextShouldInsertNode:nextNode
                                   replacingDOMRange:range
                                         givenAction:action];
    }
    
    
    // Finish up
    if (result) result = [self shouldChangeTextInDOMRange:range];
    return result;
}

- (BOOL)webView:(WebView *)webView shouldInsertText:(NSString *)string replacingDOMRange:(DOMRange *)range givenAction:(WebViewInsertAction)action
{
    BOOL result = [self canEditText];
    
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
    [self didChangeText];
}

- (void)webViewDidChangeSelection:(NSNotification *)notification
{
    WebView *webView = [self webView];
    OBPRECONDITION([notification object] == webView);
    
    
    //  Update Link Manager to match
    NSArray *anchors = [webView selectedAnchorElements];
    if ([anchors count] == 1)
    {
        SVLink *link = [[SVLink alloc] initWithURLString:[[anchors lastObject] href]
                                         openInNewWindow:NO];
        [[SVLinkManager sharedLinkManager] setSelectedLink:link editable:[webView canCreateLink]];
        [link release];
    }
    else
    {
        [[SVLinkManager sharedLinkManager] setSelectedLink:nil editable:[webView canCreateLink]];
    }
    
    
    // Let focused text know its selection has changed
    [[self focusedText] webEditorTextDidChangeSelection:notification];
}

- (void)webViewDidEndEditing:(NSNotification *)notification
{
    [self setFocusedText:nil notification:notification];
}

- (BOOL)webView:(WebView *)webView doCommandBySelector:(SEL)command
{
    BOOL result = NO;
    
    // _isForwardingCommandToWebView indicates that the command is already being processed by the Web Editor, so it's now up to the WebView to handle. Otherwise it's easy to get stuck in an infinite loop.
    if (!_isForwardingCommandToWebView)
    {
        // Does the text view want to take command?
        result = [_focusedText webEditorTextDoCommandBySelector:command];
        
        // Is it a command which we handle? (our implementation may well call back through to the WebView when appropriate)
        if (!result)
        {
            // Moving left or right should select the graphic to the left if there is one
            if (command == @selector(moveLeft:))
            {
                result = [self tryToSelectItemByMovingLeft];
            }
            else if (command == @selector(moveRight:))
            {
                result = [self tryToSelectItemByMovingRight];
            }
            
            else if ([self respondsToSelector:command])
            {
                [self doCommandBySelector:command];
                result = YES;
            }
        }
    }
    
    return result;
}

#pragma mark WebEditingDelegate Private

- (void)webView:(WebView *)webView didSetSelectionTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    [[self dataSource] webEditor:self addSelectionToPasteboard:pasteboard];
}

@end


/*  SEP - Somebody Else's Problem
*/