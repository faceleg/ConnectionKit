//
//  KTDocWindowController.m
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005-2011 Karelia Software. All rights reserved.
//

#import "KTDocWindowController.h"

#import "KT.h"
#import "SVApplicationController.h"
#import "SVArticle.h"
#import "KTCodeInjectionController.h"
#import "SVDesignChooserWindowController.h"
#import "SVPagesController.h"
#import "KTDocument.h"
#import "KTElementPlugInWrapper.h"
#import "KTHostProperties.h"
#import "SVHTMLTextBlock.h"
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
#import "SVRawHTMLGraphic.h"
#import "NSMenuItem+Karelia.h"
#import "SVCommentsWindowController.h"
#import "SVGoogleWindowController.h"
#import "SVDesignsController.h"
#import "KTDesign.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSException+Karelia.h"
#import "NSSet+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSResponder+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWindow+Karelia.h"
#import "NSToolbar+Karelia.h"

#import "KSProgressPanel.h"

#import "Debug.h"
#import "Registration.h"
#import "MAAttachedWindow.h"

NSString *gInfoWindowAutoSaveName = @"Inspector TopLeft";


@interface KTDocWindowController ()
@property(nonatomic, retain, readwrite) SVWebContentAreaController *webContentAreaController;
- (void)changeDesignTo:(KTDesign *)aDesign;
@end


#pragma mark -


@implementation KTDocWindowController

@synthesize rawHTMLMenuItem = _rawHTMLMenuItem;
@synthesize HTMLTextPageMenuItem = _HTMLTextPageMenuItem;

+ (void)initialize;
{
    [self exposeBinding:@"contentTitle"];
}

- (id)init
{
	return [self initWithWindowNibName:@"KTDocument"];
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

- (void)dealloc
{
	// Get rid of view controllers
	[self setSiteOutlineViewController:nil];
	[self setWebContentAreaController:nil];
	[self setDesignChooserWindowController:nil];
	self.rawHTMLMenuItem = nil;
	self.HTMLTextPageMenuItem = nil;
    self.HTMLEditorController = nil;
    
    // Tear down model controller. #101246
    [[self pagesController] unbind:NSContentSetBinding];
    [[self pagesController] setContent:nil];
    [self setPagesController:nil];
    
    // stop observing
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release ivars
    [myToolbars release];
    
    [_contentTitle release];
	[myMasterCodeInjectionController release];
	[myPageCodeInjectionController release];

    [super dealloc];
}

- (void)windowDidLoad
{	
    [super windowDidLoad];
	
    
    // Finish setting up controllers
    [self siteOutlineViewController].displaySmallPageIcons = [[self document] displaySmallPageIcons];
	//[[self siteOutlineViewController] setRootPage:[[[self document] site] rootPage]];
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
	myToolbars = [[NSMutableDictionary alloc] init];
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
		
	
	
	// Hide address bar if it's hidden (it's showing to begin with, in the nib)
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateDocWindowLicenseStatus:)
												 name:kKSLicenseStatusChangeNotification
											   object:nil];
	[self updateDocWindowLicenseStatus:nil];	// update them now
	
	
	
	myLastClickedPoint = NSZeroPoint;
	
	
    // Give focus to article
    [[[self webContentAreaController] webEditorViewController] setArticleShouldBecomeFocusedAfterNextLoad:YES];
	
    
	// Check for missing media
	//[self performSelector:@selector(checkForMissingMedia) withObject:nil afterDelay:0.0];
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
}

@synthesize pagesController = _pagesController;
- (void) setPagesController:(SVPagesTreeController *)controller;
{
    if (_pagesController)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:SVPagesControllerDidInsertObjectNotification object:_pagesController];
    }
    
    [controller retain];
    [_pagesController release]; _pagesController = controller;
    
    if (controller)
    {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pagesControllerDidInsertObject:) name:SVPagesControllerDidInsertObjectNotification object:controller];
    }
}

@synthesize commentsWindowController = _commentsWindowController;
@synthesize googleWindowController = _googleWindowController;

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

#pragma mark Missing Media

/*
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
            
            //[missingMediaController setMediaManager:[(KTDocument *)[self document] mediaManager]];
            
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
*/

#pragma mark IBActions

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;
{
	[[[self webContentAreaController] selectedViewControllerWhenReady] ks_doCommandBySelector:_cmd with:sender];
}

/*  The controller which is the real target of these actions may not be in the responder chain, so take care of passing the message on.
 *  BUT, do I actually want to always pass this on to the web editor? Might there be times when a different controller is desired?
 */
- (void)insertPagelet:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady]
     ks_doCommandBySelector:_cmd with:sender];
}

- (IBAction)insertFile:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (void)insertPageletTitle:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

#pragma mark WebView Actions

- (void)makeTextLarger:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (void)makeTextSmaller:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (void)makeTextStandardSize:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
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

- (SVDesignChooserWindowController *)designChooserWindowController
{
	if ( !_designChooserWindowController )
    {
        _designChooserWindowController = [[SVDesignChooserWindowController alloc] init];
		[_designChooserWindowController window];  // make sure nib is loaded

	}
	return _designChooserWindowController;
}

- (IBAction)chooseDesign:(id)sender
{
    [self showChooseDesignSheet:sender];
}

- (IBAction)nextDesign:(id)sender;
{
	SVDesignsController *designsController = [[[SVDesignsController alloc] init] autorelease];
	NSArray *arrangedObjects = [designsController arrangedObjects];
	
    KTDesign *design = [[self pagesController] valueForKeyPath:@"selection.master.design"];
	KTDesign *matchingDesign = [designsController designWithIdentifier:[design identifier]];

	NSUInteger index = [arrangedObjects indexOfObject:matchingDesign];
	if (NSNotFound == index || !arrangedObjects)
	{
		NSBeep();
	}
	else
	{
		index++;
		if (index >= [arrangedObjects count])
		{
			index = 0;	// overflow -- loop back to the beginning
		}
		KTDesign *newDesign = [arrangedObjects objectAtIndex:index];
		[self changeDesignTo:newDesign];
	}
}

- (IBAction)previousDesign:(id)sender;
{
	SVDesignsController *designsController = [[[SVDesignsController alloc] init] autorelease];
	NSArray *arrangedObjects = [designsController arrangedObjects];
	
    KTDesign *design = [[self pagesController] valueForKeyPath:@"selection.master.design"];
	KTDesign *matchingDesign = [designsController designWithIdentifier:[design identifier]];

	NSUInteger index = [arrangedObjects indexOfObject:matchingDesign];
	if (NSNotFound == index || !arrangedObjects)
	{
		NSBeep();
	}
	else
	{
		if (index > 0)
		{
			index--;
		}
		else	// loop to end
		{
			index = [arrangedObjects count] - 1;
		}
		KTDesign *newDesign = [arrangedObjects objectAtIndex:index];
		[self changeDesignTo:newDesign];
	}
}


- (IBAction)showChooseDesignSheet:(id)sender
{
    
    KTDesign *design = [[self pagesController] valueForKeyPath:@"selection.master.design"];
    if (NSIsControllerMarker(design)) design = nil;
    
    [self.designChooserWindowController setDesign:design];
    
    
    [self performSelector:@selector(showDesignSheet) withObject:nil afterDelay:0.0];
}

- (void)showDesignSheet;
{
    // Private support method that only handles getting the sheet onscreen
    [self.designChooserWindowController beginDesignChooserForWindow:[self window]
													   delegate:self
                                                     didEndSelector:@selector(designChooserDidEnd:returnCode:)];
}

- (void) hideDesignIdentityWindow
{
	[[NSAnimationContext currentContext] setDuration:1.0f];
	[_designIdentityWindow.animator setAlphaValue:0.0];	// animate closed
	
}
- (void) showDesignIdentityWindow:(KTDesign *)aDesign;
{
	if (!_designIdentityWindow)
	{
		NSUInteger kDesignIDWindowHeight = kDesignThumbHeight + 100;
		const NSUInteger kDesignIDWindowWidth = 350;
		const NSUInteger kDesignIDThumbY = 70;
		
		NSView *contentView = [[[NSView alloc] initWithFrame:NSMakeRect(0,0,kDesignIDWindowWidth, kDesignIDWindowHeight)] autorelease];
		_designIdentityThumbnail = [[[NSImageView alloc] initWithFrame:
									 NSMakeRect((kDesignIDWindowWidth- kDesignThumbWidth)/2.0,kDesignIDThumbY,
												kDesignThumbWidth, kDesignThumbHeight)] autorelease];
		[_designIdentityThumbnail setImageScaling:NSImageScaleProportionallyDown];
		_designIdentityTitle = [[NSTextField alloc] initWithFrame:NSMakeRect(0,0,kDesignIDWindowWidth, 40)];
		[_designIdentityTitle setAlignment:NSCenterTextAlignment];
		[[_designIdentityTitle cell] setLineBreakMode:NSLineBreakByTruncatingMiddle];
		[_designIdentityTitle setTextColor:[NSColor whiteColor]];
		[_designIdentityTitle setBordered:NO];
		[_designIdentityTitle setBezeled:NO];
		[_designIdentityTitle setSelectable:NO];
		[_designIdentityTitle setDrawsBackground:NO];
		[_designIdentityTitle setFont:[NSFont systemFontOfSize:[NSFont systemFontSize] * 2.0]];
		
		[contentView addSubview:_designIdentityThumbnail];
		[contentView addSubview:_designIdentityTitle];

		NSWindow *parentWindow = [self window];
		NSRect frame = [parentWindow frame];
		NSPoint attachmentPoint = NSMakePoint(frame.size.width/2.0,
											  (frame.size.height-kDesignIDWindowHeight)/2.0);
		_designIdentityWindow = [[MAAttachedWindow alloc]
								 initWithView:contentView
								 attachedToPoint:attachmentPoint
								 inWindow:parentWindow
								 onSide:MAPositionTop
								 atDistance:0.0 ];
		
		[_designIdentityWindow setHasArrow:NO];
		[_designIdentityWindow setBorderWidth:0.0];
		[_designIdentityWindow setAlphaValue:0.0];		// initially ZERO ALPHA!
	
		[parentWindow addChildWindow:_designIdentityWindow ordered:NSWindowAbove];
	}
	[_designIdentityTitle setStringValue:[aDesign title]];
	[_designIdentityThumbnail setImage:[aDesign thumbnail]];
	
	[[NSAnimationContext currentContext] setDuration:0.25f];
	[_designIdentityWindow.animator setAlphaValue:1.0];	// animate open
	[self performSelector:@selector(hideDesignIdentityWindow) withObject:nil afterDelay:1.0];

}

- (void)changeDesignTo:(KTDesign *)aDesign;
{
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
	[self showDesignIdentityWindow:aDesign];
}
- (void)designChooserDidEnd:(SVDesignChooserWindowController *)designChooser returnCode:(NSInteger)returnCode;
{
    if (returnCode == NSAlertAlternateReturn)
    {
        [NSApp endSheet:[designChooser window]];
        return;
    }

    KTDesign *aDesign = [designChooser design];
    
	OFF((@"%s %p",__FUNCTION__, aDesign));
    if (aDesign)
    {
		[self changeDesignTo:aDesign];
    }
}

#pragma mark Editor Actions

- (void)paste:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (IBAction)placeInline:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (IBAction)placeAsCallout:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (IBAction)placeInSidebar:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

- (void)moveToBlockLevel:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

#pragma mark Other

- (IBAction)toggleSmallPageIcons:(id)sender
{
	BOOL value = [[self document] displaySmallPageIcons];
    [[self document] setDisplaySmallPageIcons:!value];
}

#pragma mark Page Actions

- (void)pagesControllerDidInsertObject:(NSNotification *)notification;
{
    // As we're making a new page, give its article the focus
    [[self webContentAreaController] setViewType:KTStandardWebView];
    [[[self webContentAreaController] webEditorViewController] setArticleShouldBecomeFocusedAfterNextLoad:YES];
}

- (IBAction)addPage:(id)sender;             // your basic page
{
    [[self siteOutlineViewController] addPage:sender];
}

- (IBAction)addCollection:(id)sender;       // a collection. Uses [sender representedObject] for preset info
{
    [[self siteOutlineViewController] addCollection:sender];
}

- (IBAction)addExternalLinkPage:(id)sender; // external link
{
    [[self siteOutlineViewController] addExternalLinkPage:sender];
}

- (IBAction)addRawTextPage:(id)sender;      // Raw HTML page
{
    [[self siteOutlineViewController] addRawTextPage:sender];
}

- (IBAction)addFilePage:(id)sender;         // uses open panel to select a file, then inserts
{
    [[self siteOutlineViewController] addFilePage:sender];
}

- (void)toggleIsCollection:(id)sender;
{
    [[self siteOutlineViewController] toggleIsCollection:sender];
}

#pragma mark Action Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));
    
    BOOL result = YES;		// default to YES so we don't have to do special validation for each action. Some actions might say NO.
	SEL itemAction = [menuItem action];
		
	// File menu handled by KTDocument
		
	// Edit menu
	
	// "Paste" pasteAsRichText: NB: also intercepts general "paste" command
	if ( itemAction == @selector(pasteAsRichText:) )
	{
		// check the general pasteboard to see if there are any pages on it
		NSPasteboard *generalPboard = [NSPasteboard generalPasteboard];
		if ( nil != [generalPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]] )
		{
			result = YES;
		}
		else
		{
			result = NO;
		}
	}
	
	// Insert menu
    else if (itemAction == @selector(insertSiteTitle:) ||
             itemAction == @selector(insertSiteSubtitle:) ||
             itemAction == @selector(insertPageTitle:) ||
             itemAction == @selector(insertPageletTitle:) ||
             itemAction == @selector(insertFooter:))
    {
        result = [[[self webContentAreaController] webEditorViewController] validateMenuItem:menuItem];
    }
    else if ( itemAction == @selector(groupAsCollection:) )
    {
        result = ([[self pagesController] canGroupAsCollection]);
    }
    
	
	// View menu
    
    else if (itemAction == @selector(editRawHTMLInSelectedBlock:) ||
             itemAction == @selector(paste:) ||
             itemAction == @selector(insertPagelet:) ||
             itemAction == @selector(makeTextLarger:) ||
             itemAction == @selector(makeTextSmaller:) ||
             itemAction == @selector(makeTextStandardSize:))
    {
        id target = [[[self webContentAreaController] selectedViewControllerWhenReady]
                     ks_targetForAction:itemAction];
        
        if ([target respondsToSelector:@selector(validateMenuItem:)])
        {
            result = [target validateMenuItem:menuItem];
        }
        else if (!target)
        {
            result = NO;
        }
		// else result will be YES
    }
    else if (itemAction == @selector(selectWebViewViewType:))
    {
        result = [[self webContentAreaController] validateMenuItem:menuItem];
    }
	else if (itemAction == @selector(validateSource:))
	{
		id selection = [[[self siteOutlineViewController] content] selectedObjects];
		result = ( [KSNetworkNotifier isNetworkAvailable]
				&& !NSIsControllerMarker(selection)
				&& 1 == [selection count]
				&& nil != [[selection lastObject] pageRepresentation] );
	}
	else if ( itemAction == @selector(showPageCodeInjection:) || itemAction == @selector(showSiteCodeInjection:) )
	{
		id selection = [[[self siteOutlineViewController] content] selectedObjects];
		result = ( !NSIsControllerMarker(selection)
				  && 1 == [selection count]
				  && nil != [[selection lastObject] pageRepresentation] );
	}
	
	// "Use Small Page Icons" toggleSmallPageIcons:
    else if ( itemAction == @selector(toggleSmallPageIcons:) )
	{
		[menuItem setState:
			([[self document] displaySmallPageIcons] ? NSOnState : NSOffState)];
		// result will be YES
	}
	
	// Site menu items
    else if (itemAction == @selector(exportSiteAgain:))
    {
        NSString *exportPath = [[[self document] lastExportDirectory] path];
        result = (exportPath != nil && [exportPath isAbsolutePath]);
    }
    
    // Other
    else if ( itemAction == @selector(group:) )
    {
        result = ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] rootPage]] );
    }
    else if ( itemAction == @selector(ungroup:) )
    {
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];
        result = ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [[(KTDocument *)[self document] site] rootPage])
				 && ([[selectedItems objectAtIndex:0] isKindOfClass:[KTPage class]]) );
    }
	
	// "Visit Published Site" visitPublishedSite:
	else if ( itemAction == @selector(visitPublishedSite:) ) 
	{
		NSURL *siteURL = [[[[self document] site] hostProperties] siteURL];
		result = (nil != siteURL);
		
		NSString *title = NSLocalizedString(@"Visit Published Site", @"Menu item");
		if (!result) title = NSLocalizedString(@"Visit Published Site (Not Yet Published)", @"Menu item");
		[menuItem setTitle:title];
	}
	
	// "Visit Published Page" visitPublishedPage:
	else if ( itemAction == @selector(visitPublishedPage:) ) 
	{
		id content = [[self siteOutlineViewController] content];
		NSDate *published = [content valueForKeyPath:@"selection.datePublished"];
        
		// Enable if published, and this is only one item selected
		result = (published && !NSIsControllerMarker(published));

		// Check if page *can* be published
		BOOL canBePublished = (nil != gRegistrationString);
		if (!canBePublished)
		{
			NSNumber *isPublishableNumber = [content valueForKeyPath:@"selection.isPagePublishableInDemo"];
			if (!NSIsControllerMarker(isPublishableNumber))
			{
				canBePublished = [isPublishableNumber boolValue];
			}
		}
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];

		NSString *title = NSLocalizedString(@"Visit Published Page", @"Menu item");
		if ((nil == published) && (1==[selectedItems count])) title = NSLocalizedString(@"Visit Published Page (Not Yet Published)", @"Menu item");
		if (!canBePublished) title = NSLocalizedString(@"License Required to Publish Page", @"Menu item");
		[menuItem setTitle:title];
	}

	else if ( itemAction == @selector(submitSiteToDirectory:) ) 
	{
		NSURL *siteURL = [[[[self document] site] hostProperties] siteURL];
		result = (nil != siteURL);
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
		
		result = ( ![selection containsObject:[[[self document] site] rootPage]] );
	}

	// DEFAULT: let webKit handle it
    
    return result;
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	VALIDATION((@"%s %@ %@",__FUNCTION__, toolbarItem, [toolbarItem itemIdentifier]));
	
	BOOL result = YES;		// default to YES so we don't have to do special validation for each action. Some actions might say NO.
	SEL action = [toolbarItem action];

	if (action == @selector(editRawHTMLInSelectedBlock:))
	{
		result = NO;	// default, unless found below
		for (id selection in [[[[self webContentAreaController] webEditorViewController] graphicsController] selectedObjects])
		{
			if ([selection isKindOfClass:[SVRawHTMLGraphic class]])
			{
				result = YES;
				break;
			}
		}
	}
    else if ( action == @selector(groupAsCollection:) )
    {
        result = ([[self pagesController] canGroupAsCollection]);
    }
    else if ( action == @selector(group:) )
    {
        result = ( ![[[[self siteOutlineViewController] content] selectedObjects] containsObject:[[(KTDocument *)[self document] site] rootPage]] );
    }
    else if ( action == @selector(ungroup:) )
    {
		NSArray *selectedItems = [[[self siteOutlineViewController] content] selectedObjects];
        result = ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [[(KTDocument *)[self document] site] rootPage])
				 && ([[selectedItems objectAtIndex:0] isKindOfClass:[KTPage class]]) );
    }
    // Validate the -publishSiteFromToolbar: item here because -flagsChanged: doesn't catch all edge cases
    else if (action == @selector(publishSiteFromToolbar:))
    {
		NSToolbarItem *publishAllToolbarItem = [[[self window] toolbar] itemWithIdentifier:@"publishAll"];
		if (!publishAllToolbarItem)
		{
			[toolbarItem setLabel:
			 ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) ? TOOLBAR_PUBLISH_ALL : TOOLBAR_PUBLISH];
			[toolbarItem setImage:
			 [NSImage imageNamed:([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask ? @"toolbar_publish_all" : @"toolbar_publish")]];
		}
		
    }
    
    return result;
}

- (void)groupAsCollection:(id)sender;
{
    [[self pagesController] groupAsCollection:sender];
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

#pragma mark Code Injection & other pro stuff

@synthesize HTMLEditorController = _HTMLEditorController;
- (KTHTMLEditorController *)HTMLEditorController	// lazily instantiate
{
	if (!_HTMLEditorController)
	{
		_HTMLEditorController = [[KTHTMLEditorController alloc] init];
        //		[self addWindowController:controller];
	}
	return _HTMLEditorController;
}

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

- (IBAction)configureGoogle:(id)sender;
{
	if ( !self.googleWindowController )
	{
		self.googleWindowController = [[[SVGoogleWindowController alloc] initWithWindowNibName:@"SVGoogleSheet"] autorelease];
	}
	[self.googleWindowController setSite:[[self document] site]];
	[self.googleWindowController configureGoogle:self];
}

- (IBAction)configureComments:(id)sender;
{
    if ( !self.commentsWindowController )
    {
        self.commentsWindowController = [[[SVCommentsWindowController alloc] initWithWindowNibName:@"SVCommentsSheet"] autorelease];
    }
    [self.commentsWindowController setMaster:[[[[self document] site] rootPage] master]];
    [self.commentsWindowController configureComments:self];
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

- (void) updateDocWindowLicenseStatus:(NSNotification *)aNotification;
{
	if (nil == gRegistrationString)
	{
		
		NSString *buttonTitle = nil;
		NSString *buttonPrompt = @"";
		
		switch(gRegistrationFailureCode)
		// enum { kKSLicenseOK, kKSCouldNotReadLicenseFile, kKSEmptyRegistration, kKSBlacklisted, kKSLicenseExpired, kKSNoLongerValid, kKSLicenseCheckFailed };
		{
			case kKSLicenseCheckFailed:	// license entered but it's not valid
				
				buttonPrompt = NSLocalizedString(@"Invalid registration key entered", @"Indicator of license status of app");
				buttonTitle = NSLocalizedString(@"Update License", @"Button title to enter a license Code");
				break;
			case kKSLicenseExpired:		// Trial license expired
				buttonPrompt = NSLocalizedString(@"Trial expired", @"Indicator of license status of app");
				buttonTitle = NSLocalizedString(@"Buy a License", @"Button title to purchase a license");
				break;
			case kKSNoLongerValid:		// License from a previous version of Sandvox
				buttonPrompt = NSLocalizedString(@"Sandvox 2 license required", @"Indicator of license status of app");
				buttonTitle = NSLocalizedString(@"Upgrade your License", @"Button title to purchase a license");
				break;
			default:					// Unlicensed, treat as free/demo
				buttonPrompt = NSLocalizedString(@"Free edition (Unlicensed)", @"Indicator of license status of app");
				buttonTitle = NSLocalizedString(@"Buy a License", @"Button title to purchase a license");
				break;
		}
		NSButton *button = [[self window] createBuyNowButtonWithTitle:buttonTitle prompt:buttonPrompt];
		[button setAction:@selector(showRegistrationWindow:)];
		[button setTarget:[NSApp delegate]];
	}
	else
	{
		[[self window] removeBuyNowButton];
	}
	
}

- (void)reload:(id)sender;
{
    [[[self webContentAreaController] selectedViewControllerWhenReady] doCommandBySelector:_cmd];
}

#pragma mark HTML Validation

- (IBAction)validateSource:(id)sender
{
	id selection = [[[self siteOutlineViewController] content] selectedObjects];
	KTPage *page = nil;
	if ( !NSIsControllerMarker(selection) && 1 == [selection count] && nil != (page = [[selection lastObject] pageRepresentation]) )
	{
		[[SVValidatorWindowController sharedController] validatePage:page windowForSheet:[self window]];
	}
}

@end

