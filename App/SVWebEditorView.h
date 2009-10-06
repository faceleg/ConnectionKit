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
#import "SVWebEditorItemProtocol.h"
#import "SVWebEditorTextBlockProtocol.h"


typedef enum {
    SVWebEditingModeNormal,
    SVWebEditingModeEditing,
    SVWebEditingModeDragging,
} SVWebEditingMode;


@protocol SVWebEditorViewDataSource, SVWebEditorViewDelegate;
@class SVWebEditorWebView;


@interface SVWebEditorView : NSView <NSUserInterfaceValidations>
{
  @private
    // Content
    SVWebEditorWebView              *_webView;
    id <SVWebEditorViewDataSource>  _dataSource;    // weak ref as you'd expect
    id <SVWebEditorViewDelegate>    _delegate;      // "
    BOOL    _isLoading;
    
    // Selection
    NSArray                     *_selectedItems;
    id <SVWebEditorText>   _selectedTextBlock;
    SVWebEditingMode            _mode;
    
    // Editing
    BOOL    _mouseUpMayBeginEditing;
    
    // Drag & Drop
    DOMNode *_dragHighlightNode;
	DOMNode *_dragCaretNode1;
    DOMNode *_dragCaretNode2;
    
    // Event Handling
    NSEvent *_mouseDownEvent;   // have to record all mouse down events in case they turn into a drag op
    BOOL    _isProcessingEvent;
}


#pragma mark Document

@property(nonatomic, readonly) DOMDocument *DOMDocument;


#pragma mark Loading Data

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;

// Blocks until either loading is finished or date is reached. Returns YES if the former.
- (BOOL)loadUntilDate:(NSDate *)date;

@property(nonatomic, readonly, getter=isLoading) BOOL loading;


#pragma mark Selection

@property(nonatomic, readonly) DOMRange *selectedDOMRange;

@property(nonatomic, copy) NSArray *selectedItems;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
- (void)deselectItem:(id <SVWebEditorItem>)item;


#pragma mark Editing

@property(nonatomic, readonly) SVWebEditingMode mode;


#pragma mark Undo Support
// It is the responsibility of SVWebEditorTextBlocks to use these methods to control undo support as they modify the DOM
@property(nonatomic) BOOL allowsUndo;
- (void)removeAllUndoActions;


#pragma mark Cut, Copy & Paste
- (IBAction)cut:(id)sender;
- (IBAction)copy:(id)sender;
- (BOOL)copy;
// - (IBAction)paste:(id)sender;
- (IBAction)delete:(id)sender;


#pragma mark Layout
- (NSRect)rectOfDragCaret;
- (NSRect)rectOfDragCaretAfterDOMNode:(DOMNode *)node1
                        beforeDOMNode:(DOMNode *)node2
                          minimumSize:(CGFloat)minSize;


#pragma mark Drawing
// The editor contains a variety of subviews. When it needs the effect of drawing an overlay above them this method is called, telling you the view that is being drawn into, and where.
- (void)drawOverlayRect:(NSRect)dirtyRect inView:(NSView *)view;
- (void)drawDragCaretInView:(NSView *)view;

#pragma mark Dragging Destination

// Operates in a similar fashion to WebView's drag caret methods, but instead draw a big blue highlight around the node. To remove pass in nil
- (void)moveDragHighlightToDOMNode:(DOMNode *)node;
- (void)moveDragCaretToAfterDOMNode:(DOMNode *)node1 beforeDOMNode:(DOMNode *)node2;
- (void)removeDragCaret;


#pragma mark Getting Item Information

//  Queries the datasource
- (id <SVWebEditorItem>)itemAtPoint:(NSPoint)point;


#pragma mark Setting the DataSource/Delegate

@property(nonatomic, assign) id <SVWebEditorViewDataSource> dataSource;
@property(nonatomic, assign) id <SVWebEditorViewDelegate> delegate;

@end


#pragma mark -


@protocol SVWebEditorViewDataSource <NSObject>

/*!
 @method editingOverlay:itemAtPoint:
 @param overlay The SVEditingOverlay object sending the message.
 @param point The point being tested in the overlay's coordinate system.
 @result The frontmost item that covers the point. nil if there is none.
 */
- (id <SVWebEditorItem>)editingOverlay:(SVWebEditorView *)overlay
                                itemAtPoint:(NSPoint)point;

/*  We locate text blocks on-demand based on a DOM range. It's expected the datasource will be maintaining its own list of such text blocks already.
 */
- (id <SVWebEditorText>)webEditorView:(SVWebEditorView *)sender
                      textBlockForDOMRange:(DOMRange *)range;

- (BOOL)webEditorView:(SVWebEditorView *)sender deleteItems:(NSArray *)items;

// Return something other than NSDragOperationNone to take command of the drop
- (NSDragOperation)webEditorView:(SVWebEditorView *)sender
      dataSourceShouldHandleDrop:(id <NSDraggingInfo>)dragInfo;

/*!
 @method webEditorView:writeItems:toPasteboard:
 @param sender
 @param items An array of SVWebEditorItem objects to be written
 @param pasteboard
 @result YES if the items could be written to the pasteboard
 */
- (BOOL)webEditorView:(SVWebEditorView *)sender
           writeItems:(NSArray *)items
         toPasteboard:(NSPasteboard *)pasteboard;

@end


#pragma mark -


@protocol SVWebEditorViewDelegate <NSObject>

 - (void)webEditorView:(SVWebEditorView *)webEditorView
handleNavigationAction:(NSDictionary *)actionInformation
               request:(NSURLRequest *)request;

@end

extern NSString *SVWebEditorViewSelectionDidChangeNotification;


#pragma mark -


@interface SVWebEditorView (SPI)
@property(nonatomic, retain, readonly) WebView *webView;
- (NSDragOperation)validateDrop:(id <NSDraggingInfo>)sender proposedOperation:(NSDragOperation)op;
@end


