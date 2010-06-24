//
//  SVDesignChooserViewController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserViewController.h"
#import "NSBundle+Karelia.h"
#import "KSPlugInWrapper.h"
#import "KT.h"
#import "KTDesign.h"
#import "KTDesignFamily.h"
#import "SVDesignsController.h"

@implementation SVDesignChooserViewController

- (void)awakeFromNib
{	
	IKImageBrowserView *view = (IKImageBrowserView *)[self view];
	OBASSERT([view isKindOfClass:[IKImageBrowserView class]]);

	// We want to be notified when designs are set so we can refresh data display
	[oDesignsArrayController addObserver:self forKeyPath:@"arrangedObjects" options:(NSKeyValueObservingOptionNew) context:nil];
	[oDesignsArrayController addObserver:self forKeyPath:@"selection" options:(NSKeyValueObservingOptionNew) context:nil];
	
	
	// Here I think I want to collapse every group unless it contains the current selection!
	[view setDataSource:self];
	[view setDelegate:self];
//	[view reloadData];
		
	NSMutableDictionary *attributes;
	NSMutableParagraphStyle *paraStyle;
	
	attributes = [NSMutableDictionary dictionaryWithDictionary:[view valueForKey:IKImageBrowserCellsTitleAttributesKey]];
	paraStyle = [[[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy] autorelease];
	[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[paraStyle setTighteningFactorForTruncation:0.2];
	[attributes setObject:paraStyle forKey:NSParagraphStyleAttributeName];
	[view setValue:attributes forKey:IKImageBrowserCellsTitleAttributesKey];	

	// Same, but for highlighted
	attributes = [NSMutableDictionary dictionaryWithDictionary:[view valueForKey:IKImageBrowserCellsHighlightedTitleAttributesKey]];
	paraStyle = [[[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy] autorelease];
	[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[paraStyle setTighteningFactorForTruncation:0.2];
	[attributes setObject:paraStyle forKey:NSParagraphStyleAttributeName];
	[view setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
}

- (void) dealloc
{
	[oDesignsArrayController removeObserver:self forKeyPath:@"arrangedObjects"];
	[oDesignsArrayController removeObserver:self forKeyPath:@"selection"];

	[[self view] removeTrackingArea:_trackingArea];
	[_trackingArea dealloc];
	
	[super dealloc];
}

// Collapse all the groups except any that have the current selection.
- (void) initializeExpandedState;
{
	NSIndexSet *selIndex = [oDesignsArrayController selectionIndexes];
	int groupIndex = 0;
	IKImageBrowserView *theView = (IKImageBrowserView *)[self view];
	for (NSValue *aRangeValue in [oDesignsArrayController rangesOfGroups])
	{
		NSRange range = [aRangeValue rangeValue];
		if ([selIndex intersectsIndexesInRange:range])
		{
			[theView expandGroupAtIndex:groupIndex];
		}
		else
		{
			[theView collapseGroupAtIndex:groupIndex];
		}
		groupIndex++;
	}
}



- (void) setupTrackingRects;		// do this after the view is added and resized
{
	
	/// UNCOMMENT TO TURN THIS BACK ON
	
	_trackingArea = [[NSTrackingArea alloc] initWithRect:[[self view] frame]
												 options:NSTrackingMouseMoved|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect
												   owner:self
												userInfo:nil];
	
	[[self view] addTrackingArea:_trackingArea];
	
	// a register for those notifications on the synchronized content view.
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:[self view]];
}


- (void)mouseMoved:(NSEvent *)theEvent
{
	// DJW((@"%s %@",__FUNCTION__, theEvent));

	IKImageBrowserView *theView = (IKImageBrowserView *)[self view];
	NSPoint windowPoint = [theEvent locationInWindow];
	NSPoint localPoint = [theView convertPoint:windowPoint fromView:nil];


	if (!NSPointInRect(localPoint, [theView bounds])) return;
	
	int index = [theView indexOfItemAtPoint:localPoint];
	if (NSNotFound != index && index < [[oDesignsArrayController arrangedObjects] count])
	{
		// NSLog(@"Mouse: %@ -- index %d", NSStringFromPoint(localPoint), index);

		NSRect frame = [theView itemFrameAtIndex:index];
		float imageX = NSMidX(frame)-(kDesignThumbWidth/2);
		float howFarX = (localPoint.x - imageX) / kDesignThumbWidth;
		if (howFarX < 0.0) howFarX = 0.0;
		if (howFarX > 1.0) howFarX = 1.0;
		
		if ([[[oDesignsArrayController arrangedObjects] objectAtIndex:index] respondsToSelector:@selector(scrub:)])
		{
			[theView setAnimates:NO];		// Not sure why ... this was in Pieter Omvlee's presentation http://pieteromvlee.net/slides/IKImageBrowserView.pdf
			
			KTDesignFamily *family = [[oDesignsArrayController arrangedObjects] objectAtIndex:index];
			[family scrub:howFarX];
			if ([theView respondsToSelector:@selector(reloadCellDataAtIndex:)])
			{
				[theView reloadCellDataAtIndex:index];
			}
			else
			{
				[theView reloadData];
			}
			[theView setAnimates:YES];
		}
	}
	else
	{
//		NSLog(@"    Mouse: %@", NSStringFromPoint(localPoint));
	}
	[super mouseMoved:theEvent];
}


- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser;
{
	DJW((@"%s",__FUNCTION__));
	[oDesignsArrayController setSelectionIndexes:[aBrowser selectionIndexes]];
	
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index;
{
	// Simulate the clicking of the OK button... 
	[NSApp sendAction:@selector(chooseDesign:) to:nil from:self];	
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *) event;
{
	DJW((@"%s",__FUNCTION__));
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser backgroundWasRightClickedWithEvent:(NSEvent *) event;
{
	DJW((@"%s",__FUNCTION__));
}

// Data source

- (NSUInteger) numberOfItemsInImageBrowser:(IKImageBrowserView *) aBrowser;
{
	return [[oDesignsArrayController arrangedObjects] count];
}

- (id /*IKImageBrowserItem*/) imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index;
{
	return [ [oDesignsArrayController arrangedObjects] objectAtIndex:index];
}


- (void) imageBrowser:(IKImageBrowserView *) aBrowser removeItemsAtIndexes:(NSIndexSet *) indexes; 
{
	DJW((@"%s",__FUNCTION__));
}


- (BOOL) imageBrowser:(IKImageBrowserView *) aBrowser moveItemsAtIndexes: (NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex;
{
	return NO;
}


- (NSUInteger) imageBrowser:(IKImageBrowserView *) aBrowser writeItemsAtIndexes:(NSIndexSet *) itemIndexes toPasteboard:(NSPasteboard *)pasteboard;
{
	DJW((@"%s",__FUNCTION__));
	return -99;
}


- (NSUInteger) numberOfGroupsInImageBrowser:(IKImageBrowserView *) aBrowser;
{
	return [[oDesignsArrayController rangesOfGroups] count];
}

- (NSDictionary *) imageBrowser:(IKImageBrowserView *) aBrowser groupAtIndex:(NSUInteger) index;
{
	NSValue *rangeValue = [[oDesignsArrayController rangesOfGroups] objectAtIndex:index];
	NSRange range = [rangeValue rangeValue];
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:IKGroupBezelStyle], IKImageBrowserGroupStyleKey,
			[NSString stringWithFormat:NSLocalizedString(@"%d designs", @"count of designs in a 'family' group"), range.length], IKImageBrowserGroupTitleKey,
			rangeValue, IKImageBrowserGroupRangeKey,
			nil];
}

// We get and set the design from the IKImageBrowserView

- (void) setSelectedDesign:(KTDesign *)aDesign
{
	IKImageBrowserView *view = (IKImageBrowserView *)[self view];
	NSUInteger index = [ [oDesignsArrayController arrangedObjects] indexOfObject:aDesign];
	if (NSNotFound != index)
	{
		[view setSelectionIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[view scrollIndexToVisible:index];
	}
	else	// no selection
	{
		[view setSelectionIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
	}
}
- (KTDesign *)selectedDesign;
{
	IKImageBrowserView *view = (IKImageBrowserView *)[self view];
	NSIndexSet *selectedIndexSet = [view selectionIndexes];
	NSUInteger firstIndex = [selectedIndexSet firstIndex];
	KTDesign *result = nil;
	if (NSNotFound != firstIndex)
	{
		result = [ [oDesignsArrayController arrangedObjects] objectAtIndex:firstIndex];
	}
	if ([result isKindOfClass:[KTDesignFamily class]])
	{
		KTDesignFamily *family = (KTDesignFamily *)result;
		result = [family.designs objectAtIndex:family.imageVersion];
	}
	return result;
}


- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
	IKImageBrowserView *view = (IKImageBrowserView *)[self view];
	if ([@"arrangedObjects" isEqualToString:aKeyPath])
	{
		[view reloadData];    // it appears that IKImageBrowserView does not automatically load when setting the data source
	}
}


@end




//@implementation SVDesignChooserViewBox
//
//- (NSView *)hitTest:(NSPoint)aPoint
//{
//    return nil; // don't allow any mouse clicks for subviews (needed?)
//}
//
//@end

//@implementation SVDesignChooserSelectionView
//
//
//// view's hidden binding is bound to viewcontoller.selection (NSNegateBoolean)
//// so this only appears drawn around the selection
//- (void)drawRect:(NSRect)rect
//{
//	// draw a rectangle under where the highlight will go
//    NSBezierPath *underPath = [NSBezierPath bezierPathWithRect:rect];
//    [underPath setLineWidth:3.0];
//    [underPath setLineJoinStyle:NSRoundLineJoinStyle];
//    [[NSColor colorWithCalibratedWhite:0.10 alpha:1.0] set];
//    [underPath stroke];
//	
//    // do a thicker line in selectedControlColor to indicate selection
//    NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 1.5, 1.5) xRadius:9.0 yRadius:9.0];
//    [highlightPath setLineWidth:3.0];
//    [highlightPath setLineJoinStyle:NSRoundLineJoinStyle];
//    [[NSColor alternateSelectedControlColor] set];
//    [highlightPath stroke];
//}
//
//@end
