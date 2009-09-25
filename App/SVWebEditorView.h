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
#import "KSDragging.h"


typedef enum {
    SVWebEditingModeNormal,
    SVWebEditingModeEditing,
    SVWebEditingModeDragging,
} SVWebEditingMode;


@protocol SVWebEditorViewDataSource, SVWebEditorViewDelegate;
@class SVWebEditorWebView;


@interface SVWebEditorView : NSView <KSDraggingDestination>
{
  @private
    // Content
    SVWebEditorWebView              *_webView;
    id <SVWebEditorViewDataSource>  _dataSource;    // weak ref as you'd expect
    id <SVWebEditorViewDelegate>    _delegate;      // "
    BOOL    _isLoading;
    
    // Selection
    NSArray             *_selectedItems;
    SVWebEditingMode    _mode;
    
    // Editing
    BOOL    _mouseUpMayBeginEditing;
    
    // Drag & Drop
    id  _lastDraggingDestination;   // weak ref
    
    // Event Handling
    NSEvent *_mouseDownEvent;   // have to record all mouse down events in case they turn into a drag op
    BOOL    _isProcessingEvent;
}


#pragma mark Document

@property(nonatomic, readonly) DOMDocument *DOMDocument;

#pragma mark Loading Data

- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
@property(nonatomic, readonly, getter=isLoading) BOOL loading;


#pragma mark Selection

@property(nonatomic, readonly) DOMRange *selectedDOMRange;

@property(nonatomic, copy) NSArray *selectedItems;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
- (void)deselectItem:(id <SVWebEditorItem>)item;


#pragma mark Editing

@property(nonatomic, readonly) SVWebEditingMode mode;



#pragma mark Getting Item Information

//  Queries the datasource
- (id <SVWebEditorItem>)itemAtPoint:(NSPoint)point;


#pragma mark Setting the DataSource/Delegate

@property(nonatomic, assign) id <SVWebEditorViewDataSource> dataSource;
@property(nonatomic, assign) id <SVWebEditorViewDelegate> delegate;

@end


#pragma mark -


@protocol SVWebEditorViewDataSource <NSObject, KSDraggingDestination>

/*!
 @method editingOverlay:itemAtPoint:
 @param overlay The SVEditingOverlay object sending the message.
 @param point The point being tested in the overlay's coordinate system.
 @result The frontmost item that covers the point. nil if there is none.
 */
- (id <SVWebEditorItem>)editingOverlay:(SVWebEditorView *)overlay
                                itemAtPoint:(NSPoint)point;

/*!
 @method webEditorView:draggingDestinationForDrop:
 @param sender
 @param dragInfo
 @result A NSDraggingDestination-compliant object to handle the drop, or nil to use the default handling.
 @discussion Use this to "claim" a portion of the view as your own for drag & drop.
 */
- (id <KSDraggingDestination>)webEditorView:(SVWebEditorView *)sender
                         destinationForDrop:(id <NSDraggingInfo>)dragInfo;

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
@end


