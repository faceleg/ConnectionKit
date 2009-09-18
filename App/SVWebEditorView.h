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
#import "SVEditingOverlayItem.h"


@protocol SVWebEditorViewDataSource;
@class SVSelectionBorder, SVEditingOverlayDrawingView;


@interface SVWebEditorView : NSView
{
  @private
    // Content
    WebView *_webView;
    id <SVWebEditorViewDataSource>  _dataSource;    // weak ref as you'd expect
    
    // Selection
    NSArray *_selectedItems;
    BOOL    _isEditingSelection;
    
    // Event Handling
    NSEvent *_possibleBeginEditingMouseDownEvent;
    BOOL    _isProcessingEvent;
}


#pragma mark Document

@property(nonatomic, retain, readonly) WebView *webView;
@property(nonatomic, readonly) DOMDocument *DOMDocument;

#pragma mark Content

@property(nonatomic, assign) id <SVWebEditorViewDataSource> dataSource;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;


#pragma mark Selection

@property(nonatomic, readonly) DOMRange *selectedDOMRange;

@property(nonatomic, copy) NSArray *selectedItems;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;
- (void)deselectItem:(id <SVEditingOverlayItem>)item;

@property(nonatomic, readonly) BOOL isEditingSelection;


#pragma mark Getting Item Information

//  Queries the datasource
- (id <SVEditingOverlayItem>)itemAtPoint:(NSPoint)point;


@end


#pragma mark -


@protocol SVWebEditorViewDataSource <NSObject>

/*!
 @method editingOverlay:itemAtPoint:
 @param overlay The SVEditingOverlay object sending the message.
 @param point The point being tested in the overlay's coordinate system.
 @result The frontmost item that covers the point. nil if there is none.
 */
- (id <SVEditingOverlayItem>)editingOverlay:(SVWebEditorView *)overlay
                                itemAtPoint:(NSPoint)point;

@end


extern NSString *SVWebEditorViewSelectionDidChangeNotification;
