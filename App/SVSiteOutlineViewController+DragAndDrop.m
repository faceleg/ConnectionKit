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
#import "KTPage+Internal.h"
#import "KTPulsatingOverlay.h"
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
    NSArray *serializedPages = [pages valueForKey:@"propertyListRepresentation"];
    [pboard setPropertyList:serializedPages forType:kKTPagesPboardType];
    
    
    
    
	return YES;
}

#pragma mark Drop

- (NSDragOperation)validateDrop:(id <NSDraggingInfo>)info
               proposedSiteItem:(SVSiteItem *)item
             proposedChildIndex:(NSInteger)index;
{
    //  Rather like the Outline View datasource method, but has already taken into account the layout of root
    
    
    // Only a collection can be dropped on/into
    if ([item isCollection])
    {
        if (index != NSOutlineViewDropOnItemIndex)
        {
            // They're trying to drop at a specific index - is this allowable?
            if (![item isCollection] ||
                [[(KTPage *)item collectionSortOrder] integerValue] != SVCollectionSortManually)
            {
                [self setDropSiteItem:item dropChildIndex:NSOutlineViewDropOnItemIndex];
            }
        }
    }
    else
    {
        // Drop into parent
        [self setDropSiteItem:[item parentPage] dropChildIndex:NSOutlineViewDropOnItemIndex];
    }
    
    
    return NSDragOperationCopy;
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
				  validateDrop:(id <NSDraggingInfo>)info
				  proposedItem:(id)item
			proposedChildIndex:(NSInteger)anIndex
{
    // THE RULES:
    //  You can always drop *on* a collection
    //  You can only drop *at* a specific index if the containing collection is manually sorted
    
    
    SVSiteItem *siteItem = item;
    NSInteger index = anIndex;
    
    // Correct for the root page. i.e. a drop with a nil item is actually a drop onto/in the root page, and the index needs to be bumped slightly
    if (!item)
    {
        siteItem = [self rootPage];
        if (anIndex != NSOutlineViewDropOnItemIndex) 
        {
            if (anIndex >= 1)
            {
                index--;
            }
            else
            {
                // Disallow dropping before the root page, consider it to be a drop onto root
                index = NSOutlineViewDropOnItemIndex;
                [outlineView setDropItem:nil dropChildIndex:NSOutlineViewDropOnItemIndex];
            }
        }
    }
    
    
    
    return [self validateDrop:info proposedSiteItem:siteItem proposedChildIndex:index];
    
    
    
    
    
    
	NSPasteboard *pboard = [info draggingPasteboard];
	NSDictionary *pboardData = [pboard propertyListForType:kKTOutlineDraggingPboardType];
	NSArray *allRows = [pboardData objectForKey:@"allRows"];
	
	id root = [self rootPage];
	id proposedParent;
	if ( nil == item )
	{
		proposedParent  = root;
	}
	else
	{
		proposedParent = item;
	}
	int proposedParentSortOrder = [proposedParent integerForKey:@"collectionSortOrder"];
	// SVCollectionSortAlphabetically, SVCollectionSortByDateCreated, SVCollectionSortByDateModified, or SVCollectionSortManually
	
	BOOL cameFromProgram = (nil != [info draggingSource]);
	if (cameFromProgram)
	{
		if  ( [[self outlineView] isEqual:[info draggingSource]] )
		{
			KTPage *firstDraggedItem = [[self outlineView] itemAtRow:[[allRows objectAtIndex:0] intValue]];
			// this should be a "local" drag
			if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTOutlineDraggingPboardType]] )
			{
				if ( NSOutlineViewDropOnItemIndex == anIndex )
				{
					// we only allow, for now, dropping onto a page if it's already a collection
					// but not already the parent of firstDraggedItem and not a parent of proposedParent
					if ( [proposedParent isCollection] 
						&& ![proposedParent isEqual:[firstDraggedItem parentPage]]
						&& ![self item:proposedParent isDescendantOfItem:firstDraggedItem] )
					{
						//LOG((@"allowing drop directly onto collection %@", [proposedParent fileName]));
						return NSDragOperationMove;
					}
					else
					{
						//LOG((@"disallowing drop directly onto “%@” since it's not a collection", [proposedParent fileName]));
						return NSDragOperationNone;
					}
				}
				else if ( (proposedParent == root) && (anIndex == 0) )
				{
					// nothing should drop above home
					//LOG((@"disallowing drop since it would be above home"));
					return NSDragOperationNone;
				}
				else if ( [self item:proposedParent isDescendantOfItem:firstDraggedItem] )
				{
					// a parent should not become a child of its children
					//LOG((@"disallowing drop since it would have become a child of one of its own children"));
					return NSDragOperationNone;
				}
				else if ( [[self itemsForRows:allRows] containsObject:item] )
				{
					// an item should not become a child of itself
					//LOG((@"disallowing drop since a collection would have become a child of itself"));
					return NSDragOperationNone;
				}
				else if ( ![proposedParent isCollection] )
				{
					// a page, for now, should not become a parent just by dragging something under it
					//LOG((@"disallowing drop since don't allow creating a collection via drag"));
					return NSDragOperationNone;
				}
				else if ( [proposedParent isEqual:[firstDraggedItem parentPage]]
						 && ((proposedParent != [self rootPage] && ((unsigned)anIndex == [[[firstDraggedItem parentPage] sortedChildren] indexOfObject:firstDraggedItem]))
							 || (proposedParent == [self rootPage] && ((unsigned)(anIndex-1) == [[[firstDraggedItem parentPage] sortedChildren] indexOfObject:firstDraggedItem]))) )
				{
					// the text of the above conditional is "if the parent is the same and
					// the index is the same or, if the parent is the same and also root and
					// the index is the same as anIndex-1 (to account for "home")"
					
					// if we're just dropping at the same place, no need to show a drag indicator
					//LOG((@"disallowing drop since we're dropping in the same place"));
					return NSDragOperationNone;
				}
				else
				{
					// if we've made it this far through the rules, we need to look at KTCollectionSortType
					switch ( proposedParentSortOrder )
					{
						case SVCollectionSortManually:
						{
							// drop anywhere into an unsorted collection
							//LOG((@"allowing drop into unsorted collection"));
							return NSDragOperationMove;
							break;
						}
						case SVCollectionSortAlphabetically:
						case SVCollectionSortByDateModified:
						case SVCollectionSortByDateCreated:
						{
							// only allow drop at proposedOrdering
							int childIndex = [proposedParent proposedOrderingForProposedChild:firstDraggedItem
																					 sortType:proposedParentSortOrder];
							if ( childIndex == anIndex )
							{
								//LOG((@"allowing drop in sorted collection on appropriate index"));
								return NSDragOperationMove;
							}
							else
							{
								//LOG((@"disallowing drop in sorted collection on inappropriate index"));
								return NSDragOperationNone;
							}
							break;
						}
						default:
						{
							// sort order is unknown, disallow drag?
							//LOG((@"disallowing drop: we should never get here"));
							return NSDragOperationNone;
							break;
						}
					}
				}
			}
			else if ( NO )
			{
				// other internal pboard types
				;
			}	
		}
		else if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]] )
		{
			// we probably have some pages on the pasteboard that we want to add at the drop point
			// but we need to validate
			if ( NSOutlineViewDropOnItemIndex == anIndex )
			{
				// we only allow, for now, dropping onto a page if it's already a collection
				if ( [proposedParent isCollection] )
				{
					//LOG((@"allowing drop directly onto collection %@", [proposedParent fileName]));
					return NSDragOperationCopy;
				}
				else
				{
					//LOG((@"disallowing drop directly onto “%@” since it's not a collection", [proposedParent fileName]));
					return NSDragOperationNone;
				}
			}
			else if ( (proposedParent == root) && (anIndex == 0) )
			{
				// nothing should drop above home
				//LOG((@"disallowing drop since it would be above home"));
				return NSDragOperationNone;
			}
			else if ( ![proposedParent isCollection] )
			{
				// a page, for now, should not become a parent just by dragging something under it
				//LOG((@"disallowing drop since don't allow creating a collection via drag"));
				return NSDragOperationNone;
			}
			else
			{
				// if we've made it this far through the rules, we need to look at KTCollectionSortType
				int dropIndex = anIndex;
				if (proposedParent == [self rootPage])
				{
					--dropIndex;
				}
				
				switch ( proposedParentSortOrder )
				{
					case SVCollectionSortManually:
					{
						// drop anywhere into an unsorted collection
						//LOG((@"allowing drop into unsorted collection"));
						return NSDragOperationCopy;
						break;
					}
					
					case SVCollectionSortAlphabetically:
					{
						// we're going to be sorting on titles, so get a suitable title
						NSString *title = nil;
						// title will be the htmlTitle of the first page on the pasteboard
						NSData *pagesPboardData = [[info draggingPasteboard] dataForType:kKTPagesPboardType];
						if ( nil != pagesPboardData )
						{							
							NSDictionary *pboardInfo = [NSUnarchiver unarchiveObjectWithData:pagesPboardData];
							NSArray *pagesArray = [pboardInfo valueForKey:@"pages"];
							NSDictionary *firstPage = [pagesArray firstObjectKS];
							if ( nil != [firstPage objectForKey:@"titleHTML"] )
							{
								title = [firstPage objectForKey:@"titleHTML"];
							}
						}
						if ( nil == title )
						{
							LOG((@"error: couldn't find a suitable title for alpha sort"));
							return NSDragOperationNone;
						}
						else
						{
							LOG((@"atempting alphasort with title “%@”", title));
						}
						
						// only allow drop at proposedOrdering
						int childIndex = [proposedParent proposedOrderingForProposedChildWithTitle:title];
						if ( childIndex == dropIndex )
						{
							//LOG((@"allowing drop in sorted collection on appropriate index"));
							return NSDragOperationCopy;
						}
						else
						{
							//LOG((@"disallowing drop in sorted collection on inappropriate index"));
							return NSDragOperationNone;
						}						
						break;
					}
					case SVCollectionSortByDateModified:
					{
						// if we sort latest at top, we can only add to top
						if ( dropIndex == 0 )
						{
							return NSDragOperationCopy;
						}
						else
						{
							return NSDragOperationNone;
						}
						break;
					}
					case SVCollectionSortByDateCreated:
					{
						if ( (unsigned)dropIndex == [[proposedParent sortedChildren] count] )
						{
							return NSDragOperationCopy;
						}
						else
						{
							return NSDragOperationNone;
						}						
						break;
					}
					default:
					{
						// sort order is unknown, disallow drag?
						//LOG((@"disallowing drop: we should never get here"));
						return NSDragOperationNone;
						break;
					}
				}
			}			
		}			
	}
	
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"kKTLocalLinkPboardType"]])
	{
		if ( NSOutlineViewDropOnItemIndex == anIndex )
		{
			// If our input string is a collection, then return NO if it's not a collection.
			NSString *pboardString = [pboard stringForType:@"kKTLocalLinkPboardType"];
			if ([pboardString isEqualToString:@"KTCollection"] && ![item isCollection])
			{
				[[KTPulsatingOverlay sharedOverlay] hide];
				return NSDragOperationNone;
			}
			//set up a pulsating window
			if (item)
			{
				int row = [outlineView rowForItem:item];
				NSRect rowRect = [outlineView rectOfRow:row];
				//covert the origin to window coords
				rowRect.origin = [[outlineView window] convertBaseToScreen:[outlineView convertPoint:rowRect.origin toView:nil]];
				rowRect.origin.y -= NSHeight(rowRect); //handle it because it is flipped.
				if (!NSEqualSizes(rowRect.size, NSZeroSize))
				{
					[[KTPulsatingOverlay sharedOverlay] displayWithFrame:rowRect];
				}
				else
				{
					[[KTPulsatingOverlay sharedOverlay] hide];
				}
				
				return NSDragOperationLink;
			}
			else
			{
				[[KTPulsatingOverlay sharedOverlay] hide];
				return NSDragOperationNone;
			}
		}
		else
		{
			[[KTPulsatingOverlay sharedOverlay] hide];
			return NSDragOperationNone;
		}
	}
	
	// Fall through -- external drag, or internal drag not handled above.
	
	// "children are a zero-based index"
	
	// do we have a good drag source?
	/// check the *first* item in the list ... probably not perfect but it ought to do
	Class <KTDataSource> bestSource = [KTElementPlugin highestPriorityDataSourceForDrag:info index:0 isCreatingPagelet:NO];
	if ( nil != bestSource )
	{
		if ( NSOutlineViewDropOnItemIndex == anIndex )
		{
			// we only allow, for now, dropping onto a page if it's already a collection
			if ( [item isKindOfClass:[KTPage class]] && [item isCollection] )
			{
				//LOG((@"allowing direct drop onto pre-existing collection"));
				return NSDragOperationCopy;
			}
			else
			{
				//LOG((@"disallowing direct drop onto page that is not a collection"));
				return NSDragOperationNone;
			}
		}
		else if (proposedParent == [self rootPage] && (0 == anIndex) )
		{
			// we don't allow dropping above "home"
			//LOG((@"disallowing drop above home"));
			return NSDragOperationNone;
		}
		else if ( [proposedParent isKindOfClass:[KTPage class]] && [proposedParent isCollection] )
		{
			//LOG((@"wants to create child of %@ at index %i", [item fileName], anIndex));
			// if we've made it this far through the rules, we need to look at KTCollectionSortType
			int dropIndex = anIndex;
			if (proposedParent == [self rootPage])
			{
				--dropIndex;
			}
			
			switch ( proposedParentSortOrder )
			{
				case SVCollectionSortManually:
				{
					// drop anywhere into an unsorted collection
					//LOG((@"allowing drop into unsorted collection"));
					return NSDragOperationCopy;
					break;
				}
				case SVCollectionSortAlphabetically:
				{
					// we're going to be sorting on titles, so get a suitable title
					NSMutableDictionary *sourceInfoDictionary = [NSMutableDictionary dictionary];
					[sourceInfoDictionary setValue:[info draggingPasteboard] forKey:kKTDataSourcePasteboard];	// always include this!
					// No way to really deal with multiple items here, so just take the first title
					[bestSource populateDataSourceDictionary:sourceInfoDictionary fromPasteboard:[info draggingPasteboard] atIndex:0 forCreatingPagelet:NO];
					NSString *title = [sourceInfoDictionary valueForKey:kKTDataSourceTitle];
					if (title)
					{
						NSFileManager *fm = [NSFileManager defaultManager];
						title = [[fm displayNameAtPath:[sourceInfoDictionary valueForKey:kKTDataSourceFileName] ] stringByDeletingPathExtension];
						if  (title)
						{
							NSString *bundleIdentifier = [[NSBundle bundleForClass:bestSource] bundleIdentifier];
							if  (bundleIdentifier)
							{
								id plugin = [KTElementPlugin pluginWithIdentifier:bundleIdentifier];
								if ( nil != plugin )
								{
									title = [plugin pluginPropertyForKey:@"KTPluginUntitledName"];
								}
							}
						}
					}
					
					if ( nil == title )
					{
						LOG((@"error: couldn't find a suitable title for alpha sort"));
						return NSDragOperationNone;
					}
					else
					{
						LOG((@"atempting alphasort with title “%@”", title));
					}
					
					// only allow drop at proposedOrdering
					int childIndex = [proposedParent proposedOrderingForProposedChildWithTitle:title];
					if ( childIndex == dropIndex )
					{
						//LOG((@"allowing drop in sorted collection on appropriate index"));
						return NSDragOperationCopy;
					}
					else
					{
						//LOG((@"disallowing drop in sorted collection on inappropriate index"));
						return NSDragOperationNone;
					}						
					break;
				}
				case SVCollectionSortByDateModified:
				{
					// if we sort latest at top, we can only add to top
					if ( dropIndex == 0 )
					{
						return NSDragOperationCopy;
					}
					else
					{
						return NSDragOperationNone;
					}
					break;
				}
				case SVCollectionSortByDateCreated:
				{
					if ( (unsigned)dropIndex == [[proposedParent sortedChildren] count] )
					{
						return NSDragOperationCopy;
					}
					else
					{
						return NSDragOperationNone;
					}						
					break;
				}
				default:
				{
					// sort order is unknown, disallow drag?
					//LOG((@"disallowing drop: we should never get here"));
					return NSDragOperationNone;
					break;
				}
			}
		}
		else if ( [proposedParent isEqual:[[self outlineView] itemAtRow:([[self outlineView] numberOfRows]-1)]] )
		{
			// if we're dropping below the last row of the outline, accept the drag
			// but reposition the drop to be at the root level
			// NB: we add 1 to account for the row taken up by "home"
			[[self outlineView] setDropItem:nil 
					   dropChildIndex:([[[self rootPage] childItems] count]+1)];
			return NSDragOperationCopy;
		}
		else
		{
			LOG((@"disallowing drop: this is an unknown case"));
		}
		
		// Done with that single pass process
		[KTElementPlugin doneProcessingDrag];
		
	}
	else
	{
		LOG((@"no datasource agreed to validate this drop"));
		return NSDragOperationNone;
	}
	
	return NSDragOperationNone;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(int)anIndex
{
	NSPasteboard *pboard = [info draggingPasteboard];
	(void)[pboard types];
	
	// The new page must be a child of something
	KTPage *proposedParent = item;
	if (!proposedParent) proposedParent = [self rootPage];
	
	BOOL cameFromProgram = nil != [info draggingSource];
	
	if (cameFromProgram)
	{
		if  ([[self outlineView] isEqual:[info draggingSource]])
		{
			// drag is internal to document
			if ([pboard availableTypeFromArray:[NSArray arrayWithObject:kKTOutlineDraggingPboardType]])
			{
				BOOL result = [self acceptInternalDrop:pboard ontoPage:proposedParent childIndex:anIndex];
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
				return [self acceptArchivedPagesDrop:archivedPages ontoPage:proposedParent childIndex:anIndex];
			}
		}
	}
	else if ( nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:@"kKTLocalLinkPboardType"]] )
	{
		// hide the pulsating window
		[[KTPulsatingOverlay sharedOverlay] hide];
		// Get the page and update the pboard with it ... a way to send the info back to the origin of the drag!
		[pboard setString:[(KTPage *)item uniqueID] forType:@"kKTLocalLinkPboardType"];
		return YES;
	}
	
	// this should be a drag in from outside the application, or an internal drag not covered above.
	// we want to find a drag source for it and let it do its thing
	int dropIndex = anIndex;
	id dropItem = item;
	if ( nil == dropItem )
	{
		dropItem = [self rootPage];
		dropIndex = anIndex-1;
	}
	//LOG((@"accepting drop from external source on %@ at index %i", [dropItem fileName], dropIndex));
	BOOL result = [[self windowController] addPagesViaDragToCollection:dropItem atIndex:dropIndex draggingInfo:info];
	return result;
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
	
	
	// The behavior is different depending on the drag destination.
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
	//[[[self document] undoManager] setActionName:NSLocalizedString(@"Drag", "action name for dragging source objects withing the outline")];
	
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
																   @"action name for dragging source objects withing the outline")];
	
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
