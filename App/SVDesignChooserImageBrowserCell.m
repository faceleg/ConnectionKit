//
//  SVDesignChooserImageBrowserCell.m
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserImageBrowserCell.h"

@implementation SVDesignChooserImageBrowserCell





//----------------------------------------------------------------------------------------------------------------------


/*
 All NSRect/NSSize methods we could override:
 - (NSRect)_iconFrameForCellFrameSize:(NSSize)fp8;
 - (NSRect)frame;
 - (NSRect)imageBorderFrame;
 - (NSRect)imageFrame;
 - (NSRect)imageFrameForCellFrame:(NSRect)fp8;
 - (NSRect)playButtonFrame;
 - (NSRect)playerFrame;
 - (NSRect)roundedFrame;
 - (NSRect)selectionFrame;
 - (NSRect)subtitleFrame;
 - (NSRect)titleFrame;
 - (NSRect)titleStringFrame;
 - (NSSize)_getTitleSize;
 - (NSSize)imageSizeForCellSize:(NSSize)fp8 withAspectRatio:(float)fp16;
 - (NSSize)size;
*/ 


//----------------------------------------------------------------------------------------------------------------------

- (void)draw;
{
	[[NSColor cyanColor] set];
	[NSBezierPath strokeRect:[self frame]];
	
	[super draw];
}

- (void)drawBackground;
{
	[[NSColor redColor] set];
	[NSBezierPath fillRect:[self frame]];
	
	[super drawBackground];
}

//- (void)drawImage:(id)fp8;	// IKImageWrapper
//{
//	NSLog(@"drawImage:%@", fp8);
//	[super drawImage:fp8];
//}
- (void)drawCenteredIcon:(id)fp8;
{
	NSLog(@"drawCenteredIcon:%@", fp8);
	[super drawCenteredIcon:fp8];
}



/*
 All draw methods we can override;
 
 - (void)draw;
 - (void)drawBackground;
 - (void)drawCenteredIcon:(id)fp8;
 - (void)drawDragHighlight;
 - (void)drawImage:(id)fp8;
 - (void)drawImageOutline;
 - (void)drawOverlays;
 - (void)drawPlaceHolder;
 - (void)drawPlayerControl;
 - (void)drawSelection;
 - (void)drawSelectionOnTitle;
 - (void)drawShadow;
 - (void)drawSubtitle;
 - (void)drawTitle;
 - (void)drawTitleBackground;
*/ 

//----------------------------------------------------------------------------------------------------------------------


//----------------------------------------------------------------------------------------------------------------------




//----------------------------------------------------------------------------------------------------------------------


@end

