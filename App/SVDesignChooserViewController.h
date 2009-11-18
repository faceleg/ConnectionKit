//
//  SVDesignChooserViewController.h
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVDesignChooserViewController : NSViewController
{
    IBOutlet NSCollectionView	*oCollectionView;
    IBOutlet NSArrayController  *oArrayController;
    
    NSArray                     *designs_;
	NSTrackingRectTag			trackingRect_;
	BOOL						wasAcceptingMouseEvents_;
}

- (void) setupTrackingRects;		// do this after the view is added and resized
 
@property(retain) NSArray *designs;
@property(readonly) NSArrayController *designsArrayController;
@property(readonly) NSCollectionView *designsCollectionView;
@end

@interface SVDesignChooserScrollView : NSScrollView
{
    NSGradient *backgroundGradient_;
}
@end

@interface SVDesignChooserViewBox : NSBox
@end

@interface SVDesignChooserSelectionView : NSView
@end
