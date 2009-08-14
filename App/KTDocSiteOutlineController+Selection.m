//
//  KTDocSiteOutlineController+Selection.m
//  Marvel
//
//  Created by Mike on 25/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"

#import "KT.h"
#import "KTDocWindowController.h"
#import "KTDocWebViewController.h"
#import "KTPage+Internal.h"

#import "NSArray+Karelia.h"
#import "NSOutlineView+KTExtensions.h"


@implementation KTDocSiteOutlineController (Selection)

#pragma mark -
#pragma mark Selection Accessors

/*	Convenience method for -selectedPages. If only a single page is selected, returns that.
 *	Otherwise, nil is the return value.
 */
- (KTPage *)selectedPage
{
    KTPage *result = nil;
	
	NSArray *selectedPages = [self selectedObjects];
	if (selectedPages && [selectedPages count] == 1)
	{
		result = [selectedPages objectAtIndex:0];
	}
	
	return result;
}

+ (NSSet *)keyPathsForValuesAffectingSelectedPage
{
    return [NSSet setWithObject:@"selectedPages"];
}

/*	Override to change the outline view's selection. This will eventually call super.
 */
- (BOOL)setSelectedObjects:(NSArray *)objects
{
	[[self siteOutline] selectItems:objects forceDidChangeNotification:YES];
	return YES;
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
	OBASSERT([super setSelectedObjects:selectedPages]);
	
	// let interested parties know that selection changed
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification
														object:[selectedPages firstObjectKS]];
	
	// Refresh webview
	[[[self windowController] webViewController] setPages:[NSSet setWithArray:selectedPages]];
}

/*	If the current selection is about to be collapsed away, select the parent.
 */
- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
	KTPage *collapsingItem = [[notification userInfo] objectForKey:@"NSObject"];
	BOOL shouldSelectCollapsingItem = YES;
	NSEnumerator *selectionEnumerator = [[self selectedObjects] objectEnumerator];
	KTPage *aPage;
	
	while (aPage = [selectionEnumerator nextObject])
	{
		if (![aPage isDescendantOfPage:collapsingItem])
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

