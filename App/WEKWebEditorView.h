//
//  WEKWebEditorView.h
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An WEKWebEditorView object abstracts out some of the functionality we need in Sandvox for performing editing in a webview. With it, you should have no need to access the contained WebView directly; the editor should provide its own API as a wrapper.
//  The main thing we add to a standard WebView is the concept of selection. In this way WEKWebEditorView is a lot like NSTableView and other collection classes; it knows how to display and handle arbitrary content, but relies on a datasource to provide them.


#import <WebKit/WebKit.h>
#import "SVWebEditorTextProtocol.h"


extern NSString *kSVWebEditorViewWillChangeNotification;
extern NSString *kSVWebEditorViewDidChangeNotification;


@protocol WEKWebEditorDataSource, WEKWebEditorDelegate;
@class SVWebEditorItem, SVWebEditorTextRange;
@class WEKWebView, SVMainWebEditorItem;


@interface WEKWebEditorView : NSView <NSUserInterfaceValidations>
{
  @private
    // Content
    WEKWebView              *_webView;
    SVMainWebEditorItem             *_mainItem;
    BOOL    _isStartingLoad;
    
    // Selection
    NSResponder <SVWebEditorText>   *_focusedText;
    NSArray                         *_selectedItems;
    NSArray                         *_selectionParentItems;
    BOOL                            _isChangingSelectedItems;
    
    // Editing
    BOOL            _mouseUpMayBeginEditing;
    NSUndoManager   *_undoManager;
    BOOL            _liveLinks;
    NSPasteboard    *_insertionPasteboard;
    
    SVWebEditorItem <SVWebEditorText>   *_changingTextController;   // weak ref, only used in passing
    
    // Drag & Drop
    NSArray     *_draggedItems;
    DOMNode     *_dragHighlightNode;
    DOMRange    *_dragCaretDOMRange;
    
    // Event Handling
    NSEvent *_mouseDownEvent;   // have to record all mouse down events in case they turn into a drag op
    BOOL    _resizingGraphic;
    BOOL    _isProcessingEvent;
    BOOL    _isForwardingCommandToWebView;
    
    // Datasource/delegate
    id <WEKWebEditorDataSource>  _dataSource;    // weak ref as you'd expect
    id <WEKWebEditorDelegate>    _delegate;      // "
    NSObject                    *_dragDelegate;
}


#pragma mark Document

@property(nonatomic, readonly) DOMDocument *HTMLDocument;
- (NSView *)documentView;
- (void)scrollToPoint:(NSPoint)point;


#pragma mark Loading Data

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
@property(nonatomic, readonly, getter=isStartingLoad) BOOL startingLoad;

// Blocks until either loading is finished or date is reached. Returns YES if the former.
- (BOOL)loadUntilDate:(NSDate *)date;

@property(nonatomic, readonly) SVWebEditorItem *mainItem;   // add your items here after loading finishes
- (void)insertItem:(SVWebEditorItem *)item; // inserts the item into the tree in the place that matches the DOM


#pragma mark Text Selection

@property(nonatomic, readonly) DOMRange *selectedDOMRange;
- (void)setSelectedDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)selectionAffinity;

- (SVWebEditorTextRange *)selectedTextRange;
- (void)setSelectedTextRange:(SVWebEditorTextRange *)range affinity:(NSSelectionAffinity)affinity;

@property(nonatomic, retain, readonly) id <SVWebEditorText> focusedText;    // KVO-compliant


#pragma mark Item Selection

@property(nonatomic, copy) NSArray *selectedItems;
@property(nonatomic, retain, readonly) SVWebEditorItem *selectedItem;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
- (void)deselectItem:(SVWebEditorItem *)item;

- (IBAction)deselectAll:(id)sender; // Action method, so asks the delegate if selection should change first


#pragma mark Editing

// We don't want to allow any sort of change unless the WebView is First Responder
- (BOOL)canEditText;

@property(nonatomic) BOOL liveEditableAndSelectableLinks;   // you can bind this to the defaults

// Like NSTextView, you should call one of these when wanting to apply an editing action to the DOM. Posts kSVWebEditorViewWillChangeNotification notification if successful.
// After editing, call -didChange which posts kSVWebEditorViewDidChangeNotification and handles undo registration/peristence for the edit.
- (BOOL)shouldChangeTextInDOMRange:(DOMRange *)range;
- (BOOL)shouldChangeText:(SVWebEditorItem <SVWebEditorText> *)textController;
- (void)didChangeText;

- (NSPasteboard *)insertionPasteboard;


#pragma mark Drawing
// The editor contains a variety of subviews. When it needs the effect of drawing an overlay above them this method is called, telling you the view that is being drawn into, and where.
- (void)drawOverlayRect:(NSRect)dirtyRect inView:(NSView *)view;
- (void)drawSelectionRect:(NSRect)dirtyRect inView:(NSView *)view;

- (BOOL)inLiveGraphicResize;


#pragma mark Getting Item Information

/*  SVWebEditorItem has many similar methods. The crucial difference is that these also take into account the current selection. i.e. if editing an item, any sub-items then become available for selection. But selection handles are ignored.
 */

- (id)selectableItemAtPoint:(NSPoint)point;
- (id)selectableItemForDOMNode:(DOMNode *)node;
- (NSArray *)selectableItemsInDOMRange:(DOMRange *)range;


#pragma mark Dispatching Messages
// Makes the WebView perform the action WITHOUT allowing the Web Editor to step in as delegate
- (void)forceWebViewToPerform:(SEL)action withObject:(id)sender;


#pragma mark Setting the DataSource/Delegate
@property(nonatomic, assign) id <WEKWebEditorDataSource> dataSource;
@property(nonatomic, assign) id <WEKWebEditorDelegate> delegate;
@property(nonatomic, assign) NSObject *draggingDestinationDelegate;


@end


#pragma mark -


@interface WEKWebEditorView (EditingSupport)

#pragma mark Cut, Copy & Paste
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (BOOL)copySelectedItemsToGeneralPasteboard;
// - (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;  // deletes the selected items. If there are none, deletes selected text


#pragma mark Undo
// It is the responsibility of SVWebEditorTextBlocks to use these methods to control undo support as they modify the DOM
@property(nonatomic) BOOL allowsUndo;
- (void)removeAllUndoActions;


#pragma mark Validation
- (BOOL)validateAction:(SEL)action;


@end


#pragma mark -


@interface WEKWebEditorView (Dragging)

#pragma mark Dragging Source
- (NSArray *)draggedItems;
- (void)removeDraggedItems; // removes from DOM and item tree, then calls -forgetDraggedItems. You are responsible for calling -didChangeText after
- (void)forgetDraggedItems; // call if you want to take over handling of drag source


#pragma mark Dragging Destination

// Operates in a similar fashion to WebView's drag caret methods, but instead draw a big blue highlight around the node. To remove pass in nil
- (void)moveDragHighlightToDOMNode:(DOMNode *)node;
- (void)moveDragCaretToDOMRange:(DOMRange *)range;  // must be a collapsed range
- (void)removeDragCaret;


#pragma mark Drawing
- (void)drawDragCaretInView:(NSView *)view;


#pragma mark Layout
- (NSRect)rectOfDragCaret;


@end


#pragma mark -


@protocol WEKWebEditorDataSource <NSObject>

/*  We locate text blocks on-demand based on a DOM range. It's expected the datasource will be maintaining its own list of such text blocks already.
 */
- (SVWebEditorItem <SVWebEditorText> *)webEditor:(WEKWebEditorView *)sender
                            textBlockForDOMRange:(DOMRange *)range;

- (BOOL)webEditor:(WEKWebEditorView *)sender deleteItems:(NSArray *)items;

// Return YES if the delegate wants to handle link creation itself
- (BOOL)webEditor:(WEKWebEditorView *)sender createLink:(id)actionSender;


#pragma mark Controlling Drag Behavior

// Same as WebUIDelegate method, except it only gets called if .draggingDestinationDelegate rejected the drag
- (NSUInteger)webEditor:(WEKWebEditorView *)sender dragDestinationActionMaskForDraggingInfo:(id <NSDraggingInfo>)draggingInfo;

/*!
 @method webEditorView:writeItems:toPasteboard:
 @param sender
 @param items An array of SVWebEditorItem objects to be written
 @param pasteboard
 @result YES if the items could be written to the pasteboard
 */
- (BOOL)webEditor:(WEKWebEditorView *)sender addSelectionToPasteboard:(NSPasteboard *)pasteboard;


@end


#pragma mark -


@protocol WEKWebEditorDelegate <NSObject>

#pragma mark Selection

//  Only called in response to selection changes from the GUI and action methods. Could make it more flexible one day if needed
- (BOOL)webEditor:(WEKWebEditorView *)sender shouldChangeSelection:(NSArray *)proposedSelectedItems;
   
//  Delegate is automatically subscribed to SVWebEditorViewDidChangeSelectionNotification
- (void)webEditorViewDidChangeSelection:(NSNotification *)notification;

   
#pragma mark Loading

- (void)webEditorViewDidFirstLayout:(WEKWebEditorView *)sender;
- (void)webEditorViewDidFinishLoading:(WEKWebEditorView *)sender;

// Much like -webView:didReceiveTitle:forFrame:
- (void)webEditor:(WEKWebEditorView *)sender didReceiveTitle:(NSString *)title;

- (NSURLRequest *)webEditor:(WEKWebEditorView *)sender
            willSendRequest:(NSURLRequest *)request
           redirectResponse:(NSURLResponse *)redirectResponse
             fromDataSource:(WebDataSource *)dataSource;


#pragma mark Navigation

     - (void)webEditor:(WEKWebEditorView *)webEditorView
handleNavigationAction:(NSDictionary *)actionInformation
               request:(NSURLRequest *)request;


#pragma mark Editing
- (void)webEditorWillChange:(NSNotification *)notification;
- (BOOL)webEditor:(WEKWebEditorView *)webEditor doCommandBySelector:(SEL)action;


#pragma mark Web Editor Items
- (void)webEditor:(WEKWebEditorView *)sender didAddItem:(SVWebEditorItem *)item;


@end


extern NSString *SVWebEditorViewDidChangeSelectionNotification;


#pragma mark -


@interface WEKWebEditorView (SPI)

// Do NOT attempt to edit this WebView in any way. The whole point of WEKWebEditorView is to provide a more structured API around a WebView's editing capabilities. You should only ever be modifying the WebView through the API WEKWebEditorView and its DataSource/Delegate provides.
@property(nonatomic, retain, readonly) WebView *webView;

@end


