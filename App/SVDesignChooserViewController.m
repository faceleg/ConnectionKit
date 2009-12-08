//
//  SVDesignChooserViewController.m
//  Sandvox
//
//  Created by Terrence Talbot on 8/28/09.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDesignChooserViewController.h"
#import "NSBundle+Karelia.h"
#import "KSPlugin.h"
#import "KT.h"
#import "KTDesign.h"

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
	
	// [view setCellSize:NSMakeSize(100,65)];
}

- (void) setupTrackingRects;		// do this after the view is added and resized
{
	// _trackingRect = [[self view] addTrackingRect:[[self view] frame] owner:self userData:nil assumeInside:NO];
	
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

	NSLog(@"%s %@",__FUNCTION__, theEvent);
}
- (void)mouseExited:(NSEvent *)theEvent
{
    [[[self view] window] setAcceptsMouseMovedEvents:_wasAcceptingMouseEvents];
	NSLog(@"%s %@",__FUNCTION__, theEvent);
}
- (void)mouseMoved:(NSEvent *)theEvent
{
#define CELLWIDTH 150
#define CELLHEIGHT 112
//	NSLog(@"%s %@",__FUNCTION__, theEvent);
	NSPoint windowPoint = [theEvent locationInWindow];
	NSPoint localPoint = [[self view] convertPoint:windowPoint fromView:nil];

	NSSize itemSize = NSMakeSize(CELLWIDTH,CELLHEIGHT);		// this is constant in our case ... is there any good way to query this?
	int xIndex = localPoint.x / itemSize.width;
	int yIndex = localPoint.y / itemSize.height;
	int listIndex = yIndex * 4 + xIndex;
	if (listIndex < [self.designs count])
	{
		NSRect frameForItemAtIndex = NSMakeRect(CELLWIDTH*xIndex, CELLHEIGHT*yIndex, CELLWIDTH, CELLHEIGHT);
		
		if ([[self view] respondsToSelector:@selector(frameForItemAtIndex:)])		// 10.6
		{
//			frameForItemAtIndex = [[self view] frameForItemAtIndex:listIndex];
		}
		
		NSLog(@"%@ %d,%d -> %d : %@",NSStringFromPoint(localPoint), xIndex,yIndex, listIndex, NSStringFromRect(frameForItemAtIndex));

		[[self view] setNeedsDisplayInRect:frameForItemAtIndex];
		
		
	}
	else
	{
		NSLog(@"out of bounds");
	}
}



- (void)viewBoundsDidChange:(NSNotification *)aNotif;
{
    // we set up a tracking region so we can get mouseEntered and mouseExited events
    [[self view] removeTrackingRect:_trackingRect];
    _trackingRect = [[self view] addTrackingRect:[[self view] frame] owner:self userData:nil assumeInside:NO];
}

- (void) imageBrowserSelectionDidChange:(IKImageBrowserView *) aBrowser;
{
	NSLog(@"%s",__FUNCTION__);
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasDoubleClickedAtIndex:(NSUInteger) index;
{
	NSLog(@"%s",__FUNCTION__);
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser cellWasRightClickedAtIndex:(NSUInteger) index withEvent:(NSEvent *) event;
{
	NSLog(@"%s",__FUNCTION__);
}

- (void) imageBrowser:(IKImageBrowserView *) aBrowser backgroundWasRightClickedWithEvent:(NSEvent *) event;
{
	NSLog(@"%s",__FUNCTION__);
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
	NSLog(@"%s",__FUNCTION__);
}


- (BOOL) imageBrowser:(IKImageBrowserView *) aBrowser moveItemsAtIndexes: (NSIndexSet *)indexes toIndex:(NSUInteger)destinationIndex;
{
	return NO;
}


- (NSUInteger) imageBrowser:(IKImageBrowserView *) aBrowser writeItemsAtIndexes:(NSIndexSet *) itemIndexes toPasteboard:(NSPasteboard *)pasteboard;
{
	NSLog(@"%s",__FUNCTION__);
	return -99;
}


- (NSUInteger) numberOfGroupsInImageBrowser:(IKImageBrowserView *) aBrowser;
{
	NSLog(@"%s",__FUNCTION__);
	return 1;
}


- (NSDictionary *) imageBrowser:(IKImageBrowserView *) aBrowser groupAtIndex:(NSUInteger) index;
{
	NSLog(@"%s",__FUNCTION__);
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



@implementation SVDesignChooserScrollView

- (void)awakeFromNib
{
    //NSColor *startingColor = [NSColor darkGrayColor];
    //NSColor *endingColor = [NSColor blackColor];
    //_backgroundGradient = [[NSGradient alloc] initWithStartingColor:startingColor
    //                                                    endingColor:endingColor];    
}

- (void)drawRect:(NSRect)rect
{
    //[_backgroundGradient drawInRect:[self bounds] angle:90.0];
    //[[NSColor colorWithCalibratedRed:0.079 green:0.079 blue:0.079 alpha:1.000] set];
    //[NSBezierPath fillRect:rect];
}

- (void)dealloc
{
    //[_backgroundGradient release];
    [super dealloc];
}

@end

@implementation SVDesignChooserViewBox

- (NSView *)hitTest:(NSPoint)aPoint
{
    return nil; // don't allow any mouse clicks for subviews (needed?)
}

@end

@implementation SVDesignChooserSelectionView


// view's hidden binding is bound to viewcontoller.selection (NSNegateBoolean)
// so this only appears drawn around the selection
- (void)drawRect:(NSRect)rect
{
	// draw a rectangle under where the highlight will go
    NSBezierPath *underPath = [NSBezierPath bezierPathWithRect:rect];
    [underPath setLineWidth:3.0];
    [underPath setLineJoinStyle:NSRoundLineJoinStyle];
    [[NSColor colorWithCalibratedWhite:0.10 alpha:1.0] set];
    [underPath stroke];
	
    // do a thicker line in selectedControlColor to indicate selection
    NSBezierPath *highlightPath = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 1.5, 1.5) xRadius:9.0 yRadius:9.0];
    [highlightPath setLineWidth:3.0];
    [highlightPath setLineJoinStyle:NSRoundLineJoinStyle];
    [[NSColor alternateSelectedControlColor] set];
    [highlightPath stroke];
}

@end
