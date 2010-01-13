//
//  SVWebEditorView.h
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An SVWebEditorView object abstracts out some of the functionality we need in Sandvox for performing editing in a webview. With it, you should have no need to access the contained WebView directly; the editor should provide its own API as a wrapper.
//  The main thing we add to a standard WebView is the concept of selection. In this way SVWebEditorView is a lot like NSTableView and other collection classes; it knows how to display and handle arbitrary content, but relies on a datasource to provide them.


#import <WebKit/WebKit.h>
#import "SVWebEditorTextProtocol.h"


@protocol SVWebEditorDataSource, SVWebEditorDelegate;
@class SVWebEditorItem;
@class SVWebEditorWebView, SVMainWebEditorItem;


@interface SVWebEditorView : NSView <NSUserInterfaceValidations>
{
  @private
    // Content
    SVWebEditorWebView              *_webView;
    SVMainWebEditorItem             *_mainItem;
    id <SVWebEditorDataSource>  _dataSource;    // weak ref as you'd expect
    id <SVWebEditorDelegate>    _delegate;      // "
    BOOL    _isStartingLoad;
    
    // Selection
    id <SVWebEditorText>    _focusedText;
    NSArray                 *_selectedItems;
    NSArray                 *_selectionParentItems;
    BOOL                    _isChangingSelectedItems;
    
    // Editing
    DOMRange        *_DOMRangeOfNextEdit;
    BOOL            _mouseUpMayBeginEditing;
    NSUndoManager   *_undoManager;
    BOOL            _liveLinks;
    
    // Drag & Drop
    BOOL        _isDragging;
    DOMNode     *_dragHighlightNode;
    DOMRange    *_dragCaretDOMRange;
    
    // Event Handling
    NSEvent *_mouseDownEvent;   // have to record all mouse down events in case they turn into a drag op
    BOOL    _isProcessingEvent;
    BOOL    _isForwardingCommandToWebView;
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


#pragma mark Selection

@property(nonatomic, readonly) DOMRange *selectedDOMRange;
- (void)setSelectedDOMRange:(DOMRange *)range affinity:(NSSelectionAffinity)selectionAffinity;

@property(nonatomic, retain, readonly) id <SVWebEditorText> focusedText;    // KVO-compliant

@property(nonatomic, copy) NSArray *selectedItems;
@property(nonatomic, retain, readonly) SVWebEditorItem *selectedItem;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
- (void)deselectItem:(SVWebEditorItem *)item;

- (IBAction)deselectAll:(id)sender; // Action method, so asks the delegate if selection should change first


#pragma mark Editing

// We don't want to allow any sort of change unless the WebView is First Responder
- (BOOL)canEditText;
// WebKit doesn't supply any sort of -willFoo editing notifications, but we're in control now and can provide a pretty decent approximation.
- (void)willEditTextInDOMRange:(DOMRange *)range;
- (void)didChangeTextInDOMRange:(DOMRange *)range notification:(NSNotification *)notification;

@property(nonatomic) BOOL liveEditableAndSelectableLinks;   // you can bind this to the defaults


#pragma mark Undo Support
// It is the responsibility of SVWebEditorTextBlocks to use these methods to control undo support as they modify the DOM
@property(nonatomic) BOOL allowsUndo;
- (void)removeAllUndoActions;


#pragma mark Cut, Copy & Paste
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (BOOL)copySelectedItemsToGeneralPasteboard;
// - (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;  // deletes the selected items. If there are none, deletes selected text


#pragma mark Drawing
// The editor contains a variety of subviews. When it needs the effect of drawing an overlay above them this method is called, telling you the view that is being drawn into, and where.
- (void)drawOverlayRect:(NSRect)dirtyRect inView:(NSView *)view;
- (void)drawSelectionRect:(NSRect)dirtyRect inView:(NSView *)view;


#pragma mark Getting Item Information

/*  SVWebEditorItem has many similar methods. The crucial difference is that these also take into account the current selection. i.e. if editing an item, any sub-items then become available for selection. But selection handles are ignored.
 */

- (id)selectableItemAtPoint:(NSPoint)point;
- (id)selectableItemForDOMNode:(DOMNode *)node;
- (NSArray *)itemsInDOMRange:(DOMRange *)range;


#pragma mark Setting the DataSource/Delegate

@property(nonatomic, assign) id <SVWebEditorDataSource> dataSource;
@property(nonatomic, assign) id <SVWebEditorDelegate> delegate;

@end


#pragma mark -


@interface SVWebEditorView (Dragging)

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


@protocol SVWebEditorDataSource <NSObject>

/*  We locate text blocks on-demand based on a DOM range. It's expected the datasource will be maintaining its own list of such text blocks already.
 */
- (id <SVWebEditorText>)webEditor:(SVWebEditorView *)sender
                      textBlockForDOMRange:(DOMRange *)range;

- (BOOL)webEditor:(SVWebEditorView *)sender deleteItems:(NSArray *)items;


#pragma mark Dragging

// Return something other than NSDragOperationNone to take command of the drop
- (NSDragOperation)webEditor:(SVWebEditorView *)sender
      dataSourceShouldHandleDrop:(id <NSDraggingInfo>)dragInfo;

- (BOOL)webEditor:(SVWebEditorView *)sender acceptDrop:(id <NSDraggingInfo>)dragInfo;

/*!
 @method webEditorView:writeItems:toPasteboard:
 @param sender
 @param items An array of SVWebEditorItem objects to be written
 @param pasteboard
 @result YES if the items could be written to the pasteboard
 */
- (BOOL)webEditor:(SVWebEditorView *)sender
           writeItems:(NSArray *)items
         toPasteboard:(NSPasteboard *)pasteboard;

@end


#pragma mark -


@protocol SVWebEditorDelegate <NSObject>

#pragma mark Selection

//  Only called in response to selection changes from the GUI and action methods. Could make it more flexible one day if needed
- (BOOL)webEditor:(SVWebEditorView *)sender shouldChangeSelection:(NSArray *)proposedSelectedItems;
   
//  Delegate is automatically subscribed to SVWebEditorViewDidChangeSelectionNotification
- (void)webEditorViewDidChangeSelection:(NSNotification *)notification;

   
   
- (void)webEditorViewDidFirstLayout:(SVWebEditorView *)sender;
- (void)webEditorViewDidFinishLoading:(SVWebEditorView *)sender;

// Much like -webView:didReceiveTitle:forFrame:
- (void)webEditor:(SVWebEditorView *)sender didReceiveTitle:(NSString *)title;

 - (void)webEditor:(SVWebEditorView *)webEditorView
handleNavigationAction:(NSDictionary *)actionInformation
               request:(NSURLRequest *)request;

@end

extern NSString *SVWebEditorViewDidChangeSelectionNotification;


#pragma mark -


@interface SVWebEditorView (SPI)

// Do NOT attempt to edit this WebView in any way. The whole point of SVWebEditorView is to provide a more structured API around a WebView's editing capabilities. You should only ever be modifying the WebView through the API SVWebEditorView and its Date Source/Delegate provides.
@property(nonatomic, retain, readonly) WebView *webView;

// Returns YES if the web editor is taking command of the drop, rather than the WebView.
- (BOOL)validateDrop:(id <NSDraggingInfo>)sender proposedOperation:(NSDragOperation *)proposedOp;

- (BOOL)acceptDrop:(id <NSDraggingInfo>)sender;

@end


