//
//  KTDocWindowController+Accessors.m
//  Marvel
//
//  Created by Dan Wood on 5/5/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTInlineImageElement.h"
#import "KTPage.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import <QuartzCore/QuartzCore.h>


// GENERIC, NO-BIG-WHOOP ACCESSORS ONLY.  PUT ANYTHING WITH LOGIC IN A DIFFERENT FILE PLEASE.


@implementation KTDocWindowController ( Accessors )

#pragma mark -
#pragma mark Page Selection

/*!	Determine the default collection, either the root (if nothing selected), or the selected
 collection, or the selection's parent collection if it's not a collection.
 */
- (KTPage *)nearestParent:(NSManagedObjectContext *)aManagedObjectContext
{
	KTPage *parentCollection = nil;
	
	/// Case 17992: TJT changed nearestParent to
	// 1) use a specified context for thread safety
	// 2) if nil, return root so that there is always
	// some kind of nearestParent
	KTPage *contextRoot = [aManagedObjectContext root];
	
	// figure out our selection
	if (![[[self siteOutlineViewController] pagesController] selectedPage])
	{
		// if nothing selected, treat as if root we're selected
		parentCollection = contextRoot;
	}
	else if ( [[[[self siteOutlineViewController] pagesController] selectedPage] isEqual:contextRoot]  )
	{
		// if root is selected, we're adding to root
		parentCollection = [[[self siteOutlineViewController] pagesController] selectedPage];
	}
	else if ( [[[[self siteOutlineViewController] pagesController] selectedPage] isCollection] )
	{
		// if the selected page has an index, it must be a collection, so we're adding to it
		parentCollection = [[[self siteOutlineViewController] pagesController] selectedPage];
	}
	else
	{
		// selection won't do it, so we add to selection's parent
		parentCollection = [[[[self siteOutlineViewController] pagesController] selectedPage] parent];
	}
	
	if ( nil == parentCollection )
	{
		NSLog(@"error: unable to determine nearestParent to selectedPage, substituting home page");
		parentCollection = contextRoot;
	}
	
	return parentCollection;
}

#pragma mark -
#pragma mark Pagelet Selection

- (KTPagelet *)selectedPagelet
{
    return mySelectedPagelet; 
}

- (void)setSelectedPagelet:(KTPagelet *)aSelectedPagelet
{
    [aSelectedPagelet retain];
    [mySelectedPagelet release];
    mySelectedPagelet = aSelectedPagelet;
//	LOG((@"selectedPagelet set to %@", [mySelectedPagelet managedObjectDescription]));
}

- (NSRect)selectionRect
{ 
	return mySelectionRect;
}

- (void)setSelectionRect:(NSRect)aSelectionRect
{
    mySelectionRect = aSelectionRect;
}

- (NSPoint)lastClickedPoint 
{ 
	return myLastClickedPoint;
}

- (void)setLastClickedPoint:(NSPoint)aLastClickedPoint
{
    myLastClickedPoint = aLastClickedPoint;
}

- (NSMutableDictionary *)toolbars
{
    return myToolbars;
}

- (void)setToolbars:(NSMutableDictionary *)aToolbars
{
    [aToolbars retain];
    [myToolbars release];
    myToolbars = aToolbars;
}

- (RYZImagePopUpButton *)addPagePopUpButton
{
    return myAddPagePopUpButton;
}

- (void)setAddPagePopUpButton:(RYZImagePopUpButton *)anAddPagePopUpButton
{
    [anAddPagePopUpButton retain];
    [myAddPagePopUpButton release];
    myAddPagePopUpButton = anAddPagePopUpButton;
}

- (RYZImagePopUpButton *)addPageletPopUpButton
{
    return myAddPageletPopUpButton;
}

- (void)setAddPageletPopUpButton:(RYZImagePopUpButton *)anAddPageletPopUpButton
{
    [anAddPageletPopUpButton retain];
    [myAddPageletPopUpButton release];
    myAddPageletPopUpButton = anAddPageletPopUpButton;
}

- (RYZImagePopUpButton *)addCollectionPopUpButton
{
    return myAddCollectionPopUpButton;
}

- (void)setAddCollectionPopUpButton:(RYZImagePopUpButton *)anAddCollectionPopUpButton
{
    [anAddCollectionPopUpButton retain];
    [myAddCollectionPopUpButton release];
    myAddCollectionPopUpButton = anAddCollectionPopUpButton;
}

@end


