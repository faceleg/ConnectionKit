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
		if ( [selectionClassName isEqual:[KTPage className]] )
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
        selectedPage = [[[[self siteOutlineViewController] content] selectedObjects] objectAtIndex:0];
    }
    
    // if we haven't selected a collection, use its parent
	if ( ![selectedPage isCollection] )
	{
		selectedPage = [selectedPage parentPage];
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
	
	NSDictionary *anArchivedPage;
	for (anArchivedPage in archive)
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
        selectedPage = [[[[self siteOutlineViewController] content] selectedObjects] objectAtIndex:0];
    }
    
    if ( [selectedPage isKindOfClass:[KTPage class]] )
    {
        BOOL canPaste = ([[selectedPage showSidebar] boolValue] || [selectedPage includeCallout]);
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
            }
            
        }
    }
    else
    {
        LOG((@"would like to paste pagelets, but there's no selectedPage to paste to!"));
    }    
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
	else if ([[[[self siteOutlineViewController] content] selectionIndexes] count] > 0)
	{
		[self duplicateSelectedPages:sender];
	}
 }

@end
