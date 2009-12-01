//
//  SVSelectionBorder.h
//  Sandvox
//
//  Created by Mike on 06/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


enum SVSelectionResizeMask
{
    kSVSelectionResizeableLeft      = 1U << 0,
    kSVSelectionResizeableRight     = 1U << 1,
    kSVSelectionResizeableBottom    = 1U << 2,
    kSVSelectionResizeableTop       = 1U << 3,
};


@interface SVSelectionBorder : NSObject
{
    BOOL    _isEditing;
    NSSize  _minSize;
}

@property(nonatomic, getter=isEditing) BOOL editing;
@property(nonatomic) NSSize minSize;

- (void)drawWithFrame:(NSRect)frameRect inView:(NSView *)view;

- (NSRect)frameRectForFrame:(NSRect)frameRect;  // adjusts frame to suit -minSize if needed
- (NSRect)drawingRectForFrame:(NSRect)frameRect;
- (BOOL)mouse:(NSPoint)mousePoint isInFrame:(NSRect)frameRect inView:(NSView *)view;

@end