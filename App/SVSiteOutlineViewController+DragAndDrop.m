//
//  KTSiteOutlineDataSource+DragAndDrop.m
//  Marvel
//
//  Created by Mike on 11/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


#import "Debug.h"
#import "DOMNode+KTExtensions.h"
#import "KT.h"
#import "KTElementPlugin+DataSourceRegistration.h"
#import "SVSiteOutlineViewController.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTDocWindowController.h"
#import "KTLinkSourceView.h"
#import "KTPage+Internal.h"
#import "KTElementPlugin.h"

#import "NSArray+Karelia.h"
#import "NSException+Karelia.h"
#import "NSIndexSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"

#import "Elements+Pasteboard.h"

#import "KSProgressPanel.h"


/// these are localized strings for Case 26766 Disposable Dialog When Changing A Published Page's Path
// NSLocalizedString(@"Are you sure you wish to change the file name of this page?", @"title of alert when changing page file name")
// NSLocalizedString(@"Changing the file name of this page will also change the URL of this page. Because this page has been previously published, any bookmarks or links to this page from other websites will no longer work.", @"body of alert when changing page file name")
// NSLocalizedString(@"Change", @"alert button when changing file name")
// NSLocaiizedString(@"Note: the previously published page '%@' will not be deleted from your server.", @"alert optional note when changing page file name")



@interface SVSiteOutlineViewController (DragAndDropPrivate)

- (NSDragOperation)validateLinkDrop:(NSString *)link onProposedItem:(SVSiteItem *)proposedItem;
- (BOOL)acceptInternalDrop:(NSPasteboard *)pboard ontoPage:(KTPage *)page childIndex:(int)anIndex;
- (BOOL)acceptArchivedPagesDrop:(NSArray *)archivedPages ontoPage:(KTPage *)page childIndex:(int)anIndex;

- (void)setDropSiteItem:(id)item dropChildIndex:(NSInteger)index;
- (NSArray *)itemsForRows:(NSArray *)anArray;
- (BOOL)item:(id)anItem isDescendantOfItem:(id)anotherItem;
- (BOOL)items:(NSArray *)items containsParentOfItem:(id)item;
@end


#pragma mark -


@implementation SVSiteOutlineViewController (DragAndDrop)

#pragma mark Drag

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    if (isLocal) 
	{
        return NSDragOperationMove;
    }
	
    return NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pboard
{
	[pboard declareTypes:[NSArray arrayWithObject:kKTPagesPboardType] owner:self];
    
    NSArray *pages = items; // TODO: Only write the highest-level pages
    [self setLastItemsWrittenToPasteboard:pages];
    
    NSArray *serializedPages = [pages valueForKey:@"propertyListRepresentation"];
    [pboard setPropertyList:serializedPages forType:kKTPagesPboardType];
    
    
    
    
	return YES;
}

- (NSArray *)lastItemsWrittenToPasteboard { return _draggedItems; }
- (void)setLastItemsWrittenToPasteboard:(NSArray *)items
{
    items = [items copy];
    [_draggedItems release]; _draggedItems = items;
}

#pragma mark Validating a Drop

- (NSDragOperation)validateNonLinkDrop:(id <NSDraggingInfo>)info
                    proposedCollection:(KTPage *)collection
                    proposedChildIndex:(NSInteger)index;
{
    //  Rather like the Outline View datasource method, but has already taken into account the layout of root
    
    
    OBPRECONDITION(collection);
    OBPRECONDITION([collection isCollection]);
    
    
    // Rule 2.
    if (index != NSOutlineViewDropOnItemIndex &&
        [[collection collectionSortOrder] integerValue] != SVCollectionSortManually)
    {
        index = NSOutlineViewDropOnItemIndex;
        [self setDropSiteItem:collection dropChildIndex:index];
    }
    
    
    
    // Is the aim to move a page within the Site Outline?
    if ([info draggingSource] == [self outlineView] &&
        [info draggingSourceOperationMask] & NSDragOperationMove)
    {
        NSArray *draggedItems = [self lastItemsWrittenToPasteboard];
        
        // Rule 4. Don't allow a collection to become a descendant of itself
        for (SVSiteItem *aDraggedItem in draggedItems)
        {
            if ([collection isDescendantOfItem:aDraggedItem]) return NSDragOperationNone;
        }
        
        
        return NSDragOperationMove;
    }
    
        
    // Pretend we're going to do the preferred operation
    if ([info draggingSourceOperationMask] & NSDragOperationCopy) return NSDragOperationCopy;
    if ([info draggingSourceOperationMask] & NSDragOperationMove) return NSDragOperationMove;
    return NSDragOperationNone;
}

- (NSDragOperation)validateLinkDrop:(NSString *)pboardString onProposedItem:(SVSiteItem *)item;
{
    // If our input string is a collection, then return NO if it's not a collection.
    if ([pboardString isEqualToString:@"KTCollection"] && ![item isCollection])
    {
        return NSDragOperationNone;
    }
    //set up a pulsating window
    if (item)
    {
        NSInteger row = [[self outlineView] rowForItem:item];
        NSRect rowRect = [[self outlineView] rectOfRow:row];
        //covert the origin to window coords
        rowRect.origin = [[[self view] window] convertBaseToScreen:[[self outlineView] convertPoint:rowRect.origin toView:nil]];
        rowRect.origin.y -= NSHeight(rowRect); //handle it because it is flipped.
        if (!NSEqualSizes(rowRect.size, NSZeroSize))
        {
        }
        else
        {
        }
        
        return NSDragOperationLink;
    }
    else
    {
        return NSDragOperationNone;
    }
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
				  validateDrop:(id <NSDraggingInfo>)info
				  proposedItem:(id)item
			proposedChildIndex:(NSInteger)anIndex
{
    // There's 2 basic types of drop: creating a link, and everything else. Links are special because they create nothing. Instead it's a feedback mechanism to the source view
    
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([[pboard types] containsObject:kKTLocalLinkPboardType])
	{
        if (item && anIndex == NSOutlineViewDropOnItemIndex)
        {
            NSString *pboardString = [pboard stringForType:kKTLocalLinkPboardType];
            return [self validateLinkDrop:pboardString onProposedItem:item];
        }
        else
        {
            return NSDragOperationNone;
        }
    }
    
	
    
    // THE RULES:
    //  1.  The drop item can only be a collection
    //  2.  You can only drop at a specific index if the collection is manually sorted
    //  3.  You can't drop above the root page
    //  4.  When moving an existing page, can't drop it as a descendant of itself
    
    
    
    // Correct for the root page. i.e. a drop with a nil item is actually a drop onto/in the root page, and the index needs to be bumped slightly
    SVSiteItem *siteItem = item;
    NSInteger index = anIndex;
    if (!siteItem)
    {
        if (anIndex == 0) return NSDragOperationNone;   // rule 3.
        
        siteItem = [self rootPage];
        if (index != NSOutlineViewDropOnItemIndex) 
        {
            index--;    // we've already weeded out the case of index being 0
        }
    }
    OBASSERT(siteItem);
    
    
    // Rule 1. Only a collection can be dropped on/into.
    if ([siteItem isCollection])
    {
        return [self validateNonLinkDrop:info
                      proposedCollection:[siteItem pageRepresentation]
                      proposedChildIndex:index];
    }
    
    
    return NSDragOperationNone;
}

#pragma mark Accepting a Drop

- (BOOL)acceptNonLinkDrop:(id <NSDraggingInfo>)info
               collection:(KTPage *)collection
               childIndex:(int)index;
{
    OBPRECONDITION(collection);
    
    
    // The new page must be a child of something
    NSPasteboard *pboard = [info draggingPasteboard];
	
	BOOL cameFromProgram = nil != [info draggingSource];
	
	if (cameFromProgram)
	{
		if  ([[self outlineView] isEqual:[info draggingSource]])
		{
			// drag is internal to document
			if ([pboard availableTypeFromArray:[NSArray arrayWithObject:kKTOutlineDraggingPboardType]])
			{
				BOOL result = [self acceptInternalDrop:pboard ontoPage:collection childIndex:index];
				return result;
			}
			else if ( NO )
			{
				// other internal pboard types
				;
			}
		}
		else if ([pboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]])
		{
			// we have some pages on the pasteboard that we want to add at the drop point
			NSData *pboardData = [pboard dataForType:kKTPagesPboardType];
			if (pboardData)
			{
				NSArray *archivedPages = [NSKeyedUnarchiver unarchiveObjectWithData:pboardData];
				return [self acceptArchivedPagesDrop:archivedPages ontoPage:collection childIndex:index];
			}
		}
	}
	else if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTLocalLinkPboardType]] )
	{
		// hide the pulsating window
		// Get the page and update the pboard with it ... a way to send the info back to the origin of the drag!
		[pboard setString:[collection uniqueID] forType:kKTLocalLinkPboardType];
		return YES;
	}
	
	// this should be a drag in from outside the application, or an internal drag not covered above.
	// we want to find a drag source for it and let it do its thing
	int dropIndex = index;
	id dropItem = collection;
	if ( nil == dropItem )
	{
		dropItem = [self rootPage];
		dropIndex = index-1;
	}
	//LOG((@"accepting drop from external source on %@ at index %i", [dropItem fileName], dropIndex));
	BOOL result = [[self windowController] addPagesViaDragToCollection:dropItem atIndex:dropIndex draggingInfo:info];
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         acceptDrop:(id <NSDraggingInfo>)info
               item:(id)item
         childIndex:(int)anIndex
{
	// Remember, links are special
    NSPasteboard *pboard = [info draggingPasteboard];
	if ([[pboard types] containsObject:kKTLocalLinkPboardType])
	{
        [pboard setString:[(KTPage *)item uniqueID] forType:kKTLocalLinkPboardType];
        return YES;
    }
    
    
    // Correct for the root page. i.e. a drop with a nil item is actually a drop onto/in the root page, and the index needs to be bumped slightly
    SVSiteItem *siteItem = item;
    NSInteger index = anIndex;
    if (!siteItem)
    {
        if (anIndex == 0) return NO;   // rule 3.
        
        siteItem = [self rootPage];
        if (index != NSOutlineViewDropOnItemIndex) 
        {
            index--;    // we've already weeded out the case of index being 0
        }
    }
    OBASSERT(siteItem);
    
    
    // Rule 1. Only a collection can be dropped on/into.
    if ([siteItem isCollection])
    {
        return [self acceptNonLinkDrop:info
                            collection:[siteItem pageRepresentation]
                            childIndex:index];
    }
    
    
    return NO;
}
	

/*	Called when rearranging pages within the Site Outline
 */
- (BOOL)acceptInternalDrop:(NSPasteboard *)pboard ontoPage:(KTPage *)page childIndex:(int)anIndex
{
	NSDictionary *pboardData = [pboard propertyListForType:kKTOutlineDraggingPboardType];
	
	// remember all selected rows
	NSArray *allRows = [pboardData objectForKey:@"allRows"];
	NSArray *selectedItems = [[self outlineView] itemsAtRows:[NSIndexSet indexSetWithArray:allRows]];
	
	
	// we use parentRows here as moving the parent rows should move all the children as well
	NSArray *parentRows = [pboardData objectForKey:@"parentRows"];
	
	// Adjust dropRow to account for "home"
	int dropRow;
	if (page == [self rootPage]) {
		dropRow = anIndex-1;
	}
	else {
		dropRow = anIndex;
	}
	
	
	NSArray *draggedItems = [[self outlineView] itemsAtRows:[NSIndexSet indexSetWithArray:parentRows]];
	
	
	// The behaviour is different depending on the drag destination.
	// Drops into the middle of an unsorted collection need to also have their indexes set.
	if (dropRow > -1 && [page collectionSortOrder] == SVCollectionSortManually)
	{
		NSEnumerator *e = [draggedItems reverseObjectEnumerator];	// By running in reverse we can keep inserting pages at the same index
		KTPage *draggedItem;
		while (draggedItem = [e nextObject])
		{
			[draggedItem retain];
			
			KTPage *draggedItemParent = [draggedItem parentPage];
			if (page != draggedItemParent)
			{
				[draggedItemParent removePage:draggedItem];
				[page addChildItem:draggedItem];
			}
			
			[draggedItem moveToIndex:dropRow];
			
			[draggedItem release];
		}
	}
	else
	{
		NSEnumerator *e = [draggedItems objectEnumerator];
		KTPage *aPage;
		while (aPage = [e nextObject])
		{
			[aPage retain];
			[[aPage parentPage] removePage:aPage];
			[page addChildItem:aPage];
			[aPage release];
		}
	}
	
	// select what was selected during the drag
	NSIndexSet *selectedRows = [[self outlineView] rowsForItems:selectedItems];
	[[self outlineView] selectRowIndexes:selectedRows byExtendingSelection:NO];
	
	// Record the Undo operation
    // For reasons I cannot fathom, on Tiger this upsets the undo manager if you are dragging a freshly created page. Turning it off keeps things reasonably happy, but if you hit undo the page is deleted immediately, and hitting undo again raises an exception. It's definitely not ideal, but the best compromise I can find for now. (case 41296)
	//[[[self document] undoManager] setActionName:NSLocalizedString(@"Drag", "action name for dragging source objects within the outline")];
	
	return YES;
}

- (BOOL)acceptArchivedPagesDrop:(NSArray *)archivedPages ontoPage:(KTPage *)page childIndex:(int)anIndex
{
	BOOL result = NO;
	
	
	// Should we display a progress indicator?
	int i = 0;
	NSString *localizedStatus = NSLocalizedString(@"Copying...", "");
	BOOL displayProgressIndicator = NO;
	if ([archivedPages count] > 3)
	{
		displayProgressIndicator = YES;
	}
	else
	{
		int i;
		for ( i=0; i<[archivedPages count]; i++)
		{
			NSDictionary *pageInfo = [archivedPages objectAtIndex:i];
			if ([pageInfo boolForKey:@"isCollection"]) 
			{
				displayProgressIndicator = YES;
				break;
			}
		}
	}
	
    KSProgressPanel *progressPanel = nil;
	if (displayProgressIndicator)
	{
		progressPanel = [[KSProgressPanel alloc] init];
        [progressPanel setMessageText:localizedStatus];
        [progressPanel setInformativeText:nil];
        [progressPanel setMinValue:1 maxValue:[archivedPages count] doubleValue:1];
        
        [progressPanel beginSheetModalForWindow:[[self view] window]];
	}
	
	
	// Add the pages
	i = 1;			
	
	NSMutableArray *droppedPages = [NSMutableArray array];
	NSEnumerator *e = [archivedPages objectEnumerator];
	NSDictionary *rep;
	while (rep = [e nextObject])
	{
		if (progressPanel)
		{
			localizedStatus = NSLocalizedString(@"Copying pages...", "");
			[progressPanel setMessageText:localizedStatus];
            [progressPanel setDoubleValue:i];
			i++;
		}
		
		KTPage *aDroppedPage = [KTPage pageWithPasteboardRepresentation:rep parent:page];
		if (aDroppedPage)
		{
			result = YES;
		}
		else
		{
			break;
		}
		[droppedPages addObject:aDroppedPage];
		
		// Whinge if the page couldn't be created
		OBASSERTSTRING(page, @"unable to create Page");
	}
	
	[[[[self rootPage] managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Drag",
																   @"action name for dragging source objects within the outline")];
	
	[progressPanel endSheet];
    [progressPanel release];
	
	
	// Select the dropped pages
	[[self content] setSelectedObjects:droppedPages];
	
	
	return result;
}
			
- (void)setDropSiteItem:(id)item dropChildIndex:(NSInteger)index;
{
    //  Like the NSOutlineView method, but accounts for root
    OBPRECONDITION(item);
    
    
    if (item == [self rootPage] && index != NSOutlineViewDropOnItemIndex)
    {
        [[self outlineView] setDropItem:nil dropChildIndex:(index + 1)];
    }
    else
    {
        [[self outlineView] setDropItem:item dropChildIndex:index];
    }
}

#pragma mark -
#pragma mark Support

- (NSArray *)itemsForRows:(NSArray *)anArray
{
	NSMutableArray *items = [NSMutableArray array];
	
	NSEnumerator *e = [anArray objectEnumerator];
	id row;
	while ( row = [e nextObject] )
	{
		[items addObject:[[self outlineView] itemAtRow:[row intValue]]];
	}
	
	return [NSArray arrayWithArray:items];
}

- (BOOL)items:(NSArray *)items containsParentOfItem:(id)item
{
	BOOL result = NO;
	
    NSEnumerator *e = [items objectEnumerator];
    id object;
    while ( object = [e nextObject] )
	{
        if ( nil != [item parentPage] )
		{
            if ( object == [item parentPage] )
			{
                result = YES;
            }
        }
    }
	
    return result;
}

- (BOOL)item:(id)anItem isDescendantOfItem:(id)anotherItem
{
	BOOL result = NO;
	
	if ( [anotherItem hasChildren] )
	{
		NSEnumerator *e = [[anotherItem childItems] objectEnumerator];
		KTPage *child;
		while ( child = [e nextObject] )
		{
			if ( [child isEqual:anItem] )
			{
				result = YES;
			}
			else if ( [self item:anItem isDescendantOfItem:child] )
			{
				result = YES;
			}
		}
	}
	
	return result;
}

@end
