//
//  SVDesignChooserImageBrowserView.m
//  Sandvox
//
//  Created by Dan Wood on 12/8/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserImageBrowserView.h"
#import "SVDesignChooserImageBrowserCell.h"
#if MAC_OS_X_VERSION_MAX_ALLOWED > MAC_OS_X_VERSION_10_5
#else
#import "DumpedImageKit.h"
#endif


@implementation SVDesignChooserImageBrowserView


// If the IKImageBrowserView asked for a custom cell class, then pass on the request to the library's delegate. 
// That way the application is given a chance to customize the look of the browser...

- (Class) _cellClass
{
	return [SVDesignChooserImageBrowserCell class];
}


- (void) awakeFromNib
{
	_cellClass = [self _cellClass];
	
	if ([self respondsToSelector:@selector(setCellClass:)])
	{
		[self performSelector:@selector(setCellClass:) withObject:_cellClass];
	}
	
	[self setAllowsEmptySelection:NO];	// doesn't seem to stick when set in IB
	
	//	[self setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
	//	[self setCellSize:NSMakeSize(44.0,22.0)];
	if ([self respondsToSelector:@selector(setIntercellSpacing:)])
	{
		[self setIntercellSpacing:NSMakeSize(0.0,10.0)];	// try to get as close as possible.  don't need a subclass for just this, right?
	}
	[self setCellsStyleMask:IKCellsStyleShadowed|IKCellsStyleTitled|IKCellsStyleSubtitled];
	[self setConstrainsToOriginalSize:YES];
//	DO NOT DO THIS, BREAKS SCROLL BAR ON 10.5: [self setContentResizingMask:NSViewNotSizable];
	[self setCellSize:NSMakeSize(120,80)];	// a bit wider to allow for 4 columns.  HARD TO TELL HOW THIS REALLY ADJUSTS THINGS.
}


// This method is for 10.6 only. Create and return a cell. Please note that we must not autorelease here!

- (IKImageBrowserCell*) newCellForRepresentedItem:(id)inCell
{
	return [[_cellClass alloc] init];
}

- (void)keyDown:(NSEvent *)theEvent
{
	if (53 == [theEvent keyCode])		// escape -- doesn't seeem to be a constant for this.
	{
		[NSApp sendAction:@selector(cancelSheet:) to:nil from:self];
	}
	else
	{
		[super keyDown:theEvent];
	}
}


@end
