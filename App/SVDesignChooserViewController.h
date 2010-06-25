//
//  SVDesignChooserViewController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

@class KTDesign, SVDesignsController;

// ImageKit only declares these as informal protocols
@protocol IKImageBrowserDataSource <NSObject> @end
@protocol IKImageBrowserDelegate <NSObject> @end


@interface SVDesignChooserViewController : NSViewController <IKImageBrowserDataSource, IKImageBrowserDelegate>
{  
	IBOutlet SVDesignsController *oDesignsArrayController;
	NSTrackingRectTag			_trackingRect;
	NSTrackingArea				*_trackingArea;
	BOOL						_wasAcceptingMouseEvents;
}

- (void) setupTrackingRects;		// do this after the view is added and resized
- (void) initializeExpandedState;

- (KTDesign *)selectedDesign;
- (void) setSelectedDesign:(KTDesign *)aDesign;
- (void) setExpanded:(BOOL)expanded forRange:(NSRange)range;

@end

//@interface SVDesignChooserViewBox : NSBox
//@end
//
//@interface SVDesignChooserSelectionView : NSView
//@end
