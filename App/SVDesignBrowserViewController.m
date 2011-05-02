//
//  SVDesignBrowserViewController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVDesignBrowserViewController.h"

#import "KT.h"
#import "KTDesign.h"
#import "KTDesignFamily.h"
#import "SVDesignsController.h"
#import "SVDesignChooserImageBrowserView.h"

#import "NSBundle+Karelia.h"

#import "KSPathUtilities.h"
#import "KSWorkspaceUtilities.h"

@interface IKImageBrowserView (Private10_5)

- (void) collapseGroup:group;
- (void) expandGroup:group;
- (id) layoutManager;
- (id) groups;

@end

@implementation SVDesignBrowserViewController

#pragma mark Init & Dealloc

- (void)awakeFromNib
{	
	IKImageBrowserView *imageBrowser = [self imageBrowser];

	// Here I think I want to collapse every group unless it contains the current selection!
		
	NSMutableDictionary *attributes;
	NSMutableParagraphStyle *paraStyle;
	
	attributes = [NSMutableDictionary dictionaryWithDictionary:[imageBrowser valueForKey:IKImageBrowserCellsTitleAttributesKey]];
	paraStyle = [[[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy] autorelease];
	[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[paraStyle setTighteningFactorForTruncation:0.2];
	[attributes setObject:paraStyle forKey:NSParagraphStyleAttributeName];
	[imageBrowser setValue:attributes forKey:IKImageBrowserCellsTitleAttributesKey];	

	// Same, but for highlighted
	attributes = [NSMutableDictionary dictionaryWithDictionary:[imageBrowser valueForKey:IKImageBrowserCellsHighlightedTitleAttributesKey]];
	paraStyle = [[[attributes objectForKey:NSParagraphStyleAttributeName] mutableCopy] autorelease];
	[paraStyle setLineBreakMode:NSLineBreakByTruncatingTail];
	[paraStyle setTighteningFactorForTruncation:0.2];
	[attributes setObject:paraStyle forKey:NSParagraphStyleAttributeName];
	[imageBrowser setValue:attributes forKey:IKImageBrowserCellsHighlightedTitleAttributesKey];	
    
    
    // We want to be notified when designs are set so we can refresh data display
	[oDesignsArrayController addObserver:self forKeyPath:@"arrangedObjects"
                                 options:0
                                 context:nil];
	[oDesignsArrayController addObserver:self
                              forKeyPath:@"selection"
                                 options:NSKeyValueObservingOptionInitial
                                 context:nil];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[oDesignsArrayController removeObserver:self forKeyPath:@"arrangedObjects"];
	[oDesignsArrayController removeObserver:self forKeyPath:@"selection"];

	[self setImageBrowser:nil];
    OBPOSTCONDITION(!_browser);
    
	[_trackingArea dealloc];
	
	[super dealloc];
}

// Collapse all the groups except any that have the current selection.
- (void) initializeExpandedState;
{
	NSIndexSet *selIndex = [oDesignsArrayController selectionIndexes];
	int groupIndex = 0;
	IKImageBrowserView *theView = [self imageBrowser];
	for (NSValue *aRangeValue in [oDesignsArrayController rangesOfGroups])
	{
		NSRange range = [aRangeValue rangeValue];
		BOOL expanded = [selIndex intersectsIndexesInRange:range];
		if (expanded)
		{
			if ([theView respondsToSelector:@selector(expandGroupAtIndex:)])	// 10.5 headers lie; only in 10.6
			{
				[theView expandGroupAtIndex:groupIndex];
			}
			else if ([theView respondsToSelector:@selector(expandGroup:)]
					 && [theView respondsToSelector:@selector(layoutManager)])	// 10.5 workaround
			{
				id lm = [theView layoutManager];
				NSArray *groups = [lm groups];
				id group = [groups objectAtIndex:groupIndex];
				[theView expandGroup:group];
			}
		}
		else
		{
			if ([theView respondsToSelector:@selector(collapseGroupAtIndex:)])	// 10.5 headers lie; only in 10.6
			{
				[theView collapseGroupAtIndex:groupIndex];
				OFF((@"Collapsing group index %d - %@", groupIndex, NSStringFromRange(range)));
			}
			else if ([theView respondsToSelector:@selector(collapseGroup:)]
					 && [theView respondsToSelector:@selector(layoutManager)])	// 10.5 workaround
			{
				id lm = [theView layoutManager];
				NSArray *groups = [lm groups];
				id group = [groups objectAtIndex:groupIndex];
				[theView collapseGroup:group];
				OFF((@"Collapsing group index %d - %@", groupIndex, NSStringFromRange(range)));
			}
		}
		
		[self setContracted:!expanded forRange:range];

		groupIndex++;
	}
}



- (void)setupTrackingRects:(IKImageBrowserView *)imageBrowser;		// do this after the view is added and resized
{
	
	/// UNCOMMENT TO TURN THIS BACK ON
	
	_trackingArea = [[NSTrackingArea alloc] initWithRect:[imageBrowser frame]
												 options:NSTrackingMouseMoved|NSTrackingActiveInKeyWindow|NSTrackingInVisibleRect
												   owner:self
												userInfo:nil];
	
	[imageBrowser addTrackingArea:_trackingArea];
	
	// a register for those notifications on the synchronized content view.
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSViewBoundsDidChangeNotification object:imageBrowser];	// in case we are changing to a new view?
    if (imageBrowser)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(viewBoundsDidChange:)
                                                     name:NSViewBoundsDidChangeNotification
                                                   object:imageBrowser];
    }
}

#pragma mark View

- (IKImageBrowserView *)imageBrowser;
{
    [self view];    // make sure it's loaded
    return _browser;
}

- (void)setImageBrowser:(IKImageBrowserView *)imageBrowser;
{
    if (imageBrowser == _browser) return;
    
    [_browser removeTrackingArea:_trackingArea];
    
    // Dispose of old properly
    [_browser setDelegate:nil];
    [_browser setDataSource:nil];
    
    [_browser release]; _browser = [imageBrowser retain];
    
	[imageBrowser setDataSource:self];
	[imageBrowser setDelegate:self];
    if (oDesignsArrayController) [imageBrowser reloadData];
    
    [self setupTrackingRects:imageBrowser];
}

#pragma mark Mouse Events

- (void)mouseMoved:(NSEvent *)theEvent
{
	IKImageBrowserView *theView = [self imageBrowser];
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
		
		KTDesign *theDesign = [[oDesignsArrayController arrangedObjects] objectAtIndex:index];
		
		if (theDesign.isContracted)
		{
			[theView setAnimates:NO];		// Not sure why ... this was in Pieter Omvlee's presentation http://pieteromvlee.net/slides/IKImageBrowserView.pdf
			
			[theDesign scrub:howFarX];
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

#pragma mark Image Browser Datasource/Delegate

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index;
{
	// Simulate the clicking of the OK button... 
	[NSApp sendAction:@selector(chooseDesign:) to:nil from:self];	
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser
	cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *)event
{
	//contextual menu for item index
	NSMenu*  menu;
	
	menu = [[NSMenu alloc] initWithTitle:@"menu"];
	[menu setAutoenablesItems:NO];

	// Only can reveal designs not in the 
	_rightClickedIndex = index;
	KTDesign *design = [[oDesignsArrayController arrangedObjects] objectAtIndex:index];
	//NSString *path = [[design bundle] bundlePath];
	BOOL canBeRevealed = YES; // ... MAYBE ONLY EXTERNAL DESIGNS? ... ![path ks_isSubpathOfPath:[[NSBundle mainBundle] bundlePath]];
	
	[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"Reveal in Finder", @"")] action:@selector(revealDesign) keyEquivalent:@""];
	
	[[menu itemAtIndex:0] setTarget:self];
	[[menu itemAtIndex:0] setEnabled:canBeRevealed];

	// OPTIONAL -- open home page for third-party design
	
	if ([design URL])
	{
		[menu addItemWithTitle:[NSString stringWithFormat:NSLocalizedString(@"View Website for Design", @"")] action:@selector(openDesignURL) keyEquivalent:@""];
		[[menu itemAtIndex:1] setTarget:self];
	}
	
	
	
	[NSMenu popUpContextMenu:menu withEvent:event forView:aBrowser];
	
	[menu release];
}

- (void) revealDesign
{
	KTDesign *design = [[oDesignsArrayController arrangedObjects] objectAtIndex:_rightClickedIndex];
	NSString *path = [[design bundle] bundlePath];
	[KSWORKSPACE selectFile:path inFileViewerRootedAtPath:@""];
}

- (void) openDesignURL
{
	KTDesign *design = [[oDesignsArrayController arrangedObjects] objectAtIndex:_rightClickedIndex];
	NSURL *URL = [design URL];
	[KSWORKSPACE openURL:[URL absoluteURL]];
}



// Data source

- (NSUInteger)numberOfItemsInImageBrowser:(IKImageBrowserView *)aBrowser;
{
	return [[oDesignsArrayController arrangedObjects] count];
}

- (id /*IKImageBrowserItem*/)imageBrowser:(IKImageBrowserView *)aBrowser itemAtIndex:(NSUInteger)index;
{
	return [[oDesignsArrayController arrangedObjects] objectAtIndex:index];
}

- (BOOL)imageBrowser:(IKImageBrowserView *)aBrowser moveItemsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex;
{
	return NO;
}

- (NSUInteger)numberOfGroupsInImageBrowser:(IKImageBrowserView *)aBrowser;
{
	return [[oDesignsArrayController rangesOfGroups] count];
}

- (NSDictionary *)imageBrowser:(IKImageBrowserView *)aBrowser groupAtIndex:(NSUInteger)index;
{
	NSValue *rangeValue = [[oDesignsArrayController rangesOfGroups] objectAtIndex:index];
	NSRange range = [rangeValue rangeValue];
	
	NSString *countString = (range.length < 2)
		? NSLocalizedString(@"1 variation", @"1 designs in a 'family' group")
		: [NSString stringWithFormat:NSLocalizedString(@"%d variations", @"count of designs in a 'family' group."), range.length];
				// Should be plenty of room e.g. ... 3 Varianten, 3 variantes, 3 variações, 3 varianti
	
	return [NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:IKGroupBezelStyle], IKImageBrowserGroupStyleKey,
			countString, IKImageBrowserGroupTitleKey,
			rangeValue, IKImageBrowserGroupRangeKey,
			nil];
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)aKeyPath
                      ofObject:(id)anObject
                        change:(NSDictionary *)aChange
                       context:(void *)aContext
{
	if ([@"arrangedObjects" isEqualToString:aKeyPath])
	{
		[[self imageBrowser] reloadData];    // it appears that IKImageBrowserView does not automatically load when setting the data source
		[self initializeExpandedState];
	}
}

#pragma mark Refresh when expanded/contracted

- (void) setContracted:(BOOL)contracted forRange:(NSRange)range
{
	NSArray *objects = [oDesignsArrayController arrangedObjects];
	
	// Adjust the *first* item in this range; it will be changing depending on expanded/collapsed state.

	[[objects objectAtIndex:range.location] setContracted:contracted];
	
	IKImageBrowserView *theView = [self imageBrowser];
	if ([theView respondsToSelector:@selector(reloadCellDataAtIndex:)])
	{
		[theView reloadCellDataAtIndex:range.location];
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
