//
//  NarrowPopUpButtonCell.m
//  Amazon List
//
//  Created by Mike on 19/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import "NarrowPopUpButtonCell.h"
#import <CoreFoundation/CoreFoundation.h>

@implementation NarrowPopUpButtonCell

// Make the title empty for drawing.

- (NSRect)drawTitle:(NSAttributedString*)title withFrame:(NSRect)frame inView:(NSView*)controlView;
{
	static NSAttributedString *sEmptyAttributedString = nil;
	if (nil == sEmptyAttributedString)
	{
		sEmptyAttributedString = [[NSAttributedString alloc] initWithString:@""];
	}
	return [super drawTitle:sEmptyAttributedString withFrame:frame inView:controlView];
}

/*	Trick the cell into drawing its interior wider than it should be.
 *	This stops the right-hand end of the selected image being ignored
 *	// TODO: Refactor this to merge with KSPopupButtonCell
 */
- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSRect widerFrame = cellFrame;
	widerFrame.origin.x += 1.0;
	
	CGFloat adjustment = 	(floor(NSAppKitVersionNumber) <= 824) ? 15.0 : 0.0;		// 15 for tiger, not needed for Leopard

	widerFrame.size.width += adjustment;
	
	[super drawInteriorWithFrame: widerFrame inView: controlView];
}


@end
