//
//  SVEditingOverlay+Drawing.h
//  Sandvox
//
//  Created by Mike on 11/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h> 

#import "SVSelectionBorder.h"
#import "SVSelectionHandleLayer.h"


@interface SVEditingOverlayDrawingView : NSView
{
    CAScrollLayer   *_scrollLayer;
    NSPoint         _lastScrollPoint;
}

@property(nonatomic, retain, readonly) CAScrollLayer *scrollLayer;
- (void)scrollToPoint:(NSPoint)point;

@end
