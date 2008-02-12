//
//  UnifiedTableButtonCell.m
//  KTPlugins
//
//  Created by Mike on 10/05/2007.
//  Copyright 2007 __MyCompanyName__. All rights reserved.
//

#import "UnifiedTableButtonCell.h"


@implementation UnifiedTableButtonCell

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// Draw the right-hand border
	NSColor *borderColor = [NSColor lightGrayColor];
	[borderColor set];
	
	NSRect buttonFrame = NSInsetRect(cellFrame, 0.0, 1.0);
	
	NSRect borderRect = NSMakeRect(NSMaxX(buttonFrame) - 1.0,
								   buttonFrame.origin.y,
								   1.0,
								   buttonFrame.size.height - 1.0);
	
	NSRectFill(borderRect);
	
	
	// Draw the rest of the button
	[super drawWithFrame:cellFrame inView:controlView];
	
	
	// Draw the highlight if needed
	if ([self isHighlighted]) {
		[[NSColor colorWithCalibratedWhite:0.5 alpha:0.5] set];
		NSRectFillUsingOperation(cellFrame, NSCompositeSourceOver);
	}
}

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	// Interior drawing is reduced in width by 1 pixel to account for our single border on the right-hand side
	cellFrame.size.width -= 1.0;
	[super drawInteriorWithFrame:cellFrame inView:controlView];
}

- (void)drawImage:(NSImage*)image withFrame:(NSRect)frame inView:(NSView*)controlView
{
	// Shift the image up two pixels to center it (NSButtonCell seems to get this bit wrong on its own!)
	if ([controlView isFlipped]) {
		frame.origin.y -= 2.0;
	}
	else {
		frame.origin.y += 2.0;
	}
	
	[super drawImage:image withFrame:frame inView:controlView];
}

@end
