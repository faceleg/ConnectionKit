//
//  KTDocWindowController+Pasteboard.m
//  Marvel
//
//  Created by Terrence Talbot on 1/1/06.
//  Copyright 2006-2009 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocument.h"
#import "KTPage.h"
#import "Elements+Pasteboard.h"
#import "KTPasteboardArchiving.h"
#import "KSSilencingConfirmSheet.h"

#import "NSArray+Karelia.h"
#import "NSArray+KTExtensions.h"
#import "NSIndexSet+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSThread+Karelia.h"


@interface KTDocWindowController (Pasteboard_Private)
- (NSArray *)pastePagesFromPasteboard:(NSPasteboard *)aPboard toParent:(KTPage *)aParent keepingUniqueID:(BOOL)aFlag;
- (NSArray *)pastePagesFromArchive:(NSArray *)archive toParent:(KTPage *)aParent;
- (NSArray *)pastePageletsFromPasteboard:(NSPasteboard *)aPboard toPage:(KTPage *)aPage keepingUniqueID:(BOOL)aFlag;
@end


#pragma mark -


// NB: a lot of this code follows the same pattern for both pages and pagelets but
// is currently separated into different methods for easier debugging/understandability

@implementation KTDocWindowController ( Pasteboard )

// these pasteboards are used for cut/copy/paste of pagelets
NSString *kKTCopyPageletsPasteboard = @"KTCopyPageletsPasteboard";

#pragma mark -
#pragma mark Paste

- (IBAction)paste:(id)sender
{
    // looks at what's on pboard before deciding what to paste
    if ( [self canPastePagelets] )
    {
		[self pastePagelets:sender];
    }
    else if ( [self canPastePages] )
    {
		[self pastePages:sender];
    }
}

- (IBAction)pasteViaContextualMenu:(id)sender
{
	NSString *selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
	if ( nil != selectionClassName )
	{
		if ( [selectionClassName isEqual:[KTPagelet className]] )
		{
			[self pastePagelets:sender];
		}
		else if ( [selectionClassName isEqual:[KTPage className]] )
		{
			[self pastePages:sender];
		}
		else
		{
			LOG((@"pasteViaContextualMenu: don't know how to paste contextual selection!"));
		}		
	}
	else
	{
		LOG((@"pasteViaContextualMenu: no selectionClassName!"));
	}
}

// creates pages from data on pboard and add as children of selected parent
// paste should validate only if there is one selectedPage and it is a collection
- (IBAction)pastePages:(id)sender
{
    KTPage *selectedPage = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        selectedPage = [selection objectAtIndex:0];
    }
    else
    {
        selectedPage = [[[[self siteOutlineViewController] pagesController] selectedObjects] objectAtIndex:0];
    }
    
    // if we haven't selected a collection, use its parent
	if ( ![selectedPage isCollection] )
	{
		selectedPage = [selectedPage parent];
	}
        
    if ( nil != selectedPage )
    {
        // paste pages
        NSArray *pastedPages = [self pastePagesFromPasteboard:[NSPasteboard generalPasteboard] toParent:selectedPage keepingUniqueID:NO];
        
        // Update the undo menu title
        if ([pastedPages count] == 1)
        {
			[[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Page", "Paste Page MenuItem")];
		}
		else if ([pastedPages count] > 1)
		{
			[[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Pages", "Paste Pages MenuItem")];
		}
    }
    else
    {
        LOG((@"would like to paste pages, but there's no selectedPage to paste to!"));
    }
}

/* returns array of newly pasted pages */
- (NSArray *)pastePagesFromPasteboard:(NSPasteboard *)aPboard toParent:(KTPage *)aParent keepingUniqueID:(BOOL)aFlag
{
	NSMutableArray *result = [NSMutableArray array];
	
    NSString *type = nil;
    type = [aPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]];
    
    if ( [type length] > 0 )
    {
        @try	// Just in case there's any reall screwy data on the pasteboard
        {
            NSData *data = [aPboard dataForType:kKTPagesPboardType];
            if ([data length] > 0)
            {
				NSArray *archivedPages = [NSKeyedUnarchiver unarchiveObjectWithData:data];
				[self pastePagesFromArchive:archivedPages toParent:aParent];
            }
            else
            {
                LOG((@"would like to paste pages, but there's nothing on the pasteboard!"));
            }
        }
        @catch (NSException *exception)
        {
            [NSApp reportException:exception];
        }
    }
    else
    {
        LOG((@"expecting to paste pages, but KTPagesPboardType is not on the pboard!"));
    }
	

	return [NSArray arrayWithArray:result];
}

- (NSArray *)pastePagesFromArchive:(NSArray *)archive toParent:(KTPage *)aParent
{
	NSMutableArray *result = [NSMutableArray arrayWithCapacity:[archive count]];
	
    NSEnumerator *archivedPagesEnumerator = [archive objectEnumerator];
	NSDictionary *anArchivedPage;
	while (anArchivedPage = [archivedPagesEnumerator nextObject])
	{
		KTPage *page = [KTPage pageWithPasteboardRepresentation:anArchivedPage parent:aParent];
		if (page)
		{
			[result addObject:page];
		}
	}
	
	return [NSArray arrayWithArray:result];
}

- (BOOL)canPastePages
{
	// check the general pasteboard to see if there are any pages on it
	BOOL result = [[[NSPasteboard generalPasteboard] types] containsObject:kKTPagesPboardType];
	return result;
}

- (IBAction)pastePagelets:(id)sender
{
    KTPage *selectedPage = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        selectedPage = [selection objectAtIndex:0];
    }
    else
    {
        selectedPage = [[[[self siteOutlineViewController] pagesController] selectedObjects] objectAtIndex:0];
    }
    
    if ( [selectedPage isKindOfClass:[KTPage class]] )
    {
        BOOL canPaste = ([selectedPage includeSidebar] || [selectedPage includeCallout]);
        if ( canPaste )
        {
            // paste
            NSArray *pastedPagelets = [self pastePageletsFromPasteboard:[NSPasteboard pasteboardWithName:kKTCopyPageletsPasteboard] toPage:selectedPage keepingUniqueID:NO];
            
            // (re)label undo
            if ( [pastedPagelets count] > 0 )
            {
                if ( [pastedPagelets count] > 1 )
                {
                    [[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Pagelets", "Paste Pagelets MenuItem")];
                }
                else
                {
                    [[[self document] undoManager] setActionName:NSLocalizedString(@"Paste Pagelet", "Paste Pagelet MenuItem")];
                }
				//stale the page they belong to
				NSEnumerator *e = [pastedPagelets objectEnumerator];
				KTPagelet *cur;
				
				while (cur = [e nextObject])
				{
					if ([cur boolForKey:@"shouldPropagate"])
					{
						////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on '%@' because pagelet is marked as shouldPropagate", NSStringFromSelector(_cmd), [[cur page] titleText]));
						//[[cur page] markStale:kStaleFamily];
						break; // only need to propagate the once.
					}
					else
					{
						////LOG((@"~~~~~~~~~ %@ ....", NSStringFromSelector(_cmd)));
						//[[cur page] markStale:kStalePage];
					}
				}
            }
            
        }
    }
    else
    {
        LOG((@"would like to paste pagelets, but there's no selectedPage to paste to!"));
    }    
}

- (NSArray *)pastePageletsFromPasteboard:(NSPasteboard *)aPboard toPage:(KTPage *)aPage keepingUniqueID:(BOOL)aFlag
{

	NSMutableArray *result = [NSMutableArray array];
    
    NSString *type = nil;
    type = [aPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPageletsPboardType]];
    
    if ([type length] > 0)
    {
        @try	// Just in case there's any reall screwy data on the pasteboard
        {
			NSData *data = [aPboard dataForType:kKTPageletsPboardType];
			NSArray *pasteboardReps = [NSKeyedUnarchiver unarchiveObjectWithData:data];
			
			if (pasteboardReps && [pasteboardReps count] > 0)
			{
                NSEnumerator *e = [pasteboardReps objectEnumerator];
                NSDictionary *anArchivedPagelet;
                while (anArchivedPagelet = [e nextObject])
                {
                    KTPagelet *pagelet = [KTPagelet pageletWithPasteboardRepresentation:anArchivedPagelet page:aPage];
                    
                    if ( nil != pagelet )
                    {
                        [result addObject:pagelet];
                    }
                    else
                    {
                        LOG((@"would like to paste pagelets, but unable to create pagelet in this context!"));
                    }
                }
            }
            else
            {
                LOG((@"would like to paste pagelets, but there's nothing on the pasteboard!"));
            }
        }
        @catch (NSException *exception)
        {
            [NSApp reportException:exception];
        }
    }
    else
    {
        LOG((@"expecting to paste pagelets, but KTPageletsPboardType is not on the pboard!"));
    }
	

	return [NSArray arrayWithArray:result];
}

- (BOOL)canPastePagelets
{
	// check the pagelets pasteboard to see if there are any pagelets on it
	NSPasteboard *pboard = [NSPasteboard pasteboardWithName:kKTCopyPageletsPasteboard];
	BOOL hasPagelets = [kKTPageletsPboardType isEqualToString:[pboard availableTypeFromArray:[NSArray arrayWithObject:kKTPageletsPboardType]]];
	if ( hasPagelets )
	{
		return YES;
	}
    else
    {
        return NO;
    }
}

#pragma mark delete

- (IBAction)deleteViaContextualMenu:(id)sender
{
    id selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
    if ( [selectionClassName isEqualToString:[KTPage className]] )
    {
        [self deletePages:sender];
    }
    else if ( [selectionClassName isEqualToString:[KTPagelet className]] )
    {
        [self deletePagelets:sender];
    } 
}

#pragma mark -
#pragma mark Duplicate

// duplicate does a copy/paste at once, within the same document, using a private pboard
// the trick here is that we need to use new uniqueIDs, new titles, etc.

- (IBAction)duplicate:(id)sender
{
	if ([self selectedPagelet])
	{
		[self duplicatePagelets:sender];
	}
	else if ([[[[self siteOutlineViewController] pagesController] selectionIndexes] count] > 0)
	{
		[self duplicateSelectedPages:sender];
	}
 }

- (IBAction)duplicateViaContextualMenu:(id)sender
{
	id selectionClassName = [[sender representedObject] valueForKey:kKTSelectedObjectsClassNameKey];
    if ( [selectionClassName isEqualToString:[KTPage className]] )
    {
        [self duplicateSelectedPages:sender];
    }
    else if ( [selectionClassName isEqualToString:[KTPagelet className]] )
    {
        [self duplicatePagelets:sender];
    } 
}

/*  Duplicates the selected pages in the Site Outline
 */
- (IBAction)duplicateSelectedPages:(id)sender
{
	// Figure out our selection
	NSArray *selectedPages = [[[self siteOutlineViewController] pagesController] selectedObjects];
    if ([sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // Duplicate was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        selectedPages = [[selection mutableCopy] autorelease];
    }
	
	
	// Don't allow duplicating root - Why not? Mike.
	if ([selectedPages count] == 0 || [selectedPages containsRoot])
    {
        NSBeep();
        return;
    }
    
    
    // Duplicate each page
    NSEnumerator *pagesEnumerator = [selectedPages objectEnumerator];
    KTPage *aPage;
    NSMutableArray *newPages = [[NSMutableArray alloc] initWithCapacity:[selectedPages count]];
    while (aPage = [pagesEnumerator nextObject])
    {
        [newPages addObject:[self duplicatePage:aPage]];
    }
    
    
    // Select the new pages
    [[[self siteOutlineViewController] pagesController] setSelectedObjects:newPages];
    [newPages release];
    
    
    // Label the Undo menu item
    if ([selectedPages count] > 1)
    {
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Duplicate Pages", "Duplicate Pages MenuItem")];
    }
    else
    {
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Duplicate Page", "Duplicate Page MenuItem")];
    }
}

- (IBAction)duplicatePagelets:(id)sender
{
    // currently assumes there is only one pagelet to be deleted
/*    
    KTPagelet *selectedPagelet = nil;
    
    if ( [sender isKindOfClass:[NSMenuItem class]] && (nil != [sender representedObject]) )
    {
        // paste was sent from a contextual menuitem, get the selection from the context
        id context = [sender representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        OBASSERTSTRING([selection isKindOfClass:[NSArray class]], @"selection should be an array.");
        // we're only going to duplicate the first selected pagelet
        selectedPagelet = [selection objectAtIndex:0];
    }
    else
    {
        selectedPagelet = [self selectedPagelet];
    }
    
    if ( [selectedPagelet isKindOfClass:[KTPagelet class]] )
    {
        KTPage *selectedPage = [[[self siteOutlineViewController] pagesController] selectedPage];
        if ( [[selectedPagelet page] isEqual:selectedPage] )
        {		
            // create a special pasteboard just for this document/operation
            NSPasteboard *duplicatePboard = [NSPasteboard pasteboardWithName:kKTDuplicatePageletsPasteboard];
            [duplicatePboard declareTypes:[NSArray arrayWithObject:kKTPageletsPboardType] owner:self];
            
            // copy pagelets
            [self copyPagelets:[NSArray arrayWithObject:selectedPagelet] toPasteboard:duplicatePboard];
            
            // paste back not keeping uniqueID
            NSArray *newPagelets = [self pastePageletsFromPasteboard:duplicatePboard toPage:selectedPage keepingUniqueID:NO];
            
            // we're done, clear the pasteboard
            [duplicatePboard releaseGlobally];
            
            if ( [newPagelets count] > 0 )
            {
                // reload the page, selected the newly added pagelet, and update the inspector 
                [self postSelectionAndUpdateNotificationsForItem:[newPagelets objectAtIndex:0]];
                
                // label undo
                [[[self document] undoManager] setActionName:NSLocalizedString(@"Duplicate Pagelet", "Duplicate Pagelet MenuItem")];              
            }
        }
    }
	else
	{
		LOG((@"-deletePagelets: no recognizable object selected!"));
	}*/
}

/*  Duplicates the specified page. Does NOT manage selection in the site outline. Returns the duplicate copy
 */
- (KTPage *)duplicatePage:(KTPage *)page
{
    OBPRECONDITION(page);
    OBPRECONDITION(![page isRoot]);
    
    
    id archive = [page pasteboardRepresentation];
    
    KTPage *parent = [page parent];
    KTPage *result = [KTPage pageWithPasteboardRepresentation:archive parent:parent];
    
    // For unordered collections, the duplicate should appear just after the original
    if ([parent collectionSortOrder] == KTCollectionUnsorted)
    {
        unsigned index = [[parent sortedChildren] indexOfObjectIdenticalTo:page] + 1;
        [result moveToIndex:index];
    }
    
    return result;
}

@end
