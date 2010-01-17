//
//  KTSiteOutlineDataSource.m
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVSiteOutlineViewController.h"

#import "KTDocument.h"
#import "KTElementPlugin+DataSourceRegistration.h"
#import "KTSite.h"
#import "KTHTMLInspectorController.h"
#import "KTImageTextCell.h"
#import "KTLinkSourceView.h"
#import "KTMaster+Internal.h"
#import "KTPage.h"

#import "KSPlugin.h"
#import "KTAbstractHTMLPlugin.h"

#import "NSArray+Karelia.h"
#import "NSArray+KTExtensions.h"
#import "NSDate+Karelia.h"
#import "NSEvent+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSResponder+Karelia.h"
#import "NSSet+KTExtensions.h"
#import "NSSet+Karelia.h"

#import "Debug.h"


#define LARGE_ICON_CELL_HEIGHT	34.00
#define SMALL_ICON_CELL_HEIGHT	17.00
#define LARGE_ICON_ROOT_SPACING	24.00
#define SMALL_ICON_ROOT_SPACING 16.00


@interface SVSiteOutlineViewController ()
+ (NSSet *)mostSiteOutlineRefreshingKeyPaths;

- (void)observeValueForSortedChildrenOfPage:(KTPage *)page change:(NSDictionary *)change context:(void *)context;

- (void)observeValueForOtherKeyPath:(NSString *)keyPath
							 ofPage:(KTPage *)page
							 change:(NSDictionary *)change
							context:(void *)context;
@end


#pragma mark -


static NSString *sContentSelectionObservationContext = @"SVSiteOutlineViewControllerContentSelectionObservationContext";


@implementation SVSiteOutlineViewController

#pragma mark Init & Dealloc

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    if ([key isEqualToString:@"pages"])
    {
        return NO;
    }
    else
    {
        return [super automaticallyNotifiesObserversForKey:key];
    }
}

- (id)initWithCoder:(NSCoder *)coder
{
	if (self = [super initWithCoder:coder])
    {
        _pages = [[NSMutableSet alloc] initWithCapacity:200];
        
        // Caches
        _cachedPluginIcons = [[NSMutableDictionary alloc] init];
        _cachedCustomPageIcons = [[NSMutableDictionary alloc] init];
        
        // Icon queue
        _customIconGenerationQueue = [[NSMutableArray alloc] init];
    }
        
	return self;
}

- (void)dealloc
{
	// Dump view
    [self setOutlineView:nil];
    
    
    // Dump the pages list
    [_draggedItems release];
    
	[self resetPageObservation];       // This will also remove home page observation
    OBASSERT([_pages count] == 0);
	[_pages release];
	
    
	[_cachedFavicon release];
	[_cachedPluginIcons release];
	[_cachedCustomPageIcons release];
	[_customIconGenerationQueue release];
    
    [self setContent:nil];
	
	[super dealloc];
}

#pragma mark View

- (NSOutlineView *)outlineView
{
    [self view];    // make sure it's loaded
    return _outlineView;
}

- (void)setOutlineView:(NSOutlineView *)outlineView
{
	// Dump the old outline
	[_outlineView setDataSource:nil];  // don't call [self outlineView] as that may try to load the nib when we don't want it to
	[_outlineView setDelegate:nil];
    // TODO: Reset responder chain
	[self resetPageObservation];
	
	
	// Set up the appearance of the new view
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:@"displayName"];
	KTImageTextCell *imageTextCell = [[[KTImageTextCell alloc] init] autorelease];
	[imageTextCell setEditable:YES];
	[imageTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
	[tableColumn setDataCell:imageTextCell];
	
	[outlineView setIntercellSpacing:NSMakeSize(3.0, 1.0)];
	
	
	// Drag 'n' drop
	NSMutableArray *dragTypes = [NSMutableArray arrayWithArray:
                                 [[KTElementPlugin setOfAllDragSourceAcceptedDragTypesForPagelets:NO] allObjects]];
    
	[dragTypes addObject:kKTPagesPboardType];
	[dragTypes addObject:kKTLocalLinkPboardType];
	[outlineView registerForDraggedTypes:dragTypes];
	[outlineView setVerticalMotionCanBeginDrag:YES];
	[outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [outlineView setDraggingSourceOperationMask:NSDragOperationAll_Obsolete forLocal:NO];
	
	
	// Retain the new view
	[outlineView retain];
	[_outlineView release], _outlineView = outlineView;
    
    
    // Responder Chain
    [outlineView setNextResponder:self insert:YES];
	
	
	// Finally, hook up outline delegate & data source
	if (outlineView)
	{
		[outlineView setDelegate:self];		// -setDelegate: MUST come first to receive all notifications
		[outlineView setDataSource:self];
		
        // Ensure we have a selection (case ID unknown), and that a -selectionDidChange: message got through (Snow Leopard problem)
		//[outlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

#pragma mark Other Accessors

@synthesize content = _pagesController;
- (void)setContent:(NSArrayController *)controller
{
    [_pagesController removeObserver:self forKeyPath:@"selectedObjects"];
    
    // Store
    [controller retain];
    [_pagesController release]; _pagesController = controller;
    
    
    // Load
    [[self outlineView] reloadData];
    
    [controller addObserver:self
                 forKeyPath:@"selectedObjects"
                    options:NSKeyValueObservingOptionInitial
                    context:sContentSelectionObservationContext];
}

#pragma mark Pages List

/*	NSOutlineView does not retain its objects. Neither does NSManagedObjectContext (by default anyway!)
 *	Thus, we have to retain appropriate objects here. This is done using a simple NSSet.
 *	Every time a page is used in some way by the Site Outline we make sure it is in the set.
 *	Pages are only then removed from the set when we detect their deletion.
 *
 *	Wolf wrote a nice blogpost on this sort of business - http://rentzsch.com/cocoa/foamingAtTheMouth
 */

- (NSSet *)pages { return [[_pages copy] autorelease]; }

@synthesize rootPage = _rootPage;
- (void)setRootPage:(KTPage *)page
{
    [[self rootPage] removeObserver:self forKeyPath:@"master.favicon"];
    [[self rootPage] removeObserver:self forKeyPath:@"master.codeInjection.hasCodeInjection"];
    
    [page retain];
    [_rootPage release];
    _rootPage = page;
    
    [[self rootPage] addObserver:self forKeyPath:@"master.favicon" options:0 context:NULL];
    [[self rootPage] addObserver:self forKeyPath:@"master.codeInjection.hasCodeInjection" options:0 context:NULL];
}

- (void)addPagesObject:(KTPage *)page
{
	if (![_pages containsObject:page] )
	{
		// KVO
        NSSet *pages = [NSSet setWithObject:page];
        [self willChangeValueForKey:@"pages"
                    withSetMutation:NSKeyValueUnionSetMutation
                       usingObjects:pages];
        
        
        //	Begin observing the page
		[page addObserver:self
				forKeyPath:@"sortedChildren"
				   options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
				   context:nil];
		
		[page addObserver:self
			   forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]
				   options:(NSKeyValueObservingOptionNew)
				   context:nil];
		
		
		// Add to the set
        OBASSERT(page);
		[_pages addObject:page];
		
        
		// Cache the icon ready for display later. Include child pages (but only 1 layer deep)
		[self iconForItem:page];
		NSEnumerator *pagesEnumerator = [[page childItems] objectEnumerator];
		KTPage *aPage;
		while (aPage = [pagesEnumerator nextObject])
		{
			[self iconForItem:aPage];
		}
        
        
        // KVO
        [self didChangeValueForKey:@"pages"
                   withSetMutation:NSKeyValueUnionSetMutation
                      usingObjects:pages];
	}
}

- (void)removePagesObject:(KTPage *)aPage
{
	if ([_pages containsObject:aPage])
	{
		// KVO
        [self willChangeValueForKey:@"pages"
                    withSetMutation:NSKeyValueMinusSetMutation
                       usingObjects:[NSSet setWithObject:aPage]];
        
        // Remove observers
		[aPage removeObserver:self forKeyPath:@"sortedChildren"];
		[aPage removeObserver:self forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]];
		
		// Uncache custom icon to free memory
		[_cachedCustomPageIcons removeObjectForKey:aPage];
		
		// Remove from the set
		[_pages removeObject:aPage];
        
        // KVO
        [self didChangeValueForKey:@"pages"
                   withSetMutation:NSKeyValueMinusSetMutation
                      usingObjects:[NSSet setWithObject:aPage]];
	}
}

/*	Support method that returns the main keypaths the site outline depends on.
 */
+ (NSSet *)mostSiteOutlineRefreshingKeyPaths
{
	static NSSet *keyPaths;
	
	if (!keyPaths)
	{
		keyPaths = [[NSSet alloc] initWithObjects:@"title",
					@"isStale",
					@"codeInjection.hasCodeInjection",
					@"isDraft",
					@"customSiteOutlineIcon",
					@"index", nil];
	}
	
	return keyPaths;
}

- (void)resetPageObservation
{
    // Cancel any pending icons
    [_customIconGenerationQueue removeAllObjects];
    
    // We could use -mutableSetValueForKey to do this, but it will crash if used during -dealloc
    NSEnumerator *pagesEnumerator = [[self pages] objectEnumerator];
    KTPage *aPage;
    while (aPage = [pagesEnumerator nextObject])
    {
        [self removePagesObject:aPage];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if (context == sContentSelectionObservationContext)
    {
        if (!_isChangingSelection)
        {
            [[self outlineView] selectItems:[[self content] selectedObjects]];
        }
    }
    else
    {
        // Ignore objects not in our pages list. If we don't NSOutlineView can occasionally embark on an endless loop.
        if (![[self pages] containsObject:object])
        {
            return;
        }
        
        
        // Having prescreened the parameters, pass them onto the right support methods for processing
        OBASSERT([object isKindOfClass:[SVSiteItem class]]);
        if ([keyPath isEqualToString:@"sortedChildren"])
        {
            [self observeValueForSortedChildrenOfPage:object change:change context:context];
        }
        else
        {
            [self observeValueForOtherKeyPath:keyPath ofPage:object change:change context:context];
        }
    }
}

/*	Oh noes, the sortedChildren property of a page has changed! We need to reload something.
 */
- (void)observeValueForSortedChildrenOfPage:(KTPage *)page change:(NSDictionary *)change context:(void *)context
{
	id changeOld = [change objectForKey:NSKeyValueChangeOldKey];
    NSArray *oldSortedChildren = ([changeOld isKindOfClass:[NSArray class]]) ? changeOld : [NSArray array];
    NSSet *oldChildren  = [NSSet setWithArray:oldSortedChildren];
    
    id changeNew = [change objectForKey:NSKeyValueChangeNewKey];
	NSArray *newSortedChildren = ([changeNew isKindOfClass:[NSArray class]]) ? changeNew : [NSArray array];
	NSSet *newChildren = [NSSet setWithArray:newSortedChildren];
	
	
	// Stop observing removed pages
	NSSet *removedPages = [oldChildren setByRemovingObjects:newChildren];
	if (removedPages && [removedPages count] > 0)
	{
		[[self mutableSetValueForKey:@"pages"] minusSet:removedPages];
	}
	
	
	// Do the reload
	NSArray *oldSelection = [[self outlineView] selectedItems];
	[self reloadItem:page reloadChildren:YES];
	
	
	
	// Correct the selection
	NSMutableSet *correctedSelection = [NSMutableSet setWithArray:oldSelection];
	[correctedSelection minusSet:removedPages];
		
	NSSet *removedSelectedPages = [removedPages setByIntersectingObjectsFromArray:oldSelection];
	NSEnumerator *pagesEnumerator = [removedSelectedPages objectEnumerator];	KTPage *aRemovedPage;
	while (aRemovedPage = [pagesEnumerator nextObject])
	{
		unsigned originalIndex = [oldSortedChildren indexOfObjectIdenticalTo:aRemovedPage];	// Where possible, select the
		KTPage *replacementPage = [newSortedChildren objectClosestToIndex:originalIndex];	// next sibling, but fallback to
		[correctedSelection addObjectIgnoringNil:replacementPage];							// the previous sibling.
	}
	
	if ([correctedSelection count] == 0)	// If nothing remains to be selected, fallback to the parent
	{
		OBASSERT(page);
        [correctedSelection addObject:page];
	}
	
	[[self outlineView] selectItems:[correctedSelection allObjects] forceDidChangeNotification:YES];
}

/*	There was a change that doesn't affect the tree itself, so we just need to mark the outline for display.
 */
- (void)observeValueForOtherKeyPath:(NSString *)keyPath
							 ofPage:(KTPage *)page
							 change:(NSDictionary *)change
							context:(void *)context
{
	// When the favicon or custom icon changes, invalidate the associated cache
	if ([keyPath isEqualToString:@"master.favicon"])
	{
		[self setCachedFavicon:nil];
	}
	else if ([keyPath isEqualToString:@"customSiteOutlineIcon"])
	{
		[_cachedCustomPageIcons removeObjectForKey:page];
	}
	
	
	// Does the change also affect children?
	BOOL childrenNeedDisplay = ([keyPath isEqualToString:@"isDraft"]);
	
	
	[[self outlineView] setItemNeedsDisplay:page childrenNeedDisplay:childrenNeedDisplay];
}

#pragma mark Public Functions

- (void)reloadSiteOutline
{
	[[self outlineView] reloadData];
}

/*	!!IMPORTANT!!
 *	Please use this method rather than directly calling the outline view since it handles reloading root.
 */
- (void)reloadItem:(KTPage *)anItem reloadChildren:(BOOL)reloadChildren
{
	NSOutlineView *siteOutline = [self outlineView];
	
	
	// Do the approrpriate refresh. In the case of the home page, we must reload everything.
	if (anItem == [self rootPage] && reloadChildren)
	{
		[siteOutline reloadData];
	}
	else
	{
		[siteOutline reloadItem:anItem reloadChildren:reloadChildren];
	}

// OLD CODE I WAS TESTING - Mike.
//	// Compare selections
//	NSArray *oldSelection = [siteOutline selectedItems];
//	NSArray *newSelection = [siteOutline selectedItems];
//	if (![newSelection isEqualToArray:oldSelection])
//	{
//		[[NSNotificationCenter defaultCenter] postNotificationName:NSOutlineViewSelectionDidChangeNotification
//															object:siteOutline];
//	}
}

#pragma mark Actions

// cut selected pages (copy and then remove from parents)
- (void)cut:(id)sender;
{
	if ([self canCopy] && [self canDelete])
    {
        // Copy to the clipboard
        [self copy:sender];
        
        // Delete the selection
        [self delete:sender];
    }
    else
    {
        // There shouldn't be another responder up the chain that handles this so it will beep. But you never know, somebody else might like to handle it.
        [self makeNextResponderDoCommandBySelector:_cmd];
    }
}

// copy selected pages
- (void)copy:(id)sender
{
    if ([self canCopy])
    {
        // Package up the selected page(s) (children included)
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        [pboard declareTypes:[NSArray arrayWithObjects:kKTPagesPboardType, nil] owner:self];
        
        NSArray *topLevelPages = [[[self content] selectedObjects] parentObjects];
        NSArray *pasteboardReps = [topLevelPages valueForKey:@"pasteboardRepresentation"];
        [pboard setData:[NSKeyedArchiver archivedDataWithRootObject:pasteboardReps] forType:kKTPagesPboardType];
    }
    else
    {
        // There shouldn't be another responder up the chain that handles this so it will beep. But you never know, somebody else might like to handle it.
        [self makeNextResponderDoCommandBySelector:_cmd];
    }
}

- (void)delete:(id)sender
{
    /// Old code did a -processPendingChanges here but haven't a clue why. Mike.
        
    
    if ([self canDelete])
    {
        NSSet *selection = [[NSSet alloc] initWithArray:[[self content] selectedObjects]];
        
        // Remove the pages from their parents
        NSSet *parentPages = [selection valueForKey:@"parentPage"];
        for (KTPage *aParentPage in parentPages)
        {
            [aParentPage removePages:selection];	// Far more efficient than calling -removePage: repetitively
        }
            
        // Delete the pages
		[[[self rootPage] managedObjectContext] deleteObjectsInCollection:selection];
		
		// Label undo menu
        NSUndoManager *undoManager = [[[self rootPage] managedObjectContext] undoManager];
		if ([selection count] == 1)
		{
			if ([[selection anyObject] isCollection])
			{
				[undoManager setActionName:NSLocalizedString(@"Delete Collection", "Delete Collection MenuItem")];
			}
			else
			{
				[undoManager setActionName:NSLocalizedString(@"Delete Page", "Delete Page MenuItem")];
			}
		}
		else
		{
			[undoManager setActionName:NSLocalizedString(@"Delete Pages", "Delete Pages MenuItem")];
		}
    }
    else
    {
        // There shouldn't be another responder up the chain that handles this so it will beep. But you never know, somebody else might like to handle it.
        [self makeNextResponderDoCommandBySelector:_cmd];
    }
}

- (BOOL)canCopy
{
    BOOL result = ([[[self content] selectedObjects] count] > 0);
    return result;
}

// Can only delete a page if there's a selection and that selection doesn't include the root page
- (BOOL)canDelete
{
    NSObjectController *objectController = [self content];
    BOOL result = ([objectController canRemove] &&
                   ![[objectController selectedObjects] containsObjectIdenticalTo:[self rootPage]]);
    return result;
}

#pragma mark NSResponder

- (void)keyDown:(NSEvent *)theEvent
{
    if ([theEvent isDeleteKeyEvent])
    {
        [self delete:self];
    }
    else
    {
        [super keyDown:theEvent];
    }
}

#pragma mark Datasource

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(SVSiteItem *)item
{
	int result = 0;
	
	if (item != [self rootPage])
	{
		// Due to the slightly odd layout of the site outline, must figure the right page
		if (!item) item = [self rootPage];
		OBASSERT(item);
		
		result = [[item sortedChildren] count];
		
		// Root is a special case where we have to add 1 to the total
		if (item == [self rootPage]) result += 1;
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	BOOL result = NO;
	
	if ( item == [self rootPage] )
	{
		result = NO;
	}
	else if ([item isCollection])
	{
		result = YES;
	}
	else
	{
		result = NO;
	}
	
	return result;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(int)anIndex ofItem:(id)item
{
	id child = nil;
	
	if (!item)
	{
		if (anIndex == 0)
		{
			child = [self rootPage];
		}
		else
		{
			// subtract 1 at top level for "My Site"
			unsigned int childIndex = anIndex-1;
			NSArray *children = [[self rootPage] sortedChildren];
			if ( [children count] >= childIndex+1 )
			{
				child = [children objectAtIndex:childIndex];
			}
		}
	}
	else
	{
		// everything (with children) below top level should all be collections
		NSArray *children = [(KTPage *)item sortedChildren];
		if ( [children count] >= (unsigned int)anIndex+1 )
		{
			child = [children objectAtIndex:anIndex];
		}
	}
	
	// keep a retain http://rentzsch.com/cocoa/foamingAtTheMouth
	if (child)
	{
		[self addPagesObject:child];
	}
	
	return child;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *result = nil;
	
	if ([[tableColumn identifier] isEqualToString:@"displayName"])
	{
        OBASSERT([item isKindOfClass:[SVSiteItem class]]);
        
		if (item == [self rootPage])
		{
			result = [[[[self rootPage] master] siteTitle] text];
		}
		else
		{
			result = [item title];
		}
	}
	else
	{
		id result = [NSString stringWithFormat:@"%i:%i", [[self outlineView] rowForItem:item], [[item wrappedValueForKey:@"childIndex"] intValue]];
		return result;
	}
	
	
	// If there is no title, display a placeholder
	if (!result || [result isEqualToString:@""])
	{
		result = NSLocalizedString(@"(Empty title)",
								   @"Indication in site outline that the page has an empty title. Distinct from untitled, which is for newly created pages.");
	}
	
	
	// Tidy up
	OBPOSTCONDITION(result);
	return result;
}

- (id)outlineView:(NSOutlineView *)outlineView parentOfItem:(id)item
{
	id result = nil;
	if ([item isKindOfClass:[KTPage class]])
	{
		result = [item parentPage];
	}
	
	return result;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)aNewValue forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	; // we don't accept editing of page title via the site outline
}


#pragma mark Delegate

- (void)outlineView:(NSOutlineView *)outlineView
    willDisplayCell:(KTImageTextCell *)cell
     forTableColumn:(NSTableColumn *)tableColumn
               item:(SVSiteItem *)item
{
	// Ignore any uninteresting columns/rows
	if (!item || ![[tableColumn identifier] isEqualToString:@"displayName"]) {
		return;
	}
	
		
	// Set the cell's appearance
	if ([cell isKindOfClass:[KTImageTextCell class]])	// Fail gracefully if not the image kind of cell
	{
		// Size
		NSControlSize controlSize = ([self displaySmallPageIcons]) ? NSSmallControlSize : NSRegularControlSize;
		[cell setControlSize:controlSize];
	
		// Icon
		NSImage *pageIcon = [self iconForItem:item];
		[cell setImage:pageIcon];
		[cell setMaxImageSize:([self displaySmallPageIcons] ? 16.0 : 32.0)];
		
		// Staleness    /// 1.5 is now ignoring this key and using digest-based staleness
		//BOOL isPageStale = [item boolForKey:@"isStale"];
		//[cell setStaleness:isPageStale ? kStalenessPage : kNotStale];
		
		// Draft
		BOOL isDraft = [item pageOrParentDraft];
		[cell setDraft:isDraft];
		
		// Code Injection
		[cell setHasCodeInjection:[[item codeInjection] hasCodeInjection]];
		if (item == [self rootPage] && ![cell hasCodeInjection])
		{
			[cell setHasCodeInjection:[[[item master] codeInjection] hasCodeInjection]];
		}
		
		// Home page is drawn slightly differently
		[cell setRoot:(item == [self rootPage])];
	}
	
	
	
    //  Draw a line to "separate" the root from its children
    //  Note that we need to check there is a valid CGContext to draw into. Otherwise the console will be littered with CG error messages. This situation can sometimes arise on Snowy when switching apps.
	if (item == [self rootPage] &&
        ![[[self outlineView] selectedItems] containsObject:item] &&
        [[NSGraphicsContext currentContext] graphicsPort])
	{
		float width = [tableColumn width]*0.95;
		float lineX = ([tableColumn width] - width)/2.0;
		
		float height = 1; // line thickness
		float lineY;
		if ([self displaySmallPageIcons])
		{
			lineY = SMALL_ICON_CELL_HEIGHT+SMALL_ICON_ROOT_SPACING-3.0;
		}
		else
		{
			lineY = LARGE_ICON_CELL_HEIGHT+LARGE_ICON_ROOT_SPACING-3.0;
		}
		
		[[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] set];
		[NSBezierPath fillRect:NSMakeRect(lineX, lineY, width, height)];
		[[NSColor colorWithCalibratedWhite:0.60 alpha:1.0] set];
		[NSBezierPath fillRect:NSMakeRect(lineX, lineY+1, width, height)];
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	if ( [item isDeleted] )
	{
		LOG((@"warning: outlineView wanted to select a deleted page!"));
		return NO;
	}
	else
	{
		return YES;
	}
}

/*	Called ONLY when the selected row INDEXES changes. We must do other management to detect when the selected page
 *	changes, but the selected row(s) remain the same.
 *
 *	Initially I thought -selectionIsChanging: would do the trick, but it's not invoked by keyboard navigation.
 */
- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	if (!_isChangingSelection)
    {
        NSArray *selectedPages = [[self outlineView] selectedItems];
        
        _isChangingSelection = YES;
        [[self content] setSelectedObjects:selectedPages];
        _isChangingSelection = NO;
    }
}

/*	If the current selection is about to be collapsed away, select the parent.
 */
- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
	SVSiteItem *collapsingItem = [[notification userInfo] objectForKey:@"NSObject"];
	BOOL shouldSelectCollapsingItem = YES;
	NSEnumerator *selectionEnumerator = [[[self content] selectedObjects] objectEnumerator];
	SVSiteItem *anItem;
	
	while (anItem = [selectionEnumerator nextObject])
	{
		if (![anItem isDescendantOfCollection:collapsingItem])
		{
			shouldSelectCollapsingItem = NO;
			break;
		}
	}
	
	if (shouldSelectCollapsingItem)
	{
		[[self outlineView] selectItem:collapsingItem];
	}
}

- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if (item == [self rootPage]) 
	{
		if ( [self displaySmallPageIcons] )
		{
			return SMALL_ICON_CELL_HEIGHT + SMALL_ICON_ROOT_SPACING;
		}
		else
		{
			return LARGE_ICON_CELL_HEIGHT + LARGE_ICON_ROOT_SPACING;
		}
	}
	else
	{
		if ( [self displaySmallPageIcons] )
		{
			return SMALL_ICON_CELL_HEIGHT;
		}
		else
		{
			return LARGE_ICON_CELL_HEIGHT;
		}
	}
}

- (void)outlineViewSelectionIsChanging:(NSNotification *)notification
{
	// Close the Raw HTML editing window, if open
	NSWindowController *HTMLInspectorController = [[[[[self view] window] windowController] document] HTMLInspectorControllerWithoutLoading];
	if ( nil != HTMLInspectorController )
	{
		NSWindow *HTMLInspectorWindow = [HTMLInspectorController window];
		if ( [HTMLInspectorWindow isVisible] )
		{
			[HTMLInspectorWindow close];
		}
	}
}

#pragma mark NSUserInterfaceValidations

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = NO;
    SEL action = [anItem action];
    
    if (action == @selector(cut:))
    {
        result = ([self canDelete] && [self canCopy]);
    }
    else if (action == @selector(copy:))
    {
        result = [self canCopy];
    }
    else if (action == @selector(delete:))
    {
        result = [self canDelete];
    }
    
    return result;
}

#pragma mark Options

@synthesize displaySmallPageIcons = _useSmallIconSize;
- (void)setDisplaySmallPageIcons:(BOOL)smallIcons
{
	_useSmallIconSize = smallIcons;
    
    [self invalidateIconCaches];	// If the icon size changes this lot are no longer valid
	
	// Setup is complete, reload outline
	[self reloadSiteOutline];
}

@end
