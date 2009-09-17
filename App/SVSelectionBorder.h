//
//  SVSelectionBorder.h
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>


enum SVSelectionResizeMask
{
    kSVSelectionResizeableLeft      = 1U << 0,
    kSVSelectionResizeableRight     = 1U << 1,
    kSVSelectionResizeableBottom    = 1U << 2,
    kSVSelectionResizeableTop       = 1U << 3,
};


@class SVWebEditorView;


@interface SVSelectionBorder : CALayer
{
    CALayer *_bottomLeftSelectionHandle;
    CALayer *_leftSelectionHandle;
    CALayer *_topLeftSelectionHandle;
    CALayer *_bottomRightSelectionHandle;
    CALayer *_rightSelectionHandle;
    CALayer *_topRightSelectionHandle;
    CALayer *_bottomSelectionHandle;
    CALayer *_topSelectionHandle;
}



// Only the overlay view itself should call this
//@property(nonatomic, assign) SVWebEditingOverlay *overlayView;

//@property(nonatomic, readonly) CALayer *layer;

@end


#pragma mark -


@interface CALayer (SVTrackingAreas)
- (NSCursor *)webEditingOverlayCursor;
// The containing editing overlay view will call this as it needs to
- (void)updateTrackingAreasInView:(NSView *)view;
@end

