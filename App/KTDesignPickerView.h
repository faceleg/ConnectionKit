//
//  KTDesignPickerView.h
//  Marvel
//
//  Created by Dan Wood on 7/20/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


#define kMaximumReasonableNumberOfVisibleThumbs 50

@class KTDesign;

@interface KTDesignPickerView : NSView
{
	KTDesign *myDesign;
	
	int myListOffset;	// How far into the list the left edge is showing.
	int myUpcomingListOffset;
	int mySelectedIndex;	// of our sorted list of designs, which one is the current one
	int myClickingScreenIndex;	// which one is currently being clicked on.
	int myHoveredScreenIndex;		// which one is currently hovered over.  (If a new one, we need to change)
	int myNumberOfDesignsVisible;	// depends on window width; we need notifications when this changes
	int myNumberOfDesignsCompletelyVisible;
	int myPartialLastWidth;			// width of last, partially covered one.
	
	int myTrackingRectTags[kMaximumReasonableNumberOfVisibleThumbs];

	NSAnimation *myAnimation;
	CIImage		*myAnimationCIImage;
	NSImage *myAnimationBaseImage;
	BOOL myCoreImageAnimation;
	float myLastAnimationPosition;	// for calculating speed

	IBOutlet	NSButton *oPrevButton;
	IBOutlet	NSButton *oNextButton;
}
- (IBAction)nextPage:(id)sender;
- (IBAction)prevPage:(id)sender;

- (KTDesign *)selectedDesign;
- (void)setSelectedDesign:(KTDesign *)design;	// Do not access directly, since it could mess up bindings

- (void)inUse:(BOOL)aFlag;

@end
