//
//  KTDocSiteOutlineController+Selection.m
//  Marvel
//
//  Created by Mike on 25/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"

#import "KT.h"
#import "KTDocWindowController.h"
#import "KTDocWebViewController.h"
#import "KTPage.h"

#import "NSArray+Karelia.h"
#import "NSOutlineView+KTExtensions.h"


@implementation KTDocSiteOutlineController (Selection)

- (NSArray *)selectedPages { return mySelectedPages; }

/*	This is the public version of -setSelectedPages. It updates internal storage as well as the UI itself.
 */
- (void)setSelectedPages:(NSSet *)selectedPages;
{
	[[self siteOutline] selectItems:[selectedPages allObjects]];
}

/*	This is the private version of -setSelectedPages. It updates just the internal storage
 */
- (void)_setSelectedPages:(NSArray *)selectedPages;
{
	[self willChangeValueForKey:@"selectedPage"];
	[[self windowController] willChangeValueForKey:@"selectedPagesIncludesACollection"];
	[[self windowController] willChangeValueForKey:@"allSelectedPageTitlesAreEditable"];
	
	selectedPages = [selectedPages copy];
	[mySelectedPages release];
	mySelectedPages = selectedPages;
	
	
	[self didChangeValueForKey:@"selectedPage"];
	[[self windowController] didChangeValueForKey:@"selectedPagesIncludesACollection"];
	[[self windowController] didChangeValueForKey:@"allSelectedPageTitlesAreEditable"];
	
	// let interested parties know that selection changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification
														object:[selectedPages firstObjectOrNilIfEmpty]];
	
	// Refresh webview
	[[[self windowController] webViewController] setWebViewNeedsRefresh:YES];
}


/*	Convenience method for -selectedPages. If only a single page is selected, returns that.
 *	Otherwise, nil is the return value.
 */
- (KTPage *)selectedPage
{
    KTPage *result = nil;
	
	NSArray *selectedPages = [self selectedPages];
	if (selectedPages && [selectedPages count] == 1)
	{
		result = [selectedPages objectAtIndex:0];
	}
	
	return result;
}

#pragma mark -
#pragma mark Outline View Delegate

/*	Called ONLY when the selected row INDEXES changes. We must do other management to detect when the selected page
 *	changes, but the selected row(s) remain the same.
 *
 *	Initially I thought -selectionIsChanging: would do the trick, but it's not invoked by keyboard navigation.
 */
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	NSArray *selectedPages = [[self siteOutline] selectedItems];
	[self _setSelectedPages:selectedPages];
	
	NSArray *selectionIndexPaths = [selectedPages valueForKey:@"indexPath"];
	[self setSelectionIndexPaths:selectionIndexPaths];
}

/*	If the current selection is about to be collapsed away, select the parent.
 */
- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
	KTPage *collapsingItem = [[notification userInfo] objectForKey:@"NSObject"];
	BOOL shouldSelectCollapsingItem = YES;
	NSEnumerator *selectionEnumerator = [[self selectedPages] objectEnumerator];
	KTPage *aPage;
	
	while (aPage = [selectionEnumerator nextObject])
	{
		if (![collapsingItem containsDescendant:aPage])
		{
			shouldSelectCollapsingItem = NO;
			break;
		}
	}
	
	if (shouldSelectCollapsingItem)
	{
		[[self siteOutline] selectItem:collapsingItem];
	}
}

@end

