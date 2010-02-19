//
//  KTSiteOutlineDataSource.m
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTSiteOutlineDataSource.h"
#import "KTDocSiteOutlineController.h"

#import "KTAbstractElement+Internal.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTHTMLInspectorController.h"
#import "KTImageTextCell.h"
#import "KTMaster.h"
#import "KTPage.h"

#import "KSPlugin.h"
#import "KTAbstractHTMLPlugin.h"

#import "NSArray+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSSet+KTExtensions.h"
#import "NSSet+Karelia.h"

#import "Debug.h"


#define LARGE_ICON_CELL_HEIGHT	34.00
#define SMALL_ICON_CELL_HEIGHT	17.00
#define LARGE_ICON_ROOT_SPACING	24.00
#define SMALL_ICON_ROOT_SPACING 16.00


NSString *kKTLocalLinkPboardType = @"kKTLocalLinkPboardType";


@interface KTSiteOutlineDataSource (Private)
+ (NSSet *)mostSiteOutlineRefreshingKeyPaths;

- (void)observeValueForSortedChildrenOfPage:(KTPage *)page change:(NSDictionary *)change context:(void *)context;

- (void)observeValueForOtherKeyPath:(NSString *)keyPath
							 ofPage:(KTPage *)page
							 change:(NSDictionary *)change
							context:(void *)context;
@end


#pragma mark -


@implementation KTSiteOutlineDataSource

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

- (id)initWithSiteOutlineController:(KTDocSiteOutlineController *)controller
{
	[super init];
	
	
	mySiteOutlineController = controller;	// Weak ref
	
	myPages = [[NSMutableSet alloc] initWithCapacity:200];
	
	// Caches
	myCachedPluginIcons = [[NSMutableDictionary alloc] init];
	myCachedCustomPageIcons = [[NSMutableDictionary alloc] init];
	
	// Icon queue
	myCustomIconGenerationQueue = [[NSMutableArray alloc] init];
	
	
	
	return self;
}

- (void)dealloc
{
	[myCachedFavicon release];
	[myCachedPluginIcons release];
	[myCachedCustomPageIcons release];
	[myCustomIconGenerationQueue release];
	
	// Dump the pages list
	[self resetPageObservation];       // This will also remove home page observation
    OBASSERT([myPages count] == 0);
	[myPages release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTDocSiteOutlineController *)siteOutlineController { return mySiteOutlineController; }		// Weak ref

- (void)setSiteOutlineController:(KTDocSiteOutlineController *)controller { mySiteOutlineController = controller; }

- (NSOutlineView *)siteOutline { return [[self siteOutlineController] siteOutline]; }

- (KTDocument *)document { return [[[self siteOutlineController] windowController] document]; }

#pragma mark -
#pragma mark Pages List

/*	NSOutlineView does not retain its objects. Neither does NSManagedObjectContext (by default anyway!)
 *	Thus, we have to retain appropriate objects here. This is done using a simple NSSet.
 *	Every time a page is used in some way by the Site Outline we make sure it is in the set.
 *	Pages are only then removed from the set when we detect their deletion.
 *
 *	Wolf wrote a nice blogpost on this sort of business - http://rentzsch.com/cocoa/foamingAtTheMouth
 */

- (NSSet *)pages { return [[myPages copy] autorelease]; }

- (KTPage *)homePage { return myHomePage; }

- (void)setHomePage:(KTPage *)page
{
    [[self homePage] removeObserver:self forKeyPath:@"master.favicon"];
    [[self homePage] removeObserver:self forKeyPath:@"master.hasCodeInjection"];
    
    [page retain];
    [myHomePage release];
    myHomePage = page;
    
    [[self homePage] addObserver:self forKeyPath:@"master.favicon" options:0 context:NULL];
    [[self homePage] addObserver:self forKeyPath:@"master.hasCodeInjection" options:0 context:NULL];
}

- (void)addPagesObject:(KTPage *)page
{
	if (![myPages containsObject:page] )
	{
		// KVO
        NSSet *pages = [NSSet setWithObject:page];
        [self willChangeValueForKey:@"pages"
                    withSetMutation:NSKeyValueUnionSetMutation
                       usingObjects:pages];
        
        
        //	Begin observing the page
		[page addObserver:self
				forKeyPath:[[self siteOutlineController] childrenKeyPath]
				   options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
				   context:nil];
		
		[page addObserver:self
			   forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]
				   options:(NSKeyValueObservingOptionNew)
				   context:nil];
		
		if ([page isRoot])	// Observe home page's favicon & master code injection
		{
			[self setHomePage:page];
		}
		
        
		// Add to the set
        OBASSERT(page);
		[myPages addObject:page];
		
        
		// Cache the icon ready for display later. Include child pages (but only 1 layer deep)
		[self iconForPage:page];
		NSEnumerator *pagesEnumerator = [[page children] objectEnumerator];
		KTPage *aPage;
		while (aPage = [pagesEnumerator nextObject])
		{
			[self iconForPage:aPage];
		}
        
        
        // KVO
        [self didChangeValueForKey:@"pages"
                   withSetMutation:NSKeyValueUnionSetMutation
                      usingObjects:pages];
	}
}

- (void)removePagesObject:(KTPage *)aPage
{
	if ([myPages containsObject:aPage])
	{
		// KVO
        [self willChangeValueForKey:@"pages"
                    withSetMutation:NSKeyValueMinusSetMutation
                       usingObjects:[NSSet setWithObject:aPage]];
        
        // Remove observers
		[aPage removeObserver:self forKeyPath:[[self siteOutlineController] childrenKeyPath]];
		[aPage removeObserver:self forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]];
		
		// Uncache custom icon to free memory
		[myCachedCustomPageIcons removeObjectForKey:aPage];
		
		// Remove from the set
		[myPages removeObject:aPage];
        
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
		keyPaths = [[NSSet alloc] initWithObjects:@"titleHTML",
					@"isStale",
					@"hasCodeInjection",
					@"isDraft",
					@"customSiteOutlineIcon",
					@"index", nil];
	}
	
	return keyPaths;
}

- (void)resetPageObservation
{
    // Cancel any pending icons
    [myCustomIconGenerationQueue removeAllObjects];
    
    // Home page
	[self setHomePage:nil];
    
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
	// Ignore objects not in our pages list. If we don't NSOutlineView can occasionally embark on an endless loop.
	if (![[self pages] containsObject:object])
	{
		return;
	}
	
	
	// Having prescreened the parameters, pass them onto the right support methods for processing
	OBASSERT([object isKindOfClass:[KTPage class]]);
	if ([keyPath isEqualToString:[[self siteOutlineController] childrenKeyPath]])
	{
		[self observeValueForSortedChildrenOfPage:object change:change context:context];
	}
	else
	{
		[self observeValueForOtherKeyPath:keyPath ofPage:object change:change context:context];
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
	NSArray *oldSelection = [[self siteOutline] selectedItems];
	[self reloadPage:page reloadChildren:YES];
	
	
	
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
	
	[[self siteOutline] selectItems:[correctedSelection allObjects] forceDidChangeNotification:YES];
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
		[myCachedCustomPageIcons removeObjectForKey:page];
	}
	
	
	// Does the change also affect children?
	BOOL childrenNeedDisplay = ([keyPath isEqualToString:@"isDraft"]);
	
	
	[[self siteOutline] setItemNeedsDisplay:page childrenNeedDisplay:childrenNeedDisplay];
}

#pragma mark -
#pragma mark Public Functions

- (void)reloadSiteOutline
{
	[[self siteOutline] reloadData];
}

/*	!!IMPORTANT!!
 *	Please use this method rather than directly calling the outline view since it handles reloading root.
 */
- (void)reloadPage:(KTPage *)anItem reloadChildren:(BOOL)reloadChildren
{
	NSOutlineView *siteOutline = [self siteOutline];
	
	
	// Do the approrpriate refresh. In the case of the home page, we must reload everything.
	if ([anItem isRoot] && reloadChildren)
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

#pragma mark -
#pragma mark Datasource

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	OBPRECONDITION(!item || [item isKindOfClass:[KTPage class]]);
	int result = 0;
	
	if (![item isRoot])
	{
		// Due to the slightly odd layout of the site outline, must figure the right page
		KTPage *page = (item) ? item : [[[self document] documentInfo] root];
		OBASSERT(page);
		
		NSString *childrenKeyPath = [[self siteOutlineController] childrenKeyPath];	// Don't use -children as a shortcut as
		OBASSERT(childrenKeyPath);													// it may be our of sync during an undo
		result = [[page valueForKey:childrenKeyPath] count];						//  op.
		
		// Root is a special case where we have to add 1 to the total
		if (!item) result += 1;
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	BOOL result = NO;
	
	if ( item == [[[self document] documentInfo] root] )
	{
		result = NO;
	}
	else if ( [item isKindOfClass:[KTPage class]] && ([(KTPage *)item isCollection] || [(KTPage *)item index]) )
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
			child = [[[self document] documentInfo] root];
		}
		else
		{
			// subtract 1 at top level for "My Site"
			unsigned int childIndex = anIndex-1;
			NSArray *children = [[[[self document] documentInfo] root] sortedChildren];
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
	
	if ([[tableColumn identifier] isEqualToString:@"displayName"] && [item isKindOfClass:[KTPage class]])
	{
		KTPage *page = item;
		if ([page isRoot])
		{
			result = [[page master] siteTitleText];
		}
		else
		{
			result = [page titleText];
		}
	}
	else
	{
		id result = [NSString stringWithFormat:@"%i:%i", [[self siteOutline] rowForItem:item], [[item wrappedValueForKey:@"childIndex"] intValue]];
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
		result = [item parent];
	}
	
	return result;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)aNewValue forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	; // we don't accept editing of page title via the site outline
}


#pragma mark -
#pragma mark Delegate (Cell Drawing)

- (void)outlineView:(NSOutlineView *)outlineView
    willDisplayCell:(KTImageTextCell *)cell
     forTableColumn:(NSTableColumn *)tableColumn
               item:(id)item
{
	// Ignore any uninteresting columns/rows
	if (!item || ![[tableColumn identifier] isEqualToString:@"displayName"]) {
		return;
	}
	
	
	KTPage *page = (KTPage *)item;
	
	// Set the cell's appearance
	if ([cell isKindOfClass:[KTImageTextCell class]])	// Fail gracefully if not the image kind of cell
	{
		// Size
		NSControlSize controlSize = ([[self document] displaySmallPageIcons]) ? NSSmallControlSize : NSRegularControlSize;
		[cell setControlSize:controlSize];
	
		// Icon
		NSImage *pageIcon = [self iconForPage:item];
		[cell setImage:pageIcon];
		[cell setMaxImageSize:([[self document] displaySmallPageIcons] ? 16.0 : 32.0)];
		
		// Staleness    /// 1.5 is now ignoring this key and using digest-based staleness
		//BOOL isPageStale = [item boolForKey:@"isStale"];
		//[cell setStaleness:isPageStale ? kStalenessPage : kNotStale];
		
		// Draft
		BOOL isDraft = [item pageOrParentDraft];
		[cell setDraft:isDraft];
		
		// Code Injection
		[cell setHasCodeInjection:[page hasCodeInjection]];
		if ([page isRoot] && ![cell hasCodeInjection])
		{
			[cell setHasCodeInjection:[[page master] hasCodeInjection]];
		}
		
		// Home page is drawn slightly differently
		[cell setRoot:[item isRoot]];
	}
	
	
	
	//if ( (item == [context root]) && ![[[self siteOutline] selectedItems] containsObject:item] )
	if ( (item == [[[self document] documentInfo] root]) && ![[[self siteOutline] selectedItems] containsObject:item] )
	{
		// draw a line to "separate" the root from its children
		float width = [tableColumn width]*0.95;
		float lineX = ([tableColumn width] - width)/2.0;
		
		float height = 1; // line thickness
		float lineY;
		if ([[self document] displaySmallPageIcons])
		{
			lineY = SMALL_ICON_CELL_HEIGHT+SMALL_ICON_ROOT_SPACING-3.0;
		}
		else
		{
			lineY = LARGE_ICON_CELL_HEIGHT+LARGE_ICON_ROOT_SPACING-3.0;
		}
#warning I'm getting some CGContextSetFillColorWithColor: invalid context 0x0
		[[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] set];
		[NSBezierPath fillRect:NSMakeRect(lineX, lineY, width, height)];
		[[NSColor colorWithCalibratedWhite:0.60 alpha:1.0] set];
		[NSBezierPath fillRect:NSMakeRect(lineX, lineY+1, width, height)];
	}
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation
{
	OBASSERTSTRING([item isKindOfClass:[KTPage class]], @"item is not a page!");
	
	NSString *result = nil;
	
	// we'll build the tooltip based on defaults
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	if ( [ov isEqual:[self siteOutline]] && [defaults boolForKey:@"ShowOutlineTooltips"] )
	{
		if ( [cell isKindOfClass:[NSTextFieldCell class]] ) 
		{
			//if ( [[cell attributedStringValue] size].width > rect->size.width ) 
			//{
			//    return [cell stringValue];
			//}
			
			// this is somewhat clunky code that may be better in a table
			// but this method is called infrequently enough that it's not too bad
			
			// set up labels
			NSString *titleLabel = NSLocalizedString(@"Title: ", @"tooltip Title: ");
			NSString *pageTypeLabel = NSLocalizedString(@"Page Type: ", @"tooltip Page Type: ");
			NSString *sortingLabel = NSLocalizedString(@"Sorting:", @"tooltip Collection sorting");
			NSString *indexTypeLabel = NSLocalizedString(@"Index Type: ", @"tooltip Index Type: ");
			NSString *createdLabel = NSLocalizedString(@"Created: ", @"tooltip Created: ");
			NSString *lastUpdatedLabel = NSLocalizedString(@"Last Updated: ", @"tooltip Last Updated: ");
			NSString *serverPathLabel = NSLocalizedString(@"Server Path: ", @"tooltip Server Path: ");
			NSString *authorLabel = NSLocalizedString(@"Author: ", @"tooltip Author: ");
			NSString *languageLabel = NSLocalizedString(@"Language: ", @"tooltip Language: ");
			//			NSString *draftLabel = NSLocalizedString(@"Draft: ", @"tooltip Draft: ");
			//			NSString *needsUploadingLabel = NSLocalizedString(@"Needs Uploading: ", @"tooltip Needs Uploading: ");			   
			
			// seed with title (we always show title, but may add others)
			NSString *title = [cell stringValue];
			if ( [defaults boolForKey:@"OutlineTooltipShowTitle"] )
			{
				result = [NSString stringWithFormat:@"%@%@", titleLabel, title];
			}
			else
			{
				return title;
			}
			
			// page type
			if ( [defaults boolForKey:@"OutlineTooltipShowPageType"] )
			{
				NSString *pageType = [[item plugin] pluginPropertyForKey:@"KTPluginName"];
				if ( nil != pageType )
				{
					result = [result stringByAppendingFormat:@"\n%@%@", pageTypeLabel, pageType];
				}
			}		   
			
			
			// Sorting
			if ([item isCollection])
			{
				NSString *sortingDescription = @"";
				KTCollectionSortType sorting = [item collectionSortOrder];
				switch (sorting)
				{
					case KTCollectionSortAlpha:
						sortingDescription = NSLocalizedString(@"Alphabetical", "tooltip Collection sorting");
						break;
					case KTCollectionSortReverseAlpha:
						sortingDescription = NSLocalizedString(@"Reverse alphabetical", "tooltip Collection sorting");
						break;
					case KTCollectionSortLatestAtBottom:
						sortingDescription = NSLocalizedString(@"Latest at bottom", "tooltip Collection sorting");
						break;
					case KTCollectionSortLatestAtTop:
						sortingDescription = NSLocalizedString(@"Latest at top", "tooltip Collection sorting");
						break;
					default:
						sortingDescription = NSLocalizedString(@"Not sorted", "tooltip Collection sorting");
						break;
				}
				result = [result stringByAppendingFormat:@"\n%@ %@", sortingLabel, sortingDescription];
			}
			
			// index type, if applicable
			if ( [defaults boolForKey:@"OutlineTooltipShowIndexType"] )
			{
				if ([item index])
				{
					NSString *indexType = [[[(KTPage *)item index] plugin] pluginName];
					if ( nil != indexType )
					{
						result = [result stringByAppendingFormat:@"\n%@%@", indexTypeLabel, indexType];
					}
				}
			}		   
			
			// show time of day if today ... both creation & modification if different 
			if ( [defaults boolForKey:@"OutlineTooltipShowLastUpdated"] )
			{
				NSDate *creationDate = [item wrappedValueForKey:@"creationDate"];
				NSDate *lastModificationDate = [item wrappedValueForKey:@"lastModificationDate"];
				if ( (nil != creationDate) && (nil != lastModificationDate) )
				{
					if ( [creationDate isEqualToDate:lastModificationDate] )
					{
						result = [result stringByAppendingFormat:@"\n%@%@", lastUpdatedLabel, [lastModificationDate relativeShortDescription]];
					}
					else
					{
						result = [result stringByAppendingFormat:@"\n%@%@", createdLabel, [creationDate relativeShortDescription]];
						result = [result stringByAppendingFormat:@"\n%@%@", lastUpdatedLabel, [lastModificationDate relativeShortDescription]];
					}
				}
			}
			
			// server path
			if ( [defaults boolForKey:@"OutlineTooltipShowServerPath"] )
			{
				NSString *serverPath = [item publishedPath];
				if ( nil != serverPath )
				{
					result = [result stringByAppendingFormat:@"\n%@%@", serverPathLabel, serverPath];
				}
			}
			
			// author
			if ( [defaults boolForKey:@"OutlineTooltipShowAuthor"] )
			{
				NSString *author = [[item master] valueForKey:@"author"];
				if ( nil != author && ![author isEqualToString:@""])
				{
					result = [result stringByAppendingFormat:@"\n%@%@", authorLabel, author];
				}
			}
			
			// language
			if ( [defaults boolForKey:@"OutlineTooltipShowShowLanguage"] )
			{
				NSString *language = [[item master] valueForKey:@"language"];
				if ( nil != language && ![language isEqualToString:@""])
				{
					result = [result stringByAppendingFormat:@"\n%@%@", languageLabel, language];
				}
			}
			
			//		   // draft
			//		   if ( [defaults boolForKey:@"OutlineTooltipShowIsDraft"] )
			//		   {
			//			   NSString *status = [item boolForKey:@"isDraft"] ? NSLocalizedString(@"Yes",@"Yes") : NSLocalizedString(@"No",@"No");
			//			   result = [result stringByAppendingFormat:@"\n%@%@", draftLabel, status];
			//		   }
			//
			//		   // needs uploading 
			//		   if ( [defaults boolForKey:@"OutlineTooltipShowNeedsUploading"] )
			//		   {
			//			   NSString *status = [item boolForKey:@"isStale"] ? NSLocalizedString(@"Yes",@"Yes") : NSLocalizedString(@"No",@"No");
			//			   result = [result stringByAppendingFormat:@"\n%@%@", needsUploadingLabel, status];
			//		   }
		}
	}
	
    return result;
}

#pragma mark -
#pragma mark Delegate (Editing)

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	return NO;
}

#pragma mark -
#pragma mark Delegate (Selection)

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

#pragma mark -
#pragma mark Delegate (Row Height)

- (float)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	if ([item isRoot]) 
	{
		if ( [[self document] displaySmallPageIcons] )
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
		if ( [[self document] displaySmallPageIcons] )
		{
			return SMALL_ICON_CELL_HEIGHT;
		}
		else
		{
			return LARGE_ICON_CELL_HEIGHT;
		}
	}
}

#pragma mark -
#pragma mark Notification Handlers

- (void)outlineViewSelectionIsChanging:(NSNotification *)notification
{
	// Close the Raw HTML editing window, if open
	NSWindowController *HTMLInspectorController = [[self document] HTMLInspectorControllerWithoutLoading];
	if ( nil != HTMLInspectorController )
	{
		NSWindow *HTMLInspectorWindow = [HTMLInspectorController window];
		if ( [HTMLInspectorWindow isVisible] )
		{
			[HTMLInspectorWindow close];
		}
	}
}

- (void)pageIconSizeDidChange:(NSNotification *)notification
{
	[self invalidateIconCaches];	// If the icon size changes this lot are no longer valid
	
	// Setup is complete, reload outline
	[self reloadSiteOutline];
}

@end
