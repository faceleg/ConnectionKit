//
//  NSOutlineView+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

#import "NSOutlineView+KTExtensions.h"

#import "Debug.h"
#import "KTPage.h"

@implementation NSOutlineView ( KTExtensions )

- (void)expandSelectedRow
{
	[self expandItem:[self itemAtRow:[self selectedRow]]];
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
		NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
		NSNotification *notification = [NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification
																	 object:self];
		[queue enqueueNotification:notification 
					  postingStyle:NSPostASAP 
					  coalesceMask:NSNotificationCoalescingOnSender 
						  forModes:nil];
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
    while ( item = [e nextObject] )
    {
        unsigned int row = [self rowForItem:item];
        if ( 0 <= row )
        {
            [indexSet addIndex:row];
        }
    }
    
    if ( [indexSet count] > 0 )
    {
        [self selectRowIndexes:indexSet byExtendingSelection:NO];
		if ( aFlag )
		{
			NSNotificationQueue *queue = [NSNotificationQueue defaultQueue];
			NSNotification *notification = [NSNotification notificationWithName:NSOutlineViewSelectionDidChangeNotification
																		 object:self];
			[queue enqueueNotification:notification 
						  postingStyle:NSPostASAP 
						  coalesceMask:NSNotificationCoalescingOnSender 
							  forModes:nil];			
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

- (NSSet *)itemsForRows:(NSIndexSet *)rowIndexes
{
	NSMutableSet *buffer = [NSMutableSet setWithCapacity:[rowIndexes count]];
	
	unsigned index = [rowIndexes firstIndex];
	[buffer addObject:[self itemAtRow:index]];
	
	while ((index = [rowIndexes indexGreaterThanIndex:index]) != NSNotFound)
	{
		[buffer addObject:[self itemAtRow:index]];
	}
	
	return [NSSet setWithSet:buffer];
}

/*! returns outline cell via private name */
- (id)_outlineCell
{
	return _outlineCell;
}

@end
