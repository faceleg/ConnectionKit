//
//  KTDocSiteOutlineController.m
//  Marvel
//
//  Created by Terrence Talbot on 1/2/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocSiteOutlineController.h"

#import "Debug.h"
#import "KTAbstractElement.h"
#import "KTAppDelegate.h"
#import "KTDataSource.h"
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
#import "NSOutlineView+KTExtensions.h"
#import "NSString+Karelia.h"

#define LARGE_ICON_CELL_HEIGHT	34.00
#define SMALL_ICON_CELL_HEIGHT	17.00
#define LARGE_ICON_ROOT_SPACING	24.00
#define SMALL_ICON_ROOT_SPACING 16.00


NSString *kKTLocalLinkPboardType = @"kKTLocalLinkPboardType";


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


@interface KTDocWindowController (PrivateSiteOutline)
- (NSAttributedString *)attributedStringForDisplayOfItem:(id)anItem;
@end


#pragma mark -


@interface KTDocSiteOutlineController (Private)
- (void)setSiteOutline:(NSOutlineView *)outlineView;

- (NSSet *)pages;
- (void)addPagesObject:(KTPage *)aPage;
- (void)removePagesObject:(KTPage *)aPage;
@end


#pragma mark -


@implementation KTDocSiteOutlineController

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
	if ([key isEqualToString:@"selectionIndexPaths"] || [key isEqualToString:@"selectedPages"])
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
		myPages = [[NSMutableSet alloc] initWithCapacity:200];
		
		// Caches
		myCachedPluginIcons = [[NSMutableDictionary alloc] init];
		myCachedCustomPageIcons = [[NSMutableDictionary alloc] init];
		
		// Icon queue
		myCustomIconGenerationQueue = [[NSMutableArray alloc] init];
		
		
		// Prepare tree controller parameters
		[self setChildrenKeyPath:@"sortedChildren"];
		[self setAvoidsEmptySelection:NO];
		[self setPreservesSelection:NO];
		[self setSelectsInsertedObjects:NO];
	}
	
	return self;
}

- (void)awakeFromNib
{
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(pageIconSizeDidChange:)
												 name:@"KTDisplaySmallPageIconsDidChange"
											   object:[self document]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	[self setSiteOutline:nil];
	
	
	// Release remaining iVars
	[mySelectedPages release];
	[myPages release];
	
	[myCachedFavicon release];
	[myCachedPluginIcons release];
	[myCachedCustomPageIcons release];
	[myCustomIconGenerationQueue release];
	
	
	[super dealloc];
}

- (void)siteOutlineDidLoad
{	
	// set up the Source outline
	[[self siteOutline] setTarget:myWindowController];
	[[self siteOutline] setDoubleAction:@selector(showInfo:)];
	
	// set up cell to show graphics
	NSTableColumn *tableColumn = [[self siteOutline] tableColumnWithIdentifier:@"displayName"];
	KTImageTextCell *imageTextCell = [[[KTImageTextCell alloc] init] autorelease];
	[imageTextCell setEditable:YES];
	//[imageTextCell setImagePosition:NSImageRight];
	[tableColumn setDataCell:imageTextCell];
	
	// Causes a crash?
	[[self siteOutline] setIntercellSpacing:NSMakeSize(3.0, 1.0)];
	
	// set drag types and mask
	NSMutableArray *dragTypes = [NSMutableArray arrayWithArray:[KTDataSource allDragSourceAcceptedDragTypesForPagelets:NO]];
	[dragTypes addObject:kKTOutlineDraggingPboardType];
	[dragTypes addObject:kKTLocalLinkPboardType];
	[[self siteOutline] registerForDraggedTypes:dragTypes];
	[[self siteOutline] setVerticalMotionCanBeginDrag:YES];
	
	[[self siteOutline] setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [[self siteOutline] setDraggingSourceOperationMask:NSDragOperationAll_Obsolete forLocal:NO];
	
	
	// Setup should be out of the way, load the Site Outline
	[self reloadSiteOutline];
}

#pragma mark -
#pragma mark Accessors

- (KTDocWindowController *)windowController { return myWindowController; }

- (void)setWindowController:(KTDocWindowController *)controller
{
	myWindowController = controller;
	
	// Connect tree controller stuff up to the controller/doc
	KTDocument *document = [controller document];
	[self setManagedObjectContext:[document managedObjectContext]];
	[self setContent:[document root]];
}

- (KTDocument *)document { return [[self windowController] document]; }

- (NSOutlineView *)siteOutline { return siteOutline; }

- (void)setSiteOutline:(NSOutlineView *)outlineView
{
	[[self siteOutline] setDataSource:nil];
	[[self siteOutline] setDelegate:nil];
	
	[outlineView retain];
	[siteOutline release];
	siteOutline = outlineView;
	
	[outlineView setDelegate:self];
	[outlineView setDataSource:self];
}


/*	Supplement our default behaviour by also rebuilding the -pages list as it should now be invalid
 */
- (void)setManagedObjectContext:(NSManagedObjectContext *)managedObjectContext
{
	// Rebuild our pages list
	NSEnumerator *pagesEnumerator = [[self pages] objectEnumerator];
	KTPage *aPage;
	while (aPage = [pagesEnumerator nextObject])
	{
		[self removePagesObject:aPage];
	}
	
	
	// Super
	[super setManagedObjectContext:managedObjectContext];
}

#pragma mark -
#pragma mark Pages List

/*	NSOutlineView does not retain its objects. Neither does NSManagedObjectContext (by default anyway!)
 *	Thus, we have to retain appropriate objects here. This is done using a simple NSSet.
 *	Every time a page is used in some way by the Site Outline we make sure it is in the set.
 *	Pages are only then removed from the set when we detect their deletion.
 *
 *	Wolf wrote a nice blogpost on this sort of business - http://rentzsch.com/cocoa/foamingAtTheMouth
 */

- (NSSet *)pages { return [NSSet setWithSet:myPages]; }

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

+ (NSSet *)keyPathsRequiringChildrenReload
{
	static NSSet *keyPaths;
	
	if (!keyPaths)
	{
		keyPaths = [[NSSet alloc] initWithObjects:@"sortedChildren",
												  @"isDraft", nil];
	}
	
	return keyPaths;
}

- (void)addPagesObject:(KTPage *)aPage
{
	// Mimic the NSControllers' behaviour and set our managedObjectContext to match the object if we don't already have one
	if (![self managedObjectContext])
	{
		[self setManagedObjectContext:[aPage managedObjectContext]];
	}
	
	
	if (![myPages containsObject:aPage] )
	{
		//	Begin observing the page if needed
		[aPage addObserver:self
				forKeyPath:@"sortedChildren"
				   options:(NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld)
				   context:nil];
		
		[aPage addObserver:self
			   forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]
				   options:(NSKeyValueObservingOptionNew)
				   context:nil];
		
		if ([aPage isRoot])	// Observe home page's favicon & master code injection
		{
			[aPage addObserver:self forKeyPath:@"master.favicon" options:0 context:NULL];
			[aPage addObserver:self forKeyPath:@"master.hasCodeInjection" options:0 context:NULL];
		}
		
		// Add to the set
		[myPages addObject:aPage];
		
		// Cache the icon ready for display later. Include child pages (but only 1 layer deep)
		[self iconForPage:aPage];
		NSEnumerator *pagesEnumerator = [[aPage valueForKey:@"children"] objectEnumerator];
		KTPage *aPage;
		while (aPage = [pagesEnumerator nextObject])
		{
			[self iconForPage:aPage];
		}
	}
}

- (void)removePagesObject:(KTPage *)aPage
{
	if ([myPages containsObject:aPage])
	{
		// Remove observers
		[aPage removeObserver:self forKeyPath:@"sortedChildren"];
		[aPage removeObserver:self forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]];
		
		if ([aPage isRoot])	// Observe home page's favicon
		{
			[aPage removeObserver:self forKeyPaths:
				[NSSet setWithObjects:@"master.favicon", @"master.hasCodeInjection", nil]];
		}
		
		// Uncache custom icon to free memory
		[myCachedCustomPageIcons removeObjectForKey:[aPage uniqueID]];
		
		// Remove from the set
		[myPages removeObject:aPage];
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
	
	
	// This probably shouldn't happen, but if the observed object has been deleted stop observing it and reload the parent
	if ([object isDeleted])
	{
		OBASSERT_NOT_REACHED("As far as I'm aware, this codepath shouldn't happen. Mike.");
		[self removePagesObject:object];
		[[self siteOutline] reloadData];
		return;
	}
	
	
	// When pages are added or removed, adjust the page list to match
	// If a deleted page happens to be selected, we also need to update our -selectedPages set
	NSSet *selectedPages = [NSSet setWithArray:[self selectedPages]];
	BOOL selectedPagesNeedsUpdating = NO;
	
	if ([keyPath isEqualToString:@"sortedChildren"])
	{
		int changeKind = [(NSNumber *)[change valueForKey:NSKeyValueChangeKindKey] intValue];
		switch (changeKind)
		{
			case NSKeyValueChangeRemoval:
			{
				NSSet *removedPages = [NSSet setWithArray:[change valueForKey:NSKeyValueChangeOldKey]];
				[[self mutableSetValueForKey:@"pages"] minusSet:removedPages];
				
				if ([selectedPages intersectsSet:removedPages]) selectedPagesNeedsUpdating = YES;
								
				break;
			}
			
			case NSKeyValueChangeSetting:
			{
				NSSet *newSortedChildren = [NSSet setWithArray:[change valueForKey:NSKeyValueChangeNewKey]];
				
				NSMutableSet *removedPages = [NSMutableSet setWithArray:[change valueForKey:NSKeyValueChangeOldKey]];
				[removedPages minusSet:newSortedChildren];
				
				[[self mutableSetValueForKey:@"pages"] minusSet:removedPages];
				
				if ([selectedPages intersectsSet:removedPages]) selectedPagesNeedsUpdating = YES;
								
				break;
			}
			
			default:
				break;
		}
	}
	
	
	// When the favicon or custom icon changes, invalidate the associated cache
	if ([keyPath isEqualToString:@"master.favicon"])
	{
		[self setCachedFavicon:nil];
	}
	else if ([keyPath isEqualToString:@"customSiteOutlineIcon"])
	{
		NSString *pageID = [(KTPage *)object uniqueID];
		if (pageID)
		{
			[myCachedCustomPageIcons removeObjectForKey:[(KTPage *)object uniqueID]];
		}
	}
	
	
	// Should children be reloaded?
	BOOL reloadChildren = NO;
	if ([[[self class] keyPathsRequiringChildrenReload] containsObject:keyPath])
	{
		reloadChildren = YES;
	}
	
	
	// Do the reload
	[self reloadPage:object reloadChildren:reloadChildren];
	
	
	// Regenerate -selectedPages if required
	if (selectedPagesNeedsUpdating)
	{
		//[self generateSelectedPagesSet];	// TODO: Write a replacement for this
	}
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
	// Do the approrpriate refresh. In the case of the home page, we must reload everything.
	if ([anItem isRoot] && reloadChildren)
	{
		[[self siteOutline] reloadData];
	}
	else
	{
		[[self siteOutline] reloadItem:anItem reloadChildren:reloadChildren];
	}
}

#pragma mark -
#pragma mark Datasource

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	int result = 0;
	
	if ( nil == item )
	{
		// add 1 at top level for "My Site"
		KTPage *root = [[self document] root];
		if (root)
		{
			result = 1 + [[root valueForKeyPath:@"children.@count"] intValue];
		}
	}
	else if ( [(NSObject *)item isKindOfClass:[KTPage class]] && [(KTPage *)item isCollection] )
	{
		result = [[(KTPage *)item valueForKeyPath:@"children.@count"] intValue];
	}
	
	return result;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	BOOL result = NO;
	
	if ( item == [[self document] root] )
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
	
	if ( nil == item )
	{
		if ( 0 == anIndex )
		{
			child = [[self document] root];
		}
		else
		{
			// subtract 1 at top level for "My Site"
			unsigned int childIndex = anIndex-1;
			NSArray *children = [[(KTDocument *)[self document] root] sortedChildren];
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
	if ( nil != child )
	{
		[self addPagesObject:child];
	}
	
	return child;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if ( [[tableColumn identifier] isEqualToString:@"displayName"] )
	{
		// get title (attributedStringForDisplayOfItem: locks context)
		NSMutableAttributedString *displayName = [[self attributedStringForDisplayOfItem:item] mutableCopy];
		
		// set up a line break mode
		NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
		[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
		
		// apply the style
		[displayName addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0, [displayName length])];
		[style release];
		
		// return the string
		return [displayName autorelease];
	}
	else
	{
		id result = [NSString stringWithFormat:@"%i:%i", [[self siteOutline] rowForItem:item], [[item wrappedValueForKey:@"childIndex"] intValue]];
		return result;
	}
}

- (NSAttributedString *)attributedStringForDisplayOfItem:(id)anItem
{
	NSAttributedString *attrString = nil;
	
	if ( [anItem isKindOfClass:[KTPage class]] && [(KTPage *)anItem isRoot] )
	{
		if ( nil != [[anItem master] valueForKey:@"siteTitleAttributed"] )
		{
			id fetchedValue = [[anItem master] valueForKey:@"siteTitleAttributed"];
			if ( nil != fetchedValue )
			{
				if ( [fetchedValue isKindOfClass:[NSAttributedString class]] )
				{
					// compatibility for sites created under Tiger with 1.0.4 or previous
					attrString = [[fetchedValue mutableCopy] autorelease];
				}
				else if ( [fetchedValue isKindOfClass:[NSData class]] )
				{
					// Leopard compatibility
					attrString = [NSAttributedString attributedStringWithArchivedData:fetchedValue];
				}
				else
				{
					LOG((@"valueForKey: siteTitleAttributed returned data of unknown class"));
				}
			}
		}
		else if ( nil != [anItem wrappedValueForKey:@"titleAttributed"] )
		{
			id fetchedValue = [anItem wrappedValueForKey:@"titleAttributed"];
			if ( nil != fetchedValue )
			{
				if ( [fetchedValue isKindOfClass:[NSAttributedString class]] )
				{
					// compatibility for sites created under Tiger with 1.0.4 or previous
					attrString = [[fetchedValue mutableCopy] autorelease];
				}
				else if ( [fetchedValue isKindOfClass:[NSData class]] )
				{
					// Leopard compatibility
					attrString = [NSAttributedString attributedStringWithArchivedData:fetchedValue];
				}
				else
				{
					LOG((@"valueForKey: siteTitleAttributed returned data of unknown class"));
				}
			}
			
		}
	}
	else if ( nil != [anItem wrappedValueForKey:@"titleAttributed"] )
	{
		id fetchedValue = [anItem wrappedValueForKey:@"titleAttributed"];
		if ( nil != fetchedValue )
		{
			if ( [fetchedValue isKindOfClass:[NSAttributedString class]] )
			{
				// compatibility for sites created under Tiger with 1.0.4 or previous
				attrString = [[fetchedValue mutableCopy] autorelease];
			}
			else if ( [fetchedValue isKindOfClass:[NSData class]] )
			{
				// Leopard compatibility
				attrString = [NSAttributedString attributedStringWithArchivedData:fetchedValue];
			}
			else
			{
				LOG((@"valueForKey: siteTitleAttributed returned data of unknown class"));
			}
		}
		
	}
	else
	{
		attrString = [NSAttributedString systemFontStringWithString:@"     "];
	}
	
	if (0 == [attrString length])
	{
		attrString = [NSAttributedString systemFontStringWithString:
					  NSLocalizedString(@"(Empty title)",@"Indication in site outline that the page has an empty title. Distinct from untitled, which is for newly created pages.")
					  ];
	}
	
	return attrString;
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
	if (![[tableColumn identifier] isEqualToString:@"displayName"]) {	// Ignore any uninteresting columns
		return;
	}
	
	
	KTPage *page = (KTPage *)item;
	
	// Set the cell's appearance
	if ([cell isKindOfClass:[KTImageTextCell class]])	// Fail gracefully if not the image kind of cell
	{
		// Icon
		NSImage *pageIcon = [self iconForPage:item];
		[cell setImage:pageIcon];
		[cell setMaxImageSize:([[self document] displaySmallPageIcons] ? 16.0 : 32.0)];
		
		// Staleness
		BOOL isPageStale = [item boolForKey:@"isStale"];
		[cell setStaleness:isPageStale ? kStalenessPage : kNotStale];
		
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
	
	
	
	//if ( (item == [context root]) && ![[oSiteOutline selectedItems] containsObject:item] )
	if ( (item == [[self document] root]) && ![[[self siteOutline] selectedItems] containsObject:item] )
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
		
		[[NSColor colorWithCalibratedWhite:0.80 alpha:1.0] set];
		[NSBezierPath fillRect:NSMakeRect(lineX, lineY, width, height)];
		[[NSColor colorWithCalibratedWhite:0.60 alpha:1.0] set];
		[NSBezierPath fillRect:NSMakeRect(lineX, lineY+1, width, height)];
	}
}

- (NSString *)outlineView:(NSOutlineView *)ov toolTipForCell:(NSCell *)cell rect:(NSRectPointer)rect tableColumn:(NSTableColumn *)tc item:(id)item mouseLocation:(NSPoint)mouseLocation
{
	NSAssert([item isKindOfClass:[KTPage class]], @"item is not a page!");
	
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
				NSString *serverPath = [item wrappedValueForKey:@"publishedPath"];
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
	if ( item == [(KTPage *)[self document] root] ) 
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
	NSWindowController *HTMLInspectorController = [[self document] HTMLInspectorController];
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
	
	// Set cellsize to match page size
	NSControlSize controlSize = ([[self document] displaySmallPageIcons]) ? NSSmallControlSize : NSRegularControlSize;
	NSTableColumn *tableColumn = [[[self siteOutline] tableColumns] objectAtIndex:0];
	[[tableColumn dataCell] setControlSize:controlSize];
	
	// Setup is complete, reload outline
	[self reloadSiteOutline];
}

@end

