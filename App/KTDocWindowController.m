//
//  KTDocWindowController.m
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "KT.h"
#import "KTAbstractIndex.h"
#import "SVApplicationController.h"
#import "KTCodeInjectionController.h"
#import "KTElementPlugin+DataSourceRegistration.h"
#import "SVDesignChooserWindowController.h"
#import "SVPagesController.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTHostProperties.h"
#import "SVHTMLTextBlock.h"
#import "KTIndexPlugin.h"
#import "KTInlineImageElement.h"
#import "KTMediaManager+Internal.h"
#import "KTMissingMediaController.h"
#import "KTPage+Internal.h"
#import "SVSidebar.h"
#import "KTSite.h"
#import "SVSiteOutlineViewController.h"
#import "KTSummaryWebViewTextBlock.h"
#import "KTToolbars.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSException+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWindow+Karelia.h"

#import "KSProgressPanel.h"

#import "Debug.h"
#import "Registration.h"


NSString *gInfoWindowAutoSaveName = @"Inspector TopLeft";


@interface KTDocWindowController ()
@end


#pragma mark -


@implementation KTDocWindowController

/*	Designated initializer.
 */
- (id)initWithWindow:(NSWindow *)window;
{
	if (self = [super initWithWindow:window])
    {
        [self setShouldCloseDocument:YES];
    }
        
	return self;
}

- (id)init
{
	if (self = [super initWithWindowNibName:@"KTDocument"])
	{
		// do not cascade window using size in nib
		[self setShouldCascadeWindows:NO];
	}
    
    return self;
}

- (void)dealloc
{
	// Get rid of the site outline controller
	[self setSiteOutlineViewController:nil];
	
	
    // stop observing
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release ivars
	[self setContextElementInformation:nil];
    [self setToolbars:nil];
	[myMasterCodeInjectionController release];
	[myPageCodeInjectionController release];
	[myBuyNowButton release];

    [super dealloc];
}

- (void)windowDidLoad
{	
    [super windowDidLoad];
	
    
    // Finish setting up controllers
	[[self siteOutlineViewController] setRootPage:[[[self document] site] root]];
    [[self siteOutlineViewController] setContent:[self pagesController]];
	
	
	// Now let the webview and the site outline initialize themselves.
	[self linkPanelDidLoad];
	
	
	// Early on, window-related stuff
	NSString *sizeString = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultDocumentWindowContentSize"];
	if ( nil != sizeString )
	{
		NSSize size = NSSizeFromString(sizeString);
		size.height = MAX(size.height, 200.0);
		size.width = MAX(size.width,800.0);
		[[self window] setContentSize:size];
	}
	
	// Toolbar
	[self setToolbars:[NSMutableDictionary dictionary]];
	[self makeDocumentToolbar];
	
	
	// Restore the window's previous frame, if available. Always do this after loading toolbar to make rect consistent
	NSRect contentRect = [[[self document] site] docWindowContentRect];
	if (!NSEqualRects(contentRect, NSZeroRect))
	{
		NSWindow *window = [self window];
		[window setFrame:[window frameRectForContentRect:contentRect] display:YES];
		// -constrainFrameRect:toScreen: will automatically stop the window going offscreen for us.
	}
	
	
	
    // Tie the web content area to the source list's selection
    [[self webContentAreaController] bind:@"selectedPages"
                                 toObject:[self siteOutlineViewController]
                              withKeyPath:@"pagesController.selectedObjects"
                                  options:nil];
	
	// Link Popup in address bar
	//		[[oLinkPopup cell] setUsesItemFromMenu:NO];
	//		[oLinkPopup setIconImage:[NSImage imageNamed:@"links"]];
	//		[oLinkPopup setShowsMenuWhenIconClicked:YES];
	//		[oLinkPopup setArrowImage:nil];	// we have our own arrow, thank you
	
	
	
	// Hide address bar if it's hidden (it's showing to begin with, in the nib)
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateBuyNow:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];
	[self updateBuyNow:nil];	// update them now
	
	
	
	myLastClickedPoint = NSZeroPoint;
	
	//	[[NSNotificationCenter defaultCenter] addObserver:self
	//											 selector:@selector(infoWindowMayNeedRefreshing:)
	//												 name:kKTInfoWindowMayNeedRefreshingNotification
	//											   object:nil];	
	
	// Check for missing media
	[self performSelector:@selector(checkForMissingMedia) withObject:nil afterDelay:0.0];
		
	// LAST: clear the undo stack
	[[self document] performSelector:@selector(processPendingChangesAndClearChangeCount)
						  withObject:nil
						  afterDelay:0.0];
}

#pragma mark Controllers

@synthesize siteOutlineViewController = _siteOutlineViewController;
- (void)setSiteOutlineViewController:(SVSiteOutlineViewController *)controller
{
	// Set up the new controller
	[controller retain];
	[_siteOutlineViewController release];   _siteOutlineViewController = controller;
}

@synthesize webContentAreaController = _webContentAreaController;
- (void)setWebContentAreaController:(SVWebContentAreaController *)controller
{
    [[self webContentAreaController] setDelegate:nil];
    
    [controller retain];
    [_webContentAreaController release],   _webContentAreaController = controller;
    
    [controller setDelegate:self];
}

@synthesize pagesController = _pagesController;
- (void)setPagesController:(NSArrayController *)controller
{
    [controller retain];
    [_pagesController release]; _pagesController = controller;
}

#pragma mark -
#pragma mark Window Title

/*  We append the title of our current content to the default. This gives a similar effect to the titlebar in a web browser.
 */
- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
    SVWebContentAreaController *contentController = [self webContentAreaController];
    if ([contentController selectedViewController] == [contentController webEditorViewController])
    {
        NSString *contentTitle = [[contentController selectedViewController] title];
        if ([contentTitle length] > 0)
        {
            displayName = [displayName stringByAppendingFormat:
                           @" — %@",    // yes, that's an em-dash
                           contentTitle];
        }
	}
    
    return displayName;
}

- (void)webContentAreaControllerDidChangeTitle:(SVWebContentAreaController *)controller;
{
    [self synchronizeWindowTitleWithDocumentName];
}

#pragma mark Inspector

- (id <KSCollectionController>)objectsController;
{
    return [[self webContentAreaController] objectsController];
}

#pragma mark -
#pragma mark Missing Media

- (void)checkForMissingMedia
{
	@try	// Called once the window is on-screen via a delayedPerformSelector. Therefore we have to manage exceptions ourself.
    {
        // Check for missing media files. If any are missing alert the user
        NSSet *missingMedia = [[(KTDocument *)[self document] mediaManager] missingMediaFiles];
        if (missingMedia && [missingMedia count] > 0)
        {
            KTMissingMediaController *missingMediaController =
			[[KTMissingMediaController alloc] initWithWindowNibName:@"MissingMedia"];	// We'll release it after closing the sheet
            
            [missingMediaController setMediaManager:[(KTDocument *)[self document] mediaManager]];
            
            NSArray *sortedMissingMedia = [missingMedia allObjects];    // Not actually performing any sorting
            [missingMediaController setMissingMedia:sortedMissingMedia];
            
            [NSApp beginSheet:[missingMediaController window]
               modalForWindow:[self window]
                modalDelegate:self
               didEndSelector:@selector(missingMediaSheetDidEnd:returnCode:contextInfo:)
                  contextInfo:NULL];
        }
    }
    @catch (NSException *exception)
    {
        [NSApp reportException:exception];
    }
}

- (void)missingMediaSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
{
	[sheet orderOut:self];
	[[sheet windowController] autorelease];
	
	if (returnCode == 0)
	{
		[[self window] performClose:self]; 
	}
}

#pragma mark IBActions

- (IBAction)addPage:(id)sender;
{
    [[[self siteOutlineViewController] content] add:sender];
}

/*  The controller which is the real target of these actions may not be in the responder chain, so take care of passing the message on.
 *  BUT, do I actually want to always pass this on to the web editor? Might there be times when a different controller is desired?
 */
- (void)insertPagelet:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertPagelet:sender];
}
- (void)insertElement:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertElement:sender];
}

- (IBAction)insertSiteTitle:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertSiteTitle:sender];
}
- (IBAction)insertSiteSubtitle:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertSiteSubtitle:sender];
}
- (IBAction)insertPageTitle:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertPageTitle:sender];
}
- (IBAction)insertFooter:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertFooter:sender];
}

- (IBAction)selectWebViewViewType:(id)sender;
{
    [[self webContentAreaController] selectWebViewViewType:sender];
}

- (IBAction)windowHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Link"];		// HELPSTRING
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	BOOL result = [[self webViewController] commitEditing];
    
	if (result)
	{
		BOOL isRawHTML = NO;
		SVHTMLTextBlock *textBlock = [self valueForKeyPath:@"webViewController.currentTextEditingBlock"];
		id sourceObject = [textBlock HTMLSourceObject];
        
        NSString *sourceKeyPath = [textBlock HTMLSourceKeyPath];                   // Account for custom summaries which use
		if ([textBlock isKindOfClass:[KTSummaryWebViewTextBlock class]])    // a special key path
        {
            KTPage *page = sourceObject;
            if ([page customSummaryHTML] || ![page summaryHTMLKeyPath])
            {
                sourceKeyPath = @"customSummaryHTML";
            }
        }
        
        
        // Fallback for non-text blocks
		if (!textBlock)
		{
			isRawHTML = YES;
			sourceKeyPath = @"html";	// raw HTML
			if (nil == sourceObject)	// no appropriate pagelet selected, try page
			{
				sourceObject = [[[self siteOutlineViewController] content] selectedPage];
				if (![@"sandvox.HTMLElement" isEqualToString:[sourceObject valueForKey:@"pluginIdentifier"]])
				{
					sourceObject = nil;		// no, don't try to edit a non-rich text
				}
				else
				{
				}
			}
            
			
		}
		
		if (sourceObject)
		{
            
			[[self document] editSourceObject:sourceObject
                                      keyPath:sourceKeyPath
                                    isRawHTML:isRawHTML];
		}
	}
	else
	{
		NSLog(@"Cannot commit editing to edit HTML");
	}
}

#pragma mark -
#pragma mark Design Chooser

@synthesize designChooserWindowController = _designChooserWindowController;

- (IBAction)chooseDesign:(id)sender
{
    [self showChooseDesignSheet:sender];
}

- (IBAction)showChooseDesignSheet:(id)sender
{
    if ( !_designChooserWindowController )
    {
        _designChooserWindowController = [[SVDesignChooserWindowController alloc] initWithWindowNibName:@"SVDesignChooser"];
        [[self document] addWindowController:_designChooserWindowController];
    }
    
    [_designChooserWindowController displayAsSheet];
}

#pragma mark -
#pragma mark Other

- (IBAction)toggleSmallPageIcons:(id)sender
{
	BOOL value = [[self document] displaySmallPageIcons];
    [[self document] setDisplaySmallPageIcons:!value];
}

#pragma mark Page Actions

/*! adds a new collection to site outline, obtaining the information of a dictionary
from representedObject */

// TODO: Perhaps a lot more of this logic ought to be moved to KTPage+Operations.m


- (IBAction)addCollection:(id)sender
{
	OBASSERTSTRING( [sender respondsToSelector:@selector(representedObject)], @"Sender needs to have a representedObject" );
	
	NSDictionary *presetDict= [sender representedObject];
	NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
	KTIndexPlugin *indexPlugin = identifier ? [KTIndexPlugin pluginWithIdentifier:identifier] : nil;
	
    if ( nil != indexPlugin )
    {		
		NSBundle *indexBundle = [indexPlugin bundle];
		// Figure out page type to construct based on info plist.  Be  a bit forgiving if not found.
		NSString *pageIdentifier = [presetDict objectForKey:@"KTPreferredPageBundleIdentifier"];
		if (nil == pageIdentifier)
		{
			pageIdentifier = [indexBundle objectForInfoDictionaryKey:@"KTPreferredPageBundleIdentifier"];
		}
		KTElementPlugin *pagePlugin = pageIdentifier ? [KTElementPlugin pluginWithIdentifier:pageIdentifier]  : nil;
		if (nil == pagePlugin)
		{
			pageIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultIndexBundleIdentifier"];
			pagePlugin = pageIdentifier ? [KTElementPlugin pluginWithIdentifier:pageIdentifier] : nil;
		}
		if (nil == pagePlugin)
		{
			[NSException raise: NSInternalInconsistencyException
						format: @"Unable to create page of type %@.",
				pageIdentifier];
		}
		
		/// Case 17992, nearestParent method now requires we pass in a context
		KTPage *nearestParent = [self nearestParent:[[self document] managedObjectContext]];
		/// Case 17992, added assert to better detect source of exception
		OBASSERTSTRING((nil != nearestParent), @"nearestParent should not be nil, root at worst");
		
		KTPage *indexPage = [KTPage insertNewPageWithParent:nearestParent plugin:pagePlugin];
		[indexPage setBool:YES forKey:@"isCollection"]; // Duh!
		
		// Now set the index on the page
		[indexPage setWrappedValue:identifier forKey:@"collectionIndexBundleIdentifier"];
		Class indexToAllocate = [indexBundle principalClassIncludingOtherLoadedBundles:YES];
		KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:indexPage plugin:indexPlugin] autorelease];
		[indexPage setIndex:theIndex];
		
		
		// Now re-set title of page to be the appropriate untitled name
		NSString *englishPresetTitle = [presetDict objectForKey:@"KTPresetUntitled"];
		NSString *presetTitle = [indexBundle localizedStringForKey:englishPresetTitle value:englishPresetTitle table:nil];
		
		[indexPage setTitleText:presetTitle];
		
		NSDictionary *pageSettings = [presetDict objectForKey:@"KTPageSettings"];
		[indexPage setValuesForKeysWithDictionary:pageSettings];
		
		[self insertPage:indexPage parent:nearestParent];
		
		
		// Generate a first child page if desired
		NSString *firstChildIdentifier = [presetDict valueForKeyPath:@"KTFirstChildSettings.pluginIdentifier"];
		if (firstChildIdentifier && [firstChildIdentifier isKindOfClass:[NSString class]])
		{
			NSMutableDictionary *firstChildProperties =
				[NSMutableDictionary dictionaryWithDictionary:[presetDict objectForKey:@"KTFirstChildSettings"]];
			[firstChildProperties removeObjectForKey:@"pluginIdentifier"];
			
			KTPage *firstChild = [KTPage insertNewPageWithParent:indexPage
												 plugin:[KTElementPlugin pluginWithIdentifier:firstChildIdentifier]];
			
			NSEnumerator *propertiesEnumerator = [firstChildProperties keyEnumerator];
			NSString *aKey;
			while (aKey = [propertiesEnumerator nextObject])
			{
				id aProperty = [firstChildProperties objectForKey:aKey];
				if ([aProperty isKindOfClass:[NSString class]])
				{
					aProperty = [indexBundle localizedStringForKey:aProperty value:nil table:@"InfoPlist"];
				}
				
				[firstChild setValue:aProperty forKey:aKey];
			}
		}
		
		
		// Any collection with an RSS feed should have an RSS Badge.
		if ([pageSettings boolForKey:@"collectionSyndicate"])
		{
			// Give weblogs special introductory text
			if ([[presetDict objectForKey:@"KTPresetIndexBundleIdentifier"] isEqualToString:@"sandvox.GeneralIndex"])
			{
				NSString *intro = NSLocalizedString(@"<p>This is a new weblog. You can replace this text with an introduction to your blog, or just delete it if you wish. To add an entry to the weblog, add a new page using the \\U201CPages\\U201D button in the toolbar. For more information on blogging with Sandvox, please have a look through our <a href=\"help:Blogging_with_Sandvox\">help guide</a>.</p>",
													"Introductory text for Weblogs");
				
				[indexPage setValue:intro forKey:@"richTextHTML"];
			}
		}
        
        
        // Expand the item in the Site Outline
        [[[self siteOutlineViewController] outlineView] expandItem:indexPage];
    }
    else
    {
		[NSException raise:kKareliaDocumentException reason:@"Unable to instantiate collection"
							userInfo:[NSDictionary dictionaryWithObject:sender forKey:@"sender"]];
    }
}

/*! inserts aPage at the current selection */
- (void)insertPage:(KTPage *)aPage parent:(KTPage *)aCollection
{
	// add component to parent
	[aCollection addPage:aPage];
	
	[[[self siteOutlineViewController] content] setSelectedObjects:[NSArray arrayWithObject:aPage]];
	
	// label undo and perserve the current selection
    if ( [aPage isCollection] )
	{
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Add Collection", "action name for adding a collection")];
    }
    else
	{
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Add Page", "action name for adding a page")];
    }
	
	if (([aPage boolForKey:@"includeInSiteMenu"])) 
	{
		////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on root because included in site menu", NSStringFromSelector(_cmd)));
		//[[aCollection root] markStale:kStaleFamily];
	}
	else
	{
		////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on '%@' because page inserted but not in site menu", NSStringFromSelector(_cmd), [aCollection titleText]));
		//[aCollection markStale:kStaleFamily];
	}
	
}

/*! group the selection in a new summary */
- (void)group:(id)sender
{
	NSArray *selectedPages = [[[[[self siteOutlineViewController] content] selectedObjects] retain] autorelease];	// Hang onto it for length of method
	
	// This shouldn't happen
	if ([selectedPages count] == 0)
	{
		NSBeep();
		NSLog(@"Unable to create group: no selection to group.");
		return;
	}
	
	
	// It is not possible to make a group containing root
	OBASSERTSTRING(![selectedPages containsObject:[[[self document] site] root]], @"Can't create a group containing root");
	
	
	KTPage *firstSelectedPage = [selectedPages objectAtIndex:0];
	
	// our group's parent will be the original parent of firstSelectedPage
	KTPage *parentCollection = [(KTPage *)firstSelectedPage parentPage];
	if ( (nil == parentCollection) || (nil == [[parentCollection site] root]) )
	{
		NSLog(@"Unable to create group: could not determine parent collection.");
		return;
	}
	
	// create a new summary
	KTElementPlugin *collectionPlugin = nil;
	if ( [sender respondsToSelector:@selector(representedObject)] )
	{
		collectionPlugin = [sender representedObject];
	}
	
	if (!collectionPlugin)
	{
		NSString *defaultIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultIndexBundleIdentifier"];
		collectionPlugin = defaultIdentifier ? [KTIndexPlugin pluginWithIdentifier:defaultIdentifier] : nil;
	}
	OBASSERTSTRING(collectionPlugin, @"Must have a new collection plug-in to group the pages into");
	
	
	NSBundle *collectionBundle = [collectionPlugin bundle];
	NSString *pageIdentifier = [collectionBundle objectForInfoDictionaryKey:@"KTPreferredPageBundleIdentifier"];
	KTElementPlugin *pagePlugin = pageIdentifier ? [KTElementPlugin pluginWithIdentifier:pageIdentifier] : nil;
	if ( nil == pagePlugin )
	{
		pageIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultIndexBundleIdentifier"];
		pagePlugin = pageIdentifier ? [KTElementPlugin pluginWithIdentifier:pageIdentifier] : nil;
	}
	if ( nil == pagePlugin )
	{
		NSLog(@"Unable to create group: could not locate default index.");
		return;
	}
	
	///////////////////////////////////////////////////////////////////////////////////////////////////
	// at this point, we should be good to go
	
	// first, remove the selectedPages from their parents
	// the selectedPages array will hold pointers so we don't lose them
	unsigned int i;
	for ( i=0; i < [selectedPages count]; i++ )
	{
		KTPage *page = [selectedPages objectAtIndex:i];
		[[page parentPage] removePage:page];
	}
	
	
	// now, create a new collection to hold selectedPages
	KTPage *collection = [KTPage insertNewPageWithParent:parentCollection 
										 plugin:pagePlugin];
	
	
	[collection setValue:[collectionBundle bundleIdentifier] forKey:@"collectionIndexBundleIdentifier"];
	
// FIXME: we should load up the properties from a KTPreset
	
	Class indexToAllocate = [collectionBundle principalClassIncludingOtherLoadedBundles:YES];
	KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:collection plugin:collectionPlugin] autorelease];
	[collection setIndex:theIndex];
	[collection setInteger:KTCollectionUnsorted forKey:@"collectionSortOrder"];				
	[collection setBool:YES forKey:@"isCollection"];
	[collection setBool:NO forKey:@"includeTimestamp"];
	
	// insert the new collection
	[parentCollection addPage:collection];
	
	// add our selectedPages back to the new collection
	for ( i=0; i < [selectedPages count]; i++ )
	{
		KTPage *page = [selectedPages objectAtIndex:i];
		[collection addPage:page];
	}            
	
	[[[self siteOutlineViewController] content] setSelectedObjects:[NSSet setWithObject:collection]];
	
	// expand the new collection
	[[[self siteOutlineViewController] outlineView] expandItem:collection];
	
	// tidy up the undo stack with a relevant name
	[[[self document] undoManager] setActionName:NSLocalizedString(@"Group", @"action name for grouping selected items")];
}

#pragma mark -
#pragma mark Action Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    //return YES;
    
	OFF((@"KTDocWindowController validateMenuItem:%@ %@", [menuItem title], NSStringFromSelector([menuItem action])));
	SEL itemAction = [menuItem action];
		
	// File menu handled by KTDocument
		
	// Edit menu
	
	// "Paste" paste:
	if ( itemAction == @selector(paste:) )
	{
		{
			NSArray *selectedPages = [[[self siteOutlineViewController] content] selectedObjects];
			if (1 != [selectedPages count])
			{
				return NO;	// can't paste if zero or >1 pages selected
			}
				
			KTPage *selectedPage = [selectedPages objectAtIndex:0];
			if ( [self canPastePages] )
			{
				return [selectedPage isCollection];
			}
			else if ( [self canPastePagelets] )
			{
				return ([[selectedPage showSidebar] boolValue] || [selectedPage includeCallout]);
			}
			else
			{
				return NO;
			}
		}
	}	
	
	// "Paste" pasteAsRichText: NB: also intercepts general "paste" command
	else if ( itemAction == @selector(pasteAsRichText:) )
	{
		// check the general pasteboard to see if there are any pages on it
		NSPasteboard *generalPboard = [NSPasteboard generalPasteboard];
		if ( nil != [generalPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]] )
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	// "Create Link..." showLinkPanel:
	else if (itemAction == @selector(showLinkPanel:))
	{
		return NO;
        
        NSString *title;
		BOOL result = [[self webViewController] validateCreateLinkItem:menuItem title:&title];
		[menuItem setTitle:title];
		return result;
	}
	
	// View menu
    
    else if (itemAction == @selector(selectWebViewViewType:))
    {
        return [[self webContentAreaController] validateMenuItem:menuItem];
    }
	
	// "Use Small Page Icons" toggleSmallPageIcons:
    else if ( itemAction == @selector(toggleSmallPageIcons:) )
	{
		[menuItem setState:
			([[self document] displaySmallPageIcons] ? NSOnState : NSOffState)];
		return YES;	// enabled if we can see the site outline
	}
	
	// Site menu items
    else if (itemAction == @selector(addPage:))
    {
        return YES;
    }
    else if (itemAction == @selector(addPagelet:))
    {
		KTPage *selectedPage = [[[self siteOutlineViewController] content] selectedPage];
		return ([selectedPage sidebarChangeable]);
    }
	else if (itemAction == @selector(addCollection:))
    {
        return YES;
    }	
    else if (itemAction == @selector(exportSiteAgain:))
    {
        NSString *exportPath = [[[self document] site] lastExportDirectoryPath];
        return (exportPath != nil && [exportPath isAbsolutePath]);
    }
    
    // Other
    else if ( itemAction == @selector(group:) )
    {
        return ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] root]] );
    }
    else if ( itemAction == @selector(ungroup:) )
    {
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];
        return ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [[(KTDocument *)[self document] site] root])
				 && ([[selectedItems objectAtIndex:0] isKindOfClass:[KTPage class]]) );
    }
	
	// "Visit Published Site" visitPublishedSite:
	else if ( itemAction == @selector(visitPublishedSite:) ) 
	{
		NSURL *siteURL = [[[[self document] site] hostProperties] siteURL];
		return (nil != siteURL);
	}
	
	// "Visit Published Page" visitPublishedPage:
	else if ( itemAction == @selector(visitPublishedPage:) ) 
	{
		NSURL *pageURL = [[[[self siteOutlineViewController] content] selection] valueForKey:@"URL"];
		BOOL result = (pageURL && !NSIsControllerMarker(pageURL));
        return result;
	}

	else if ( itemAction == @selector(submitSiteToDirectory:) ) 
	{
		NSURL *siteURL = [[[[self document] site] hostProperties] siteURL];
		return (nil != siteURL);
	}
	
	// Window menu
	// "Show Inspector" toggleInfoShown:
	
	// Help menu
	// Debug menu
    // Contextual menu
	else if ( (itemAction == @selector(cutViaContextualMenu:))
			  || (itemAction == @selector(copyViaContextualMenu:))
			  || (itemAction == @selector(deleteViaContextualMenu:))
			  || (itemAction == @selector(duplicateViaContextualMenu:)) )
	{
        id context = [menuItem representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
		
		if ( ![selection containsObject:[[[self document] site] root]] )
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
    else if ( itemAction == @selector(pasteViaContextualMenu:) )
    {
        if ( ![self canPastePages] )
        {
            return NO;
        }
        
        id context = [menuItem representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
        if ( [selection isKindOfClass:[NSArray class]] )
        {
            KTPage *firstPage = [selection objectAtIndex:0];
            if ( [firstPage isCollection] )
            {
                return YES;
            }
            else
            {
                return NO;
            }
        }
        else
        {
            KTPage *page = selection;
            if ( [page isCollection] )
            {
                return YES;
            }
            else
            {
                return NO;
            }
        }
    }

	// DEFAULT: let webKit handle it
	else
	{
		return YES;
	}
    
    return YES;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	if ( [toolbarItem action] == @selector(addPage:) )
    {
        return YES;
    }
    else if ( [toolbarItem action] == @selector(addCollection:) )
    {
        return YES;
    }
    else if ( [toolbarItem action] == @selector(groupAsCollection:) )
    {
        return ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] root]] );
    }
    else if ( [toolbarItem action] == @selector(group:) )
    {
        return ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] root]] );
    }
    else if ( [toolbarItem action] == @selector(ungroup:) )
    {
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];
        return ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [[(KTDocument *)[self document] site] root])
				 && ([[selectedItems objectAtIndex:0] isKindOfClass:[KTPage class]]) );
    }
    // Validate the -publishSiteFromToolbar: item here because -flagsChanged: doesn't catch all edge cases
    else if ([toolbarItem action] == @selector(publishSiteFromToolbar:))
    {
        [toolbarItem setLabel:
         ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) ? TOOLBAR_PUBLISH_ALL : TOOLBAR_PUBLISH];
    }
    
    return YES;
}

#pragma mark Window Delegate

- (void)windowDidResize:(NSNotification *)aNotification
{
    NSWindow *window = [aNotification object];
	
	NSRect windowRect = [[window contentView] frame];
	NSSize windowSize = windowRect.size;
	
    if ( window == [self window] ) {
		[[NSUserDefaults standardUserDefaults] setObject:NSStringFromSize(windowSize)
												  forKey:@"DefaultDocumentWindowContentSize"];
    }
}

- (void)windowWillClose:(NSNotification *)notification;
{
    // Ignore windows not our own
    if ([notification object] != [self window])
    {
        return;
    }
    
    
	[self setSiteOutlineViewController:nil];
}

#pragma mark -
#pragma mark Components

- (BOOL)addPagesViaDragToCollection:(KTPage *)aCollection atIndex:(int)anIndex draggingInfo:(id <NSDraggingInfo>)info
{
	// LOG((@"%@", NSStringFromSelector(_cmd) ));
    
	BOOL result = NO;	// set to YES if at least one item got processed
	int numberOfItems = [KTElementPlugin numberOfItemsToProcessDrag:info];
	
	/*
     /// Mike: I see no point in this artificial limit in 1.5
     int maxNumberDragItems = [defaults integerForKey:@"MaximumDraggedPages"];
     numberOfItems = MIN(numberOfItems, maxNumberDragItems);
     */
	KTPage *latestPage = nil; //only select the last page created
	
	
    //[[[self document] managedObjectContext] lockPSCAndSelf];
    // TODO: it would be nice if we could do the ordering insert just once ahead of time, rather than once per "insertPage:atIndex:"
    
    NSString *localizedStatus = NSLocalizedString(@"Creating pages...", "");
    KSProgressPanel *progressPanel = nil;
    if (numberOfItems > 3)
    {
        progressPanel = [[KSProgressPanel alloc] init];
        [progressPanel setMessageText:localizedStatus];
        [progressPanel setInformativeText:nil];
        [progressPanel setMinValue:0 maxValue:numberOfItems doubleValue:0];
        [progressPanel beginSheetModalForWindow:[self window]];
    }
    
    int i;
    for ( i = 0 ; i < numberOfItems ; i++ )
    {
        NSAutoreleasePool *poolForEachDrag = [[NSAutoreleasePool alloc] init];
        
        [progressPanel setMessageText:localizedStatus];
        [progressPanel setDoubleValue:i];
        
        Class <KTDataSource> bestSource = [KTElementPlugin highestPriorityDataSourceForDrag:info index:i isCreatingPagelet:NO];
        if ( nil != bestSource )
        {
            NSMutableDictionary *dragDataDictionary = [NSMutableDictionary dictionary];
            [dragDataDictionary setValue:[info draggingPasteboard] forKey:kKTDataSourcePasteboard];	// always include this!
            
            BOOL didPerformDrag;
            didPerformDrag = [bestSource populateDataSourceDictionary:dragDataDictionary fromPasteboard:[info draggingPasteboard] atIndex:i forCreatingPagelet:NO];
            NSString *theBundleIdentifier = [[NSBundle bundleForClass:bestSource] bundleIdentifier];
            
            if ( didPerformDrag && theBundleIdentifier)
            {
                KTElementPlugin *thePlugin = [KTElementPlugin pluginWithIdentifier:theBundleIdentifier];
                if (thePlugin)
                {
                    [dragDataDictionary setObject:thePlugin forKey:kKTDataSourcePlugin];
                    
                    KTPage *newPage = [KTPage pageWithParent:aCollection
                                        dataSourceDictionary:dragDataDictionary
                              insertIntoManagedObjectContext:[[self document] managedObjectContext]];
                    
                    if (newPage)
                    {
                        // Insert the page where indicated
                        [aCollection addPage:newPage];
                        if (anIndex != NSOutlineViewDropOnItemIndex && [aCollection collectionSortOrder] == KTCollectionUnsorted)
                        {
                            [newPage moveToIndex:anIndex];
                        }
                        
                        
                        
                        if ( NSOutlineViewDropOnItemIndex != anIndex )
                        {
                            latestPage = newPage;
                        }
                        
                        // we're golden
                        result = YES;
                        
                        // Now see if we need to recurse; it's a collection
                        if ([[dragDataDictionary objectForKey:kKTDataSourceRecurse] boolValue])
                        {
                            NSString *defaultIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultIndexBundleIdentifier"];
                            KTIndexPlugin *indexPlugin = defaultIdentifier ? [KTIndexPlugin pluginWithIdentifier:defaultIdentifier] : nil;
                            NSBundle *indexBundle = [indexPlugin bundle];
                            
                            // FIXME: we should load up the properties from a KTPreset
                            
                            [newPage setValue:[indexBundle bundleIdentifier] forKey:@"collectionIndexBundleIdentifier"];
                            Class indexToAllocate = [indexBundle principalClassIncludingOtherLoadedBundles:YES];
                            KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:newPage plugin:indexPlugin] autorelease];
                            [newPage setIndex:theIndex];
                            [newPage setBool:YES forKey:@"isCollection"]; // should this info be specified in the plist?
                            [newPage setBool:NO forKey:@"includeTimestamp"];		// collection should generally not have timestamp
                            
                            // At this point we should recurse ... deal with indexes, and whether it was photos
                        }
                        
                        // label undo last
                        [[[self document] undoManager] setActionName:NSLocalizedString(@"Drag from External Source",
                                                                                       "action name for dragging external objects to source outline")];
                    }
                    else
                    {
                        LOG((@"error: unable to create item of type: %@", theBundleIdentifier));
                    }
                }
                else
                {
                    LOG((@"error: datasource returned unknown bundle identifier: %@", theBundleIdentifier));
                }
            }
            else
            {
                LOG((@"%@ did not accept drop, no child returned", bestSource));
            }
        }
        else
        {
            LOG((@"No datasource agreed to handle types: %@", [[[info draggingPasteboard] types] description]));
        }
        
        [poolForEachDrag release];
    }
    
    [progressPanel endSheet];
    [progressPanel release];
    
	
	// if not dropping on an item, set the selection to the last page created
	if ( latestPage != nil )
	{
		[[[self siteOutlineViewController] content] setSelectedObjects:[NSSet setWithObject:latestPage]];
	}
	
	// Done
	[KTElementPlugin doneProcessingDrag];
	
	return result;
}

#pragma mark -
#pragma mark Code Injection

- (KTCodeInjectionController *)masterCodeInjectionController
{
	if (!myMasterCodeInjectionController)
	{
		myMasterCodeInjectionController =
			[[KTCodeInjectionController alloc] initWithSiteOutlineController:[[self siteOutlineViewController] content] master:YES];
		
		[[self document] addWindowController:myMasterCodeInjectionController];
	}
	
	return myMasterCodeInjectionController;
}

- (IBAction)showSiteCodeInjection:(id)sender
{
	[[self masterCodeInjectionController] showWindow:sender];
}

- (KTCodeInjectionController *)pageCodeInjectionController
{
	if (!myPageCodeInjectionController)
	{
		myPageCodeInjectionController =
			[[KTCodeInjectionController alloc] initWithSiteOutlineController:[[self siteOutlineViewController] content] master:NO];
		
		[[self document] addWindowController:myPageCodeInjectionController];
	}
	
	return myPageCodeInjectionController;
}

- (IBAction)showPageCodeInjection:(id)sender
{
	[[self pageCodeInjectionController] showWindow:sender];
}

#pragma mark -
#pragma mark Support

- (void) updateBuyNow:(NSNotification *)aNotification
{
	if (nil == gRegistrationString)
	{
		if (!myBuyNowButton)
		{
			NSButton *newButton = [[self window] createBuyNowButton];
			myBuyNowButton = [newButton retain];
			[myBuyNowButton setAction:@selector(showRegistrationWindow:)];
			[myBuyNowButton setTarget:[NSApp delegate]];
		}
		[myBuyNowButton setHidden:NO];
	}
	else
	{
		[myBuyNowButton setHidden:YES];
	}
	
}

- (void)updateWebView:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] setNeedsLoad];
}

@end

