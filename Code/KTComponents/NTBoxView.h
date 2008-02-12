//
//  NTBoxView.h
//  Path Finder
//
//  Created by Steve Gehrman on Sat May 17 2003.
//  Copyright (c) 2003 CocoaTech. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum { NTBoxLeft = 1 << 0, NTBoxRight = 1 << 1, NTBoxTop = 1 << 2, NTBoxBottom = 1 << 3 };
enum { NTBoxEmpty = -1, NTBoxGradient = 0 /* default */,  NTBoxBevel };

@interface NTBoxView : NSView
{
    BOOL	_drawsFrame;
    BOOL	_shadow;
	int		_borderMask;
	int		_fill;
	NSColor	*myFrameColor;
}

- (NSRect)contentBounds;

- (void)setDrawsFrame:(BOOL)set;
- (void)setDrawsFrame:(BOOL)set withShadow:(BOOL)shadow;
- (void)setFill:(int)inFill;

- (BOOL)drawsShadow;
- (BOOL)drawsFrame;

- (void)setBorderMask:(int)aMask;		// if not set -- zero -- all sides drawn.

- (NSColor *)frameColor;
- (void)setFrameColor:(NSColor *)color;
@end
