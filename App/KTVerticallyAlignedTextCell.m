//
//  KTVerticallyAlignedTextCell.m
//  KTComponents
//
//  Created by Mike on 04/01/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTVerticallyAlignedTextCell.h"


@interface KTVerticallyAlignedTextCell (Private)
- (void)drawVerticallyCenteredWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (void)drawAtBottomOfCellWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
@end


@implementation KTVerticallyAlignedTextCell

- (id)initTextCell:(NSString *)aString
{
	[super initTextCell:aString];
	[self setVerticalAlignment:KTVerticalCenterTextAlignment];
	return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
	[super initWithCoder:decoder];
	[self setVerticalAlignment:KTVerticalCenterTextAlignment];
	return self;
}

// We don't need to implement copyWithZone: since only instance variable is not an object

# pragma mark *** Accessors ***

- (KTVerticalTextAlignment)verticalAlignment { return myVerticalAlignment; }

- (void)setVerticalAlignment:(KTVerticalTextAlignment)alignment
{
	myVerticalAlignment = alignment;
}

# pragma mark *** Drawing ***

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	switch ([self verticalAlignment])
	{
		// If vertically aligned to the top, just do the normal drawing
		case KTTopTextAlignment:
			[super drawWithFrame: cellFrame inView: controlView];
			break;
		
		case KTVerticalCenterTextAlignment:
			[self drawVerticallyCenteredWithFrame: cellFrame inView: controlView];
			break;
		
		case KTBottomTextAlignment:
			[self drawAtBottomOfCellWithFrame: cellFrame inView: controlView];
			break;
	}
}

- (void)drawVerticallyCenteredWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize textSize = [self cellSizeForBounds: cellFrame];
	float verticalOffset = (cellFrame.size.height - textSize.height) / 2;
	NSRect centeredCellFrame = NSInsetRect(cellFrame, 0.0, verticalOffset);
	
	[super drawWithFrame: centeredCellFrame inView: controlView];
}

- (void)drawAtBottomOfCellWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSSize textSize = [self cellSizeForBounds: cellFrame];
	
	// The y co-ordinate depends on the view being flipped or not
	float y = cellFrame.origin.y;
	if ([controlView isFlipped]) {
		y = cellFrame.origin.y + cellFrame.size.height - textSize.height;
	}
	 
	NSRect bottomFrame = NSMakeRect(cellFrame.origin.x,
									y,
									cellFrame.size.width,
									textSize.height);
	
	[super drawWithFrame: bottomFrame inView: controlView];
}

@end
