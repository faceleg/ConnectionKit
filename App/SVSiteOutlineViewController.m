//
//  KTSiteOutlineDataSource.m
//  Marvel
//
//  Created by Mike on 25/04/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "SVSiteOutlineViewController.h"

#import "KTDocument.h"
#import "KTSite.h"
#import "KTImageTextCell.h"
#import "SVLink.h"
#import "KTLinkConnector.h"
#import "KTLinkSourceView.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "SVPagesController.h"
#import "SVPageTemplate.h"
#import "KTElementPlugInWrapper.h"

#import "NSManagedObjectContext+KTExtensions.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSSet+KTExtensions.h"

#import "KSLicensedAppDelegate.h"
#import "KSPlugInWrapper.h"
#import "KSProgressPanel.h"

#import "NSArray+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSEvent+Karelia.h"
#import "NSIndexPath+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSSortDescriptor+Karelia.h"
#import "KTPublishingEngine.h"
#import "KTSiteOutlineView.h"

#import "Registration.h"

#import "Debug.h"


#define CAN_CONVERT_TO_COLLECTIONS


@interface SVSiteOutlineViewController ()
+ (NSSet *)mostSiteOutlineRefreshingKeyPaths;

- (void)observeValueForOtherKeyPath:(NSString *)keyPath
							 ofPage:(KTPage *)page
							 change:(NSDictionary *)change
							context:(void *)context;

// Drag & Drop
@property(nonatomic, copy) NSArray *nodesToWriteToPasteboard;   // call with nil to clean out

- (BOOL)moveTreeNodes:(NSArray *)nodes intoCollectionAtIndexPath:(NSIndexPath *)indexPath childIndex:(NSInteger)index;

@end


#pragma mark -


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
        _cachedImagesByRepresentation = [[NSMutableDictionary alloc] init];
        
        // Icon queue
        _queue = [[NSOperationQueue alloc] init];
        [_queue setMaxConcurrentOperationCount:2];  // empirical. Left to its own devices, GCD will often spawn 1 thread per image as the op becomes disk-bound. On most Macs 2 is definitely faster than 1
    }
        
	return self;
}

- (void)dealloc
{
	// Dump view
    [self setOutlineView:nil];
    
    
    [self setContent:nil];  // implementation relies on .rootPage being non-nil, so must do this first
    //[self setRootPage:nil];
    
    // Dump the pages list
    [_nodesToWriteToPasteboard release];
    
	[self resetPageObservation];       // This will also remove home page observation
    OBASSERT([_pages count] == 0);
	[_pages release];
	
    
	[_cachedFavicon release];
	[_cachedPluginIcons release];
	[_cachedImagesByRepresentation release];
    [_queue release];
    
    
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
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:kKSLicenseStatusChangeNotification
                                                  object:nil];
    
	[_outlineView setDataSource:nil];  // don't call [self outlineView] as that may try to load the nib when we don't want it to
	[_outlineView setDelegate:nil];
    [_outlineView setNextResponder:[self nextResponder]];   // reset responder chain
	[self resetPageObservation];
	
	
	// Set up the appearance of the new view
    [outlineView setAutoresizesOutlineColumn:NO];   // used to do this in the nib, but IB seems determined to turn on back on occasionally
    
	NSTableColumn *tableColumn = [outlineView tableColumnWithIdentifier:@"displayName"];
	KTImageTextCell *imageTextCell = [[KTImageTextCell alloc] init];
	[imageTextCell setEditable:YES];
	[imageTextCell setLineBreakMode:NSLineBreakByTruncatingTail];
    [tableColumn setDataCell:imageTextCell];
    [imageTextCell release];
	
	[outlineView setIntercellSpacing:NSMakeSize(3.0, 1.0)];
	
	
	// Drag 'n' drop
    if (outlineView)
    {
        // Register for fairly generic stuff since don't want to block on plug-in loading
        NSArray *dragTypes = NSARRAY((NSString *)kUTTypeItem,
                                     kKTPagesPboardType,
                                     kKTLocalLinkPboardAllowedType);
        [outlineView registerForDraggedTypes:dragTypes];
        
        [outlineView setVerticalMotionCanBeginDrag:YES];
        [outlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
        [outlineView setDraggingSourceOperationMask:NSDragOperationAll_Obsolete forLocal:NO];
    }
	
	if (outlineView != _outlineView && nil != _outlineView)
	{
		[[NSNotificationCenter defaultCenter] removeObserver:self
														name:@"KTDisplaySmallPageIconsDidChange"
													  object:[[[_outlineView window] windowController] document]];
	}
    
    
    // Licensing
    if (outlineView) [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(licenseDidChange:) name:kKSLicenseStatusChangeNotification object:nil];
    
	
	// Finally, hook up outline delegate & data source
	if (outlineView)
	{
		[outlineView setDelegate:self];		// -setDelegate: MUST come first to receive all notifications
		[outlineView setDataSource:self];
		
		// Set up observing, for view size
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(pageIconSizeDidChange:)
													 name:@"KTDisplaySmallPageIconsDidChange"
												   object:[[[outlineView window] windowController] document]];
	}
	
	// Retain the new view
	[outlineView retain];
	[_outlineView release], _outlineView = outlineView;
    
    // Responder Chain
    [outlineView setNextResponder:self insert:YES];
	


}

- (BOOL)isOutlineViewLoaded; { return _outlineView != nil; }

- (void)licenseDidChange:(NSNotification *)notification;
{
    [[self outlineView] setNeedsDisplay:YES];
}

#pragma mark Other Accessors

@synthesize content = _pagesController;
- (void)setContent:(SVPagesTreeController *)controller
{
    if (_pagesController) [[NSNotificationCenter defaultCenter] removeObserver:self name:SVPagesControllerDidInsertObjectNotification object:_pagesController];
    
    // Store
    [controller retain];
    [_pagesController release]; _pagesController = controller;
    //[controller setContent:[self rootPage]];
    
    
    // Observe    
    if (controller) [[NSNotificationCenter defaultCenter] addObserver:self
                                                             selector:@selector(pagesControllerDidInsertObject:)
                                                                 name:SVPagesControllerDidInsertObjectNotification
                                                               object:controller];
    
    
    // Restore selection
    NSArray *selection = [self persistentSelectedObjects];
    if ([selection count] == 0)
    {
        [controller setSelectionIndexPaths:[NSArray arrayWithObject:
                                            [NSIndexPath indexPathWithIndex:0]]];
    }
    else
    {
        [controller setSelectedObjects:selection];
    }
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

- (void)setRootPage:(KTPage *)page
{
    [_rootPage removeObserver:self forKeyPath:@"master.siteTitle.text"];
    [_rootPage removeObserver:self forKeyPath:@"master.favicon"];
    [_rootPage removeObserver:self forKeyPath:@"master.codeInjection.hasCodeInjection"];
    
    [page retain];
    [_rootPage release];
    _rootPage = page;
    
    [_rootPage addObserver:self forKeyPath:@"master.siteTitle.text" options:0 context:NULL];
    [_rootPage addObserver:self forKeyPath:@"master.favicon" options:0 context:NULL];
    [_rootPage addObserver:self forKeyPath:@"master.codeInjection.hasCodeInjection" options:0 context:NULL];
}

- (void)addPages:(NSSet *)pages;
{
    NSMutableSet *newPages = [pages mutableCopy];
    [newPages minusSet:_pages];
    
    if ([newPages count])
    {
        // KVO
        [self willChangeValueForKey:@"pages"
                    withSetMutation:NSKeyValueUnionSetMutation
                       usingObjects:newPages];
        
        
        [_pages unionSet:newPages];
        
        for (SVSiteItem *page in newPages)
        {
            //	Begin observing the page
            [page addObserver:self
                  forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]
                      options:(NSKeyValueObservingOptionNew)
                      context:nil];
            
            
            // Cache the icon ready for display later. Include child pages (but only 1 layer deep)
            [self iconForItem:page isThumbnail:NULL];
            /*NSEnumerator *pagesEnumerator = [[page childItems] objectEnumerator];
             SVSiteItem *aPage;
             while (aPage = [pagesEnumerator nextObject])
             {
             [self iconForItem:aPage isThumbnail:NULL];
             }*/
        }
        
        
        // KVO
        [self didChangeValueForKey:@"pages"
                   withSetMutation:NSKeyValueUnionSetMutation
                      usingObjects:newPages];
    }
    
    [newPages release];
}

- (void)addPagesObject:(KTPage *)page;
{
	if (![_pages containsObject:page])
	{
		// KVO
        NSSet *pages = [NSSet setWithObject:page];
        [self willChangeValueForKey:@"pages"
                    withSetMutation:NSKeyValueUnionSetMutation
                       usingObjects:pages];
        
        
        //	Begin observing the page
		[page addObserver:self
			   forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]
				   options:(NSKeyValueObservingOptionNew)
				   context:nil];
		
		
		// Add to the set
        OBASSERT(page);
		[_pages addObject:page];
		
        
		// Cache the icon ready for display later. Include child pages (but only 1 layer deep)
		[self iconForItem:page isThumbnail:NULL];
		/*NSEnumerator *pagesEnumerator = [[page childItems] objectEnumerator];
		SVSiteItem *aPage;
		while (aPage = [pagesEnumerator nextObject])
		{
			[self iconForItem:aPage isThumbnail:NULL];
		}*/
        
        
        // KVO
        [self didChangeValueForKey:@"pages"
                   withSetMutation:NSKeyValueUnionSetMutation
                      usingObjects:pages];
	}
}

- (void)removePages:(NSSet *)pages
{
	// KVO
    [self willChangeValueForKey:@"pages"
                withSetMutation:NSKeyValueMinusSetMutation
                   usingObjects:pages];
    
    for (SVSiteItem *aPage in pages)
    {
        if ([_pages containsObject:aPage])
        {
            // Remove observers
            [aPage removeObserver:self forKeyPaths:[[self class] mostSiteOutlineRefreshingKeyPaths]];
            
            // Uncache custom icon to free memory
            [_cachedImagesByRepresentation removeObjectForKey:aPage];
            
            // Remove from the set
            [_pages removeObject:aPage];
        }
    }
    
    // KVO
    [self didChangeValueForKey:@"pages"
               withSetMutation:NSKeyValueMinusSetMutation
                  usingObjects:pages];
}

/*	Support method that returns the main keypaths the site outline depends on.
 */
+ (NSSet *)mostSiteOutlineRefreshingKeyPaths
{
	static NSSet *keyPaths;
	
	if (!keyPaths)
	{
		keyPaths = [[NSSet alloc] initWithObjects:
                    @"thumbnailType",
                    @"customThumbnail",
                    @"thumbnailSourceGraphic.imageRepresentation",
					@"isStale",
					@"codeInjection.hasCodeInjection",
					@"isDraft",
					@"index", nil];
	}
	
	return keyPaths;
}

- (void)resetPageObservation
{
    // Cancel any pending icons
    //[_customIconGenerationQueue removeAllObjects];
    
    // We could use -mutableSetValueForKey to do this, but it will crash if used during -dealloc
    [self removePages:[self pages]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    // Ignore objects not in our pages list. If we don't, NSOutlineView can occasionally embark on an endless loop.
    if (![[self pages] containsObject:object])
    {
        return;
    }
    
    
    // Having prescreened the parameters, pass them onto the right support methods for processing
    OBASSERT([object isKindOfClass:[SVSiteItem class]]);
    [self observeValueForOtherKeyPath:keyPath ofPage:object change:change context:context];
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
		[_cachedImagesByRepresentation removeObjectForKey:page];
	}
	
	
	// Does the change also affect children?
	BOOL childrenNeedDisplay = ([keyPath isEqualToString:@"isDraft"]);
	
	
    [[self outlineView] setItemNeedsDisplay:page childrenNeedDisplay:childrenNeedDisplay];
}

#pragma mark Adding a Page

- (void)addSiteItem:(id)sender;
{
    // Calls -add: or -addChild: on the controller as appropriate to selection
    NSTreeNode *selection = [[self content] selectedNode];
    if ([[self outlineView] isItemExpanded:selection])
    {
        [[self content] addChild:self];
    }
    else
    {
        [[self content] add:self];
    }
}

- (IBAction)addPage:(id)sender;             // your basic page
{
    SVPageTemplate *template = [sender representedObject];
    
    [[self content] setEntityNameWithPageTemplate:template];
    [self addSiteItem:sender];
}

- (IBAction)addCollection:(id)sender;       // a collection. Uses [sender representedObject] for preset info
{
    [self addPage:sender];
}

- (IBAction)addExternalLinkPage:(id)sender; // external link
{
    [[self content] setEntityTypeWithURL:nil external:YES];
    [self addSiteItem:sender];
}

- (IBAction)addRawTextPage:(id)sender;      // Raw HTML page
{
    [[self content] setEntityTypeWithURL:nil external:NO];
    [self addSiteItem:sender];
}

- (IBAction)addFilePage:(id)sender;         // uses open panel to select a file, then inserts
{
    // Throw up an open panel
    NSWindow *window = [[self view] window];
    NSOpenPanel *openPanel = [[[window windowController] document] makeChooseDialog];
    
    [openPanel beginSheetForDirectory:nil
                                 file:nil
                       modalForWindow:window
                        modalDelegate:self
                       didEndSelector:@selector(chooseFilePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)chooseFilePanelDidEnd:(NSSavePanel *)sheet
                   returnCode:(int)returnCode
                  contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    [[self content] setEntityTypeWithURL:[sheet URL] external:NO];
    [self addSiteItem:self];
}

- (KTPage *)collectionForPagesControllerToInsertInto:(SVPagesController *)sender;
{
    // Want to insert inside of collections only if they're expanded
    KTPage *result = [[sender selectedObjects] lastObject];
    
    if (!([result isCollection] && [[self outlineView] isItemExpanded:result]) &&
        [result parentPage])
    {
        result = [result parentPage];
    }
    
    return result;
}

- (void)pagesControllerDidInsertObject:(NSNotification *)notification;
{
    SVPagesTreeController *controller = [notification object];
    NSTreeNode *node = [controller selectedNode];  // Really, I ought to have a way of pulling this from the notification
    
    if (node) [[self outlineView] expandItem:node];
}

#pragma mark Other Actions

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
        NSOutlineView *outline = [self outlineView];
        NSPasteboard *pboard = [NSPasteboard generalPasteboard];
        
        [self outlineView:outline writeItems:[outline selectedItems] toPasteboard:pboard];
    }
    else
    {
        // There shouldn't be another responder up the chain that handles this so it will beep. But you never know, somebody else might like to handle it.
        [self makeNextResponderDoCommandBySelector:_cmd];
    }
}

- (void)paste:(id)sender;
{
    // Only paste if there's pages on the pboard. Otherwise send up to window controller
    NSPasteboard *pboard = [NSPasteboard generalPasteboard];
    if ([[pboard types] containsObject:kKTPagesPboardType])
    {
        // Create a page for the content
        SVPagesTreeController *controller = [self content];
        [controller addObjectsFromPasteboard:pboard];
    }
    else
    {
        if (![[self nextResponder] tryToPerform:_cmd with:sender]) NSBeep();
    }
}

- (IBAction)rename:(id)sender;
{
    if ([self canRename])
    {
        [[[self view] window] makeFirstResponder:[self outlineView]];
        
        [[self outlineView] editColumn:0
                                   row:[[self outlineView] selectedRow]
                             withEvent:nil
                                select:YES];
    }
}

- (IBAction)duplicate:(id)sender;
{
    NSArray *items = [[self content] selectedObjects];
    NSMutableArray *newItems = [[NSMutableArray alloc] initWithCapacity:[items count]];
    
    for (SVSiteItem *anItem in items)
    {
        // Serialize
        id plist = [anItem serializedProperties];
        
        
        // Where's it going to be placed?
        KTPage *parent = [anItem parentPage];
        OBASSERT(parent);
        
        
        // Create copy
        SVSiteItem *duplicate = [[NSManagedObject alloc] initWithEntity:[anItem entity]
                                         insertIntoManagedObjectContext:[anItem managedObjectContext]];
        
        [newItems addObject:duplicate];
        [duplicate awakeFromPropertyList:plist parentItem:parent];
        [duplicate release];
    }
    
    
    // Insert new items
    [[self content] addObjects:newItems];
    [newItems release];
}

- (BOOL)canCopy
{
    BOOL result = ([[[self content] selectedObjects] count] > 0);
    return result;
}

- (BOOL)canRename;
{
    // Can only edit if there is a single item selected, and its not root
    NSIndexSet *selection = [[self outlineView] selectedRowIndexes];
    BOOL result = ([selection count] == 1 && ![selection containsIndex:0]);
    return result;
}

#pragma mark Deleting Pages

- (void)warnBeforeDeletingPage:(KTPage *)page;
{
    NSAlert *alert = [[NSAlert alloc] init];
    
    
    // Main text
    [alert setMessageText:[NSString stringWithFormat:
                           NSLocalizedString(@"Are you sure you want to delete “%@”?", "alert title"),
                           [page title]]];
    
    [alert setInformativeText:
     NSLocalizedString(@"It has already been published at:",
                       "alert subtitle")];
    
    
    // Accessory View
    NSString *currentLink = [[page URL] absoluteString];
    [oDeletePublishedPageURLLink setUrlString:currentLink];
    [oDeletePublishedPageURLLink setTitle:currentLink];
    
    [oNewPageURLLabel setStringValue:[[page URL] absoluteString]];
    
    [alert setAccessoryView:oDeletePublishedPageAlertAccessoryView];
    
    
    // Buttons
    [alert addButtonWithTitle:NSLocalizedString(@"Delete", "button title")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "button title")];
    
    
    // Present
    [alert beginSheetModalForWindow:[[self view] window]
                      modalDelegate:self
                     didEndSelector:@selector(deletePublishedPageAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:NULL];
    
    [alert release];
}

- (void)deletePublishedPageAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)context;
{
    if (returnCode == NSAlertFirstButtonReturn) [[self content] remove:self];
}

- (void)delete:(id)sender
{
    /// Old code did a -processPendingChanges here but haven't a clue why. Mike.
    
    
    if ([self canDelete])
    {
        SVPagesTreeController *controller = [self content];
        if ([controller canRemove])
        {
            NSSet *selection = [[[NSSet alloc] initWithArray:[[self content] selectedObjects]] autorelease];
            
            // Warn before deleting a published page
            if ([selection count] == 1)
            {
                KTPage *page = [selection anyObject];
                if ([page datePublished])
                {
                    [self warnBeforeDeletingPage:page];
                    return;
                }
            }
            
            [controller remove:sender];
        }
        
        // Remove the pages from their parents
        //NSSet *parentPages = [selection valueForKey:@"parentPage"];
        //for (KTPage *aParentPage in parentPages)
        //{
        //    [aParentPage removePages:selection];	// Far more efficient than calling -removePage: repetitively
        //}
    }
    else
    {
        // There shouldn't be another responder up the chain that handles this so it will beep. But you never know, somebody else might like to handle it.
        [self makeNextResponderDoCommandBySelector:_cmd];
    }
}

// Can only delete a page if there's a selection and that selection doesn't include the root page
- (BOOL)canDelete
{
    SVPagesTreeController *controller = [self content];
    
    BOOL result = ([controller canRemove] &&
                   ![[controller selectionIndexPaths] containsObject:[NSIndexPath indexPathWithIndex:0]]);
    
    return result;
}

#pragma mark Page Behaviour Actions

- (void)setIsCollection:(BOOL)makeCollection;
{
    [[self content] setValue:NSBOOL(makeCollection) forKeyPath:@"selection.isCollection"];
}

- (IBAction)toggleIsCollection:(id)sender;
{
    [self toggleIsCollectionWithDelegate:nil didToggleSelector:NULL];
}

- (void)setToCollection:(BOOL)makeCollection withDelegate:(id)delegate didToggleSelector:(SEL)selector;
{
	// Quick sanity check
    if (![self canToggleIsCollection])
    {
        NSBeep();
        return;
    }
	
	BOOL isAlreadyCorrect = ([[self content] selectedItemsAreCollections] == NSOnState && makeCollection)
	|| ([[self content] selectedItemsAreCollections] == NSOffState && !makeCollection);
	if (!isAlreadyCorrect)
	{
		// Prepare callback invocation
		NSInvocation *callback = nil;
		if (delegate)
		{
			callback = [NSInvocation invocationWithSelector:selector target:delegate];
			[callback setArgument:&self atIndex:2];
		}
		
		
		// Warn before changing this on a published page
		if ([[self content] selectedItemsHaveBeenPublished])
		{
			NSArray *selection = [[self content] selectedObjects];
			OBASSERT([selection count] == 1);
			
			NSAlert *alert = [[NSAlert alloc] init];
			
			
			// Main text
			KTPage *page = [selection lastObject];
			if (makeCollection)
			{
				[alert setMessageText:[NSString stringWithFormat:
									   NSLocalizedString(@"Are you sure you want to publish the page “%@” as a collection?", "alert title"),
									   [page title]]];
			}
			else
			{
				[alert setMessageText:[NSString stringWithFormat:
									   NSLocalizedString(@"Are you sure you want to stop publishing the page “%@” as a collection?", "alert title"),
									   [page title]]];
			}
			
			[alert setInformativeText:
			 NSLocalizedString(@"This will break any bookmarks to the page your visitors might have saved.",
							   "alert subtitle")];
			
			
			// Accessory View
			NSString *currentLink = [[page URL] absoluteString];
			[oCurrentPageURLLink setUrlString:currentLink];
			[oCurrentPageURLLink setTitle:currentLink];
			
			[oNewPageURLLabel setStringValue:[[page URLAsCollection:makeCollection] absoluteString]];
			
			[alert setAccessoryView:oToggleIsCollectionAlertAccessoryView];
			
			
			// Buttons
			[alert addButtonWithTitle:NSLocalizedString(@"Change", "button title")];
			[alert addButtonWithTitle:NSLocalizedString(@"Cancel", "button title")];
			
			
			// Present
			[alert beginSheetModalForWindow:[[self view] window]
							  modalDelegate:self
							 didEndSelector:@selector(toggleIsCollectionAlertDidEnd:returnCode:contextInfo:)
								contextInfo:[callback retain]];
			
			[alert release];
		}
		else
		{
			[self setIsCollection:makeCollection];
			
			// Send callback
			BOOL result = YES;
			[callback setArgument:&result atIndex:3];
			[callback invoke];
		}
	}
}

- (void)toggleIsCollectionWithDelegate:(id)delegate didToggleSelector:(SEL)selector;
{
    // Quick sanity check
    if (![self canToggleIsCollection])
    {
        NSBeep();
        return;
    }
    
    BOOL makeCollection = [[self content] selectedItemsAreCollections] != NSOnState;
    [self setToCollection:makeCollection withDelegate:delegate didToggleSelector:selector];
}

- (BOOL)canToggleIsCollection;
{
    BOOL result = NO;
    
    if ([[[self content] selectedObjects] count] == 1)
    {
        // Can't enable control if collection already has children…
        NSNumber *haveChildren = [[self content] valueForKeyPath:@"selection.hasChildren"];
        if (!NSIsControllerMarker(haveChildren) && ![haveChildren boolValue])
        {
            // …or is home page
            NSNumber *containsHome = [[self content] valueForKeyPath:@"selection.isRoot"];
            if (!NSIsControllerMarker(containsHome) && ![containsHome boolValue]) result = YES;
        }
    }
    
    return result;
}

- (void)toggleIsCollectionAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
{
    NSInvocation *callback = contextInfo;
    
    BOOL result = (returnCode == NSAlertFirstButtonReturn);
    if (result)
    {
        BOOL makeCollection = [[self content] selectedItemsAreCollections] != NSOnState;
        [self setIsCollection:makeCollection];
    }
    
    [callback setArgument:&result atIndex:3];
    [callback invoke];
    [callback release];
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

- (id)outlineView:(NSOutlineView *)outlineView parentOfItem:(id)item
{
	id result = nil;
	if ([item isKindOfClass:[KTPage class]])
	{
		result = [item parentPage];
	}
	
	return result;
}

#pragma mark Delegate

- (void)outlineView:(NSOutlineView *)outlineView
    willDisplayCell:(KTImageTextCell *)cell
     forTableColumn:(NSTableColumn *)tableColumn
               item:(NSTreeNode *)node
{
    SVSiteItem *item = [node representedObject];
    
	// Ignore any uninteresting columns/rows
	if (!item || ![[tableColumn identifier] isEqualToString:@"displayName"]) {
		return;
	}
		
	// Set the cell's appearance
    NSInteger rowIndex = [outlineView rowForItem:node];
    BOOL isRoot = rowIndex == 0;
    
    if ([cell isKindOfClass:[KTImageTextCell class]])	// Fail gracefully if not the image kind of cell
	{
		// Size
		NSControlSize controlSize = ([self displaySmallPageIcons]) ? NSSmallControlSize : NSRegularControlSize;
		[cell setControlSize:controlSize];
	
		// Icon
        BOOL thumbnail = NO;
		NSImage *pageIcon = [self iconForItem:item isThumbnail:&thumbnail];
		[cell setImage:pageIcon];
        [cell setIsImageThumbnail:thumbnail];
		[cell setMaxImageSize:([self displaySmallPageIcons] ? 16.0 : 32.0)];
		
		// Staleness    /// 1.5 is now ignoring this key and using digest-based staleness
		//BOOL isPageStale = [item boolForKey:@"isStale"];
		//[cell setStaleness:isPageStale ? kStalenessPage : kNotStale];
		
		// Draft
		BOOL isDraft = [item isDraftOrHasDraftAncestor];
		[cell setDraft:isDraft];
		

		
		// Disable drawing of the non-publishable stripes when we are in a drag.
		BOOL inDraggedRows = [[(KTSiteOutlineView *)outlineView draggedRows] containsIndex:rowIndex];
		
        
		BOOL isPublishable = (nil != gRegistrationString) || [item isPagePublishableInDemo] || inDraggedRows;
		[cell setPublishable:isPublishable];
		// always show as publishable if we are registered.  ALSO show publishable (no markings) if in a drag.
		
		// Code Injection
        [cell setHasCodeInjection:[[item codeInjection] hasCodeInjection]];
		if (isRoot && ![cell hasCodeInjection])
		{
			[cell setHasCodeInjection:[[[item master] codeInjection] hasCodeInjection]];
		}
	}
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item
{
    // Root can't be collapsed
    BOOL result = ([outlineView rowForItem:item] > 0);
    return result;
}

/*	If the current selection is about to be collapsed away, select the parent.
 */
- (void)outlineViewItemWillCollapse:(NSNotification *)notification
{
	KTPage *collapsingPage = [[notification userInfo] objectForKey:@"NSObject"];
	BOOL shouldSelectCollapsingItem = YES;
	NSEnumerator *selectionEnumerator = [[[self content] selectedObjects] objectEnumerator];
	SVSiteItem *anItem;
	
	while (anItem = [selectionEnumerator nextObject])
	{
		if (![anItem isDescendantOfCollection:collapsingPage])
		{
			shouldSelectCollapsingItem = NO;
			break;
		}
	}
	
	if (shouldSelectCollapsingItem)
	{
		[[self outlineView] selectItem:collapsingPage];
	}
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(NSTreeNode *)item
{
    float result = [outlineView rowHeight];
    
	if ([outlineView rowForItem:item] == 0)
	{
		result += ([self displaySmallPageIcons] ? SMALL_ICON_ROOT_SPACING : LARGE_ICON_ROOT_SPACING);
	}
    
    return result;
}

#pragma mark Drag

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)isLocal
{
    if (isLocal) 
	{
        return NSDragOperationGeneric;
    }
	
    return NSDragOperationCopy;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)nodes toPasteboard:(NSPasteboard *)pboard
{
    // Takes care of sorting the nodes and resetting _numberOfNodesWrittenToPasteboard.
	[self setNodesToWriteToPasteboard:nodes];
    nodes = [self nodesToWriteToPasteboard];
    
    NSMutableArray *serializedPages = [[NSMutableArray alloc] init];
    
    // Serialize top-level pages, as determined by _numberOfNodesWrittenToPasteboard
    while (_indexOfNextNodeToWriteToPasteboard < [nodes count])
    {
        NSTreeNode *aNode = [nodes objectAtIndex:_indexOfNextNodeToWriteToPasteboard];
        _indexOfNextNodeToWriteToPasteboard++;
        
        NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
        [[aNode representedObject] populateSerializedProperties:plist delegate:self];
        [serializedPages addObject:plist];
        [plist release];
    }
    
    [pboard declareTypes:[NSArray arrayWithObject:kKTPagesPboardType] owner:nil];
    [pboard setPropertyList:serializedPages forType:kKTPagesPboardType];
    
    [serializedPages release];
    return YES;
}

- (id)serializeChildrenOfPage:(KTPage *)page;
{
    NSTreeNode *node = [[self content] nodeForObject:page];
    OBASSERT(node);
    
    if ([[self outlineView] isItemExpanded:node])
    {
        NSArray *nodes = [self nodesToWriteToPasteboard];
        if (_indexOfNextNodeToWriteToPasteboard >= [nodes count]) return nil;    // done all the writing already
        
        
        // Serialize chosen children
        NSMutableArray *result = [NSMutableArray array];
        NSTreeNode *aNode = [nodes objectAtIndex:_indexOfNextNodeToWriteToPasteboard];
        
        while ([aNode ks_isDescendantOfNode:node])
        {
            _indexOfNextNodeToWriteToPasteboard++;
            
            NSMutableDictionary *plist = [[NSMutableDictionary alloc] init];
            [[aNode representedObject] populateSerializedProperties:plist delegate:self];
            [result addObject:plist];
            [plist release];
            
            if (_indexOfNextNodeToWriteToPasteboard >= [nodes count]) break;    // done all the writing already
            aNode = [nodes objectAtIndex:_indexOfNextNodeToWriteToPasteboard];
        }
        
        return result;
    }
    else
    {
        // Collapsed items should serialize all descendants
        return [[page sortedChildren] valueForKey:@"serializedProperties"];
    }
}

@synthesize nodesToWriteToPasteboard = _nodesToWriteToPasteboard;
- (void)setNodesToWriteToPasteboard:(NSArray *)nodes;
{
    // Sort the nodes by index path so we write them in correct order
    nodes = [nodes sortedArrayUsingDescriptors:[NSSortDescriptor sortDescriptorArrayWithKey:@"indexPath"
                                                                                  ascending:YES]];
    
    [_nodesToWriteToPasteboard release]; _nodesToWriteToPasteboard = [nodes copy];
    _indexOfNextNodeToWriteToPasteboard = 0;
}

#pragma mark Validating a Drop

// THE RULES:
//  (1.  The drop item can only be a collection) – ditching partly for 2.0
//  2.  You can only drop at a specific index if the collection is manually sorted
//  3.  You can't drop above the root page
//  4.  When moving an existing page, can't drop it as a descendant of itself
//  5.  No point moving a page to a destination that is actually the same as source



- (NSDragOperation)validateNonLinkDrop:(id <NSDraggingInfo>)info
                      proposedTreeNode:(NSTreeNode *)node
                    proposedChildIndex:(NSInteger)index;
{
    //  Rather like the Outline View datasource method, but has already taken into account the layout of root
    
    
    KTPage *page = [node representedObject];
    
    
    OBPRECONDITION(node);
#ifndef CAN_CONVERT_TO_COLLECTIONS
    OBPRECONDITION([page isCollection]);
#endif
    
    
    // Rule 2.
    if (index != NSOutlineViewDropOnItemIndex &&
        [[page collectionSortOrder] integerValue] != SVCollectionSortManually)
    {
        index = NSOutlineViewDropOnItemIndex;
        [[self outlineView] setDropItem:node dropChildIndex:index];
    }
    
    
    
    // Is the aim to move a page within the Site Outline?
    if ([info draggingSource] == [self outlineView] &&
        [info draggingSourceOperationMask] & NSDragOperationGeneric)
    {
        // Don't allow drops onto a published non-collection, as they're unsuitable for conversion. #98962
        if (![page isCollection] && [page datePublished]) return NSDragOperationNone;
        
        
        NSArray *draggedItems = [self nodesToWriteToPasteboard];
        
        // Rule 4. Don't allow an item to become a descendant of itself
        for (NSTreeNode *aDraggedItem in draggedItems)
        {
            if ([node ks_isDescendantOfNode:aDraggedItem])
            {
                return NSDragOperationNone;
            }
        }
        
        
        NSTreeNode *draggedItem = [draggedItems objectAtIndex:0];
        if ([draggedItem parentNode] == node)
        {
            // Rule 5. No point dropping an item *onto* its parent
            if (index == NSOutlineViewDropOnItemIndex)
            {
                return NSDragOperationNone;
            }
            else
            {
                // Rule 5. No point dropping just before or after the dragged item
                NSUInteger draggedIndex = [[draggedItem indexPath] lastIndex];
                if (index == draggedIndex || index == draggedIndex+1)
                {
                    return NSDragOperationNone;
                }
            }
        }
        
        
        return NSDragOperationGeneric;
    }
    
    
    // Outside files can only be dropped into collections
    if ([page isCollection])
    {
        // Pretend we're going to do the preferred operation
        if ([info draggingSourceOperationMask] & NSDragOperationCopy) return NSDragOperationCopy;
        if ([info draggingSourceOperationMask] & NSDragOperationGeneric) return NSDragOperationGeneric;
    }
    return NSDragOperationNone;
}

- (NSDragOperation)validateLinkDrop:(NSString *)pboardString onProposedItem:(NSTreeNode *)node;
{
    // If our input string is a collection, then return NO if it's not a collection.
    if ([pboardString isEqualToString:@"KTCollection"] && ![[node representedObject] isCollection])
    {
        return NSDragOperationNone;
    }
    //set up a pulsating window
    if (node)
    {
        NSInteger row = [[self outlineView] rowForItem:node];
        NSRect rowRect = [[self outlineView] rectOfRow:row];
        //covert the origin to window coords
        rowRect.origin = [[[self view] window] convertBaseToScreen:[[self outlineView] convertPoint:rowRect.origin toView:nil]];
        rowRect.origin.y -= NSHeight(rowRect); //handle it because it is flipped.
        if (!NSEqualSizes(rowRect.size, NSZeroSize))
        {
        }
        else
        {
        }
        
        return NSDragOperationLink;
    }
    else
    {
        return NSDragOperationNone;
    }
}

- (NSDragOperation)outlineView:(NSOutlineView *)outlineView
				  validateDrop:(id <NSDraggingInfo>)info
				  proposedItem:(NSTreeNode *)node
			proposedChildIndex:(NSInteger)anIndex
{
    // There's 2 basic types of drop: creating a link, and everything else. Links are special because they create nothing. Instead it's a feedback mechanism to the source view
    
    SVSiteItem *siteItem = [node representedObject];
    
    NSPasteboard *pboard = [info draggingPasteboard];
    if ([[pboard types] containsObject:kKTLocalLinkPboardAllowedType])
	{
        if (siteItem && anIndex == NSOutlineViewDropOnItemIndex)
        {
            NSString *pboardString = [pboard stringForType:kKTLocalLinkPboardAllowedType];
            return [self validateLinkDrop:pboardString onProposedItem:node];
        }
        else
        {
            return NSDragOperationNone;
        }
    }
    
	
    
    // Correct for the root page. i.e. a drop with a nil item is actually a drop onto/in the root page, and the index needs to be bumped slightly
    NSInteger index = anIndex;
    if (!node)
    {
        if (anIndex == 0) return NSDragOperationNone;   // rule 3.
        
        node = [[[[self content] arrangedObjects] childNodes] objectAtIndex:0];
        siteItem = [node representedObject];
        
        if (index != NSOutlineViewDropOnItemIndex) 
        {
            index--;    // we've already weeded out the case of index being 0
        }
        
        [[self outlineView] setDropItem:node dropChildIndex:index];
    }
    OBASSERT(siteItem);
    
    
    // Rule 1. Only a collection can be dropped on/into.
#ifndef CAN_CONVERT_TO_COLLECTIONS
    if ([siteItem isCollection])
#else
    if ([siteItem pageRepresentation])
#endif
    {
        return [self validateNonLinkDrop:info
                      proposedTreeNode:node
                      proposedChildIndex:index];
    }
    
    
    return NSDragOperationNone;
}

#pragma mark Accepting a Drop

- (BOOL)acceptNonLinkDrop:(id <NSDraggingInfo>)info
                     node:(NSTreeNode *)node
               childIndex:(NSInteger)index;
{
    KTPage *collection = [node representedObject];
    OBPRECONDITION(collection);
    OBPRECONDITION([collection isCollection]);
    
    
    // Is the aim to move a page within the Site Outline?
    if ([info draggingSource] == [self outlineView] &&
        [info draggingSourceOperationMask] & NSDragOperationMove)
    {
        NSArray *draggedItems = [self nodesToWriteToPasteboard];
        return [self moveTreeNodes:draggedItems intoCollectionAtIndexPath:[node indexPath] childIndex:index];
    }
    else
    {
        // Create a page for the content
        if (index < 0) index = [[node childNodes] count];
        NSIndexPath *path = [[node indexPath] indexPathByAddingIndex:index];
        
        return [[self content] insertObjectsFromPasteboard:[info draggingPasteboard]
                                    atArrangedObjectIndexPath:path];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView
         acceptDrop:(id <NSDraggingInfo>)info
               item:(NSTreeNode *)node
         childIndex:(NSInteger)anIndex;
{
	// Remember, links are special
    NSPasteboard *pboard = [info draggingPasteboard];
	if ([[pboard types] containsObject:kKTLocalLinkPboardAllowedType])
	{
        KTLinkConnector *linkConnector = [info draggingSource];
        
        SVLink *link = [[SVLink alloc] initWithPage:[node representedObject] openInNewWindow:NO];
        [linkConnector setLink:link];
        [link release];
        
        return YES;
    }
    
    
    // Correct for the root page. i.e. a drop with a nil item is actually a drop onto/in the root page, and the index needs to be bumped slightly
    NSInteger index = anIndex;
    if (!node)
    {
        if (anIndex == 0) return NO;   // rule 3.
        
        node = [[[[self content] arrangedObjects] childNodes] objectAtIndex:0];
        if (index != NSOutlineViewDropOnItemIndex)
        {
            index--;    // we've already weeded out the case of index being 0
        }
    }
    
    
    // Rule 1. Only a collection can be dropped on/into.
    KTPage *page = [node representedObject];
    OBASSERT(page);
    
#ifdef CAN_CONVERT_TO_COLLECTIONS
    [page setIsCollection:YES];
#else
    if ([page isCollection])
#endif
    {
        return [self acceptNonLinkDrop:info
                                  node:node
                            childIndex:index];
    }
    
    
    return NO;
}


/*	Called when rearranging pages within the Site Outline
 */
- (BOOL)moveTreeNodes:(NSArray *)nodes intoCollectionAtIndexPath:(NSIndexPath *)indexPath childIndex:(NSInteger)index;
{	
	OBPRECONDITION(indexPath);
    //OBPRECONDITION([collection isCollection]);
    
	
    NSMutableArray *expansion = [[NSMutableArray alloc] initWithCapacity:[nodes count]];
    for (NSTreeNode *aNode in nodes)
    {
        BOOL expanded = [[self outlineView] isItemExpanded:aNode];
        [expansion addObject:NSBOOL(expanded)];
    }
    
    
    // Insert each item in turn. By running in reverse we can keep reusing the same index
    SVPagesTreeController *controller = [self content];
    
    [controller moveNodes:nodes
              toIndexPath:[indexPath indexPathByAddingIndex:index]];
	
    
    // Restore expansion state. #95795
    NSUInteger i, count = [nodes count];
    for (i = 0; i < count; i++)
    {
        SVSiteItem *anItem = [nodes objectAtIndex:i];
        BOOL expanded = [[expansion objectAtIndex:i] boolValue];
        if (expanded) [[self outlineView] expandItem:anItem];
    }
    
    [expansion release];
	return YES;
}

/*
- (BOOL)acceptArchivedPagesDrop:(NSArray *)archivedPages ontoPage:(KTPage *)page childIndex:(int)anIndex
{
	BOOL result = NO;
	
	
	// Should we display a progress indicator?
	int i = 0;
	NSString *localizedStatus = NSLocalizedString(@"Copying…", "");
	BOOL displayProgressIndicator = NO;
	if ([archivedPages count] > 3)
	{
		displayProgressIndicator = YES;
	}
	else
	{
		for ( NSDictionary *pageInfo in archivedPages)
		{
			if ([pageInfo boolForKey:@"isCollection"]) 
			{
				displayProgressIndicator = YES;
				break;
			}
		}
	}
	
    KSProgressPanel *progressPanel = nil;
	if (displayProgressIndicator)
	{
		progressPanel = [[KSProgressPanel alloc] init];
        [progressPanel setMessageText:localizedStatus];
        [progressPanel setInformativeText:nil];
        [progressPanel setMinValue:1 maxValue:[archivedPages count] doubleValue:1];
        
        [progressPanel beginSheetModalForWindow:[[self view] window]];
	}
	
	
	// Add the pages
	i = 1;			
	
	NSMutableArray *droppedPages = [NSMutableArray array];
	NSDictionary *rep;
	for (rep in archivedPages)
	{
		if (progressPanel)
		{
			localizedStatus = NSLocalizedString(@"Copying pages…", "");
			[progressPanel setMessageText:localizedStatus];
            [progressPanel setDoubleValue:i];
			i++;
		}
		
		KTPage *aDroppedPage = [KTPage pageWithPasteboardRepresentation:rep parent:page];
		if (aDroppedPage)
		{
			result = YES;
		}
		else
		{
			break;
		}
		[droppedPages addObject:aDroppedPage];
		
		// Whinge if the page couldn't be created
		OBASSERTSTRING(page, @"unable to create Page");
	}
	
	[[[[self rootPage] managedObjectContext] undoManager] setActionName:NSLocalizedString(@"Drag",
                                                                                          @"action name for dragging source objects within the outline")];
	
	[progressPanel endSheet];
    [progressPanel release];
	
	
	// Select the dropped pages
	[[self content] setSelectedObjects:droppedPages];
	
	
	return result;
}*/

#pragma mark NSUserInterfaceValidations

- (BOOL)validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
    BOOL result = YES;
    SEL action = [anItem action];
    
    if (action == @selector(cut:))
    {
        result = ([self canDelete] && [self canCopy]);
    }
    else if (action == @selector(copy:))
    {
        result = [self canCopy];
    }
    else if (action == @selector(rename:))
    {
        result = [self canRename];
    }
    else if (action == @selector(delete:))
    {
        result = [self canDelete];
    }
    
    else if (action == @selector(toggleIsCollection:))
    {
        // Set state to match
        id control = anItem;
        NSString *title = [[self content] convertToCollectionControlTitle];
        [control setTitle:title];
        
        result = [self canToggleIsCollection];
    }
    
    
    return result;
}

#pragma mark Options

- (void)pageIconSizeDidChange:(NSNotification *)notification
{
	BOOL smallIcons = [[[notification userInfo] objectForKey:@"displaySmallPageIcons"] boolValue];
	self.displaySmallPageIcons = smallIcons;
}

@synthesize displaySmallPageIcons = _useSmallIconSize;
- (void)setDisplaySmallPageIcons:(BOOL)smallIcons
{
	_useSmallIconSize = smallIcons;

	[self invalidateIconCaches];	// If the icon size changes this lot are no longer valid
	
	// Setup is complete, reload outline
    if ([self isOutlineViewLoaded])
    {
        [[self outlineView] setRowHeight:(smallIcons ? SMALL_ICON_CELL_HEIGHT : LARGE_ICON_CELL_HEIGHT)];
        [_outlineView reloadData];
    }
}



#pragma mark Persistence

- (NSArray *)persistentSelectedObjects;
{
	
    NSManagedObjectContext *context = [[self content] managedObjectContext];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"isSelectedInSiteOutline != 0"];
    
    NSArray *result = [context fetchAllObjectsForEntityForName:@"SiteItem"
                                           predicate:predicate
                                               error:NULL];
    
    return result;
}

- (NSArray *)persistentExpandedObjects;
{
    NSManagedObjectContext *context = [[self content] managedObjectContext];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"collectionIsExpandedInSiteOutline != 0"];
    
    NSArray *result = [context fetchAllObjectsForEntityForName:@"Page"
													 predicate:predicate
														 error:NULL];
    
    return result;
}

- (void)restoreExpandedItems;
{
    SVPagesTreeController *controller = [self content];
    NSArray *objects = [self persistentExpandedObjects];
    
    for (SVSiteItem *aPage in objects)
    {
        NSIndexPath *path = [controller indexPathOfObject:aPage];
        NSTreeNode *node = [[controller arrangedObjects] descendantNodeAtIndexPath:path];
        [[self outlineView] expandItem:node];
    }
}

- (NSArray *)expandedObjects;
{
	NSMutableArray *result = [NSMutableArray array];
	NSOutlineView *ov = self.outlineView;
	
	int rows = [ov numberOfRows];
	for (int row = 0 ; row < rows ; row++)
	{
		NSTreeNode *item = [ov itemAtRow:row];
		BOOL expanded = [ov isItemExpanded:item];
		if (expanded)
		{
			[result addObject:[item representedObject]];
		}
	}
	return [NSArray arrayWithArray:result];
}

- (void)persistUIProperties;
{
	
	NSView *subview = [[oSplitView subviews] firstObjectKS];
	int width = (int) [subview frame].size.width;
	[[[[[[self view] window] windowController] document] site] setValue:[NSNumber numberWithInt:width] forKey:@"sourceOutlineSize"];
	
    // Remove old selection
    NSArray *oldSelection = [self persistentSelectedObjects];
    [oldSelection makeObjectsPerformSelector:@selector(setIsSelectedInSiteOutline:)
                                  withObject:[NSNumber numberWithBool:NO]];
    
    NSArray *selection = [[self content] selectedObjects];
    [selection makeObjectsPerformSelector:@selector(setIsSelectedInSiteOutline:)
                               withObject:[NSNumber numberWithBool:YES]];

    // Similarly for expanded collections
    oldSelection = [self persistentExpandedObjects];
    [oldSelection makeObjectsPerformSelector:@selector(setCollectionIsExpandedInSiteOutline:)
                                  withObject:[NSNumber numberWithBool:NO]];
    
    selection = [self expandedObjects];
	
    [selection makeObjectsPerformSelector:@selector(setCollectionIsExpandedInSiteOutline:)
                               withObject:[NSNumber numberWithBool:YES]];

}
	 
// called by KTDocWindowController windowDidLoad
- (void)loadPersistentProperties;
{	
	int newWidth = [[[[[[self view] window] windowController] document] site] integerForKey:@"sourceOutlineSize"];
	if (newWidth < 20)
	{
		newWidth = 200;	// reasonable default, in case it's stored badly or -1 uninitialized.
	}
	NSView *viewToResize = [[oSplitView subviews] firstObjectKS];
	NSRect resizeFrame = [viewToResize frame];
	
	NSView *otherView = [[oSplitView subviews] lastObject];
	NSRect otherFrame = [otherView frame];
	
	// Make sure that neither subview goes below 50 pixels wide, just in case
	newWidth = MAX(newWidth, 50);
	newWidth = MIN(newWidth, (resizeFrame.size.width + otherFrame.size.width - 50));
	
	int delta = newWidth - resizeFrame.size.width;	// We need to adjust both widths appropriately
	
	resizeFrame.size.width += delta;
	[viewToResize setFrame:resizeFrame];
	
	otherFrame.size.width -= delta;
	[otherView setFrame:otherFrame];
	
	[oSplitView adjustSubviews];
    
	NSArray *selectedItems = [self persistentSelectedObjects];
	
    // Restore expanded items. make sure homepage is expanded
	[self restoreExpandedItems];
    [self.outlineView expandItem:[self.outlineView itemAtRow:0]];
    
    
    // Restore selected items
	NSMutableIndexSet *toSelect = [NSMutableIndexSet indexSet];
	for (id item in selectedItems)
	{
		NSInteger row = [self.outlineView rowForItem:item];
		if (row >= 0) [toSelect addIndex:row];
	}
    if ([toSelect count])
    {
        [self.outlineView selectRowIndexes:toSelect byExtendingSelection:NO];
    }
}

@end


#pragma mark -


@implementation SVSiteItem (SVSiteOutline)

@dynamic isSelectedInSiteOutline;
@dynamic collectionIsExpandedInSiteOutline;

@end

