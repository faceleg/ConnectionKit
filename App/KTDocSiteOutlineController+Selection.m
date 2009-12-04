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

@end

