//
//  KTDocWindowController+SplitViews.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony LLC. All rights reserved.
//

/*
PURPOSE OF THIS CLASS/CATEGORY:
	Constraints and such related to the splitview.

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	x

TO DO:

 */

#import "KTDocWindowController.h"

#import "KTAppDelegate.h"
#import "KTDocument.h"
#import "KTDesignPickerView.h"
#import "KTComponents.h"
#import <iMediaBrowser/iMedia.h>

#pragma mark -
#pragma mark SplitView (Notifications)

@implementation KTDocWindowController ( SplitViews )

- (void) updateDraggerState
{
	RBSplitSubview *sidebarSplit = [oSidebarSplitView subviewAtPosition:0];
	
	NSString *toolTipText;
	if ([sidebarSplit isCollapsed])
	{
		toolTipText = NSLocalizedString(@"Drag to the right to reveal the site outline sitebar",@"tooltip");
	}
	else
	{
		toolTipText = NSLocalizedString(@"Drag to the left or right to adjust the width of the site outline sidebar.",@"tooltip");
	}
	[oSplitDragView setToolTip:toolTipText];
}

- (NSTimeInterval)splitView:(RBSplitView*)sender willAnimateSubview:(RBSplitSubview*)subview withDimension:(float)dimension;
{
	return // ([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask)
			//	? 3.0		// SLOW ... DON'T DO SLOW ANIMATION BECAUSE IT CONFLICTS WITH COMMAND-SHIFT-D KEY
			//	:
			dimension * (0.2/150.0);
}

- (void)splitView:(RBSplitView*)sender didCollapse:(RBSplitSubview*)subview
{
    if ( sender == oSidebarSplitView )
    {
		[[NSApp delegate] updateMenusForDocument:[self document]];
		[[self document] setDisplaySiteOutline:NO];
		[self updateDraggerState];
    }
	else if (sender == oDesignsSplitView)
	{
		[[NSApp delegate] updateMenusForDocument:[self document]];
		[oDesignsView inUse:NO];
	}
}

- (void)splitView:(RBSplitView*)sender didExpand:(RBSplitSubview*)subview;
{
    if ( sender == oSidebarSplitView )
    {
		[[NSApp delegate] updateMenusForDocument:[self document]];
		[[self document] setDisplaySiteOutline:YES];
		[self updateDraggerState];
    }
	if (sender == oDesignsSplitView)
	{
		[[NSApp delegate] updateMenusForDocument:[self document]];

		[oDesignsView inUse:YES];		// set up UI since we're showing it
	}
}

static float sGrowCutoffSidebarDimension;

/*!	Cause the little dragging view to work as the dragger
*/
- (int)splitView:(RBSplitView*)sender dividerForPoint:(NSPoint)point inSubview:(RBSplitSubview*)subview
{
	int result = NSNotFound;
	
	if (sender == oSidebarSplitView)
	{
		RBSplitSubview *sidebarSplit = [sender subviewAtPosition:0];
		RBSplitSubview *webviewSplit = [sender subviewAtPosition:1];
		// Check for dragging control in lower left corner of right-hand subview
		if (subview == webviewSplit)
		{
			if ([oSplitDragView mouse:[oSplitDragView convertPoint:point fromView:sender] inRect:[oSplitDragView bounds]])
			{
				result = 0;
			}
		}
		else if (subview == sidebarSplit)
		{
			// check for the narrow rectangle that's the edge between the two views
			NSRect bounds = [subview bounds];
			bounds.origin.x += bounds.size.width - 1;
			bounds.size.width = 1;
			
			if ([oSplitDragView mouse:point inRect:bounds])
			{
				result = 0;
			}
		}
		if (0 == result)
		{
			// If we are about to drag, make this calculation
			// Mark the sidebar dimension where values above will force a grow/shrink of the window.
			sGrowCutoffSidebarDimension = [subview dimension]
				+ [webviewSplit dimension] - [webviewSplit minDimension];
		}
	}
	return result;
}


/*!	Grow the window if the webview is already at its minimum size (growing only)
or if the option key is held down while dragging.
This will shrink the window to APPROXIMATELY return the window to its original size before
you start dragging to enlarge.  Not exact, depending on how fast mouse is moved.  But close enough.
*/
- (BOOL)splitView:(RBSplitView*) sender
			 shouldResizeWindowForDivider:(unsigned int)divider
	  betweenView:(RBSplitSubview*)leading
								  andView:(RBSplitSubview*)trailing
								 willGrow:(BOOL)grow
{
	if (sender == oSidebarSplitView)
	{
		RBSplitSubview *sidebarSplit = [sender subviewAtPosition:0];
		RBSplitSubview *webviewSplit = [sender subviewAtPosition:1];
		BOOL result;
		if (grow)
		{
			// Grow if there's not room for the two views to be seen
			result = [webviewSplit dimension] < [webviewSplit minDimension] + [sidebarSplit minDimension];
		}
		else
		{
			// Shrink if we have moved the sidebar position is to the left of our starting point
			result = ([sidebarSplit dimension] >= sGrowCutoffSidebarDimension);
		}
		result |= 0 != ([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask);
		return result;
	}
	else
	{
		return NO;
	}
}

- (NSRect)splitView:(RBSplitView*)sender cursorRect:(NSRect)rect forDivider:(unsigned int)divider
{
	if (sender == oSidebarSplitView)
	{
		[sender addCursorRect:[oSplitDragView convertRect:[oSplitDragView bounds] toView:sender]
					   cursor:[RBSplitView cursor:RBSVVerticalCursor]];

		RBSplitSubview *sidebarSplit = [sender subviewAtPosition:0];
		NSRect bounds = [sidebarSplit bounds];
		bounds.origin.x += bounds.size.width - 1;
		bounds.size.width = 1;
		[sender addCursorRect:bounds cursor:[RBSplitView cursor:RBSVVerticalCursor]];

		return rect;
	}
	else
	{
		return NSZeroRect;
	}
}


/*!	Don't let sidebar expand as window expands.
But as window shrinks, allow the sidebar to shrink (to the collapsing point) if needed.
*/
- (void)splitView:(RBSplitView*)sender wasResizedFrom:(float)oldDimension to:(float)newDimension
{
	if (sender == oSidebarSplitView)
	{
		RBSplitSubview *sidebarSplit = [sender subviewAtPosition:0];
		RBSplitSubview *webviewSplit = [sender subviewAtPosition:1];
		
		// If the space left for the web view is at least its minimum, only adjust webview dim.
		// (otherwise, this will allow both views to resize, which will leave webview at minimum)
		if (newDimension - [sidebarSplit dimension] >= [webviewSplit minDimension])
		{
			[sender adjustSubviewsExcepting:sidebarSplit];
		}
		[self updateDraggerState];
	}
}

- (RBSplitView *)siteOutlineSplitView { return oSidebarSplitView; }

@end
