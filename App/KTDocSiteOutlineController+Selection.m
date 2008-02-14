//
//  KTDocSiteOutlineController+Selection.m
//  Marvel
//
//  Created by Mike on 25/01/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"

#import "KTDocWindowController.h"
#import "KTDocWebViewController.h"


@interface KTDocSiteOutlineController (SelectionPrivate)
- (void)generateSelectedPagesSet;
@end


@implementation KTDocSiteOutlineController (Selection)

- (id)selection
{
	id result = [myTempSelectionController selection];
	return result; 
}

#pragma mark -
#pragma mark Selection Indexes

- (NSIndexSet *)selectedIndexes { return mySelectedIndexes; }

/*	Private method responsible for storing the selected indexes
 */
- (void)_setSelectedIndexes:(NSIndexSet *)indexes
{
	[self willChangeValueForKey:@"selection"];
	[self willChangeValueForKey:@"selectedIndexes"];
	
	[indexes retain];
	[mySelectedIndexes release];
	mySelectedIndexes = indexes;
	
	[self didChangeValueForKey:@"selectedIndexes"];
	
	// Update the selectedPages list
	[self generateSelectedPagesSet];
	
	[self didChangeValueForKey:@"selection"];
}

/*	Public method that updates the outline view's selection. This will then call through to appropriate prviate methods
 */
- (void)setSelectedIndexes:(NSIndexSet *)indexes
{
	[[self siteOutline] selectRowIndexes:indexes byExtendingSelection:NO];
}

/*	Called ONLY when the selected row INDEXES changes. We must do other management to detect when the selected page
 *	changes, but the selected row(s) remain the same.
 */
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[self _setSelectedIndexes:[[self siteOutline] selectedRowIndexes]];
}

#pragma mark -
#pragma mark Selected Pages

/*	If there's a lot of objects selected, it can be time consuming to generate this list.
 *	Therefore, eventually, we should cache it and generated on-demand
 */
- (NSSet *)selectedPages { return mySelectedPages; }

/*	As with _setSelectedIndexes, there is a private method that does no UI update
 */
- (void)_setSelectedPages:(NSSet *)selectedPages;
{
	[self willChangeValueForKey:@"selectedPage"];
	[[self docWindowController] willChangeValueForKey:@"selectedPagesIncludesACollection"];
	[[self docWindowController] willChangeValueForKey:@"allSelectedPageTitlesAreEditable"];
	
	selectedPages = [selectedPages copy];
	[mySelectedPages release];
	mySelectedPages = selectedPages;
	
	// Got to keep the controller in sync for the benefit of the UI
	[myTempSelectionController setContent:selectedPages];
	[myTempSelectionController setSelectedObjects:[selectedPages allObjects]];
	
	[self didChangeValueForKey:@"selectedPage"];
	[[self docWindowController] didChangeValueForKey:@"selectedPagesIncludesACollection"];
	[[self docWindowController] didChangeValueForKey:@"allSelectedPageTitlesAreEditable"];
	
	// let interested parties know that selection changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification
														object:[selectedPages anyObject]];
	
	// update window title
	[[self docWindowController] synchronizeWindowTitleWithDocumentName];
	
	// Refresh webview
	[[[self docWindowController] webViewController] setWebViewNeedsRefresh:YES];
}

/*	Select the pages in the UI, and thereby the appropriate storage methods will get called here
 */
- (void)setSelectedPages:(NSSet *)selectedPages;
{
	[[self siteOutline] selectItems:[selectedPages allObjects]];
}

/*	Convenience method for -selectedPages. If only a single page is selected, returns that.
 *	Otherwise, nil is the return value.
 */
- (KTPage *)selectedPage
{
    KTPage *result = nil;
	
	NSSet *selectedPages = [self selectedPages];
	if (selectedPages && [selectedPages count] == 1)
	{
		result = [selectedPages anyObject];
	}
	
	return result;
}

- (void)generateSelectedPagesSet
{
	NSSet *pages = [[self siteOutline] itemsForRows:[self selectedIndexes]];
	[self _setSelectedPages:pages];
}

@end
