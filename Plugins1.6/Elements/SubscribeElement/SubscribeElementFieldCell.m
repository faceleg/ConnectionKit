//
//  SubscribeElementFieldCell.m
//  SubscribeElement
//
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "SubscribeElementFieldCell.h"

#import "SandvoxPlugin.h"


@interface SubscribeElementFieldCell (Private)
- (NSImageCell *)lockIconCell;
@end


@implementation SubscribeElementFieldCell

#pragma mark -
#pragma mark Memory Management

- (void)dealloc
{
	[myLockIconCell release];
	
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone
{
	SubscribeElementFieldCell *copy = [super copyWithZone:zone];
	
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
