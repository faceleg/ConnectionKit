//
//  SVWebViewContainerView.h
//  Sandvox
//
//  Created by Mike on 04/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  A Web Editing View is used to contain a WebView so that it can gain early access to hit testing in order to deny certain events reaching the WebView. By doing so it can create a UI paradigm whereby areas of the WebView becme "selectable" – that is, a click will place a selection border around an object rather than performing the normal action. The selected object can then be mainpulated (e.g. change size, reposition), or a second click will allow access to WebKit's usual behaviour for the content.


#import <WebKit/WebKit.h>


@protocol SVWebEditingOverlayDataSource;


@class SVSelectionBorder;


@interface SVWebEditingOverlay : NSView
{
  @private
    id <SVWebEditingOverlayDataSource>  _dataSource;    // weak ref as you'd expect
    
    NSMutableArray  *_selection;
}

@property(nonatomic, assign) id <SVWebEditingOverlayDataSource> dataSource;

@property(nonatomic, copy, readonly) NSArray *selectedBorders;
- (void)insertObject:(SVSelectionBorder *)border inSelectedBordersAtIndex:(NSUInteger)index;
- (void)removeObjectFromSelectedBordersAtIndex:(NSUInteger)index;


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


@protocol SVWebEditingOverlayDataSource <NSObject>

/*!
 @method editingOverlay:hitTest:
 @abstract When something hit tests an area which the overlay is not intending to claim for its own, the responsibility for hit testing is delegated.
 @param overlay The WebEditingOverlay object sending the message.
 @param point The point being tested. Like -[NSView hitTest:], specified in the overlay's superview's coordinates.
 @result The deepest view of the hierarchy that contains the point. Return nil if the area is considered "selectable" rather than targeting the view beneath the overlay.
 */
- (NSView *)editingOverlay:(SVWebEditingOverlay *)overlay hitTest:(NSPoint)point;

@end