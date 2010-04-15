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

@implementation SVDesignChooserViewController

- (void)awakeFromNib
{	
	IKImageBrowserView *view = (IKImageBrowserView *)[self view];
	OBASSERT([view isKindOfClass:[IKImageBrowserView class]]);

	// We want to be notified when designs are set so we can refresh data display
	[self addObserver:self forKeyPath:@"designs" options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"selectedDesign" options:(NSKeyValueObservingOptionNew) context:nil];
	
	[view setDataSource:self];
	[view setDelegate:self];
		
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

	[[[self view] window] setAcceptsMouseMovedEvents:YES];

}

- (void) setupTrackingRects;		// do this after the view is added and resized
{
	
	/// UNCOMMENT TO TURN THIS BACK ON
	
	_trackingRect = [[self view] addTrackingRect:[[self view] frame] owner:self userData:nil assumeInside:NO];
	
	// a register for those notifications on the synchronized content view.
    [[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(viewBoundsDidChange:)
												 name:NSViewBoundsDidChangeNotification
											   object:[self view]];
}


- (void)mouseEntered:(NSEvent *)theEvent
{
	_wasAcceptingMouseEvents = [[[self view] window] acceptsMouseMovedEvents];
	[[[self view] window] setAcceptsMouseMovedEvents:YES];
    [[[self view] window] makeFirstResponder:self];

	DJW((@"%s %@",__FUNCTION__, theEvent));
}
- (void)mouseExited:(NSEvent *)theEvent
{
    [[[self view] window] setAcceptsMouseMovedEvents:_wasAcceptingMouseEvents];
	DJW((@"%s %@",__FUNCTION__, theEvent));
}
- (void)mouseMoved:(NSEvent *)theEvent
{
	IKImageBrowserView *theView = (IKImageBrowserView *)[self view];
	NSPoint windowPoint = [theEvent locationInWindow];
	NSPoint localPoint = [theView convertPoint:windowPoint fromView:nil];


	if (!NSPointInRect(localPoint, [theView bounds])) return;
	
	int index = [theView indexOfItemAtPoint:localPoint];
	if (NSNotFound != index)
	{
		NSLog(@"Mouse: %@ -- index %d", NSStringFromPoint(localPoint), index);

		NSRect frame = [theView itemFrameAtIndex:index];
		float imageX = NSMidX(frame)-(kDesignThumbWidth/2);
		float howFarX = (localPoint.x - imageX) / kDesignThumbWidth;
		if (howFarX < 0.0) howFarX = 0.0;
		if (howFarX > 1.0) howFarX = 1.0;
		
		if ([[self.designs objectAtIndex:index] respondsToSelector:@selector(scrub:)])
		{
			[theView setAnimates:NO];		// Not sure why ... this was in Pieter Omvlee's presentation http://pieteromvlee.net/slides/IKImageBrowserView.pdf
			
			KTDesignFamily *family = [self.designs objectAtIndex:index];
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

- (void)viewBoundsDidChange:(NSNotification *)aNotif;
{
    // we set up a tracking region so we can get mouseEntered and mouseExited events
    [[self view] removeTrackingRect:_trackingRect];
    _trackingRect = [[self view] addTrackingRect:[[self view] frame] owner:self userData:nil assumeInside:NO];
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser;
{
	DJW((@"%s",__FUNCTION__));
	
	// Re-add a tracking rect... Will this help?
	_trackingRect = [[self view] addTrackingRect:[[self view] frame] owner:self userData:nil assumeInside:NO];

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
	return [self.designs count];
}

- (id /*IKImageBrowserItem*/) imageBrowser:(IKImageBrowserView *) aBrowser itemAtIndex:(NSUInteger)index;
{
	return [self.designs objectAtIndex:index];
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
	return 1;
}


- (NSDictionary *) imageBrowser:(IKImageBrowserView *) aBrowser groupAtIndex:(NSUInteger) index;
{
	return nil;
}

// We get and set the design from the IKImageBrowserView

- (void) setSelectedDesign:(KTDesign *)aDesign
{
	IKImageBrowserView *view = (IKImageBrowserView *)[self view];
	NSUInteger index = [self.designs indexOfObject:aDesign];
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
		result = [self.designs objectAtIndex:firstIndex];
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
	if ([@"designs" isEqualToString:aKeyPath])
	{
		[view reloadData];    // it appears that IKImageBrowserView does not automatically load when setting the data source
	}
}


@synthesize designs = _designs;
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
