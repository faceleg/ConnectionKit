//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"
#import "KTSiteOutlineDataSource.h"

#import "Debug.h"
#import "KTAbstractElement.h"
#import "KTAppDelegate.h"
#import "KTElementPlugin+DataSourceRegistration.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTHTMLInspectorController.h"
#import "KTImageTextCell.h"
#import "KTMaster.h"
#import "KTPage.h"

#import "NSAttributedString+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSString+Karelia.h"


/*	These strings are localizations for case https://karelia.fogbugz.com/default.asp?4736
 *	Not sure when we're going to have time to implement it, so strings are placed here to ensure they are localized.
 *
 *	NSLocalizedString(@"There is already a page with the file name \\U201C%@.\\U201D Do you wish to rename it to \\U201C%@?\\U201D",
					  "Alert message when changing the file name or extension of a page to match an existing file");
 *	NSLocalizedString(@"There are already some pages with the same file name as those you are adding. Do you wish to rename them to be different?",
					  "Alert message when pasting/dropping in pages whose filenames conflict");
 */


@interface KTDocWindowController (PrivatePageStuff)
- (void)insertPage:(KTPage *)aPage parent:(KTPage *)aCollection;
@end


#pragma mark -


@interface KTDocSiteOutlineController ()
- (void)setSiteOutline:(NSOutlineView *)outlineView;

- (NSSet *)pages;
- (void)addPagesObject:(KTPage *)aPage;
- (void)removePagesObject:(KTPage *)aPage;
@end


#pragma mark -


@implementation KTDocSiteOutlineController

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

#pragma mark -
#pragma mark Init/Dealloc/Awake

- (id)initWithCoder:(NSCoder *)decoder
{
	self = [super initWithCoder:decoder];
	
	if ( nil != self )
	{
		mySiteOutlineDataSource = [[KTSiteOutlineDataSource alloc] initWithSiteOutlineController:self];
		
		// Prepare tree controller parameters
		[self setObjectClass:[KTPage class]];
		
		[self setAvoidsEmptySelection:NO];
		[self setPreservesSelection:YES];
		[self setSelectsInsertedObjects:NO];
		
		[self bind:@"contentSet" toObject:mySiteOutlineDataSource withKeyPath:@"pages" options:nil];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
    [self setWindowController:nil];
	[self setSiteOutline:nil];
	
	
	// Release remaining iVars
	[mySiteOutlineDataSource setSiteOutlineController:nil];
	[mySiteOutlineDataSource release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTDocWindowController *)windowController { return myWindowController; }

- (void)setWindowController:(KTDocWindowController *)controller
{
	// Stop observing the old controller
	[[NSNotificationCenter defaultCenter] removeObserver:mySiteOutlineDataSource
													name:@"KTDisplaySmallPageIconsDidChange"
												  object:[self windowController]];
	
	// Store the controller
	myWindowController = controller;
	
	
	// Do stuff with the new controller
	if (!controller)
	{
		[self setSiteOutline:nil];
	}
	
	if (controller)
	{
		OBASSERT([controller document]);
        [[NSNotificationCenter defaultCenter] addObserver:mySiteOutlineDataSource
												 selector:@selector(pageIconSizeDidChange:)
													 name:@"KTDisplaySmallPageIconsDidChange"
												   object:[controller document]];
	}
}

- (NSOutlineView *)siteOutline { return siteOutline; }

- (void)setSiteOutline:(NSOutlineView *)outlineView
{
	// Dump the old outline
	NSOutlineView *oldSiteOutline = [self siteOutline];
	if (oldSiteOutline)
	{
		[oldSiteOutline setDataSource:nil];
		[oldSiteOutline setDelegate:nil];
		
		NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
		[notificationCenter removeObserver:self name:NSOutlineViewSelectionDidChangeNotification object:oldSiteOutline];
		[notificationCenter removeObserver:self name:NSOutlineViewItemWillCollapseNotification object:oldSiteOutline];
	}
	[mySiteOutlineDataSource resetPageObservation];
	
	
	// Set up the appearance of the new view
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:@"displayName"];
	KTImageTextCell *imageTextCell = [[[KTImageTextCell alloc] init] autorelease];
	[imageTextCell setEditable:YES];
	[imageTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
	[tableColumn setDataCell:imageTextCell];
	
	[outlineView setIntercellSpacing:NSMakeSize(3.0, 1.0)];
	
	
	// Set up the behaviour of the new view
	[outlineView setTarget:myWindowController];
	[outlineView setDoubleAction:@selector(showInfo:)];
	
    
    // Drag n drop
	NSMutableArray *dragTypes = [NSMutableArray arrayWithArray:
                                 [[KTElementPlugin setOfAllDragSourceAcceptedDragTypesForPagelets:NO] allObjects]];
    
	[dragTypes addObject:kKTOutlineDraggingPboardType];
	[dragTypes addObject:kKTLocalLinkPboardType];
	[outlineView registerForDraggedTypes:dragTypes];
	[outlineView setVerticalMotionCanBeginDrag:YES];
	[outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [outlineView setDraggingSourceOperationMask:NSDragOperationAll_Obsolete forLocal:NO];
	
	
	// Retain the new view
	[outlineView retain];
	[siteOutline release];
	siteOutline = outlineView;
	
	
	// Finally, hook up outline delegate & data source
	if (siteOutline)
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(outlineViewSelectionDidChange:)
													 name:NSOutlineViewSelectionDidChangeNotification
												   object:siteOutline];
		
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(outlineViewItemWillCollapse:)
													 name:NSOutlineViewItemWillCollapseNotification
												   object:siteOutline];
		
		[outlineView setDelegate:mySiteOutlineDataSource];		// -setDelegate: MUST come first to receive all notifications
		[outlineView setDataSource:mySiteOutlineDataSource];
		
        // Ensure we have a selection (case ID unknown), and that a -selectionDidChange: message got through (Snow Leopard problem)
		[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
     }
}

- (NSString *)childrenKeyPath { return @"sortedChildren"; }

#pragma mark -
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

