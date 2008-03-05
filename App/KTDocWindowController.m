//
//  KTDocWindowController.m
//  Marvel
//
//  Created by Dan Wood on 5/4/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDocWindowController.h"

#import "Debug.h"

#import "NSException+Karelia.h"

#import "KTDocWebViewController.h"

#import "KTLinkSourceView.h"

#import "AMRollOverButton.h"
#import "KT.h"
#import "KTAppDelegate.h"
#import "KTApplication.h"

#import "KTBundleManager.h"
#import "KTIndexPlugin.h"

#import "KTInlineImageElement.h"

#import "KTDesignPickerView.h"
#import "KTDocWindow.h"
#import "KTDocument.h"
#import "KTElementPlugin.h"
#import "KTHostProperties.h"
#import "KTInfoWindowController.h"
#import "KTPluginInspectorViewsManager.h"
#import "KTDocSiteOutlineController.h"
#import "KTCodeInjectionController.h"

#import "KTWebViewTextBlock.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "KTAbstractDataSource.h"

#import "KTMediaManager+Internal.h"
#import "KTMissingMediaController.h"

#import "KSTextField.h"
#import "KTToolbars.h"
#import "KTTransferController.h"
#import "NSTextView+KTExtensions.h"
#import "NTBoxView.h"
#import "Registration.h"
#import <WebKit/WebKit.h>
#import <iMediaBrowser/iMedia.h>
#import "NSArray+KTExtensions.h"
#import "KSValidateCharFormatter.h"

#import "NSCharacterSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSColor+Karelia.h"
#import "NSWindow+Karelia.h"
#import "KSSilencingConfirmSheet.h"

#import "KTManagedObjectContext.h"

#import "NSOutlineView+KTExtensions.h"

#import "KTPage.h"

#import "NSBundle+Karelia.h"
#import "KTAbstractIndex.h"
#import "NSThread+Karelia.h"

NSString *gInfoWindowAutoSaveName = @"Inspector TopLeft";


@interface KTDocWindowController ( Private )
- (void)showAddressBar:(BOOL)inShow;
- (void)showDesigns:(BOOL)inShow;
- (void)showInfo:(BOOL)inShow;
- (void)showStatusBar:(BOOL)inShow;

- (BOOL)validateCopyPagesItem:(id <NSValidatedUserInterfaceItem>)item;
- (BOOL)validateCutPagesItem:(id <NSValidatedUserInterfaceItem>)item;

- (void)updateCutMenuItem;
- (void)updateCopyMenuItem;
- (void)updateDeletePagesMenuItem;
@end


@implementation KTDocWindowController

/*!	Designated initializer.
*/

- (id)initWithWindow:(NSWindow *)window;
{
	self = [super initWithWindow:window];
	[self setShouldCloseDocument:YES];
	///[self siteOutlineInitSupport];
	return self;
}

- (id)init
{
	self = [super initWithWindowNibName:@"KTDocument"];
	
	if ( nil != self )
	{
		// be ready for webview vs. context updating collisions
		myUpdateLock = [[NSLock alloc] init];
		myIsSuspendingUIUpdates = NO;
		
		// set up a pseudo lock that we can @syncronized around
		[self setAddingPagesViaDragPseudoLock:[[[NSObject alloc] init] autorelease]];
		
		// do not cascade window using size in nib
		[self setShouldCascadeWindows:NO];
	}
    return self;
}

//- (oneway void)release
//{
//	//  TOTAL BIZARRE KLUDGE -- I CAN'T DO THIS IN DEALLOC; I GET COMPLAINTS ABOUT STILL HAVING
//	// REGISTERED OBSERVERS. FOR SOME REASON, IT COMPLAINS ABOUT THIS BEFORE MY DEALLOC CODE IS
//	// CALLED!  SO INSTEAD, I DO THIS JUST BEFORE IT'S ABOUT TO DEALLOC!
//	
//	if ([self retainCount] == 1)
//	{
//		[self webViewDeallocSupport];
//		[self siteOutlineDeallocSupport];
//	}
//	[super release];
//}

- (void)dealloc
{
	[self setWebViewController:nil];
	
	  // stop observing
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    // release my copy of the window script object.
	[[self webViewController] setWindowScriptObject:nil];
	
	// no more updating
	[myUpdateLock release]; myUpdateLock = nil;

    // disconnect UI delegates
    [oDesignsSplitView setDelegate:nil];
	[oDocumentController unbind:@"contentObject"];
	[oKeywordsField unbind:@"value"];			// balance out the bind in code here too?
    [oDocumentController setContent:nil];
    [oSidebarSplitView setDelegate:nil];

    // release ivars
	[self setContextElementInformation:nil];
    [self setAddCollectionPopUpButton:nil];
    [self setAddPagePopUpButton:nil];
    [self setAddPageletPopUpButton:nil];
    [self setHTMLSource:nil];
    [self setImageReplacementRegistry:nil];
    [self setReplacementImages:nil];
    [self setSelectedDOMRange:nil];
    [self setSelectedInlineImageElement:nil];
    [self setSelectedPagelet:nil];
    [self setToolbars:nil];
    [self setWebViewTitle:nil];    
	[self setAddingPagesViaDragPseudoLock:nil];
	[myMasterCodeInjectionController release];
	[myPageCodeInjectionController release];
	[myPluginInspectorViewsManager release];
	[myBuyNowButton release]; myBuyNowButton = nil;

    [super dealloc];
}

// break bindings in oDocumentController
- (void)documentControllerDeallocSupport
{
	[oDocumentController unbind:@"contentObject"];
    [oDocumentController setContent:nil];
	[oKeywordsField unbind:@"value"];			// balance out the bind in code here too?
}

- (void)selectionDealloc
{
	[self setSelectedInlineImageElement:nil];
    [self setSelectedPagelet:nil];
}

- (void)windowDidLoad
{	
    [super windowDidLoad];
	@try
	{
		// Setup binding
		[oDocumentController setContent:self];		// allow nib binding to the KTDocWindowController

		// Now let the webview and the site outline initialize themselves.
		[self webViewDidLoad];
		[oSiteOutlineController siteOutlineDidLoad];		
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
		[self updatePopupButtonSizesSmall:[[self document] displaySmallPageIcons]];
		
		
		// Design Chooser bindings
		[oDesignsView bind:@"selectedDesign"
				  toObject:[self siteOutlineController]
			   withKeyPath:@"selection.master.design"
				   options:nil];
				   
		
		// Split View
		// Do not use autosave, we save this in document... [oSidebarSplitView restoreState:YES];
		short sourceOutlineSize = [[self document] sourceOutlineSize];
		if ( sourceOutlineSize > 0)
        {
			[[[self siteOutlineSplitView] subviewAtPosition:0] setDimension:sourceOutlineSize];
			[oSidebarSplitView adjustSubviews];
		}
		[RBSplitView setCursor:RBSVDragCursor toCursor:[NSCursor resizeLeftRightCursor]];
		
		// UI setup of box views
		[oStatusBar setDrawsFrame:YES];
		[oStatusBar setBorderMask:NTBoxTop];
		
		[oDetailPanel setDrawsFrame:YES];
		[oDetailPanel setBorderMask:(NTBoxRight | NTBoxBottom)];
		
		NSCharacterSet *illegalCharSetForPageTitles = [[NSCharacterSet legalPageTitleCharacterSet] invertedSet];
		NSFormatter *formatter = [[[KSValidateCharFormatter alloc]
			initWithIllegalCharacterSet:illegalCharSetForPageTitles] autorelease];
		[oPageNameField setFormatter:formatter];
		
		
		// Prepare the collection index.html popup
		[oCollectionIndexExtensionButton bind:@"defaultValue"
									 toObject:[self siteOutlineController]
								  withKeyPath:@"selection.defaultIndexFileName"
								      options:nil];
		
		[oCollectionIndexExtensionButton setMenuTitle:NSLocalizedString(@"Index file name",
			"Popup menu title for setting the index.html file's extensions")];
		
		[oFileExtensionPopup bind:@"defaultValue"
						 toObject:[self siteOutlineController]
					  withKeyPath:@"selection.defaultFileExtension"
						  options:nil];
		
		
		
		// Link Popup in address bar
		//		[[oLinkPopup cell] setUsesItemFromMenu:NO];
		//		[oLinkPopup setIconImage:[NSImage imageNamed:@"links"]];
		//		[oLinkPopup setShowsMenuWhenIconClicked:YES];
		//		[oLinkPopup setArrowImage:nil];	// we have our own arrow, thank you
		
		
		
		// Hide address bar if it's hidden (it's showing to begin with, in the nib)
		if (![[self document] showDesigns])
		{
			[oDesignsSplitPane collapse];	// collapse the split pane -- without animation.
		}
		else	// initialize the view
		{
			[self splitView:oDesignsSplitView didExpand:oDesignsSplitPane];
		}
		
		// Same with status bar
		if (![[self document] displayStatusBar])
		{
			[self showStatusBar:NO];
		}
				
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(anyWindowWillClose:)
													 name:NSWindowWillCloseNotification
												   object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(updateBuyNow:)
													 name:kKSLicenseStatusChangeNotification
												   object:nil];
		[self updateBuyNow:nil];	// update them now
		
		// register for requests to refresh the document title
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(refreshDocumentTitle:)
													 name:kKTDocumentTitleNeedsRefreshingNotification
												   object:nil];
		
		/// turn off undo within the cell to avoid exception
		/// -[NSBigMutableString substringWithRange:] called with out-of-bounds range
		/// this still leaves the setting of keywords for the page undo'able, it's
		/// just now that typing inside the field is now not undoable
		[[oKeywordsField cell] setAllowsUndo:NO];
		
		[[NSApp delegate] performSelector:@selector(checkPlaceholderWindow:) 
				   withObject:nil
				   afterDelay:0.0];
	}
	@catch (NSException *exception)
	{
		LOG((@"%@ -- Caught %@: %@", NSStringFromSelector(_cmd), [exception name], [exception reason]));
		[exception raise];		// re-raise, this is a bad error
	}
    
    // Media Manager
    //[[self document] setOldMediaManager:[KTOldMediaManager mediaManagerWithDocument:[self document]]];
	
	
	[self showInfo:[[NSUserDefaults standardUserDefaults] boolForKey:@"DisplayInfo"]];
	
	myLastClickedPoint = NSZeroPoint;
		
	// register for updates
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(updateSelectedItemForDocWindow:)
												 name:kKTItemSelectedNotification
											   object:nil];
	
//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(infoWindowMayNeedRefreshing:)
//												 name:kKTInfoWindowMayNeedRefreshingNotification
//											   object:nil];	
	
	if ( ![[self document] isReadOnly] )
	{
		[[self document] setLastSavedTime:[NSDate date]];
	}
	
	
	// Check for missing media
	[self performSelector:@selector(checkForMissingMedia) withObject:nil afterDelay:0.0];
	
	
	// LAST: clear the undo stack
	[[self document] performSelector:@selector(processPendingChangesAndClearChangeCount)
						  withObject:nil
						  afterDelay:0.0];
}

/*!	Gets invoked when defaults change, for instance.
*/
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
//	if ([keyPath isEqualToString:@"selectedPage.collectionSortOrder"])
//	{
//		OFF((@"observe of selectedPage.collectionSortOrder reloading outline"));
//		[self reloadItemAndChildren:[self selectedPage]];
//	}
//	else if ( [keyPath isEqualToString:@"selectedPage.titleHTML"] )
//	{
//		[NSObject cancelPreviousPerformRequestsWithTarget:oSiteOutline];	// cancel all so we aren't caring about the object
//		OFF((@"selectedPage.titleHTML changed; re-selecting page %@", [[self selectedPage] titleText]));
//		[oSiteOutline performSelector:@selector(selectItem:)
//						   withObject:[self selectedPage] 
//						   afterDelay:0.0];
//	}
//	else if ( [keyPath isEqualToString:@"children"] )
//	{
//		TJT((@"children have changed, reloading (%@)", [object managedObjectDescription]));
//		[self reloadItem:object reloadChildren:YES];
//	}
//	else if ( [keyPath isEqualToString:@"titleHTML"] )
//	{
//		TJT((@"titleHTML has changed, reloading (%@)", [object managedObjectDescription]));
//		[self reloadItem:object reloadChildren:NO];
//	}
//	else if ( [keyPath isEqualToString:@"collectionSortOrder"] )
//	{
//		TJT((@"collectionSortOrder has changed, reloading (%@)", [object managedObjectDescription]));
//		[self reloadItem:object reloadChildren:YES];
//	}
//	else	// other ...
//	{
//		OFF((@"observeValueForKeyPath: %@", keyPath));
//		OFF((@"                object: %@", object));
//		OFF((@"                change: %@", [change description]));
//		// in case author changed
//		[self synchronizeWindowTitleWithDocumentName];
//	}
	
	LOG((@"%@ observing %@", keyPath));
	if ( [keyPath isEqualToString:@"selectedPage.master.author"] )
	{
		[self synchronizeWindowTitleWithDocumentName];
	}
}

#pragma mark -
#pragma mark Missing Media

- (void)checkForMissingMedia
{
	// Check for missing media files. If any are missing alert the user
	NSSet *missingMedia = [[(KTDocument *)[self document] mediaManager] missingMediaFiles];
	if (missingMedia && [missingMedia count] > 0)
	{
		KTMissingMediaController *missingMediaController =
			[[KTMissingMediaController alloc] initWithWindowNibName:@"MissingMedia"];	// We'll release it after closing the sheet
		
		[missingMediaController setMediaManager:[(KTDocument *)[self document] mediaManager]];
		
		NSArray *sortDescriptors = [NSArray arrayWithObject:[[[NSSortDescriptor alloc] initWithKey:@"filename" ascending:YES] autorelease]];
		NSArray *sortedMissingMedia = [[missingMedia allObjects] sortedArrayUsingDescriptors:sortDescriptors];
		[missingMediaController setMissingMedia:sortedMissingMedia];
		
		[NSApp beginSheet:[missingMediaController window]
		   modalForWindow:[self window]
			modalDelegate:self
		   didEndSelector:@selector(missingMediaSheetDidEnd:returnCode:contextInfo:)
			  contextInfo:NULL];
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

#pragma mark -
#pragma mark NSWindowController overrides

- (NSString *)windowTitleForDocumentDisplayName:(NSString *)displayName
{
	if ([[self siteOutlineController] selectedPage])
	{
		return [NSString stringWithFormat:@"%@ %C %@",
			displayName,
			0x2014,	// em dash
			[[[self siteOutlineController] selectedPage] comboTitleText]];
	}
	return displayName;
}

- (void)refreshDocumentTitle:(NSNotification *)aNotification
{
	[self synchronizeWindowTitleWithDocumentName];
}

#pragma mark -
#pragma mark Public Functions

- (BOOL)sidebarIsCollapsed
{
	return [[oSidebarSplitView subviewAtPosition:0] isCollapsed];
}

- (void)setStatusField:(NSString *)string
{
	if (nil == string) string = @"";	/// defense against nil
    [oStatusBarField setStringValue:string];
	[oStatusBarField displayIfNeeded];
}

- (NSString *)status
{
	return [oStatusBarField stringValue];
}

- (void)updatePopupButtonSizesSmall:(BOOL)aSmall;
{
	NSSize iconSize = aSmall ? NSMakeSize(16.0,16.0) : NSMakeSize(32.0, 32.0);
	
	NSArray *popupButtonsToAdjust = [NSArray arrayWithObjects:
		[self addPagePopUpButton],
		[self addPageletPopUpButton],
		[self addCollectionPopUpButton],
		nil];
	NSEnumerator *theEnum = [popupButtonsToAdjust objectEnumerator];
	RYZImagePopUpButton *aPopup;
	
	NSMutableParagraphStyle *style = [[[NSMutableParagraphStyle alloc] init] autorelease];
	[style setMinimumLineHeight:iconSize.height];
	
	while (nil != (aPopup = [theEnum nextObject]) )
	{
		NSEnumerator *thePopupEnum = [[[aPopup menu] itemArray] objectEnumerator];
		NSMenuItem *item;
		
		while (nil != (item = [thePopupEnum nextObject]) )
		{
			NSImage *image = [item image];
			[image setSize:iconSize];
			
			// We also have to set the line height.
			NSMutableAttributedString *titleString
				= [[[NSMutableAttributedString alloc] initWithAttributedString:[item attributedTitle]] autorelease];
			[titleString addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(0,[titleString length])];
			[titleString addAttribute:NSBaselineOffsetAttributeName
								value:[NSNumber numberWithFloat:((([image size].height-[NSFont smallSystemFontSize])/2.0)+2.0)]
								range:NSMakeRange(0,[titleString length])];
			
			
			[item setAttributedTitle:titleString];
		}
	}
}

#pragma mark -
#pragma mark IBActions

- (IBAction) windowHelp:(id)sender
{
	[NSApp showHelpPage:@"Link"];		// HELPSTRING
}

- (IBAction)saveDocumentTo:(id)sender
{
	// NSPersistentDocument does not support saveTo:
	// so we're going to fudge it by, first,
	// saving this document's context and, then,
	// using NSFileManger to copy the saved context
	// to another location
	
	// actually, before we do anything, let's make sure we're all on disk
	[[self document] autosaveDocument:nil];
	
	// first, put up a sheet to pick a location
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	
	[savePanel setAllowedFileTypes:[NSArray arrayWithObject:kKTDocumentExtension]];
	[savePanel setAllowsOtherFileTypes:NO];
	[savePanel setTitle:NSLocalizedString(@"Save a Copy As...", @"Save a Copy As...")];
	[savePanel setPrompt:NSLocalizedString(@"Save a Copy", @"Save a Copy")];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:kKTDocumentExtension];
	
	// the document will pick it up on the backend and do the saveTo: there
	NSURL *fileURL = [[self document] fileURL];
	NSString *directory = [[fileURL path] stringByDeletingLastPathComponent];
	[savePanel beginSheetForDirectory:directory
								 file:nil 
					   modalForWindow:[self window] 
						modalDelegate:[self document] 
					   didEndSelector:@selector(savePanelDidEnd:returnCode:contextInfo:) 
						  contextInfo:@"saveDocumentTo:"];
}

- (IBAction)deselectAll:(id)sender
{
	id documentView = [[[oWebView mainFrame] frameView] documentView];
	if ( [documentView conformsToProtocol:@protocol(WebDocumentText)] )
	{
		[documentView deselectAll];
	}
}

- (IBAction) validateSource:(id)sender
{
	NSString *pageSource = [self HTMLSource];
	NSString *charset = [[[[self siteOutlineController] selectedPage] master] valueForKey:@"charset"];
	NSStringEncoding encoding = [charset encodingFromCharset];
	NSData *pageData = [pageSource dataUsingEncoding:encoding allowLossyConversion:YES];
	
	NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"sandvox_source.html"];
	NSString *pathOut = [NSTemporaryDirectory() stringByAppendingPathComponent:@"validation.html"];
	[pageData writeToFile:path atomically:NO];
	
	// curl -F uploaded_file=@karelia.html -F ss=1 -F outline=1 -F sp=1 -F noatt=1 -F verbose=1  http://validator.w3.org/check
	NSString *argString = [NSString stringWithFormat:@"-F uploaded_file=@%@ -F ss=1 -F verbose=1 http://validator.w3.org/check", path, pathOut];
	NSArray *args = [argString componentsSeparatedByString:@" "];
	
	NSTask *task = [[[NSTask alloc] init] autorelease];
	[task setLaunchPath:@"/usr/bin/curl"];
	[task setArguments:args];
	
	[[NSFileManager defaultManager] createFileAtPath:pathOut contents:[NSData data] attributes:nil];
	NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:pathOut];
	[task setStandardOutput:fileHandle];
	
#ifndef DEBUG
	// Non-debug builds should throw away stderr
	[task setStandardError:[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"]];
#endif
	[task launch];
	[task waitUntilExit];
	int status = [task terminationStatus];
	
	if (0 == status)
	{
		// Scrape page to get status
		BOOL isValid = NO;
		NSString *resultingPageString = [[[NSString alloc] initWithContentsOfFile:pathOut
																		 encoding:NSUTF8StringEncoding
																			error:nil] autorelease];
		if (nil != resultingPageString)
		{
			NSRange foundValidRange = [resultingPageString rangeBetweenString:@"<h2 class=\"valid\">" andString:@"</h2>"];
			if (NSNotFound != foundValidRange.location)
			{
				isValid = YES;
				NSString *explanation = [resultingPageString substringWithRange:foundValidRange];
				
				NSRunInformationalAlertPanelRelativeToWindow(
					NSLocalizedString(@"HTML is Valid",@"Title of results alert"),
					NSLocalizedString(@"The validator returned the following status message:\n\t%@",@""),
					nil,nil,nil, [self window], explanation);
			}
		}
		
		if (!isValid)		// not valid -- load the page, give them a way out!
		{
			[[self webViewController] setViewType: KTHTMLValidationView];
			[[oWebView mainFrame] loadData:[NSData dataWithContentsOfFile:pathOut]
								  MIMEType:@"text/html"
						  textEncodingName:@"utf-8" baseURL:[NSURL URLWithString:@"http://validator.w3.org/"]];
			[self performSelector:@selector(showValidationResultsAlert) withObject:nil afterDelay:0.0];
		}
	}
	else
	{
		[KSSilencingConfirmSheet
			alertWithWindow:[self window]
			   silencingKey:@"shutUpValidateError"
					  title:NSLocalizedString(@"Unable to Validate",@"Title of alert")
					 format:NSLocalizedString(@"Unable to post HTML to validator.w3.org:\n%@", @"error message"), path];
	}
}

-(void) showValidationResultsAlert
{
				[KSSilencingConfirmSheet
				alertWithWindow:[self window]
				   silencingKey:@"shutUpNotValidated"
						  title:NSLocalizedString(@"Validation Results Loaded",@"Title of alert")
						 format:NSLocalizedString(@"The results from the HTML validator have been loaded into Sandvox's web view. To return to the standard view of your web page, choose the 'Reload Web View' menu.", @"validated message")];
}

#pragma mark -
#pragma mark WebView View Type

/*	The sender's tag should correspond to a view type
 */
- (IBAction)selectWebViewViewType:(id)sender;
{
	KTWebViewViewType viewType = [sender tag];
	[[self webViewController] setViewType:viewType];
}

#pragma mark -
#pragma mark Other

- (IBAction)toggleDesignsShown:(id)sender
{
    // set value
	BOOL value = [[self document] showDesigns];
	BOOL newValue = !value;
	[[self document] setShowDesigns:newValue];
    
	// update UI
	[self showDesigns:newValue];
	[[NSApp delegate] updateMenusForDocument:[self document]];
}

- (IBAction)toggleStatusBarShown:(id)sender
{
    // set value
	BOOL value = [[self document] displayStatusBar];
	BOOL newValue = !value;
	[[self document] setDisplayStatusBar:newValue];
	
	// update UI
	[[NSApp delegate] updateMenusForDocument:[self document]];
	[self showStatusBar:newValue];
}

- (IBAction)toggleEditingControlsShown:(id)sender
{
    // set value
	BOOL value = [[self document] displayEditingControls];
	BOOL newValue = !value;
	[[self document] setDisplayEditingControls:newValue];

	// update UI
	[[NSApp delegate] updateMenusForDocument:[self document]];
	[self updateToolbar];
	[[self webViewController] setWebViewNeedsRefresh:YES];
}

- (IBAction)toggleInfoShown:(id)sender
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
	// reverse the flag in defaults
	BOOL value = [defaults boolForKey:@"DisplayInfo"];
	BOOL newValue = !value;
	[defaults setBool:newValue forKey:@"DisplayInfo"];
	
	// set menu to opposite of flag
	if ( newValue )
	{
		[[NSApp delegate] setDisplayInfoMenuItemTitle:KTHideInfoMenuItemTitle];
	}
	else
	{
		[[NSApp delegate] setDisplayInfoMenuItemTitle:KTShowInfoMenuItemTitle];
	}
	
	// display info, if appropriate
	[self showInfo:newValue];
}

- (IBAction)toggleSiteOutlineShown:(id)sender
{
	RBSplitSubview *sidebarSplit = [oSidebarSplitView subviewAtPosition:0];
    BOOL newValue = [sidebarSplit isCollapsed];	// opposite of current actual state
	
	NSWindow *window = [self window];
	NSRect frame = [window frame];
	
	if (newValue)		//  FIXME: This needs new versions of RBSplitView from RB ... to deal with programatic/dragged collapses
	{
		[sidebarSplit expand];
		frame.size.width += [sidebarSplit dimension];
	}
	else
	{
		[sidebarSplit collapse];
		frame.size.width -= [sidebarSplit dimension];
		if (frame.size.width < [window minSize].width)
		{
			frame.size.width = [window minSize].width;
		}
	}
	[window setFrame:frame display:NO];
	
	[oSidebarSplitView adjustSubviews];
    
    [[NSApp delegate] updateMenusForDocument:[self document]];
}

- (IBAction)toggleSmallPageIcons:(id)sender
{
	BOOL value = [[self document] displaySmallPageIcons];
    [[self document] setDisplaySmallPageIcons:!value];
	[[NSApp delegate] updateMenusForDocument:[self document]];
}

- (IBAction) makeTextLarger:(id)sender
{
	[oWebView makeTextLarger:sender];
	[[self document] setWrappedValue:[NSNumber numberWithFloat:[oWebView textSizeMultiplier]] forKey:@"textSizeMultiplier"];
	[[NSApp delegate] updateMenusForDocument:[self document]];
}

- (IBAction) makeTextSmaller:(id)sender
{
	[oWebView makeTextSmaller:sender];
	[[self document] setWrappedValue:[NSNumber numberWithFloat:[oWebView textSizeMultiplier]] forKey:@"textSizeMultiplier"];
	[[NSApp delegate] updateMenusForDocument:[self document]];
}

- (IBAction) makeTextNormal:(id)sender
{
	[oWebView setTextSizeMultiplier:1.0];
	[[self document] setWrappedValue:[NSNumber numberWithFloat:1.0] forKey:@"textSizeMultiplier"];
	[[NSApp delegate] updateMenusForDocument:[self document]];
}



/*!	We need to define export here so it can be validated by the doc window controller.
*/
- (IBAction)export:(id)sender
{
	[[self document] export:sender];
}
- (IBAction)exportAgain:(id)sender
{
	[[self document] exportAgain:sender];
}
- (IBAction)saveToHost:(id)sender
{
	[[self document] saveToHost:sender];
}
- (IBAction)saveAllToHost:(id)sender
{
	[[self document] saveAllToHost:sender];
}

- (IBAction)reloadOutline:(id)sender
{
	[[self siteOutlineController] reloadSiteOutline];
}

#pragma mark Page Actions

/*! adds a new page to site outline, obtaining its class from representedObject */
- (IBAction)addPage:(id)sender
{
    // LOG((@"%@: addPage using bundle: %@", self, [sender representedObject]));
	NSBundle *pageBundle = nil;
	
	if ( [sender respondsToSelector:@selector(representedObject)] )
	{
		KTElementPlugin *plugin = [sender representedObject];
		pageBundle = [plugin bundle];
	}
	
	if ( nil != pageBundle && [pageBundle isMemberOfClass:[NSBundle class]] )
    {
		/// Case 17992, we now pass in a context to nearestParent
		KTPage *nearestParent = [self nearestParent:(KTManagedObjectContext *)[[self document] managedObjectContext]];
		if ( ![nearestParent isKindOfClass:[KTPage class]] )
		{
			NSLog(@"unable to addPage: nearestParent is nil");
			return;
		}
		
		KTPage *page = [KTPage pageWithParent:nearestParent 
									   bundle:pageBundle 
			   insertIntoManagedObjectContext:(KTManagedObjectContext *)[[self document] managedObjectContext]];
		
		if ( nil != page )
		{
			[self insertPage:page parent:nearestParent];
			[oSiteOutline scrollRowToVisible:[oSiteOutline rowForItem:page]];
			/// Case 18433: force didChangeNotification since selectedRowIndex may not actually change
			[oSiteOutline selectItem:page forceDidChangeNotification:YES];	// Shouldn't the SiteOutlineController handle this?
		}
		else
		{
			NSLog(@"unable to addPage: unable to create Page");
			return;
		}
	}
	else
    {
		NSLog(@"unable to addPage: sender has no representedObject");
		return;
    }
}

/*! adds a new pagelet to current page, obtaining its class from representedObject */
- (IBAction)addPagelet:(id)sender
{
    //LOG((@"%@: addPagelet using bundle: %@", self, [sender representedObject]));
	KTElementPlugin *pageletPlugin = nil;
	
	if ([sender respondsToSelector:@selector(representedObject)])
	{
		pageletPlugin = [sender representedObject];
	}
	
	if (pageletPlugin && [pageletPlugin isKindOfClass:[KTElementPlugin class]])
    {
		KTPage *targetPage = [[self siteOutlineController] selectedPage];
		if (nil == targetPage)
		{
			// if nothing is selected, treat as if the root folder were selected
			targetPage = [(KTDocument *)[self document] root];
		}
		
		KTPagelet *pagelet = [KTPagelet pageletWithPage:targetPage plugin:pageletPlugin];
		
		if ( nil != pagelet )
		{
			[self insertPagelet:pagelet toSelectedItem:targetPage];
		}
		else
		{
			[self raiseExceptionWithName:kKareliaDocumentException reason:@"unable to create Pagelet"];
		}
	}
	else
    {
		[self raiseExceptionWithName:kKareliaDocumentException
							  reason:@"sender has no representedObject"
							userInfo:[NSDictionary dictionaryWithObject:sender forKey:@"sender"]];
    }
}


/*! adds a new collection to site outline, obtaining the information of a dictionary
from representedObject */

// TODO: Perhaps a lot more of this logic ought to be moved to KTPage+Operations.m


- (IBAction)addCollection:(id)sender
{
	NSAssert( [sender respondsToSelector:@selector(representedObject)], @"Sender needs to have a representedObject" );
	
	NSDictionary *presetDict= [sender representedObject];
	NSString *identifier = [presetDict objectForKey:@"KTPresetIndexBundleIdentifier"];
	
	NSBundle *indexBundle = [[KTIndexPlugin pluginWithIdentifier:identifier] bundle];
	
    if ( nil != indexBundle && [indexBundle isMemberOfClass:[NSBundle class]] )
    {		
		// Figure out page type to construct based on info plist.  Be  a bit forgiving if not found.
		NSString *pageIdentifier = [presetDict objectForKey:@"KTPreferredPageBundleIdentifier"];
		if (nil == pageIdentifier)
		{
			pageIdentifier = [indexBundle objectForInfoDictionaryKey:@"KTPreferredPageBundleIdentifier"];
		}
		NSBundle *pageBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:pageIdentifier] bundle];
		if (nil == pageBundle)
		{
			pageIdentifier = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultIndexBundleIdentifier"];
			pageBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:pageIdentifier] bundle];
		}
		if (nil == pageBundle)
		{
			[NSException raise: NSInternalInconsistencyException
						format: @"Unable to create page of type %@.",
				pageIdentifier];
		}
		
		/// Case 17992, nearestParent method now requires we pass in a context
		KTPage *nearestParent = [self nearestParent:(KTManagedObjectContext *)[[self document] managedObjectContext]];
		/// Case 17992, added assert to better detect source of exception
		NSAssert((nil != nearestParent), @"nearestParent should not be nil, root at worst");
		KTPage *indexPage = [KTPage pageWithParent:nearestParent 
											bundle:pageBundle 
					insertIntoManagedObjectContext:(KTManagedObjectContext *)[[self document] managedObjectContext]];
		[indexPage setBool:YES forKey:@"isCollection"]; // Duh!
		
		// Now set the index on the page
		[indexPage setWrappedValue:identifier forKey:@"collectionIndexBundleIdentifier"];
		Class indexToAllocate = [NSBundle principalClassForBundle:indexBundle];
		KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:indexPage plugin:[KTAppPlugin pluginWithBundle:indexBundle]] autorelease];
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
			
			KTPage *firstChild = [KTPage pageWithParent:indexPage
												 bundle:[[KTElementPlugin pluginWithIdentifier:firstChildIdentifier] bundle]
						 insertIntoManagedObjectContext:(KTManagedObjectContext *)[[self document] managedObjectContext]];
			
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
		if ([[pageSettings objectForKey:@"collectionSyndicate"] boolValue])
		{
			// Make the initial RSS badge
			NSString *initialBadgeBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultRSSBadgeBundleIdentifier"];
			if (nil != initialBadgeBundleID && ![initialBadgeBundleID isEqualToString:@""])
			{
				KTElementPlugin *badgePlugin = [KTAppPlugin pluginWithIdentifier:initialBadgeBundleID];
				if (badgePlugin)
				{
					[KTPagelet pageletWithPage:indexPage plugin:badgePlugin];
				}
			}
		
		
			// Give weblogs special introductory text
			if ([[presetDict objectForKey:@"KTPresetIndexBundleIdentifier"] isEqualToString:@"sandvox.GeneralIndex"])
			{
				NSString *intro = NSLocalizedString(@"<p>This is a new weblog. You can replace this text with an introduction to your blog, or just delete it if you wish.</p><p>To add an entry to the weblog, add a new page using the \"Pages\" button in the toolbar.</p><p>For more information on blogging with Sandvox, please have a look through our <a href=\"http://docs.karelia.com/z/Blogging_with_Sandvox.html\">help guide</a>.</p>",
													"Introductory text for Weblogs");
				
				[indexPage setValue:intro forKey:@"richTextHTML"];
			}
		}
    }
    else
    {
		[self raiseExceptionWithName:kKareliaDocumentException reason:@"Unable to instantiate collection"
							userInfo:[NSDictionary dictionaryWithObject:sender forKey:@"sender"]];
    }
}

/*! inserts aPage at the current selection */
- (void)insertPage:(KTPage *)aPage parent:(KTPage *)aCollection
{
	KTPage *targetPage = [[self siteOutlineController] selectedPage];
	// figure out our selection
	if (nil == targetPage)
	{
		// if nothing is selected, treat as if the root folder were selected
		targetPage = [(KTDocument *)[self document] root];
	}
	
	// add component to parent
	[aCollection addPage:aPage];
	
	// preserve the selection for undo
	id selectedRowIndexes = [[oSiteOutline selectedRowIndexes] copyWithZone:[self zone]];
	
	[oSiteOutline selectItem:aPage];	// Shouldn't the SiteOutlineController handle this?
	if ( [aPage isKindOfClass:[KTPage class]] )
	{
		[oSiteOutline expandSelectedRow];
	}
	
	// label undo and perserve the current selection
    if ( [aPage isCollection] )
	{
        [[[self document] undoManager] setActionName:NSLocalizedString(@"Add Collection", "action name for adding a collection")];
    }
    else
	{
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Add Page", "action name for adding a page")];
    }
	[selectedRowIndexes release];
	
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
	[[self document] siteStructureChanged];	// allows site map page to notice change in site structure
	
}

/*! inserts aPagelet at the current selection.  Just insert as a sidebar; let it be moved to callout */
- (void)insertPagelet:(KTPagelet *)aPagelet toSelectedItem:(KTPage *)selectedItem
{
	if ( [selectedItem isKindOfClass:[KTPage class]] )
	{
		if ([selectedItem includeSidebar] || [selectedItem includeCallout]) {
			//[selectedItem insertPagelet:aPagelet atIndex:0];
			/// There's no need to actually insert the pagelet, since creating it on this page did the job. Mike.
		}
		else {
            NSBeep();
		}
	}
	else
	{
		RAISE_EXCEPTION(kKareliaDocumentException, @"selectedItem is of unknown class", [NSDictionary dictionaryWithObject:selectedItem forKey:@"selectedItem"]);
		return;
	}
	
	// add component to parent
	
	// label undo and perserve the current selection
	[[[self document] undoManager] setActionName:NSLocalizedString(@"Add Pagelet", @"action name for adding a page")];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification object:aPagelet];
}

/*! group the selection in a new summary */
- (void)group:(id)sender
{
	NSMutableArray *selectedPages = [[oSiteOutline selectedItems] mutableCopy];
	if ( [selectedPages count] > 0 )
    {
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		
		// do not include the top level summary in any grouping
		if ( [selectedPages objectAtIndex:0] == [(KTDocument *)[self document] root] )
		{
			[selectedPages removeObject:[(KTDocument *)[self document] root]];
		}
		id firstSelectedPage = [selectedPages objectAtIndex:0];
		
		// our group's parent will be the original parent of firstSelectedPage
		KTPage *parentCollection = [(KTPage *)firstSelectedPage parent];
		
		if ( (nil == parentCollection) || (nil == [parentCollection root]) )
		{
			NSLog(@"Unable to create group: could not determine parent collection.");
			[selectedPages release];
			return;
		}
		
		// create a new summary
		NSBundle *collectionBundle = nil;
		if ( [sender respondsToSelector:@selector(representedObject)] )
		{
			collectionBundle = [sender representedObject];
		}
		
		if ( nil == collectionBundle )
		{
			NSString *defaultIdentifier = [defaults stringForKey:@"DefaultIndexBundleIdentifier"];
			collectionBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:defaultIdentifier] bundle];
		}
				
		if ( (nil != collectionBundle) && [collectionBundle isMemberOfClass:[NSBundle class]] )
		{
			NSString *pageIdentifier = [collectionBundle objectForInfoDictionaryKey:@"KTPreferredPageBundleIdentifier"];
			NSBundle *pageBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:pageIdentifier] bundle];
			if ( nil == pageBundle )
			{
				pageIdentifier = [defaults objectForKey:@"DefaultIndexBundleIdentifier"];
				pageBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:pageIdentifier] bundle];
			}
			if ( nil == pageBundle )
			{
				NSLog(@"Unable to create group: could not locate default index.");
				[selectedPages release];
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
				[[page parent] removePage:page];
			}
            
            // now, create a new collection to hold selectedPages
			KTPage *collection = [KTPage pageWithParent:parentCollection 
												 bundle:pageBundle 
						 insertIntoManagedObjectContext:(KTManagedObjectContext *)[[self document] managedObjectContext]];
			
			
			[collection setValue:[collectionBundle bundleIdentifier] forKey:@"collectionIndexBundleIdentifier"];
			
// FIXME: we should load up the properties from a KTPreset
			
			Class indexToAllocate = [NSBundle principalClassForBundle:collectionBundle];
			KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:collection plugin:[KTAppPlugin pluginWithBundle:collectionBundle]] autorelease];
			[collection setIndex:theIndex];
			[collection setInteger:KTCollectionUnsorted forKey:@"collectionSortOrder"];				
			[collection setBool:YES forKey:@"isCollection"];
			[collection setBool:NO forKey:@"includeTimestamp"];
			
			// insert the new collection
			int insertIndex = [[[oSiteOutline itemAboveFirstSelectedRow] wrappedValueForKey:@"ordering"] intValue]+1;
			[collection setInteger:insertIndex forKey:@"ordering"];
			[parentCollection addPage:collection];
            
            // add our selectedPages back to the new collection
			for ( i=0; i < [selectedPages count]; i++ )
			{
                KTPage *page = [selectedPages objectAtIndex:i];
				[collection addPage:page];
				[page setInteger:i forKey:@"ordering"];
			}            
			
			[oSiteOutline selectItem:collection forceDidChangeNotification:YES]; /// Case 18433	// Shouldn't the SiteOutlineController handle this?
			[oSiteOutline expandSelectedRow];
			
			// tidy up the undo stack with a relevant name
			[[[self document] undoManager] setActionName:NSLocalizedString(@"Group", @"action name for grouping selected items")];
        }
		else
		{
			NSLog(@"Unable to create group: could not create default collection.");
		}
		
    }
	else
	{
        NSLog(@"Unable to create group: no selection to group.");
	}
	
	// clean up memory
	[selectedPages release];
}

// paste some raw HTML
- (IBAction)pasteTextAsMarkup:(id)sender
{
    NSString *markup = [[NSPasteboard generalPasteboard] stringForType:NSStringPboardType];
    [oWebView replaceSelectionWithMarkupString:markup ? markup : @""];
}

- (IBAction)insertList:(id)sender
{
    [oWebView replaceSelectionWithMarkupString:@"<p><ul><li></li></ul></p>"];
}

- (IBAction)insert2Table:(id)sender
{
    [oWebView replaceSelectionWithMarkupString:@"<table><tr><td></td><td></td></tr></table>"];
}



/*! removes the selected pages */
- (IBAction)remove:(id)sender
{
	NSAssert([NSThread isMainThread], @"should be main thread");
	
	// here's the naive approach
	NSArray *selectedPages = [[oSiteOutline selectedItems] copy];
	id itemAbove = [oSiteOutline itemAboveFirstSelectedRow];
	
	KTPage *selectedParent = [[[self siteOutlineController] selectedPage] parent];
	if (nil == selectedParent)
	{
		selectedParent = [(KTDocument *)[self document] root];
	}
	
	KTManagedObjectContext *context = (KTManagedObjectContext *)[selectedParent managedObjectContext];
	
	NSEnumerator *e = [selectedPages objectEnumerator];
	KTPage *object;
	while ( object = [e nextObject] )
	{
		KTPage *parent = [object parent];
		[parent removePage:object]; // this might be better done with a delete rule in the model
		LOG((@"deleting page \"%@\" from context", [object fileName]));
		[context threadSafeDeleteObject:object];
	}
	
	[context processPendingChanges];
	LOG((@"removed a save here, is it still needed?"));
//	[[self document] saveContext:context onlyIfNecessary:NO];
	
	if ( [selectedPages count] == 1 )
	{
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Remove Selected Page", @"action name for removing selected page")];
	}
	else
	{
		[[[self document] undoManager] setActionName:NSLocalizedString(@"Remove Selected Pages", @"action name for removing selected pages")];
	}
	
	[oSiteOutline selectItem:itemAbove forceDidChangeNotification:YES]; /// Case 18433	// Shouldn't the SiteOutlineController handle this?
	
	[itemAbove release];
	[selectedPages release];
}

#pragma mark -
#pragma mark Action Validation

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	//LOG((@"asking window controller to validate menu item: %@", [menuItem title]));
	
	// File menu handled by KTDocument
		
	// Edit menu
	
	// "Cut" cut:
	if ([menuItem action] == @selector(cut:))
	{
		// if there's a WebKit selection, let WebKit handle it
		if ([oWebView selectedDOMRange])
		{
			return [[self webViewController] webKitValidateMenuItem:menuItem];
		}
		else
		{
			return [self validateCutPagesItem:menuItem];
		}
	}
	
	// "Cut Page(s)" cutPages:
	else if ([menuItem action] == @selector(cutPages:))
	{
		return [self validateCutPagesItem:menuItem];
	}
	
	// "Copy" copy:
	else if ([menuItem action] == @selector(copy:))
	{
		// if there's a selection, let WebKit handle it
		if ( nil != [oWebView selectedDOMRange] )
		{
			return [[self webViewController] webKitValidateMenuItem:menuItem];
		}
		else
		{
			return [self validateCopyPagesItem:menuItem];
		}
	}	
	
	// "Copy Page(s)" copyPages:
	else if ([menuItem action] == @selector(copyPages:))
	{
		return [self validateCopyPagesItem:menuItem];
	}
	
	// "Paste" paste:
	else if ( [menuItem action] == @selector(paste:) )
	{
		// if there's a selection, let WebKit handle it
		if ( nil != [oWebView selectedDOMRange] )
		{
			return [[self webViewController] webKitValidateMenuItem:menuItem];
		}
		else
		{
			NSArray *selectedPages = [oSiteOutline selectedItems];
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
				return ([selectedPage includeSidebar] || [selectedPage includeCallout]);
			}
			else
			{
				return NO;
			}
		}
	}	
	
	// "Paste" pasteAsRichText: NB: also intercepts general "paste" command
	else if ( [menuItem action] == @selector(pasteAsRichText:) )
	{
		// check the general pasteboard to see if there are any pages on it
		NSPasteboard *generalPboard = [NSPasteboard generalPasteboard];
		NSArray *types = [generalPboard types];
		if ( nil != [generalPboard availableTypeFromArray:[NSArray arrayWithObject:kKTPagesPboardType]] )
		{
			return YES;
		}
		else if ( (nil != [oWebView selectedDOMRange]) 
				  && nil != [types firstObjectCommonWithArray:[oWebView pasteboardTypesForSelection]] )
		{
			return [[self webViewController] webKitValidateMenuItem:menuItem];
		}
		else
		{
			return NO;
		}
	}
	
	// "Paste as Plain Text" pasteAsPlainText:
	else if ( [menuItem action] == @selector(pasteAsPlainText:) )
	{
		// let WebKit handle it
		return [[self webViewController] webKitValidateMenuItem:menuItem];
	}

	// "Paste As HTML":
	else if ( [menuItem action] == @selector(pasteTextAsMarkup:) )
	{
		// let WebKit handle it ?????
		return [[self webViewController] webKitValidateMenuItem:menuItem];
	}
	
	// "Delete Page(s)" deletePage:
	else if ( [menuItem action] == @selector(deletePages:) )
	{
		if ( ![[[self window] firstResponder] isEqual:oSiteOutline] )
		{
			return NO;
		}

		KTPage *selectedPage = [[self siteOutlineController] selectedPage];
		NSArray *selectedPages = [oSiteOutline selectedItems];
		
		if ( (nil != selectedPage) && ![selectedPage isRoot] )
		{
			return YES;
		}
		else if ( ([selectedPages count] > 1) && ![selectedPages containsRoot] )
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	// "Delete Pagelet(s)" deletePagelets:
	else if ( [menuItem action] == @selector(deletePagelets:) )
	{
		KTPage *selectedPage = [[self siteOutlineController] selectedPage];
		KTPagelet *selectedPagelet = [self selectedPagelet];
		if ( (nil != selectedPagelet) && [[selectedPagelet page] isEqual:selectedPage] )
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
	
	// "Create Link..." showLinkPanel:
	else if ([menuItem action] == @selector(showLinkPanel:))
	{
		NSString *title;
		BOOL result = [[self webViewController] validateCreateLinkItem:menuItem title:&title];
		[menuItem setTitle:title];
		return result;
	}
	
	// View menu
	// "Hide Designs" toggleDesignsShown:
    else if ( [menuItem action] == @selector(toggleDesignsShown:) )
    {
        return YES;
    }
	
	// "Hide Status Bar" toggleStatusBarShown:
	
	// "Hide Site Outline" toggleSiteOutlineShown:
	else if ( [menuItem action] == @selector(toggleSiteOutlineShown:) )
	{
		return YES;
	}
	
	// "Use Small Page Icons" toggleSmallPageIcons:
    else if ( [menuItem action] == @selector(toggleSmallPageIcons:) )
	{
		[menuItem setState:
			([[self document] displaySmallPageIcons] ? NSOnState : NSOffState)];
		RBSplitSubview *sidebarSplit = [oSidebarSplitView subviewAtPosition:0];
		return ![sidebarSplit isCollapsed];	// enabled if we can see the site outline
	}
	
	// "Make Text Bigger" makeTextLarger:
	else if ( [menuItem action] == @selector(makeTextLarger:) )
	{
		return [oWebView canMakeTextLarger];
	}
	
	// "Make Text Smaller" makeTextSmaller:
	else if ( [menuItem action] == @selector(makeTextSmaller:) )
	{
		return [oWebView canMakeTextSmaller];
	}
	
	else if ( [menuItem action] == @selector(makeTextNormal:) )
	{
		return YES;
	}
	
	else if ([menuItem action] == @selector(selectWebViewViewType:))
	{
		// Select the correct item for the current view type
		KTWebViewViewType menuItemViewType = [menuItem tag];
		if (menuItemViewType == [[self webViewController] viewType]) {
			[menuItem setState:NSOnState];
		}
		else {
			[menuItem setState:NSOffState];
		}
		
		// Disable the RSS item if the current page does not support it
		BOOL result = YES;
		if (menuItemViewType == KTRSSSourceView || menuItemViewType == KTRSSView)
		{
			KTPage *page = [[self siteOutlineController] selectedPage];
			if (![page collectionCanSyndicate] || ![page boolForKey:@"collectionSyndicate"]) {
				result = NO;
			}
		}
		
		return result;
	}
	
	// Site menu items
    else if ( [menuItem action] == @selector(addPage:) )
    {
        return YES;
    }
    else if ( [menuItem action] == @selector(addPagelet:) )
    {
		KTPage *selectedPage = [[self siteOutlineController] selectedPage];
		return ([selectedPage includeCallout] || [selectedPage includeSidebar]);
    }
	else if ( [menuItem action] == @selector(addCollection:) )
    {
        return YES;
    }	
    else if ( [menuItem action] == @selector(group:) )
    {
        return ( ![[oSiteOutline selectedItems] containsObject:[(KTDocument *)[self document] root]] );
    }
    else if ( [menuItem action] == @selector(ungroup:) )
    {
		NSArray *selectedItems = [oSiteOutline selectedItems];
        return ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [(KTDocument *)[self document] root])
				 && ([[selectedItems objectAtIndex:0] isKindOfClass:[KTPage class]]) );
    }
	else if ( [menuItem action] == @selector(duplicate:) )
    {
		KTPage *selectedPage = [[self siteOutlineController] selectedPage];
		KTPagelet *selectedPagelet = [self selectedPagelet];
		if ( (nil != selectedPagelet) && [[selectedPagelet page] isEqual:selectedPage] )
		{
			// we're going to be duplicating a pagelet
			return YES;
		}
		else
		{
			// we're going to be duplicating a page or pages
			return ( ![[oSiteOutline selectedItems] containsObject:[[self document] root]] );
		}
    }
	
	// "Sync Page with Host" saveToHost:
	else if ( [menuItem action] == @selector(saveToHost:) || [menuItem action] == @selector(saveAllToHost:) )
	{
		BOOL canSave = NO;
		
		KTHostProperties *hostProperties = [[self document] valueForKeyPath:@"documentInfo.hostProperties"];
		
		if ([[hostProperties valueForKey:@"remoteHosting"] intValue])
		{
			NSString *hostName = [hostProperties valueForKey:@"hostName"];
			canSave = (nil != hostName);
		}
		if ([[hostProperties valueForKey:@"localHosting"] intValue])
		{
			canSave = YES;	// I think we can always sync 
		}
		
		return canSave;
		
	}
	
	// "Export Site..." export:
	else if ( [menuItem action] == @selector(export:)  || [menuItem action] == @selector(doExport:))	// export requires you to be set for remote hosting
    {
		return YES;
    }
	
	// "Export Site Again" exportAgain:
	else if ( [menuItem action] == @selector(exportAgain:) )	// export requires you to be set for remote hosting
    {
		// to work, we need an existing transfer controller and storage path.
		KTTransferController *exportController = [[self document] exportTransferController];
		NSString *storagePath = [exportController storagePath];
		return (nil != storagePath);
    }
	
	// Window menu
	// "Show Inspector" toggleInfoShown:
	
	// Help menu
	// Debug menu
    // Contextual menu
	else if ( ([menuItem action] == @selector(cutViaContextualMenu:))
			  || ([menuItem action] == @selector(copyViaContextualMenu:))
			  || ([menuItem action] == @selector(deleteViaContextualMenu:))
			  || ([menuItem action] == @selector(duplicateViaContextualMenu:)) )
	{
        id context = [menuItem representedObject];
        id selection = [context valueForKey:kKTSelectedObjectsKey];
		
		if ( ![selection containsRoot] )
		{
			return YES;
		}
		else
		{
			return NO;
		}
	}
    else if ( [menuItem action] == @selector(pasteViaContextualMenu:) )
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

	else if ( [menuItem action] == @selector(validateSource:) )
	{
		[menuItem setState:(KTHTMLValidationView == [[self webViewController] viewType]) ? NSOnState : NSOffState];
		return YES;
	}	
	
	// DEFAULT: let webKit handle it
	else
	{
		if ( kGeneratingPreview == [self publishingMode] )
		{
			return [[self webViewController] webKitValidateMenuItem:menuItem];
		}
		else 
		{
			return NO;
		}

	}
}

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	OFF((@"asking to validate toolbar item: %@", [toolbarItem itemIdentifier]));
	
	if ( kGeneratingPreview != [self publishingMode] )
	{
		return NO; // how can toolbars be doing anything if we're publishing?
	}	
	
    if ( [toolbarItem action] == @selector(addPage:) )
    {
        return YES;
    }
    else if ( [toolbarItem action] == @selector(addPagelet:) )
    {
		KTPage *selectedPage = [[self siteOutlineController] selectedPage];
		return ([selectedPage includeCallout] || [selectedPage includeSidebar]);
    }
    else if ( [toolbarItem action] == @selector(addCollection:) )
    {
        return YES;
    }
    else if ( [toolbarItem action] == @selector(groupAsCollection:) )
    {
        return ( ![[oSiteOutline selectedItems] containsObject:[(KTDocument *)[self document] root]] );
    }
    else if ( [toolbarItem action] == @selector(group:) )
    {
        return ( ![[oSiteOutline selectedItems] containsObject:[(KTDocument *)[self document] root]] );
    }
    else if ( [toolbarItem action] == @selector(ungroup:) )
    {
		NSArray *selectedItems = [oSiteOutline selectedItems];
        return ( (1==[selectedItems count])
				 && ([selectedItems objectAtIndex:0] != [(KTDocument *)[self document] root])
				 && ([[selectedItems objectAtIndex:0] isKindOfClass:[KTPage class]]) );
    }
    else if ( [toolbarItem action] == @selector(toggleDesignsShown:) )
    {
        return YES;
    }
    else if ( [toolbarItem action] == @selector(duplicate:) )
    {
        return ( ![[oSiteOutline selectedItems] containsObject:[[self document] root]] );
    }
	else if ([toolbarItem action] == @selector(showLinkPanel:))
	{
		NSString *label;
		BOOL result = [[self webViewController] validateCreateLinkItem:toolbarItem title:&label];
		[toolbarItem setLabel:label];
		return result;
	}
	else if ( [toolbarItem action] == @selector(saveToHost:) )
	{
		// same logic as menu validation
		BOOL canSave = NO;
		
		NSManagedObject *hostProperties = [[self document] valueForKeyPath:@"documentInfo.hostProperties"];

		// commenting out -- this makes it slow.the //NSDictionary *dict = [hostProperties dictionary];	// need a real dictionary
		
		if ([[hostProperties valueForKey:@"remoteHosting"] intValue])
		{
			NSString *hostName = [hostProperties valueForKey:@"hostName"];
			canSave = (nil != hostName);
		}
		if ([[hostProperties valueForKey:@"localHosting"] intValue])
		{
			canSave = YES;	// I think we can always sync 
		}
				
		return canSave;
	}
	
    return YES;
}

- (BOOL)validateCopyPagesItem:(id <NSValidatedUserInterfaceItem>)item
{
	BOOL result = NO;
	
	NSSet *selectedPages = [[self siteOutlineController] selectedPages];
	if (selectedPages && [selectedPages count] > 0)
	{
		result = YES;
	}
	
	return result;
}

/*	The item is enabled if at least 1 page is selected, and none of them is the home page
 */
- (BOOL)validateCutPagesItem:(id <NSValidatedUserInterfaceItem>)item
{
	BOOL result = NO;
	
	NSSet *selectedPages = [[self siteOutlineController] selectedPages];
	if (selectedPages && [selectedPages count] > 0 && ![selectedPages containsObject:[[self document] root]])
	{
		result = YES;
	}
	
	return result;
}

#pragma mark -
#pragma mark Selection

- (void)postSelectionAndUpdateNotificationsForItem:(id)aSelectableItem
{
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTItemSelectedNotification 
														object:aSelectableItem];
}

- (void)updateSelectedItemForDocWindow:(NSNotification *)aNotification
{
	OFF((@"windowController shows you selected %@", [[aNotification object] managedObjectDescription]));
	id selectedObject = [aNotification object];
	
	if ([selectedObject respondsToSelector:@selector(DOMNode)])
	{
		DOMNode *dn = [selectedObject DOMNode];
		DOMDocument *dd = [dn ownerDocument];
		DOMDocument *myDD = [[oWebView mainFrame] DOMDocument];
		if (dd != myDD)
		{
			return;		// notification is coming from a different dom document, thus differnt svx document
		}
	}
	
	if ( ![[selectedObject document] isEqual:[self document]] )
	{
		return; // notification is coming from a different document
	}
	
	if ( [selectedObject isKindOfClass:[KTInlineImageElement class]] )
	{
		[self setSelectedInlineImageElement:selectedObject];
	}
	else if ( [selectedObject isKindOfClass:[KTPagelet class]] )
	{
		[self setSelectedPagelet:selectedObject];
	}
	else	// KTPage
	{
		myDocumentVisibleRect = NSZeroRect;
		myHasSavedVisibleRect = YES;		// new page, so don't save the scroll position.
		[self setSelectedPagelet:nil];
		[self setSelectedInlineImageElement:nil];
	}
	
	[self updateEditMenuItems];
	[[NSApp delegate] updateDuplicateMenuItemForDocument:[self document]];
}

- (void)updateEditMenuItems
{
	[self updateCutMenuItem];
	[self updateCopyMenuItem];
	[self updateDeletePagesMenuItem];
}

- (void)updateCutMenuItem
{
	NSArray *selectedPages = [oSiteOutline selectedItems];
	if ([selectedPages count])
	{
		
		NSResponder *firstResponder = [[self window] firstResponder];
		// Is the first responder other than the outline view, or no pages selected? Fix the title.
		
		if ( (firstResponder != oSiteOutline) || ([selectedPages count] == 0) )
		{
			[[NSApp delegate] setCutMenuItemTitle:KTCutMenuItemTitle];
		}
		else if ( [selectedPages count] > 1 )
		{
			[[NSApp delegate] setCutMenuItemTitle:KTCutPagesMenuItemTitle];
		}
		else if ( [selectedPages count] == 1 )
		{
			[[NSApp delegate] setCutMenuItemTitle:KTCutPageMenuItemTitle];
		}
		
		// set alternate menu item, default is Cut Page
		if ( [selectedPages count] > 1 )
		{
			[[NSApp delegate] setCutPagesMenuItemTitle:KTCutPagesMenuItemTitle];
		}
		else
		{
			[[NSApp delegate] setCutPagesMenuItemTitle:KTCutPageMenuItemTitle];
		}
	}
}

- (void)updateCopyMenuItem
{
	NSArray *selectedPages = [oSiteOutline selectedItems];
	if ([selectedPages count])
	{
		NSResponder *firstResponder = [[self window] firstResponder];
		// Is the first responder other than this window, or no pages selected? Fix the title.
		
		if ( (firstResponder != oSiteOutline) || ([selectedPages count] == 0) )
		{
			[[NSApp delegate] setCopyMenuItemTitle:KTCopyMenuItemTitle];
		}
		else if ( [selectedPages count] > 1 )
		{
			[[NSApp delegate] setCopyMenuItemTitle:KTCopyPagesMenuItemTitle];
		}
		else if ( [selectedPages count] == 1 )
		{
			[[NSApp delegate] setCopyMenuItemTitle:KTCopyPageMenuItemTitle];
		}
		
		// set alternate menu item, default is Cut Page
		if ( [selectedPages count] > 1 )
		{
			[[NSApp delegate] setCopyPagesMenuItemTitle:KTCopyPagesMenuItemTitle];
		}
		else
		{
			[[NSApp delegate] setCopyPagesMenuItemTitle:KTCopyPageMenuItemTitle];
		}
	}
}

- (void)updateDeletePagesMenuItem
{
	NSArray *selectedPages = [oSiteOutline selectedItems];
	if ([selectedPages count])
	{
		if ( [selectedPages count] > 1 )
		{
			[[NSApp delegate] setDeletePagesMenuItemTitle:KTDeletePagesMenuItemTitle];
		}
		else
		{
			if ( [(KTPage *)[selectedPages objectAtIndex:0] isCollection] )
			{
				[[NSApp delegate] setDeletePagesMenuItemTitle:KTDeleteCollectionMenuItemTitle];
			}
			else
			{
				[[NSApp delegate] setDeletePagesMenuItemTitle:KTDeletePageMenuItemTitle];
			}
		}
	}
}

#pragma mark -
#pragma mark Plugins

- (KTPluginInspectorViewsManager *)pluginInspectorViewsManager
{
	if (!myPluginInspectorViewsManager)
	{
		myPluginInspectorViewsManager = [[KTPluginInspectorViewsManager alloc] init];
	}
	
	return myPluginInspectorViewsManager;
}

#pragma mark -
#pragma mark TextField Delegate

- (void)controlTextDidEndEditing:(NSNotification *)aNotification
{
	//LOG((@"controlTextDidEndEditing: %@", aNotification));
	id object = [aNotification object];
	if ( [object isEqual:oLinkDestinationField] )
	{
		/// defend against nil
		NSString *string = [[[object stringValue] stringWithValidURLScheme] trimFirstLine];
		if (nil == string) string = @"";
		[object setStringValue:string];
	}
}

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	//LOG((@"controlTextDidEndEditing: %@", aNotification));
	id object = [aNotification object];
	if ( [object isEqual:oLinkDestinationField] )
	{
		NSString *value = [[[oLinkDestinationField stringValue] stringWithValidURLScheme] trimFirstLine];
		
		BOOL empty = ( [value isEqualToString:@""] 
			 || [value isEqualToString:@"http://"] 
			 || [value isEqualToString:@"https://"] 
			 || [value isEqualToString:@"ftp://"]
					   || [value isEqualToString:@"mailto:"] );
		
		[oLinkView setConnected:!empty];
	}
}


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor;
{
	if ( [control isEqual:oLinkDestinationField] )
	{
		NSString *value = [[[oLinkDestinationField stringValue] stringWithValidURLScheme] trimFirstLine];
		
		if ( [value isEqualToString:@""] 
			 || [value isEqualToString:@"http://"] 
			 || [value isEqualToString:@"https://"] 
			 || [value isEqualToString:@"ftp://"]
			 || [value isEqualToString:@"mailto:"] )
		{
			// empty, this is OK
			return YES;
		}
		else if ( [value hasPrefix:@"mailto:"] )
		{
			// check how mailto looks.
			if ( NSNotFound == [value rangeOfString:@"@"].location )
			{
				return NO;
			}
		}
		else
		{
			// Check how URL looks.  If it's bad, beep and exit -- don't let them close.
			NSURL *checkURL = [NSURL URLWithString:[value encodeLegally]];
			NSString *host = [checkURL host];
			NSString *path = [checkURL path];
			if (NULL == checkURL
				|| (NULL == host && NULL == path) 
				|| (NULL != host && NSNotFound == [host rangeOfString:@"."].location) )
			{
				return NO;
			}
		}
	}
	return YES;
}

#pragma mark -
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

/*!	Window has become main, so we might have changed documents.  Make sure the global windows are current.
*/
- (void)windowDidBecomeMain:(NSNotification *)notification;
{
	///only update menus, which will query document contents, if we're in normal mode
	if ( kGeneratingPreview == [self publishingMode] )
	{
		// Update application menus to reflect this document
		[[NSApp delegate] updateMenusForDocument:[self document]];
		//	[[NSApp delegate] setCurrentDocument:[self document]];
	
		[self updateEditMenuItems];
	}
}

- (void)alertDidEndForWindowClosingWithTransfersInProgress:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertFirstButtonReturn) {
		NSLog(@"terminating transfers");
		[[self document] terminateConnections];
		[[self window] performClose:nil];
	}
}

- (BOOL)windowShouldClose:(id)sender
{
	//see if there are any transfers in progress
	if ([[self document] connectionsAreConnected]) {
		NSAlert *cancelUpload = [NSAlert alertWithMessageText:NSLocalizedString(@"Publishing in Progress", @"Window Will Close")
												defaultButton:NSLocalizedString(@"Finish", @"Window will close")
											  alternateButton:NSLocalizedString(@"Ignore", @"Window will close")
												  otherButton:nil
									informativeTextWithFormat:NSLocalizedString(@"Files are currently getting published to your host. Would you like to finish the publishing first?", @"Window will close")];
		[cancelUpload setAlertStyle:NSWarningAlertStyle];
		[cancelUpload beginSheetModalForWindow:[self window]
								 modalDelegate:self
								didEndSelector:@selector(alertDidEndForWindowClosingWithTransfersInProgress:returnCode:contextInfo:)
								   contextInfo:nil];
		return NO;
	}
	return YES;
}

- (void)windowWillClose:(NSNotification *)notification;
{
//	[[NSApp delegate] setCurrentDocument:nil];

	if ( ![[NSApp delegate] appIsTerminating] )
	{
		// Empty out the windowScriptObject, remove the pointer to self to kill reference loop
		// NOT WORKING THOUGH
		
		// Case 9274, kludge approach to Graham's suggestion
		if ([[[self webViewController] windowScriptObject] retainCount] == 1)
		{
			[[self webViewController] setWindowScriptObject:nil];
		}
		else
		{
			[[[self webViewController] windowScriptObject] removeWebScriptKey:@"helper"];	// bugzilla # 6152 ... ought to release old value
		}
	}

	[oDocumentController unbind:@"contentObject"];
	[oKeywordsField unbind:@"value"];			// balance out the bind in code
	[oDocumentController setContent:nil];
}

/*!	Notification that some window is closing
*/
- (void)anyWindowWillClose:(NSNotification *)aNotification
{
	id obj = [aNotification object];
	if (obj == [[KTInfoWindowController sharedControllerWithoutLoading] window])
	{
		NSRect frame = [obj frame];
		NSPoint topLeft = NSMakePoint(frame.origin.x, frame.origin.y+frame.size.height);
		NSString *topLeftAsString = NSStringFromPoint(topLeft);
		[[NSUserDefaults standardUserDefaults] setObject:topLeftAsString forKey:gInfoWindowAutoSaveName];

		[[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"DisplayInfo"];
		[[NSApp delegate] setDisplayInfoMenuItemTitle:KTShowInfoMenuItemTitle];
	}
	else if (obj == [[iMediaBrowser sharedBrowserWithoutLoading] window])
	{
		[[NSApp delegate] setDisplayMediaMenuItemTitle:KTShowMediaMenuItemTitle];
	}
	else if ([[aNotification object] isKindOfClass:[KTDocWindow class]])
	{
		;  // taken care of from standard one
	}
	else
	{
		// LOG((@"windowWillClose --> %@", [aNotification object]));
	}
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize
{
	NSSize result = proposedFrameSize;
	RBSplitSubview *leftView = [oSidebarSplitView subviewAtPosition:0];
	
	if (![leftView isCollapsed])	// not collapsed -- see if we can do this
	{
		float currentWidth = [sender frame].size.width;
		if (proposedFrameSize.width < currentWidth)	// we're shrinking
		{
			RBSplitSubview *rightView = [oSidebarSplitView subviewAtPosition:1];
			float minimumWidths = [rightView minDimension] + [leftView minDimension];
			
			// Only allow shrinking if we're N pixels moved over, making it kind of hard to shrink.
			if (proposedFrameSize.width < minimumWidths ) // && proposedFrameSize.width > minimumWidths - 100)
			{
				result = NSMakeSize(currentWidth, proposedFrameSize.height);
				// Slightly smaller than minimum, don't let it shrink to that size.
			}
		}
	}
	return result;
}

#pragma mark -
#pragma mark Undo

/*	We observe notifications from the document's undo manager
 */
- (void)setDocument:(NSDocument *)document
{
	NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
	
	[notificationCenter removeObserver:self
								  name:NSUndoManagerWillCloseUndoGroupNotification
								object:[[self document] undoManager]];
	
	[super setDocument:document];
	
	[notificationCenter addObserver:self
						   selector:@selector(undoManagerWillCloseUndoGroup:)
						       name:NSUndoManagerWillCloseUndoGroupNotification
							 object:[document undoManager]];
}

/*	Called whenever a change is undone. Ensure the correct page is highlighted in the Site Outline to show the change.
 */
- (void)undo_selectPagesWithIDs:(NSSet *)pageIDs scrollPoint:(NSPoint)scrollPoint
{
	// Select the pages in the Site Outline; the rest is taken care of for us
	NSManagedObjectContext *moc = [[self document] managedObjectContext];
	NSMutableSet *pages = [NSMutableSet setWithCapacity:[pageIDs count]];
	
	NSEnumerator *pagesEnumerator = [pageIDs objectEnumerator];
	NSString *aPageID;
	while (aPageID = [pagesEnumerator nextObject])
	{
		KTPage *aPage = [KTPage pageWithUniqueID:aPageID inManagedObjectContext:moc];
		[pages addObjectIgnoringNil:aPage];
	}
	
	[[self siteOutlineController] setSelectedPages:pages];
	
	
	// Record what to do when redoing/undoing the change again
	NSUndoManager *undoManager = [[self document] undoManager];
	[[undoManager prepareWithInvocationTarget:self] undo_selectPagesWithIDs:pageIDs scrollPoint:scrollPoint];
}

- (void)undoManagerWillCloseUndoGroup:(NSNotification *)notification
{
	NSUndoManager *undoManager = [notification object];
	
	// When ending the top level undo group, record the selected pages
	if ([undoManager groupingLevel] == 1)
	{
		NSSet *pageIDs = [[[self siteOutlineController] selectedPages] valueForKey:@"uniqueID"];
		
		// Figuring out the scroll point is a little trickier
		NSPoint scrollPoint = NSZeroPoint;
		WebView *webView = [[self webViewController] webView];
		NSView <WebDocumentView> *documentView = [[[webView mainFrame] frameView] documentView];
		NSClipView *clipView = (NSClipView *)[documentView superview];
		if ([clipView isKindOfClass:[NSClipView class]])
		{
			scrollPoint = [clipView documentVisibleRect].origin;
		}
		
		[[undoManager prepareWithInvocationTarget:self] undo_selectPagesWithIDs:pageIDs scrollPoint:scrollPoint];
	}
}

#pragma mark -
#pragma mark Components

- (BOOL)addPagesViaDragToCollection:(KTPage *)aCollection atIndex:(int)anIndex draggingInfo:(id <NSDraggingInfo>)info
{
	// LOG((@"%@", NSStringFromSelector(_cmd) ));

	[[self document] suspendAutosave];

	BOOL result = NO;	// set to YES if at least one item got processed
	int numberOfItems = [KTAbstractDataSource numberOfItemsToProcessDrag:info];
	
	/*
	/// Mike: I see no point in this artificial limit in 1.5
	int maxNumberDragItems = [defaults integerForKey:@"MaximumDraggedPages"];
	numberOfItems = MIN(numberOfItems, maxNumberDragItems);
	*/
	KTPage *latestPage = nil; //only select the last page created
	
	@synchronized ( [self addingPagesViaDragPseudoLock] )
	{
		[[[self document] managedObjectContext] lockPSCAndSelf];
// TODO: it would be nice if we could do the ordering insert just once ahead of time, rather than once per "insertPage:atIndex:"
		
		NSString *localizedStatus = NSLocalizedString(@"Creating pages...", "");
		BOOL didDisplayProgressIndicator = NO;
		if ( numberOfItems > 3 )
		{
			[self beginSheetWithStatus:localizedStatus
							  minValue:0 
							  maxValue:numberOfItems 
								 image:nil];
			didDisplayProgressIndicator = YES;
		}
				
		int i;
		for ( i = 0 ; i < numberOfItems ; i++ )
		{
			NSAutoreleasePool *poolForEachDrag = [[NSAutoreleasePool alloc] init];

			if ( didDisplayProgressIndicator )
			{
				[self updateSheetWithStatus:localizedStatus progressValue:i];
			}
			
			KTAbstractDataSource *bestSource = [KTAbstractDataSource highestPriorityDataSourceForDrag:info index:i isCreatingPagelet:NO];
			if ( nil != bestSource )
			{
				NSMutableDictionary *dragDataDictionary = [NSMutableDictionary dictionary];
				[dragDataDictionary setValue:[info draggingPasteboard] forKey:kKTDataSourcePasteboard];	// always include this!
				
				BOOL didPerformDrag;
				didPerformDrag = [bestSource populateDictionary:dragDataDictionary forPagelet:NO fromDraggingInfo:info index:i];
				NSString *theBundleIdentifier = [bestSource pageBundleIdentifier];
				
				if ( didPerformDrag && (nil != theBundleIdentifier) )
				{
					NSBundle *theBundle = [[[[NSApp delegate] bundleManager] pluginWithIdentifier:theBundleIdentifier] bundle];
					if ( nil != theBundle )
					{
						[dragDataDictionary setObject:theBundle forKey:kKTDataSourceBundle];
						
						KTPage *newPage = [KTPage pageWithParent:aCollection
											dataSourceDictionary:dragDataDictionary
								  insertIntoManagedObjectContext:(KTManagedObjectContext *)[[self document] managedObjectContext]];
						
						if ( nil != newPage )
						{
							int insertIndex = anIndex+i;		// add 1 to the index so we will always go after the next one
							if ( NSOutlineViewDropOnItemIndex == anIndex )
							{
								// add at end
								insertIndex = [[aCollection children] count];
							}
							
							// insert the page where indicated
							[aCollection addPage:newPage];
							
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
								NSBundle *indexBundle = [[KTIndexPlugin pluginWithIdentifier:defaultIdentifier] bundle];
								
// FIXME: we should load up the properties from a KTPreset
								
								[newPage setValue:[indexBundle bundleIdentifier] forKey:@"collectionIndexBundleIdentifier"];
								Class indexToAllocate = [NSBundle principalClassForBundle:indexBundle];
								KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:newPage plugin:[KTAppPlugin pluginWithBundle:indexBundle]] autorelease];
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
					LOG((@"%@ did not accept drop, no child returned", [bestSource className]));
				}
			}
			else
			{
				LOG((@"No datasource agreed to handle types: %@", [[[info draggingPasteboard] types] description]));
			}
			
			[poolForEachDrag release];
		}
		LOG((@"removed a save here, is it still needed?"));
//		[[self document] saveContext:(KTManagedObjectContext *)[[self document] managedObjectContext] onlyIfNecessary:YES];
		
		if ( didDisplayProgressIndicator )
		{
			[self endSheet];
		}
		
		[[[self document] managedObjectContext] unlockPSCAndSelf];
	}
	
	// if not dropping on an item, set the selection to the last page created
	if ( latestPage != nil )
	{
		if (aCollection != (KTPage *)[[self document] root])
		{
			[oSiteOutline expandItem:aCollection];
		}
		[oSiteOutline selectItem:latestPage forceDidChangeNotification:YES]; /// Case 18433	// Shouldn't the SiteOutlineController handle this?
	}
	
	// Done
	[KTAbstractDataSource doneProcessingDrag];
	[[self document] resumeAutosave];
	
	return result;
}

#pragma mark -
#pragma mark Code Injection

- (KTCodeInjectionController *)masterCodeInjectionController
{
	if (!myMasterCodeInjectionController)
	{
		myMasterCodeInjectionController =
			[[KTCodeInjectionController alloc] initWithSiteOutlineController:[self siteOutlineController] master:YES];
		
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
			[[KTCodeInjectionController alloc] initWithSiteOutlineController:[self siteOutlineController] master:NO];
		
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


- (void)showDesigns:(BOOL)inShow
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"DoAnimations"])
	{
		if ( inShow )
		{
			[oDesignsSplitPane expandWithAnimation];
		}
		else
		{
			[oDesignsSplitPane collapseWithAnimation];
		}
	}
	else
	{
		if ( inShow )
		{
			[oDesignsSplitPane expand];
		}
		else
		{
			[oDesignsSplitPane collapse];
		}
	}
}

- (void)showStatusBar:(BOOL)inShow
{
    if ( inShow ) {
        // show status bars
        // add status bar back as a subview
        // resize the two views in the frame
		[oStatusBar setHidden:NO];
		
		NSRect webViewFrame = [oWebView frame];
		float statusBarHeight = [oStatusBar frame].size.height;
		webViewFrame.size.height -= statusBarHeight;
		webViewFrame.origin.y += statusBarHeight;
		[oWebView setFrame:webViewFrame];
		[oWebView setNeedsDisplay:YES];
    }
    else {
        // hide status bars
		
		[oStatusBar setHidden:YES];
		
		NSRect webViewFrame = [oWebView frame];
		float statusBarHeight = [oStatusBar frame].size.height;
		webViewFrame.size.height += statusBarHeight;
		webViewFrame.origin.y -= statusBarHeight;
		[oWebView setFrame:webViewFrame];
		[oWebView setNeedsDisplay:YES];
    }
	
}

/*!	Show the info, in whatever is the current configuration.  Close other things not showing.
*/
- (void)showInfo:(BOOL)inShow
{
	if (inShow)	// show separate info
	{
		KTInfoWindowController *sharedController = [KTInfoWindowController sharedController];
		[sharedController setAssociatedDocument:[self document]];
		if (nil != mySelectedInlineImageElement)
		{
			[sharedController setupViewStackFor:mySelectedInlineImageElement selectLevel:NO];
		}
		else if (nil != mySelectedPagelet)
		{
			[sharedController setupViewStackFor:mySelectedPagelet selectLevel:NO];
		}
		else if ([[self siteOutlineController] selectedPage])
		{
			[sharedController setupViewStackFor:[[self siteOutlineController] selectedPage] selectLevel:NO];
		}
		
		[sharedController putContentInWindow];
		
		if (![[sharedController window] isVisible])
		{
			NSString *topLeftAsString = [[NSUserDefaults standardUserDefaults] objectForKey:gInfoWindowAutoSaveName];
			if ( nil != topLeftAsString )
			{
				NSWindow *window = [sharedController window];
				NSPoint topLeft = NSPointFromString(topLeftAsString);
				NSRect screenRect = [[window screen] visibleFrame];
				NSRect frame = [window frame];
				frame.origin = topLeft;
				if (!NSContainsRect(screenRect, frame))
				{
					if (NSMaxX(frame) > NSMaxX(screenRect))
					{
						frame.origin.x -= (NSMaxX(frame) - NSMaxX(screenRect));	// right edge
					}
					if (NSMaxY(frame) > NSMaxY(screenRect))
					{
						frame.origin.y = NSMaxY(screenRect);	// top edge
					}
					if (NSMinX(frame) < NSMinX(screenRect))
					{
						frame.origin.x = NSMinX(screenRect);	// left edge
					}
					if (NSMinY(frame) < NSMinY(screenRect))
					{
						frame.origin.y = NSMinY(screenRect) + frame.size.height;	// bottom edge
					}
				}
				[window setFrameTopLeftPoint:frame.origin];
			}
			[sharedController showWindow:nil];
		}
	}
	else	// hide
	{
		KTInfoWindowController *sharedControllerMaybe = [KTInfoWindowController sharedControllerWithoutLoading];
 		if (sharedControllerMaybe)
		{

			NSRect frame = [[sharedControllerMaybe window] frame];
			NSPoint topLeft = NSMakePoint(frame.origin.x, frame.origin.y+frame.size.height);
			NSString *topLeftAsString = NSStringFromPoint(topLeft);
			[[NSUserDefaults standardUserDefaults] setObject:topLeftAsString forKey:gInfoWindowAutoSaveName];

			[[sharedControllerMaybe window] orderOut:nil];
		}
	}
}

//- (void)infoWindowMayNeedRefreshing:(NSNotification *)aNotification
//{
//	KTDocument *document = [aNotification object];
//	if ( [document isEqual:[self document]] )
//	{
//		KTInfoWindowController *sharedController = [KTInfoWindowController sharedInfoWindowController];
//		[sharedController setAssociatedDocument:[self document]];
//		if (nil != mySelectedInlineImageElement)
//		{
//			[sharedController setupViewStackFor:mySelectedInlineImageElement];
//		}
//		else if (nil != mySelectedPagelet)
//		{
//			[sharedController setupViewStackFor:mySelectedPagelet];
//		}
//		else if (nil != mySelectedPage)
//		{
//			[sharedController setupViewStackFor:mySelectedPage];
//		}	
//	}
//}

- (void)logStaleness:(id)sender
{
	[[self document] logStaleness:sender];
}

- (BOOL)isSuspendingUIUpdates
{
	return myIsSuspendingUIUpdates;
}

- (void)suspendUIUpdates
{
	//LOG((@"deactivating UI updates"));
	[myUpdateLock lock];
	myIsSuspendingUIUpdates = YES;
}

- (void)resumeUIUpdates
{
	//LOG((@"(re)activating UI updates"));
	[myUpdateLock unlock];
	myIsSuspendingUIUpdates = NO;
}

// the goal here will be to clear the HTML markup from the pasteboard before pasting,
// if we can just get this to work!
- (void)handleEvent:(DOMEvent *)event;
{
	LOG((@"event= %@", event));
}

@end

