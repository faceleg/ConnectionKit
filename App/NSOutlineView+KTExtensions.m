//
//  NSOutlineView+KTExtensions.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//

#import "NSOutlineView+KTExtensions.h"

#import "Debug.h"
#import "KTPage.h"

@implementation NSOutlineView (KTExtensions)

#pragma mark Items

- (int)numberOfChildrenOfItem:(id)item;
{
	int result = [[self dataSource] outlineView:self numberOfChildrenOfItem:item];
	return result;
}

- (id)child:(int)index ofItem:(id)item
{
	id result = [[self dataSource] outlineView:self child:index ofItem:item];
	return result;
}

- (NSArray *)itemsAtRows:(NSIndexSet *)rowIndexes
{
	// We can bail early in certain circumstances
	if (!rowIndexes || [rowIndexes count] <= 0)
	{
		return nil;
	}
	
	
	NSMutableArray *buffer = [NSMutableArray arrayWithCapacity:[rowIndexes count]];
	
	unsigned index = [rowIndexes firstIndex];
	[buffer addObject:[self itemAtRow:index]];
	
	while ((index = [rowIndexes indexGreaterThanIndex:index]) != NSNotFound)
	{
		[buffer addObject:[self itemAtRow:index]];
	}
	
	return [[buffer copy] autorelease];
}

- (NSIndexSet *)rowsForItems:(NSArray *)items;
{
	NSMutableIndexSet *buffer = [[NSMutableIndexSet alloc] init];
	NSEnumerator *itemsEnumerator = [items objectEnumerator];
	id anItem;		int aRow;
	
	while (anItem = [itemsEnumerator nextObject])
	{
		aRow = [self rowForItem:anItem];
		[buffer addIndex:aRow];
	}
	
	// Tidy up
	NSIndexSet *result = [[buffer copy] autorelease];
	[buffer release];
	return result;
}

#pragma mark Selection

- (void)expandSelectedRow
{
	[self expandItem:[self itemAtRow:[self selectedRow]]];
}

/*	Walks up the hierarchy expanding the item's parents so that it is visible.
 *	Returns the row the item ends up at. (-1 if the op couldn't be done)
 */
- (int)makeItemVisible:(id)item
{
	OBPRECONDITION(item);

	int result = [self rowForItem:item];
	if (result < 0)
	{
		id parent = nil; // [self parentOfItem:item];
		if (parent)
		{
			int parentRow = [self makeItemVisible:parent];
			if (parentRow >= 0)
			{
				[self expandItem:parent];
				result = [self rowForItem:item];
			}
		}
	}
	
	return result;
}

- (void)selectItem:(id)anItem
{
	OFF((@"selectItem: %@", [anItem titleText]));

	[self selectItem:anItem forceDidChangeNotification:NO];
}

- (void)selectItem:(id)anItem forceDidChangeNotification:(BOOL)aFlag
{
    int row = [self rowForItem:anItem];
	OFF((@"selectItem: %@ forceDidChangeNotification:%d -> row %d", [anItem titleText], aFlag, row));
    [self selectRowIndexes:[NSIndexSet indexSetWithIndex:row] byExtendingSelection:NO];
	if ( aFlag )
	{
		NSNotification *notification = [NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification
																	 object:self];
		[[NSNotificationCenter defaultCenter] postNotification:notification];
		

// THE OLD CODE WAS USING A QUEUE TO COALESCE THE NOTIFICATIONS, BUT THIS MEANS DELAYING BY ONE RUNLOOP ITERATION. Mike.
		
//		NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
//		
//		[queue enqueueNotification:notification 
//					  postingStyle:NSPostASAP 
//					  coalesceMask:NSNotificationCoalescingOnSender 
//						  forModes:nil];
	}
}

- (void)selectItems:(NSArray *)theItems
{
	[self selectItems:theItems forceDidChangeNotification:NO];
}

- (void)selectItems:(NSArray *)theItems forceDidChangeNotification:(BOOL)aFlag
{
    NSMutableIndexSet *indexSet = [NSMutableIndexSet indexSet];
    
    NSEnumerator *e = [theItems objectEnumerator];
    id item;
    while (item = [e nextObject])
    {
        int row = [self rowForItem:item];
		
		// If the item doesn't have a row, it is presumably hidden inside a collapsed parent.
		// We must work up the hierarchy expanding items until it becomes visible.
		if (row < 0)
		{
			row = [self makeItemVisible:item];
		}
		
        if (row >= 0)
        {
            [indexSet addIndex:row];
        }
    }
    
    if ([indexSet count] > 0)
    {
        [self selectRowIndexes:indexSet byExtendingSelection:NO];
		
		if (aFlag)
		{
			[[NSNotificationCenter defaultCenter] postNotificationName:NSOutlineViewSelectionDidChangeNotification
																object:self];
		}
    }
}

/*!	If one item selected, return it.  Otherwise, return nil.
*/
- (id)selectedItem
{
	if ( 1 == [self numberOfSelectedRows] )
	{
		int selectedRow = [self selectedRow];
		id result = [self itemAtRow:selectedRow];
		return result;
	}
	else
	{
		return nil;
	}
	//return (1 == [self numberOfSelectedRows]) ? [self itemAtRow:[self selectedRow]] : nil;
}

/*!	Return selected items as an array of items
*/
- (NSArray *)selectedItems
{
    NSMutableArray *array = [NSMutableArray array];
    NSIndexSet *indexSet = [self selectedRowIndexes];
    unsigned int count = [indexSet count];
    
    if ( count > 0 ) {
        unsigned int anIndex = [indexSet firstIndex];
        
		id theObj = [self itemAtRow:anIndex];
		if (nil != theObj)	// above may return null, not sure why
		{
			[array addObject:theObj];
			while ( NSNotFound != (anIndex = [indexSet indexGreaterThanIndex:anIndex]) )
			{
				theObj = [self itemAtRow:anIndex];
				if (!theObj)
				{
					theObj = [NSNull null];
				}
				[array addObject:theObj];
			}
		}
    }
    return [NSArray arrayWithArray:array];
}

- (id)itemAboveFirstSelectedRow
{
    return [self itemAtRow:[[self selectedRowIndexes] firstIndex]-1];
}

#pragma mark -
#pragma mark Drawing

/*	Equivalent to -reloadItem:reloadChildren: but for handling -setNeedsDisplayInRect:
 */
- (void)setItemNeedsDisplay:(id)item childrenNeedDisplay:(BOOL)recursive
{
	NSRect displayRect = [self rectOfRow:[self rowForItem:item]];
	
	// Basic tactic for recursive display is to union the item's rect and that of its last visible child
	if (recursive && [self isItemExpanded:item])
	{
		id lastVisibleChild = [self lastVisibleChildOfItem:item];
		NSRect lastChildRect = [self rectOfRow:[self rowForItem:lastVisibleChild]];
		displayRect = NSUnionRect(displayRect, lastChildRect);
	}
	
	[self setNeedsDisplayInRect:displayRect];
}

/*	If the item is expanded and has some children, searches down into the hierarchy to find the last visible
 *	child. Otherwise, just returns the item.
 */
- (id)lastVisibleChildOfItem:(id)item
{
	id result = item;
	
	if ([self isItemExpanded:item])
	{
		int childCount = [self numberOfChildrenOfItem:item];
		if (childCount > 0)
		{
			id lastChild = [self child:(childCount - 1) ofItem:item];
			result = [self lastVisibleChildOfItem:lastChild];
		}
	}
	
	return result;
}

@end

