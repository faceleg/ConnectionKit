//
//  SVDesignChooserViewController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>

#if MAC_OS_X_VERSION_MAX_ALLOWED <= MAC_OS_X_VERSION_10_5
@protocol IKImageBrowserDataSource <NSObject> @end
@protocol IKImageBrowserDelegate <NSObject> @end
#endif

@interface SVDesignChooserViewController : NSViewController <IKImageBrowserDataSource, IKImageBrowserDelegate>
{
	IBOutlet IKImageBrowserView	*oImageBrowserView;
    
    NSArray                     *_designs;
	NSTrackingRectTag			_trackingRect;
	BOOL						_wasAcceptingMouseEvents;
}

- (void) setupTrackingRects;		// do this after the view is added and resized
 
@property(retain) NSArray *designs;
@end

@interface SVDesignChooserScrollView : NSScrollView
{
    NSGradient *_backgroundGradient;
}
@end

@interface SVDesignChooserViewBox : NSBox
@end

@interface SVDesignChooserSelectionView : NSView
@end
