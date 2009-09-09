//
//  SVWebViewContainerView.h
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  An SVEditingOverlay view is used to place over a WebView so that it can gain early access to hit testing in order to deny certain events reaching the WebView. By doing so it can create a UI paradigm whereby areas of the WebView becme "selectable" – that is, a click will place a selection border around an object rather than performing the normal action. The selected object can then be manipulated (e.g. change size, reposition), or a second click will allow access to WebKit's usual behaviour for the content.


#import <Cocoa/Cocoa.h>
#import "SVEditingOverlayItem.h"


@protocol SVWebEditingOverlayDataSource;
@class SVSelectionBorder;


@interface SVEditingOverlay : NSView
{
  @private
    id <SVWebEditingOverlayDataSource>  _dataSource;    // weak ref as you'd expect
    
    NSArray *_selectedItems;
    NSArray *_selectionBorders;
}

#pragma mark Data Source

@property(nonatomic, assign) id <SVWebEditingOverlayDataSource> dataSource;


#pragma mark Selection

@property(nonatomic, copy) NSArray *selectedItems;
- (void)selectItems:(NSArray *)items byExtendingSelection:(BOOL)extendSelection;


#pragma mark Getting Item Information

//  Queries the datasource
- (id <SVEditingOverlayItem>)itemAtPoint:(NSPoint)point;


#pragma mark Event Handling

/*  SVWebEditingOverlay overrides NSView's default hit testing behaviour in some important ways:
 *
 *      1.  If the point corresponds to the current selection, the receiver will be returned.
 *
 *      2.  Otherwise, hit testing will be delegated to the receiver's Data Source.
 *
 *      3.  BUT, depending on the current event, a different view may be returned that will handle a particular event type before passing it onto the real recipient. This has to be done in -hitTest: so as to hook into Cocoa's event handling mechanisms. If you're looking to avoid this, use the -editingOverlayHitTest: method which will ignore the requirement.
 */
- (NSView *)hitTest:(NSPoint)aPoint;
- (NSView *)editingOverlayHitTest:(NSPoint)aPoint;

@end


#pragma mark -


@protocol SVWebEditingOverlayDataSource <NSObject>

/*!
 @method editingOverlay:hitTest:
 @abstract When something hit tests an area which the overlay is not intending to claim for its own, the responsibility for hit testing is delegated.
 @param overlay The WebEditingOverlay object sending the message.
 @param point The point being tested. Like -[NSView hitTest:], specified in the overlay's superview's coordinates.
 @result The deepest view of the hierarchy that contains the point. Return nil if the area is considered "selectable" rather than targeting the view beneath the overlay.
 */
- (NSView *)editingOverlay:(SVEditingOverlay *)overlay hitTest:(NSPoint)point;


// You should return the selection border that represents the foremost item at that point, or nil if there is none. The overlay view uses this for adding to its selection etc.
- (id <SVEditingOverlayItem>)editingOverlay:(SVEditingOverlay *)overlay
                                itemAtPoint:(NSPoint)point;

@end


extern NSString *SVWebEditingOverlaySelectionDidChangeNotification;
