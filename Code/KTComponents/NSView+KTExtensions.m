
#import "NSView+Karelia.h"

@implementation NSView ( KTExtensions )

- (NSImage *)snapshot
{ 
	return [self snapshotFromRect:[self bounds]];
}

- (NSImage *)snapshotFromRect:(NSRect)aRect;
{
	NSImage *result = [[NSImage alloc] initWithSize:aRect.size];
	
	[self lockFocus];
	NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:aRect];
	[self unlockFocus];
	
	[result addRepresentation:rep];
	[rep release];
	
	return [result autorelease];
}

/*
	NSView: Set and get a view's single subview
	Original Source: <http://cocoa.karelia.com/AppKit_Categories/NSView__Set_and_get.m>
	(See copyright notice at <http://cocoa.karelia.com>)
	 */

/*"	Set inView to be the subview of self.  If there is currently no subview, it is impossible to properly size the subview to fit within the subview.
"*/

//- (void) setSubview:(NSView *)inView
//{
//	NSArray *subviews = [self subviews];
//	
//	// Replace or insert subview if not the right one already
//	if (0 == [subviews count])
//	{
//		// needs to look at self and use that for frame calculations
//		NSView *oldSubview = [subviews objectAtIndex:0];
//		NSRect superFrame = [self bounds];
//		
//		float originX = 0;
//		float originY = 0;
//		if ( superFrame.size.height > ([inView bounds].size.height) )
//		{
//			originY = superFrame.size.height - [inView bounds].size.height;
//		}
//		
//		float width = superFrame.size.width;
//		float height = superFrame.size.height;
//		if ( [inView respondsToSelector:@selector(minimumHeight)] )
//		{
//			if ( superFrame.size.height < [(KTView *)inView minimumHeight] )
//			{
//				height = [(KTView *)inView minimumHeight];
//			}
//		}
//		
//		NSRect newFrameRect = NSMakeRect(originX, originY, width, height);
//		if ( [inView isKindOfClass:[KTView class]] )
//		{
//			NSLog(@"setting KTView as only subview with frame %@",  NSStringFromRect(newFrameRect));
//		}
//		
//		[self addSubview:inView];		// ANY WAY TO AUTO-RESIZE IT?
//		[inView setFrame:newFrameRect];
//		
//	}
//	else if ([subviews objectAtIndex:0] != inView)
//	{
//		NSView *oldSubview = [subviews objectAtIndex:0];
//		NSRect oldFrame = [oldSubview frame];
//		[oldSubview removeFromSuperview];
//		
//		float originX = 0;
//		float originY = 0;
//		if ( oldFrame.size.height > ([inView bounds].size.height) )
//		{
//			originY = oldFrame.size.height - [inView bounds].size.height;
//		}
//		
//		float width = oldFrame.size.width;
//		float height = oldFrame.size.height;
//		if ( [inView respondsToSelector:@selector(minimumHeight)] )
//		{
//			if ( oldFrame.size.height < [(KTView *)inView minimumHeight] )
//			{
//				height = [(KTView *)inView minimumHeight];
//			}
//		}
//		
//		NSRect newFrameRect = NSMakeRect(originX, originY, width, height);
//		if ( [inView isKindOfClass:[KTView class]] )
//		{
//			NSLog(@"seting KTView as a subview with frame %@", NSStringFromRect(newFrameRect));
//		}		
//		[self addSubview:inView];
//		[inView setFrame:newFrameRect];
//	}
//}
	
- (void) setSubview:(NSView *)inView
{
	NSArray *subviews = [self subviews];
	
	// Replace or insert subview if not the right one already
	if (0 == [subviews count])
	{
		[self addSubview:inView];		// ANY WAY TO AUTO-RESIZE IT?
	}
	else if ([subviews objectAtIndex:0] != inView)
	{
		NSView *oldSubview = [subviews objectAtIndex:0];
		NSRect frame = [oldSubview frame];
		[oldSubview removeFromSuperview];
		[inView setFrame:frame];
		[self addSubview:inView];
	}
}

/*"	Return the single (or first) subview of self.
"*/

- (id) subview
{
	id result = nil;
	NSArray *subviews = [self subviews];
	if ([subviews count])
	{
		result = [subviews objectAtIndex:0];
	}
	return result;
}

/*	Sets the receiver's frame so that it is centered in the rectangle
 *	The size of the receiver remains the same
 */
- (void)centerInRect:(NSRect)outerFrame
{
	NSRect myFrame = [self frame];
	
	float xInset = (outerFrame.size.width - myFrame.size.width) / 2;
	float yInset = (outerFrame.size.height - myFrame.size.height) / 2;
	
	NSRect newFrame = myFrame;
	newFrame.origin.x = outerFrame.origin.x + xInset;
	newFrame.origin.y = outerFrame.origin.y + yInset;
	
	[self setFrame: NSIntegralRect(newFrame)];
}

@end
