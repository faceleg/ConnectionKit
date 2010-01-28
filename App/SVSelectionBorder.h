//
//  SVSelectionBorder.h
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import <QuartzCore/QuartzCore.h>


enum
{
    kSVSelectionXResizeable     = 1U << 0,
    kSVSelectionYResizeable     = 1U << 1,
    kSVSelectionWidthResizeable = 1U << 2,
    kSVSelectionHeightResizeable= 1U << 3,
};
//typedef SVSelectionResizingMask NSInteger;


@interface SVSelectionBorder : NSObject
{
    BOOL            _isEditing;
    NSSize          _minSize;
    unsigned int    _resizingMask;
}

@property(nonatomic, getter=isEditing) BOOL editing;
@property(nonatomic) NSSize minSize;
@property(nonatomic) unsigned int resizingMask; // bitmask of CAEdgeAntialiasingMask


#pragma mark Layout
- (NSRect)frameRectForGraphicBounds:(NSRect)bounds;  // adjusts frame to suit -minSize if needed
- (NSRect)drawingRectForGraphicBounds:(NSRect)bounds;
- (BOOL)mouse:(NSPoint)mousePoint isInFrame:(NSRect)frameRect inView:(NSView *)view;


#pragma mark Drawing
- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;
- (void)drawWithGraphicBounds:(NSRect)bounds inView:(NSView *)view;


@end