//
//  ContactElementFieldCell.m
//  ContactElement
//
//  Created by Mike on 17/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "ContactElementFieldCell.h"

#import <SandvoxPlugin.h>


@interface ContactElementFieldCell (Private)
- (NSImageCell *)lockIconCell;
@end


@implementation ContactElementFieldCell

#pragma mark -
#pragma mark Memory Management

- (void)dealloc
{
	[myLockIconCell release];
	
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	ContactElementFieldCell *copy = [super copyWithZone:zone];
	
	[copy->myLockIconCell retain];
	
	return copy;
}

#pragma mark -
#pragma mark Accessors

- (BOOL)isLocked { return myLocked; }

- (void)setLocked:(BOOL)locked { myLocked = locked; }

#pragma mark -
#pragma mark Drawing

- (NSImageCell *)lockIconCell
{
	if (!myLockIconCell)
	{
		NSImage *icon = [NSImage imageNamed:@"NSLockLockedTemplate"];	// try for Leopard resizable version
		if (nil == icon)
		{
			// fallback
			icon = [NSImage imageInBundle:[NSBundle bundleForClass:[self class]]
									named:@"lock.png"];
		}
	
		myLockIconCell = [[NSImageCell alloc] initImageCell:icon];
		[myLockIconCell setImageAlignment:NSImageAlignCenter];
		[myLockIconCell setImageScaling:NSScaleNone];
	}
	
	return myLockIconCell;
}

/*	How we draw depends on if there is a lock icon to draw
 */
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	if ([self isLocked])
	{
		// Split the cell in two
		NSRect textRect;
		NSRect lockIconRect;
		NSDivideRect(cellFrame, &lockIconRect, &textRect, cellFrame.size.height, NSMaxXEdge);
		
		[super drawWithFrame:textRect inView:controlView];
		[[self lockIconCell] drawWithFrame:lockIconRect inView:controlView];
	}
	else
	{
		[super drawWithFrame:cellFrame inView:controlView];
	}
}

@end
