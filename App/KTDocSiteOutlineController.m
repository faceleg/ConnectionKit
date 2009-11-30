//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"

#import "KTElementPlugin.h"
#import "KTPage+Internal.h"
#import "SVSidebar.h"

#import "NSArray+Karelia.h"

#import "Debug.h"


/*	These strings are localizations for case https://karelia.fogbugz.com/default.asp?4736
 *	Not sure when we're going to have time to implement it, so strings are placed here to ensure they are localized.
 *
 *	NSLocalizedString(@"There is already a page with the file name \\U201C%@.\\U201D Do you wish to rename it to \\U201C%@?\\U201D",
					  "Alert message when changing the file name or extension of a page to match an existing file");
 *	NSLocalizedString(@"There are already some pages with the same file name as those you are adding. Do you wish to rename them to be different?",
					  "Alert message when pasting/dropping in pages whose filenames conflict");
 */


#pragma mark -


@implementation KTDocSiteOutlineController

#pragma mark Managing Objects

- (void)addObject:(KTPage *)page
{
    // Figure out where to insert the page. i.e. from our selection, what collection should it be made a child of?
    KTPage *parent = [[self selectedObjects] lastObject];
    if (![parent isCollection]) parent = [parent parent];
    if (!parent) parent = [[self managedObjectContext] root];
    
    
    // Figure out the predecessor (which page to inherit properties from)
    KTPage *predecessor = parent;
	NSArray *children = [parent childrenWithSorting:KTCollectionSortLatestAtTop inIndex:NO];
	if ([children count] > 0)
	{
		predecessor = [children firstObjectKS];
	}
	
	
    // Attach to parent & other relationships
	[page setMaster:[parent master]];
	[page setSite:[parent valueForKeyPath:@"site"]];
	[parent addPage:page];	// Must use this method to correctly maintain ordering
	
	
    // Load properties from parent/sibling
	[page setAllowComments:[predecessor allowComments]];
	[page setIncludeTimestamp:[predecessor includeTimestamp]];
	
	
	// Keeping it old school. Let the page know it's being inserted
    [page awakeFromBundleAsNewlyCreatedObject:YES];
    
    
    // Give it standard pagelets
    [[page sidebar] addPagelets:[[parent sidebar] pagelets]];
    
    
    // Finally, do the actual controller-level insertion
    [super addObject:page];
}

#pragma mark -

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"selectedPages"])
	{
		return NO;
	}
	else
	{
		return [super automaticallyNotifiesObserversForKey:key];
	}
}

#pragma mark Accessors

- (NSString *)childrenKeyPath { return @"sortedChildren"; }

#pragma mark KVC

/*	When the user customizes the filename, we want it to become fixed on their choice
 */
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath
{
	[super setValue:value forKeyPath:keyPath];
	
	if ([keyPath isEqualToString:@"selection.fileName"])
	{
		[self setValue:[NSNumber numberWithBool:NO] forKeyPath:@"selection.shouldUpdateFileNameWhenTitleChanges"];
	}
}

@end

