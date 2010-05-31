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
#import "SVArticle.h"
#import "KTCodeInjectionController.h"
#import "SVDesignChooserWindowController.h"
#import "SVPagesController.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "KTHostProperties.h"
#import "SVHTMLTextBlock.h"
#import "KTIndexPlugInWrapper.h"
#import "KTMissingMediaController.h"
#import "KTPage+Internal.h"
#import "SVSidebar.h"
#import "KTSite.h"
#import "SVSiteOutlineViewController.h"
#import "KTSummaryWebViewTextBlock.h"
#import "SVTextAttachment.h"
#import "KTToolbars.h"
#import "KSSilencingConfirmSheet.h"
#import "SVValidatorWindowController.h"
#import "KSNetworkNotifier.h"

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
@property(nonatomic, retain, readwrite) SVWebContentAreaController *webContentAreaController;
@end


#pragma mark -


@implementation KTDocWindowController

+ (void)initialize;
{
    [self exposeBinding:@"contentTitle"];
}

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
	// Get rid of view controllers
	[self setSiteOutlineViewController:nil];
	[self setWebContentAreaController:nil];
	
    // stop observing
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release ivars
    [self setToolbars:nil];
    
    [_contentTitle release];
	[myMasterCodeInjectionController release];
	[myPageCodeInjectionController release];
	[myBuyNowButton release];

    [super dealloc];
}

- (void)windowDidLoad
{	
    [super windowDidLoad];
	
    
    // Finish setting up controllers
	[[self siteOutlineViewController] setRootPage:[[[self document] site] rootPage]];
    [[self siteOutlineViewController] setContent:[self pagesController]];

	// Ready to do this now that the above has been set
	[[self siteOutlineViewController] loadPersistentProperties];

	
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
    [self unbind:@"contentTitle"];
    
    [controller retain];
    [_webContentAreaController release],   _webContentAreaController = controller;
    
    [controller setDelegate:self];
    return; // FIXME: disabled because it retains window controller indefinitely
    [self bind:@"contentTitle"
      toObject:controller
   withKeyPath:@"selectedViewController.title"
       options:nil];
}

@synthesize pagesController = _pagesController;

#pragma mark Window Title

/*  We append the title of our current content to the default. This gives a similar effect to the titlebar in a web browser.
 */
- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
    SVWebContentAreaController *contentController = [self webContentAreaController];
    
    NSString *contentTitle = [[contentController selectedViewController] title];
    if ([contentTitle length] > 0)
    {
        displayName = [displayName stringByAppendingFormat:
                       @" — %@",    // yes, that's an em-dash
                       contentTitle];
	}
    
    return displayName;
}

@synthesize contentTitle = _contentTitle;
- (void)setContentTitle:(NSString *)title
{
    title = [title copy];
    [_contentTitle release]; _contentTitle = title;
    
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
    return;
    
	@try	// Called once the window is on-screen via a delayedPerformSelector. Therefore we have to manage exceptions ourself.
    {
        // Check for missing media files. If any are missing alert the user
        NSSet *missingMedia = [[self document] missingMedia];
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

/*  The controller which is the real target of these actions may not be in the responder chain, so take care of passing the message on.
 *  BUT, do I actually want to always pass this on to the web editor? Might there be times when a different controller is desired?
 */
- (void)insertPagelet:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertPagelet:sender];
}
- (IBAction)insertFile:(id)sender;
{
    NSViewController *controller = [[self webContentAreaController] selectedViewController];
    [controller doCommandBySelector:_cmd];
}

- (void)insertPageletTitle:(id)sender;
{
    [[[self webContentAreaController] webEditorViewController] insertPageletTitle:sender];
}

#pragma mark WebView Actions

- (void)makeTextLarger:(id)sender;
{
    id controller = [[self webContentAreaController] selectedViewControllerWhenReady];
    if ([controller respondsToSelector:_cmd]);
    {
        [controller makeTextLarger:sender];
    }
}

- (void)makeTextSmaller:(id)sender;
{
    id controller = [[self webContentAreaController] selectedViewControllerWhenReady];
    if ([controller respondsToSelector:_cmd]);
    {
        [controller makeTextSmaller:sender];
    }
}

- (void)makeTextStandardSize:(id)sender;
{
    id controller = [[self webContentAreaController] selectedViewControllerWhenReady];
    if ([controller respondsToSelector:_cmd]);
    {
        [controller makeTextStandardSize:sender];
    }
}

- (IBAction)selectWebViewViewType:(id)sender;
{
    [[self webContentAreaController] selectWebViewViewType:sender];
}

#pragma mark -

- (IBAction)windowHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Link"];		// HELPSTRING
}

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
	}
    
    KTDesign *design = [[self pagesController] valueForKeyPath:@"selection.master.design"];
    if (NSIsControllerMarker(design)) design = nil;
    [_designChooserWindowController setDesign:design];
    
    [_designChooserWindowController beginSheetModalForWindow:[self window]
                                                    delegate:self
                                              didEndSelector:@selector(designChooserDidEnd:)];
}

- (void)designChooserDidEnd:(SVDesignChooserWindowController *)designChooser
{
    KTDesign *aDesign = [designChooser design];
    
	DJW((@"%s %p",__FUNCTION__, aDesign));
	[[self pagesController] setValue:aDesign forKeyPath:@"selection.master.design"];
    
    
    // Update in-design media
    [[self document] designDidChange];
    
    
    // Let all graphics know of the change.
    NSArray *graphics = [[[self pagesController] managedObjectContext]
                         fetchAllObjectsForEntityForName:@"Graphic" error:NULL];
    for (SVGraphic *aGraphic in graphics)
    {
        for (SVSidebar *aSidebar in [aGraphic sidebars])
        {
            KTPage *page = [aSidebar page];
            if (page) [aGraphic didAddToPage:page];
        }
        
        SVRichText *text = [[aGraphic textAttachment] body];
        if ([text isKindOfClass:[SVArticle class]])
        {
            KTPage *page = [(SVArticle *)text page];
            if (page) [aGraphic didAddToPage:page];
        }
    }
}

#pragma mark Other

- (IBAction)toggleSmallPageIcons:(id)sender
{
	BOOL value = [[self document] displaySmallPageIcons];
    [[self document] setDisplaySmallPageIcons:!value];
}

#pragma mark Page Actions

- (IBAction)addPage:(id)sender;             // your basic page
{
    [[self pagesController] setEntityName:@"Page"];
    [[self pagesController] setCollectionPreset:nil];
    [[self pagesController] add:self];
}

- (IBAction)addCollection:(id)sender;       // a collection. Uses [sender representedObject] for preset info
{
    [[self pagesController] setEntityName:@"Page"];
    [[self pagesController] setCollectionPreset:[sender representedObject]];
    [[self pagesController] add:self];
}

- (IBAction)addExternalLinkPage:(id)sender; // external link
{
    [[self pagesController] setEntityName:@"ExternalLink"];
    [[self pagesController] add:self];
}

- (IBAction)addRawTextPage:(id)sender;      // Raw HTML page
{
    [[self pagesController] setEntityName:@"File"];
    [[self pagesController] setFileURL:nil];    // will make its own file
    [[self pagesController] add:self];
}

- (IBAction)addFilePage:(id)sender;         // uses open panel to select a file, then inserts
{
    // Throw up an open panel
    NSOpenPanel *openPanel = [[self document] makeChooseDialog];
    
    [openPanel beginSheetForDirectory:nil
                                 file:nil
                       modalForWindow:[self window]
                        modalDelegate:self
                       didEndSelector:@selector(chooseFilePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
}

- (void)chooseFilePanelDidEnd:(NSSavePanel *)sheet
                   returnCode:(int)returnCode
                  contextInfo:(void *)contextInfo;
{
    if (returnCode == NSCancelButton) return;
    
    
    [[self pagesController] setEntityName:@"File"];
    [[self pagesController] setFileURL:[sheet URL]];
    [[self pagesController] add:self];
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
	OBASSERTSTRING(![selectedPages containsObject:[[[self document] site] rootPage]], @"Can't create a group containing root");
	
	
	KTPage *firstSelectedPage = [selectedPages objectAtIndex:0];
	
	// our group's parent will be the original parent of firstSelectedPage
	KTPage *parentCollection = [(KTPage *)firstSelectedPage parentPage];
	if ( (nil == parentCollection) || (nil == [[parentCollection site] rootPage]) )
	{
		NSLog(@"Unable to create group: could not determine parent collection.");
		return;
	}
	
	// create a new summary
	KTElementPlugInWrapper *collectionPlugin = nil;
	if ( [sender respondsToSelector:@selector(representedObject)] )
	{
		collectionPlugin = [sender representedObject];
	}
	
	if (!collectionPlugin)
	{
		NSString *defaultIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultIndexBundleIdentifier"];
		collectionPlugin = defaultIdentifier ? [KTIndexPlugInWrapper pluginWithIdentifier:defaultIdentifier] : nil;
	}
	OBASSERTSTRING(collectionPlugin, @"Must have a new collection plug-in to group the pages into");
	
	
	NSBundle *collectionBundle = [collectionPlugin bundle];
	NSString *pageIdentifier = [collectionBundle objectForInfoDictionaryKey:@"KTPreferredPageBundleIdentifier"];
	KTElementPlugInWrapper *pagePlugin = pageIdentifier ? [KTElementPlugInWrapper pluginWithIdentifier:pageIdentifier] : nil;
	if ( nil == pagePlugin )
	{
		pageIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultIndexBundleIdentifier"];
		pagePlugin = pageIdentifier ? [KTElementPlugInWrapper pluginWithIdentifier:pageIdentifier] : nil;
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
		[[page parentPage] removeChildItem:page];
	}
	
	
	// now, create a new collection to hold selectedPages
	KTPage *collection = [KTPage insertNewPageWithParent:parentCollection 
										 plugin:pagePlugin];
	
	
	[collection setValue:[collectionBundle bundleIdentifier] forKey:@"collectionIndexBundleIdentifier"];
	
// FIXME: we should load up the properties from a KTPreset
	
	Class indexToAllocate = [collectionBundle principalClassIncludingOtherLoadedBundles:YES];
	KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:collection plugin:collectionPlugin] autorelease];
	[collection setIndex:theIndex];
	[collection setInteger:SVCollectionSortManually forKey:@"collectionSortOrder"];				
	[collection setBool:YES forKey:@"isCollection"];
	[collection setBool:NO forKey:@"includeTimestamp"];
	
	// insert the new collection
	[parentCollection addChildItem:collection];
	
	// add our selectedPages back to the new collection
	for ( i=0; i < [selectedPages count]; i++ )
	{
		KTPage *page = [selectedPages objectAtIndex:i];
		[collection addChildItem:page];
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
    OFF((@"KTDocWindowController validateMenuItem:%@ %@", [menuItem title], NSStringFromSelector([menuItem action])));
    
    BOOL result = YES;
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
	
	// Insert menu
    if (itemAction == @selector(insertSiteTitle:) ||
        itemAction == @selector(insertSiteSubtitle:) ||
        itemAction == @selector(insertPageTitle:) ||
        itemAction == @selector(insertPageletTitle:) ||
        itemAction == @selector(insertFooter:))
    {
        return [[[self webContentAreaController] webEditorViewController] validateMenuItem:menuItem];
    }
    
	
	// View menu
    
    else if (itemAction == @selector(makeTextLarger:) ||
             itemAction == @selector(makeTextSmaller:) ||
             itemAction == @selector(makeTextStandardSize:))
    {
        result = NO;
        
        id controller = [[self webContentAreaController] selectedViewControllerWhenReady];
        if ([controller respondsToSelector:itemAction])
        {
            result = [controller validateMenuItem:menuItem];
        }
    }
    else if (itemAction == @selector(selectWebViewViewType:))
    {
        return [[self webContentAreaController] validateMenuItem:menuItem];
    }
	else if (itemAction == @selector(validateSource:))
	{
		id selection = [[[self siteOutlineViewController] content] selectedObjects];
		return ( [KSNetworkNotifier isNetworkAvailable]
				&& !NSIsControllerMarker(selection)
				&& 1 == [selection count]
				&& nil != [[selection lastObject] pageRepresentation] );
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
    else if (itemAction == @selector(addCollection:))
    {
        return YES;
    }	
    else if (itemAction == @selector(exportSiteAgain:))
    {
        NSString *exportPath = [[[self document] lastExportDirectory] path];
        return (exportPath != nil && [exportPath isAbsolutePath]);
    }
    
    // Other
    else if ( itemAction == @selector(group:) )
    {
        return ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] rootPage]] );
    }
    else if ( itemAction == @selector(ungroup:) )
    {
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];
        return ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [[(KTDocument *)[self document] site] rootPage])
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
		
		if ( ![selection containsObject:[[[self document] site] rootPage]] )
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
    
    return result;
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
        return ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] rootPage]] );
    }
    else if ( [toolbarItem action] == @selector(group:) )
    {
        return ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] rootPage]] );
    }
    else if ( [toolbarItem action] == @selector(ungroup:) )
    {
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];
        return ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [[(KTDocument *)[self document] site] rootPage])
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
	int numberOfItems = [KTElementPlugInWrapper numberOfItemsInPasteboard:[info draggingPasteboard]];
	
	/*
     /// Mike: I see no point in this artificial limit in 1.5
     int maxNumberDragItems = [defaults integerForKey:@"MaximumDraggedPages"];
     numberOfItems = MIN(numberOfItems, maxNumberDragItems);
     */
	KTPage *latestPage = nil; //only select the last page created
	
	    
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
        
        Class bestSource = [KTElementPlugInWrapper highestPriorityDataSourceForPasteboard:[info draggingPasteboard] index:i isCreatingPagelet:NO];
        if ( nil != bestSource )
        {
            NSMutableDictionary *dragDataDictionary = [NSMutableDictionary dictionary];
            [dragDataDictionary setValue:[info draggingPasteboard] forKey:kKTDataSourcePasteboard];	// always include this!
            
            BOOL didPerformDrag;
            didPerformDrag = [bestSource populateDataSourceDictionary:dragDataDictionary fromPasteboard:[info draggingPasteboard] atIndex:i forCreatingPagelet:NO];
            NSString *theBundleIdentifier = [[NSBundle bundleForClass:bestSource] bundleIdentifier];
            
            if ( didPerformDrag && theBundleIdentifier)
            {
                KTElementPlugInWrapper *thePlugin = [KTElementPlugInWrapper pluginWithIdentifier:theBundleIdentifier];
                if (thePlugin)
                {
                    [dragDataDictionary setObject:thePlugin forKey:kKTDataSourcePlugin];
                    
                    KTPage *newPage = [KTPage pageWithParent:aCollection
                                        dataSourceDictionary:dragDataDictionary
                              insertIntoManagedObjectContext:[[self document] managedObjectContext]];
                    
                    if (newPage)
                    {
                        // Insert the page where indicated
                        [aCollection addChildItem:newPage];
                        if (anIndex != NSOutlineViewDropOnItemIndex && [aCollection collectionSortOrder] == SVCollectionSortManually)
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
                            KTIndexPlugInWrapper *indexPlugin = defaultIdentifier ? [KTIndexPlugInWrapper pluginWithIdentifier:defaultIdentifier] : nil;
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
	[KTElementPlugInWrapper doneProcessingDrag];
	
	return result;
}

#pragma mark -
#pragma mark Code Injection

- (KTCodeInjectionController *)masterCodeInjectionController
{
	if (!myMasterCodeInjectionController)
	{
		myMasterCodeInjectionController =
			[[KTCodeInjectionController alloc] initWithPagesController:[[self siteOutlineViewController] content] master:YES];
		
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
			[[KTCodeInjectionController alloc] initWithPagesController:[[self siteOutlineViewController] content] master:NO];
		
		[[self document] addWindowController:myPageCodeInjectionController];
	}
	
	return myPageCodeInjectionController;
}

- (IBAction)showPageCodeInjection:(id)sender
{
	[[self pageCodeInjectionController] showWindow:sender];
}

#pragma mark Persistence

- (void)persistUIProperties
{
    [super persistUIProperties];
    
    // Window size
	NSWindow *window = [self window];
	if (window)
	{
		[[[self document] site] setDocWindowContentRect:[window contentRectForFrameRect:[window frame]]];
	}
	[[[self document] site] setLastExportDirectoryPath:[[[self document] lastExportDirectory] path]];
    
    // Ask Site Outline View Controller to do the same - this will save the split view width
    [[self siteOutlineViewController] persistUIProperties];
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

- (void)reload:(id)sender;
{
    NSResponder *controller = [[self webContentAreaController] selectedViewControllerWhenReady];
    [controller doCommandBySelector:_cmd];
}

#pragma mark HTML Validation

- (IBAction)validateSource:(id)sender
{
	id selection = [[[self siteOutlineViewController] content] selectedObjects];
	KTPage *page = nil;
	if ( !NSIsControllerMarker(selection) && 1 == [selection count] && nil != (page = [[selection lastObject] pageRepresentation]) )
	{
		NSString *pageSource = [page markupString];
		NSString *docTypeName = [page docTypeName];
		NSString *charset = [[page master] valueForKey:@"charset"];
		[[SVValidatorWindowController sharedController] validateSource:pageSource charset:charset docTypeString:docTypeName windowForSheet:[self window]];	// it will do loading, displaying, etc.
	}
}

@end

