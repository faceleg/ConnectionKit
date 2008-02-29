//
//  KTDocument.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Standard NSDocument subclass to handle a single web site.
	(Core functionality of the document is handled in this file)
	Deals with:
 General UI
 DataCrux
 File I/O
 Menu & Toolbar
 Accessors
 Actions
 WebView Notifications
 
 
 TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	Inherits from NSDocument
	Delegate of the webview
 
 IMPLEMENTATION NOTES & CAUTIONS:
	The WebView notifications ought to be in a category, but for some strange reason,
	they aren't found there, so we have to put them into the main class!
 
 */

/*!
 @class KTDocument
 @abstract An NSPersistentDocument subclass that encapsulates functionality for a single website.
 @discussion An NSPersistentDocument subclass that encapsulates functionality for a single website. Major areas of responsibility include General UI, CoreData and additional File I/O, Menu and Toolbar, Accessors, Actions, and WebView Notifications.
 @updated 2005-03-12
 */

#import "KTDocument.h"

#import "Debug.h"
#import "KT.h"
#import "KTAppDelegate.h"

#import "KTAppPlugin.h"
#import "KTBundleManager.h"
#import "KTElementPlugin.h"
#import "KTIndexPlugin.h"

#import "KTCodeInjectionController.h"

#import "KTAbstractBugReporter.h"
#import "KTDesignManager.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocumentController.h"
#import "KTHTMLInspectorController.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "KTInfoWindowController.h"
#import "KTMaster.h"
#import "KTMediaManager+Internal.h"
#import "KTStalenessManager.h"
#import "KTTransferController.h"
#import "KTUtilities.h"
#import "NSBundle+Karelia.h"
#import "KTAbstractIndex.h"
#import "KSSilencingConfirmSheet.h"
#import "KTManagedObjectContext.h"
#import "KTPage.h"
#import "NSArray+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSApplication+Karelia.h"

#import <iMediaBrowser/iMediaBrowser.h>

#import "Registration.h"

//#import "KTUndoManager.h"

@interface KTDocument ( Private )
+ (void)initialize;
- (BOOL)keepBackupFile;
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel;
- (IBAction)saveAllToHost:(id)sender;
- (IBAction)saveToHost:(id)sender;
- (KTTransferController *)localTransferController;
- (KTTransferController *)remoteTransferController;
- (void)setExportTransferController:(KTTransferController *)anExportTransferController;

- (NSArray *)bundleIdentifiersRequiredByPlugin:(id)aPlugin;
- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation;
- (NSError *)willPresentError:(NSError *)inError;
- (NSMutableSet *)bundlesRequiredByPlugin:(id)aPlugin;
- (NSString *)defaultStoreFileName;
- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType;

- (id)init;
- (id)initForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError;
- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
- (id)initWithType:(NSString *)type error:(NSError **)error;

- (void)close;
- (void)dealloc;

- (void)insertPage:(KTPage *)aPage parent:(KTPage *)aCollection;
- (void)makeWindowControllers;
- (void)setDocument:(KTDocument *)aDocument;
- (void)setLocalTransferController:(KTTransferController *)aLocalTransferController;
- (void)setPluginInspectorViews:(NSMutableDictionary *)aDictionary;
- (void)setRemoteTransferController:(KTTransferController *)aRemoteTransferController;
- (void)setupHostSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;
- (void)setupTransferControllers;
- (void)windowControllerWillLoadNib:(NSWindowController *)windowController;

- (void)setSiteCachePath:(NSString *)aPath;
- (void)setSnapshotPath:(NSString *)aPath;
- (NSDate *)lastSnapshotDate;

// Saving
- (void)quickLookThumbnailWebViewIsFinishedWith;

@end


@implementation KTDocument

#pragma mark init

/*! designated initializer for all NSDocument instances. Common initialization to new doc and opening a doc */
- (id)init
{
	if (gLicenseViolation)
	{
		NSBeep();
		return nil;
	}
	
    if ( nil != [super init] )
	{
		// set up autosave
		myIsSuspendingAutosave = NO;
		
		// we always start in preview
		[[self windowController] setPublishingMode:kGeneratingPreview];
		
		
		// Init UI accessors
		NSNumber *tmpValue = [self wrappedInheritedValueForKey:@"displaySiteOutline"];
		[self setDisplaySiteOutline:(tmpValue) ? [tmpValue boolValue] : YES];
		
		tmpValue = [self wrappedInheritedValueForKey:@"displayStatusBar"];
		[self setDisplayStatusBar:(tmpValue) ? [tmpValue boolValue] : YES];
		
		tmpValue = [self wrappedInheritedValueForKey:@"displayEditingControls"];
		[self setDisplayEditingControls:(tmpValue) ? [tmpValue boolValue] : YES];
		
		tmpValue = [self wrappedInheritedValueForKey:@"displaySmallPageIcons"];
		[self setDisplaySmallPageIcons:(tmpValue) ? [tmpValue boolValue] : NO];
		
		
		// Initialize the sidebar caches
		myTopSidebarsCache = [[NSMutableDictionary alloc] init];
		myBottomSidebarsCache = [[NSMutableDictionary alloc] init];
		
#ifdef DEBUG
		// custom undo manager for debugging only
		//		KTUndoManager *undoManager = [[[KTUndoManager alloc] init] autorelease];
		//		[self setUndoManager:undoManager];
		//		[undoManager setDocument:self];
#endif
    }
	
    return self;
}

/*! initializer for creating a new document
	NB: this is not shown on screen
 */
- (id)initWithType:(NSString *)type error:(NSError **)error
{
 	// Do nothing if the license is invalid
	if (gLicenseViolation) {
		NSBeep();
		*error = nil;	// Otherwise we crash	// TODO: Perhaps actually return an error
		[self release];	return nil;
	}
	
	
	// Ask the user for the location and home page type of the document
	NSSavePanel *savePanel = [NSSavePanel savePanel];
	[savePanel setTitle:NSLocalizedString(@"New Site", @"Save Panel Title")];
	[savePanel setPrompt:NSLocalizedString(@"Create", @"Create Button")];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:kKTDocumentExtension];
	[savePanel setCanCreateDirectories:YES];
	
	[[NSBundle mainBundle] loadNibNamed:@"NewDocumentAccessoryView" owner:self];
	[savePanel setAccessoryView:oNewDocAccessoryView];
	
	NSSet *pagePlugins = [[[NSApp delegate] bundleManager] pagePlugins];
	[[[NSApp delegate] bundleManager] addPlugins:pagePlugins
									      toMenu:[oNewDocHomePageTypePopup menu]
									      target:nil
									      action:nil
									   pullsDown:NO
									   showIcons:NO];
	
	int saveResult = [savePanel runModalForDirectory:nil file:nil];
	if (saveResult == NSFileHandlingPanelCancelButton) {
		*error = nil;	// Otherwise we crash
		[self release];	return nil;
	}
		
	
	//  Put up a progress bar
	NSImage *newDocumentImage = [NSImage imageNamed:@"document.icns"];
	NSString *progressMessage = NSLocalizedString(@"Creating Site...",@"Creating Site...");
	[[NSApp delegate] showGenericProgressPanelWithMessage:progressMessage image:newDocumentImage];
		
	
	@try
	{
		// Do we already have a file there? Remove it.
		NSURL *saveURL = [savePanel URL];
		if ([[NSFileManager defaultManager] fileExistsAtPath:[saveURL path]])
		{
			// is saveURL path writeable?
			if (![[NSFileManager defaultManager] isWritableFileAtPath:[saveURL path]])
			{
				NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"Unable to create new document.",@"Alert: Unable to create new document.")]
							  forKey:NSLocalizedDescriptionKey]; // message text
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"The path %@ is not writeable.",@"Alert: The path %@ is not writeable."), [saveURL path]]
							  forKey:NSLocalizedFailureReasonErrorKey]; // informative text
				*error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:errorInfo];
				
				[self release];
				return nil;
			}
			
			if (![[NSFileManager defaultManager] removeFileAtPath:[saveURL path] handler:nil])
			{
				
				//  put up an error that the previous file could not be overwritten
				NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"Unable to create new document.",@"Alert: Unable to create new document.")]
							  forKey:NSLocalizedDescriptionKey]; // message text
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"Could not remove pre-existing file at path %@.",@"Alert: Could not remove pre-existing file at path %@."), [saveURL path]]
							  forKey:NSLocalizedFailureReasonErrorKey]; // informative text
				
				*error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:errorInfo];
				
				[self release];
				return nil;
			}
		}
		
		
		// Create the document
		[super initWithType:type error:error];
		[[NSDocumentController sharedDocumentController] addDocument:self];	// So managed objects can access their document during init.
		
		
		// Is this path a currently open document? if yes, close it!
		NSDocument *openDocument = [[NSDocumentController sharedDocumentController] documentForURL:saveURL];
		if (openDocument)
		{
			[openDocument canCloseDocumentWithDelegate:nil shouldCloseSelector:NULL contextInfo:nil];
			[openDocument close];
		}	
			
			
		// Make a new documentInfo to store document properties
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		KTDocumentInfo *documentInfo = [NSEntityDescription insertNewObjectForEntityForName:@"DocumentInfo" inManagedObjectContext:context];
		[self setDocumentInfo:documentInfo];
		[self setDocumentID:[documentInfo valueForKey:@"siteID"]];
		
		NSDictionary *docProperties = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultDocumentProperties"];
		if (docProperties)
		{
			[documentInfo setValuesForKeysWithDictionary:docProperties];
		}
		
		// make a new root
		NSBundle *defaultRootBundle = [[[oNewDocHomePageTypePopup selectedItem] representedObject] bundle];
		NSAssert(defaultRootBundle, @"No root bundle for new site");
		// POSSIBLE PROBLEM -- THIS WON'T WORK WITH EXTERALLY LOADED BUNDLES...
		[defaultRootBundle load];
		
		KTPage *root = [KTPage rootPageWithDocument:self bundle:defaultRootBundle];
		NSAssert((nil != root), @"root page is nil!");
		[self setRoot:root];
		[[self documentInfo] setValue:root forKey:@"root"];
		
		// Create the site Master object
		KTMaster *master = [NSEntityDescription insertNewObjectForEntityForName:@"Master" inManagedObjectContext:[self managedObjectContext]];
		[root setValue:master forKey:@"master"];
		
		// Set the design
		KTDesign *design = [[[[KTAppDelegate sharedInstance] designManager] sortedDesigns] firstObject];
		[master setDesign:design];		

		// set up root properties that used to come from document defaults
		[master setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"author"] forKey:@"author"];
		[root setBool:YES forKey:@"isCollection"];
		
		[master setValue:[self language] forKey:@"language"];
		[master setValue:[self charset] forKey:@"charset"];
		
		NSString *subtitle = [[NSBundle mainBundle] localizedStringForString:@"siteSubtitleHTML"
																	language:[master valueForKey:@"language"]
			fallback:NSLocalizedStringWithDefaultValue(@"siteSubtitleHTML",
													   nil,
													   [NSBundle mainBundle],
													   @"This is the subtitle for your site.",
													   @"Default introduction statement for a page")];
		[master setValue:subtitle forKey:@"siteSubtitleHTML"];
		
		// set initial required bundles
		[self setRequiredBundlesIdentifiers:[NSSet setWithObject:[defaultRootBundle bundleIdentifier]]];
		
	// FIXME: we should load up the properties from a KTPreset
		[root setBool:NO forKey:@"includeTimestamp"];
		[root setInteger:KTCollectionUnsorted forKey:@"collectionSortOrder"];
		[root setBool:NO forKey:@"collectionSyndicate"];
		[root setInteger:0 forKey:@"collectionMaxIndexItems"];
		[root setBool:NO forKey:@"collectionShowPermanentLink"];
		[root setBool:YES forKey:@"collectionHyperlinkPageTitles"];		
		[root setTitleText:[self defaultRootPageTitleText]];
		
		// Make the initial Sandvox badge
		NSString *initialBadgeBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBadgeBundleIdentifier"];
		if (nil != initialBadgeBundleID && ![initialBadgeBundleID isEqualToString:@""])
		{
			KTElementPlugin *badgePlugin = [KTAppPlugin pluginWithIdentifier:initialBadgeBundleID];
			if (badgePlugin)
			{
				KTPagelet *pagelet = [KTPagelet pageletWithPage:root plugin:badgePlugin];
				[pagelet setPrefersBottom:YES];
			}
		}
		
		NSString *defaultRootIndexIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultRootIndexBundleIdentifier"];
		if (nil != defaultRootIndexIdentifier && ![defaultRootIndexIdentifier isEqualToString:@""])
		{
			NSBundle *bundle = [[KTIndexPlugin pluginWithIdentifier:defaultRootIndexIdentifier] bundle];
			if (nil != bundle)
			{
				[root setValue:defaultRootIndexIdentifier forKey:@"collectionIndexBundleIdentifier"];
				
				Class indexToAllocate = [NSBundle principalClassForBundle:bundle];
				KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:root plugin:[KTAppPlugin pluginWithBundle:bundle]] autorelease];
				[root setIndex:theIndex];
			}
		}
		
		[self setLocalTransferController:nil];		// make sure to clear old settings after we have some host properties
		[self setRemoteTransferController:nil];
		[self setExportTransferController:nil];
		
		// no snapshot/backup on opening new document
		mySnapshotOrBackupUponFirstSave = KTNoBackupOnOpening;
		
		
		//  Set the site title
		NSString *siteName = [[NSFileManager defaultManager] displayNameAtPath:[[saveURL path] stringByDeletingPathExtension]];
		[master setValue:siteName forKey:@"siteTitleHTML"];
		
		
		// Set the Favicon
		NSString *faviconPath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
		KTMediaContainer *faviconMedia = [[root mediaManager] mediaContainerWithPath:faviconPath];
		[master setValue:[faviconMedia identifier] forKey:@"faviconMediaIdentifier"];
		
		
		// Save ourself
		BOOL didSave = [self saveToURL:saveURL 
								 ofType:kKTDocumentExtension 
					   forSaveOperation:NSSaveAsOperation
								  error:error];
		if (!didSave) {
			[self release];	return nil;
		}
		
		
		// Hide the doc's extension if requested
		if ([savePanel isExtensionHidden])
		{
			[[NSFileManager defaultManager] performSelector:@selector(setExtensionHiddenAtPath:)
												 withObject:[saveURL path]
												 afterDelay:1.0];
		}
	}
	@finally
	{
		// Hide the progress window
		[[NSApp delegate] hideGenericProgressPanel];
	}
	
	return self;
}

/*! initializer for opening an existing document */
- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	if (gLicenseViolation)
	{
		NSBeep();
		return nil;
	}
	
	// now, open document
	self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError];
	if ( nil != self )
	{
		if ( [[self documentInfo] boolForKey:@"isNewDocument"] )
		{
			[self setShowDesigns:YES];	// new doc needs designs showing initially
			[[self documentInfo] setValue:[NSNumber numberWithBool:NO] forKey:@"isNewDocument"];
		}
		else
		{
			[self setShowDesigns:NO];	// assume doc already opened doesn't need to show designs initially
		}
		
		// cache documentID, we use it often, we don't want to fetch it every time
		NSString *siteID = [[self documentInfo] valueForKey:@"siteID"];
		[self setDocumentID:siteID];
		
		// establish autosave notifications
		[self observeNotificationsForContext:(KTManagedObjectContext *)[self managedObjectContext]];
		
		[[self stalenessManager] performSelector:@selector(beginObservingAllPages) withObject:nil afterDelay:0.0];
		
		// remember this as an open document
		[[KTAppDelegate sharedInstance] performSelector:@selector(updateLastOpened)
											 withObject:nil
											 afterDelay:0.0];
		
		// A little bit of repair; we need to have language stored in the root if it's not there
		if (![[[self root] master] valueForKey:@"language"])
		{
			[[[self root] master] setValue:[self language] forKey:@"language"];
		}

		// For diagnostics, log the value of the host properties
		// TODO: use a default to decide whether to log this and make the default be NO
		NSLog(@"hostProperties = %@", [self valueForKeyPath:@"documentInfo.hostProperties"]);
		
		// note whether we should backup/snapshot before document (any context) is first saved
		mySnapshotOrBackupUponFirstSave  = [[NSUserDefaults standardUserDefaults] integerForKey:@"BackupOnOpening"];
	}
	
	return self;
}

#pragma mark dealloc

- (void)dealloc
{
	if ( ![NSThread isMainThread] )
	{
		LOG((@"dealloc'ing documenet via background thread? why? will this result in a pool problem? draino!"));
	}
	
	// no more notifications
	// TODO: FIXME: Chris Hanson indicates that we should be removing each specific observation
	// rather than doing blanket removal
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// no more saving
	[self cancelAndInvalidateAutosaveTimers]; // invalidates and releases myAutosaveTimer
    [myLastSavedTime release]; myLastSavedTime = nil;
	
	[oNewDocAccessoryView release];
		
    [self setDocumentInfo:nil];
	[self setDocumentID:nil];
    [self setRoot:nil];

	[myMediaManager release];
	[myPluginDelegatesManager release];
	[self quickLookThumbnailWebViewIsFinishedWith];
	
    [self setLocalTransferController:nil];
    [self setRemoteTransferController:nil];
    [self setExportTransferController:nil];
    [self setSiteCachePath:nil];
	[self setSnapshotPath:nil];
	
	[myStalenessManager stopObservingAllPages];
	[myStalenessManager release];
	
	// Empty sidebar caches
	[myTopSidebarsCache release];
	[myBottomSidebarsCache release];
	
	// release context
	[myManagedObjectContext release]; myManagedObjectContext = nil;
	
	// release model last
	[myManagedObjectModel release]; myManagedObjectModel = nil;
	
	[super dealloc];
}

/*! returns root as a single page array, used in DebugTable bindings */
- (NSArray *)rootAsArray
{
	return [NSArray arrayWithObject:[self root]];
}

#pragma mark -
#pragma mark Public Functions

/*! return the single KTDocWindowController associated with this document */
- (KTDocWindowController *)windowController
{
	//NSAssert(nil != myDocWindowController, @"windowController should not be nil");
	return myDocWindowController;
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel
{
	[savePanel setTitle:NSLocalizedString(@"New Site","Save Panel Title")];
	[savePanel setPrompt:NSLocalizedString(@"Create","Create Button")];
	[savePanel setTreatsFilePackagesAsDirectories:NO];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:(NSString *)kKTDocumentExtension];
	
    return YES;
}

/*!	Returns the base of the url like http://mysite.mydomain.com/~user/thisSite/ 
 */
- (NSString *)publishedSiteURL
{
	NSString *result = @"http://unpublished.example.com/";
	KTHostProperties *hostProperties = [self valueForKeyPath:@"documentInfo.hostProperties"];
	
	NSString *remoteSiteURL = [hostProperties remoteSiteURL];
	if (nil != remoteSiteURL)
	{
		result = remoteSiteURL;
	}
	else
	{
		NSString *globalSiteURL = [hostProperties globalSiteURL];
		if (nil != globalSiteURL)
		{
			result = globalSiteURL;
		}
	}
	
	return result;
}

/*! returns publishSiteURL/sitemap.xml */
- (NSString *)publishedSitemapURL
{
	NSString *result = [self publishedSiteURL];
	if ( (nil == result) || [result hasSuffix:@"example.com/"] )
	{
		result = @""; // show placeholder in UI
	}
	else
	{
		if (![result hasSuffix:@"/"])
		{
			result = [result stringByAppendingString:@"/"];
		}
		result = [result stringByAppendingString:@"sitemap.xml.gz"];	/// can't use stringByAppendingPathComponent
	}
	
	return result;
}

- (void)siteStructureChanged
{
	/// Case 19023: this method is being called during terminate: and messing things up
	/// so let's not do this if we're closing
	if ( ![self isClosing] )
	{
		@try
		{
			KTPage *root = [self root];
			[root makeSelfOrDelegatePerformSelector:@selector(siteStructureChanged:forPage:) withObject:nil withPage:root recursive:YES];
		}
		@finally
		{
		}
	}
}

+ (NSString *)defaultStoreType
{
	// options are NSSQLiteStoreType, NSXMLStoreType, NSBinaryStoreType, or NSInMemoryStoreType
	// also, be sure to set (and match) Store Type in application target properties
	return NSSQLiteStoreType;
}

+ (NSString *)defaultMediaStoreType { return NSXMLStoreType; }

#pragma mark -
#pragma mark Document paths

/*! returns /path/to/document/datastore.sqlite3 */
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT([inURL isFileURL]);
	
	NSString *filename = @"datastore";
	NSString *defaultStoreType = [KTDocument defaultStoreType];
	if ( [defaultStoreType isEqualToString:NSSQLiteStoreType] )
	{
		filename = [filename stringByAppendingPathExtension:@"sqlite3"];
	}
	else if ( [defaultStoreType isEqualToString:NSXMLStoreType] )
	{
		filename = [filename stringByAppendingPathExtension:@"xml"];
	}
	else if ( [defaultStoreType isEqualToString:NSBinaryStoreType] )
	{
		filename = [filename stringByAppendingPathExtension:@"bplist"];
	}
	else
	{
		filename = [filename stringByAppendingPathExtension:@"unknownType"];
	}
	
	NSString *path = [[inURL path] stringByAppendingPathComponent:filename];
	NSURL *result = [NSURL fileURLWithPath:path];
	return result;
}

/*	Returns /path/to/document/Site
 */
+ (NSURL *)siteURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT([inURL isFileURL]);
	NSString *path = [[inURL path] stringByAppendingPathComponent:@"Site"];
	NSURL *result = [NSURL fileURLWithPath:path];
	return result;
}

+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT([inURL isFileURL]);
	NSString *docPath = [inURL path];
	NSString *qlPath = [docPath stringByAppendingPathComponent:@"QuickLook"];
	NSURL *result = [NSURL fileURLWithPath:qlPath];
	return result;
}

+ (NSURL *)mediaStoreURLForDocumentURL:(NSURL *)docURL
{
	NSString *mediaStorePath = [[docURL path] stringByAppendingPathComponent:@"media.xml"];
	NSURL *result = [[NSURL alloc] initWithScheme:[docURL scheme] host:[docURL host] path:mediaStorePath];
	
	return result;
}

/*! Returns /path/to/document/Site/_Media
 */
+ (NSURL *)mediaURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT([inURL isFileURL]);
	NSString *sitePath = [[self siteURLForDocumentURL:inURL] path];
	NSString *mediaPath = [sitePath stringByAppendingPathComponent:@"_Media"];
	NSURL *result = [NSURL fileURLWithPath:mediaPath];
	return result;
}

- (NSString *)mediaPath
{
	/// This used to be done from [self fileURL] but that doesn't work when making the very first save
	NSPersistentStoreCoordinator *storeCordinator = [[self managedObjectContext] persistentStoreCoordinator];
	NSURL *storeURL = [storeCordinator URLForPersistentStore:[[storeCordinator persistentStores] firstObject]];
	NSString *docPath = [[storeURL path] stringByDeletingLastPathComponent];
	NSURL *docURL = [[NSURL alloc] initWithScheme:[storeURL scheme] host:[storeURL host] path:docPath];
	NSString *result = [[KTDocument mediaURLForDocumentURL:docURL] path];
	
	[docURL release];
	return result;
}

/*	Temporary media is stored in:
 *	
 *		Application Support -> Sandvox -> Temporary Media Files -> Document ID -> a file
 *
 *	This method returns the path to that directory, creating it if necessary.
 */
- (NSString *)temporaryMediaPath;
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	NSArray *applicationSupportDirectorys = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,
																				NSUserDomainMask,
																				YES);
	
	NSString *applicationSupportDirectory = [applicationSupportDirectorys firstObjectOrNilIfEmpty];
	NSString *sandvoxSupportDirectory = [applicationSupportDirectory stringByAppendingPathComponent:@"Sandvox"];
	NSString *mediaFilesDirectory = [sandvoxSupportDirectory stringByAppendingPathComponent:@"Temporary Media Files"];
	NSString *result = [mediaFilesDirectory stringByAppendingPathComponent:[self documentID]];
	
	// Create the directory if needs be
	if (![fileManager fileExistsAtPath:result])
	{
		[fileManager createDirectoryPath:result attributes:nil];
	}
		
	OBPOSTCONDITION(result);
	return result;
}

- (NSString *)siteDirectoryPath;
{
	NSURL *docURL = [self fileURL];
	
	if (!docURL)
	{
		NSPersistentStoreCoordinator *storeCordinator = [[self managedObjectContext] persistentStoreCoordinator];
		NSURL *storeURL = [storeCordinator URLForPersistentStore:[[storeCordinator persistentStores] firstObject]];
		NSString *docPath = [[storeURL path] stringByDeletingLastPathComponent];
		docURL = [[NSURL alloc] initWithScheme:[storeURL scheme] host:[storeURL host] path:docPath];
	}
	
	NSString *result = [[KTDocument siteURLForDocumentURL:docURL] path];
	return result;
}

#pragma mark -
#pragma mark NSDocument Overrides

/*!	Force KTDocument to use a custom subclass of NSWindowController
 */
- (void)makeWindowControllers
{
    KTDocWindowController *controller = [[[KTDocWindowController alloc] init] autorelease];
    [self addWindowController:controller];
	myDocWindowController = [controller retain]; // released in removeWindowController:
}

- (void)addWindowController:(NSWindowController *)windowController
{
	if ( nil != windowController )
    {
		[super addWindowController:windowController];
	}
}

- (void)removeWindowController:(NSWindowController *)windowController
{
	//LOG((@"KTDocument -removeWindowController"));
	if ( [windowController isKindOfClass:[KTDocWindowController class]] )
    {
		// cleanup

		[self removeObserversForContext:(KTManagedObjectContext *)[self managedObjectContext]];
		[self cancelAndInvalidateAutosaveTimers];
		[[self windowController] selectionDealloc];
		
		// suspend webview updating
		//[[[self windowController] webViewController] setSuspendNextWebViewUpdate:SUSPEND];
		//[NSObject cancelPreviousPerformRequestsWithTarget:[[self windowController] webViewController] selector:@selector(doDelayedRefreshWebViewOnMainThread) object:nil];
		[[self windowController] webViewDeallocSupport];
		
		// suspend outline view updating
		///[[self windowController] siteOutlineDeallocSupport];
				
		// final clean up, we're done
		[(KTDocWindowController *)windowController documentControllerDeallocSupport];
		
		// balance retain in makeWindowControllers
		[myDocWindowController release]; myDocWindowController = nil;
	}
    
	if ( nil != windowController )
	{
		if ( [windowController isEqual:myHTMLInspectorController] )
		{
			[self setHTMLInspectorController:nil];
		}
		
		[super removeWindowController:windowController];
	}
}

- (void)close
{	
	LOGMETHOD;
	
	// Allow anyone interested to know we're closing. e.g. KTDocWebViewController uses this
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KTDocumentWillClose" object:self];
    
	//LOG((@"KTDocument -close"));
	// NB: [self windowController] is nil by the time we get here...

	/// clear Info window before changing selection to try to avoid an odd zombie issue (Case 18771)
	// tell info window to release inspector views and object controllers
	if ( [self isEqual:[[KTInfoWindowController sharedInfoWindowControllerWithoutLoading] associatedDocument]] )
	{
		// close info window
		[[KTInfoWindowController sharedInfoWindowControllerWithoutLoading] clearAll];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)kKTItemSelectedNotification object:nil];	// select nothing

    // is the media browser up?
    if ( nil != [iMediaBrowser sharedBrowserWithoutLoading] )
    {
        // are we closing the last open document?
        if ( [[[KTDocumentController sharedDocumentController] documents] count] == 1 )
        {
            // close media window
            [[KTAppDelegate sharedInstance] setDisplayMediaMenuItemTitle:KTShowMediaMenuItemTitle];
            [[iMediaBrowser sharedBrowser] close];
        }
    }
	
	// try to forget this was an open document
	[[KTAppDelegate sharedInstance] performSelector:@selector(updateLastOpened) 
	withObject:nil
	afterDelay:0.0];
	
	

	// Remove temporary media files
	[[self mediaManager] deleteTemporaryMediaFiles];
	
	[super close];
}

- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(id)contextInfo
{
	LOGMETHOD;
	
	OFF((@"KTDocument -canCloseDocumentWithDelegate initial selector: %@", NSStringFromSelector(shouldCloseSelector)));
	OFF((@"contextInfo = %@", contextInfo));
	
	if ( ![[[self windowController] window] makeFirstResponder:nil] )
	{
		return;
	}
	
	// CRITICAL: we need to signal writeToURL:::: that we're closing
	[self setClosing:YES];
	
	// close link panel
	if ( [[[self windowController] linkPanel] isVisible] )
	{
		[[self windowController] closeLinkPanel];
	}
	
	if ( [[self managedObjectContext] hasChanges] && [self isReadOnly] )
	{
		// document is read only, offer to Save As...
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"This document is read-only. Would you like to save it to a new location?", 
		"alert message text: Document is read-only.") 
		defaultButton:NSLocalizedString(@"Save As...",
		"Save As... Button") 
		alternateButton:NSLocalizedString(@"Don\\U2019t Save",
		"Don't Save Button") 
		otherButton:NSLocalizedString(@"Cancel",
		"Cancel Button")
							 informativeTextWithFormat:NSLocalizedString(@"If you don\\U2019t save, your changes will be lost.",
		"alert informative text: If you don’t save, your changes will be lost.")];
		
		NSMutableDictionary *alertContextInfo = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		@"canCloseDocumentWithDelegate:", @"context",
		delegate, @"delegate",
		NSStringFromSelector(shouldCloseSelector), @"selector",
		nil];
		
		[alert beginSheetModalForWindow:[[self windowController] window]
						  modalDelegate:self 
		didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:)
		contextInfo:[alertContextInfo retain]];
		return;
	}
	else
	{
		[self autosaveDocument:nil];
	}
	
	// we want to exit this method by sending [delegate shouldCloseSelector] with YES or NO
	// since the selector is a private method, we'll use an NSInvocation to do it properly
	// i.e., simulate [delegate _document:self shouldClose:YES contextInfo:contextInfo];
	BOOL shouldClose = YES;
	NSInvocation *callback = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
	[callback setSelector:shouldCloseSelector]; // not sure why this is necessary, but it is
	[callback setArgument:&self atIndex:2];
	[callback setArgument:&shouldClose atIndex:3];
	[callback setArgument:&contextInfo atIndex:4];
	[callback invokeWithTarget:delegate];
}

- (BOOL)isClosing
{
	return myIsClosing;
}

- (void)setClosing:(BOOL)aFlag
{
	myIsClosing = aFlag;
}

/*! we override willPresentError: here largely to deal with
	any validation issues when saving the document
 */
- (NSError *)willPresentError:(NSError *)inError
{
	// customizations for NSCocoaErrorDomain
	if ( [[inError domain] isEqualToString:NSCocoaErrorDomain] ) 
	{
		int errorCode = [inError code];
		
		// is this a Core Data validation error?
		if ( (errorCode >= NSValidationErrorMinimum) && (errorCode <= NSValidationErrorMaximum) ) 
		{
			// If there are multiple validation errors, inError will be a NSValidationMultipleErrorsError
			// and all the validation errors will be in an array in the userInfo dictionary for key NSDetailedErrorsKey
			id detailedErrors = [[inError userInfo] objectForKey:NSDetailedErrorsKey];
			if ( detailedErrors != nil ) 
			{
				unsigned numErrors = [detailedErrors count];							
				NSMutableString *errorString = [NSMutableString stringWithFormat:@"%u validation errors have occurred", numErrors];
				if ( numErrors > 3 )
				{
					[errorString appendFormat:@".\nThe first 3 are:\n"];
				}
				else
				{
					[errorString appendFormat:@":\n"];
				}
				
				unsigned i;
				for ( i = 0; i < ((numErrors > 3) ? 3 : numErrors); i++ ) 
				{
					[errorString appendFormat:@"%@\n", [[detailedErrors objectAtIndex:i] localizedDescription]];
				}
				
				NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[inError userInfo]];
				[userInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
				
				return [NSError errorWithDomain:[inError domain] code:[inError code] userInfo:userInfo];
			} 
			else 
			{
				// if there are no detailed errors (i.e., multiple errors), just return the error
				return inError;
			}
		}
	}
	
	return inError;
}

#pragma mark -
#pragma mark UI validation

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
	OFF((@"asking to KTDocument to validate toolbar item: %@ %@", [toolbarItem itemIdentifier], NSStringFromSelector([toolbarItem action]) ));
	
	if ( kGeneratingPreview != [[self windowController] publishingMode] )
	{
		return NO; // how can toolbars be doing anything if we're publishing?
	}	
	
    // Enable the Edit Raw HTML for blocks of editable HTML, or if the selected pagelet or page is HTML.
	if ( [toolbarItem action] == @selector(editRawHTMLInSelectedBlock:) )
	{
		if ([self valueForKeyPath:@"windowController.webViewController.currentTextEditingBlock.DOMNode"]) return YES;
		
		KTPagelet *selPagelet = [[self windowController] selectedPagelet];
		if (nil != selPagelet)
		{
			if ([@"sandvox.HTMLElement" isEqualToString:[selPagelet valueForKey:@"pluginIdentifier"]])
			{
				return YES;
			}
		}
		KTPage *selPage = [[[self windowController] siteOutlineController] selectedPage];
		if ([@"sandvox.HTMLElement" isEqualToString:[selPage valueForKey:@"pluginIdentifier"]])
		{
			return YES;
		}
		
		return NO;	// not one of the above conditions
	}
    return YES;
}


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	//LOG((@"asking document to validate menu item: %@", [menuItem title]));
	
	// File menu	
	// "Save Snapshot" saveDocumentSnapshot:
	if ( [menuItem action] == @selector(saveDocumentSnapshot:) ) 
	{
		return ![self isReadOnly];
	}
	
	// "Save As..." saveDocumentAs:
	else if ( [menuItem action] == @selector(saveDocumentAs:) )
	{
		return YES;
	}
	
	// "Save a Copy As..." saveDocumentTo:
	else if ( [menuItem action] == @selector(saveDocumentTo:) )
	{
		return YES;
	}
	
	// "Revert to Snapshot..." revertDocumentToSnapshot:
	else if ( [menuItem action] == @selector(revertDocumentToSnapshot:) ) 
	{
		return [self hasValidSnapshot];
	}
	
	// Site menu
	// "View Published Site" viewPublishedSite:
	else if ( [menuItem action] == @selector(viewPublishedSite:) ) 
	{
		NSString *publishedSiteURL = [self publishedSiteURL];
		return ( (nil != publishedSiteURL)
				 && ![publishedSiteURL hasSuffix:@"example.com/"] );
	}
	
	else if ( [menuItem action] == @selector(editRawHTMLInSelectedBlock:) )
	{
		// Yes if:  we are in a block of editable HTML, or if the selected pagelet or page is HTML.
		
		if ([self valueForKeyPath:@"windowController.webViewController.currentTextEditingBlock.DOMNode"]) return YES;
		
		KTPagelet *selPagelet = [[self windowController] selectedPagelet];
		if (nil != selPagelet)
		{
			if ([@"sandvox.HTMLElement" isEqualToString:[selPagelet valueForKey:@"pluginIdentifier"]])
			{
				return YES;
			}
		}
		KTPage *selPage = [[[self windowController] siteOutlineController] selectedPage];
		if ([@"sandvox.HTMLElement" isEqualToString:[selPage valueForKey:@"pluginIdentifier"]])
		{
			return YES;
		}
		
		return NO;	// not one of the above conditions
	}
	
	return [super validateMenuItem:menuItem]; 
}

#pragma mark -
#pragma mark Actions

- (IBAction)saveDocumentSnapshot:(id)sender
{
	if ( [self hasValidSnapshot] )
	{
		NSDate *snapshotDate = [self lastSnapshotDate];
		NSString *dateString = [snapshotDate relativeFormatWithTimeAndStyle:NSDateFormatterMediumStyle];

		NSString *title = NSLocalizedString(
					@"Do you want to replace the last snapshot?", @"alert: replace snapshot title");		
		NSString *message = [NSString stringWithFormat: NSLocalizedString(@"The older snapshot will be placed in the Trash.  It was saved %@.  ","alert: snapshot will be placed in trash.  %@ is a date or a day name like yesterday with a time."), dateString];
		
		// confirm with silencing confirm sheet
		[[self confirmWithWindow:[[self windowController] window]
					silencingKey:@"SilenceSaveDocumentSnapshot"
					   canCancel:YES 
						OKButton:NSLocalizedString(@"Snapshot", "Snapshot Button")
						 silence:nil 
						   title:title
						  format:message] snapshotPersistentStore:nil];
	}
	else
	{
		// nothing to replace, just create the snapshot
		[self snapshotPersistentStore:nil];
	}
}

- (IBAction)revertDocumentToSnapshot:(id)sender
{
	if ( [self hasValidSnapshot] )
	{
		NSDate *snapshotDate = [self lastSnapshotDate];
		NSString *dateString = [snapshotDate relativeFormatWithTimeAndStyle:NSDateFormatterMediumStyle];
		
		NSString *titleFormatString = NSLocalizedString(@"Do you want to revert to the most recently saved snapshot?", 
														"alert: revert to snapshot.");
		NSString *title = [NSString stringWithFormat:titleFormatString, dateString];
		
		NSString *message = [NSString stringWithFormat:NSLocalizedString(@"The previous snapshot was saved %@. Your current changes will be lost.", "alert: changes will be lost. %@ is replaced by a date or day+time"), dateString];
		
		NSAlert *alert = [NSAlert alertWithMessageText:title 
		defaultButton:NSLocalizedString(@"Revert", "Revert Button") 
		alternateButton:NSLocalizedString(@"Cancel", "Cancel Button")  
		otherButton:nil
		informativeTextWithFormat:message];
		
		[alert beginSheetModalForWindow:[[self windowController] window] modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:[[NSDictionary dictionaryWithObject:@"revertDocumentToSnapshot:" forKey:@"context"] retain]];
	}
	else
	{
		// might want to change this to an alert, though the code
		// should never reach here if menu validation is working
		NSLog(@"Document %@ has no valid snapshot.", [self displayName]);
	}
}

- (IBAction)saveDocumentAs:(id)sender
{
	LOG((@"========= beginning Save As... ========="));
// FIXME: the prompt for the panel should really be Save As, not Create
	//[self saveAllContexts]; // could be autosaveDocument
	[self autosaveDocument:nil];
	
	[super saveDocumentAs:sender];
}

- (void)cleanupBeforePublishing
{
	[[[self windowController] webViewController] commitEditing];
	if (nil == gRegistrationString)
	{
		[KSSilencingConfirmSheet alertWithWindow:[[self windowController] window] silencingKey:@"shutUpDemoUploadWarning" title:NSLocalizedString(@"Sandvox Demo: Restricted Publishing", @"title of alert") format:NSLocalizedString(@"You are running a demo version of Sandvox. Only the home page (watermarked) will be exported or uploaded. To publish additional pages, you will need to purchase a license.",@"")];
	}
	
	// Make sure both localHosting and remoteHosting are set to true
	KTHostProperties *hostProperties = [self valueForKeyPath:@"documentInfo.hostProperties"];
	if ([[hostProperties valueForKey:@"localHosting"] intValue] == 1 && 
		[[hostProperties valueForKey:@"remoteHosting"] intValue] == 1)
	{
		[hostProperties setValue:[NSNumber numberWithInt:0] forKey:@"localHosting"];
	}
	
	// force the current page to be the selection, deselecting any inline image.
	[[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)kKTItemSelectedNotification
	object:[[[self windowController] siteOutlineController] selectedPage]];
	
	// save the context to make sure any changes got processed
	[self cancelAndInvalidateAutosaveTimers];
	[self autosaveDocument:nil]; // should still save all contexts before proceeding
	
	// no undo after publishing
	[[self undoManager] removeAllActions];
}

- (IBAction) saveToHost:(id)sender
{
	[self cleanupBeforePublishing];
	
	KTHostProperties *hostProperties = [self valueForKeyPath:@"documentInfo.hostProperties"];
	int local = [hostProperties integerForKey:@"localHosting"];
	int remote = [hostProperties integerForKey:@"remoteHosting"];
	
	if (local && remote)
	{
//	FIXME:	We are temporarily changing from allowing both remote and local to an and/or situation
		if (nil == myRemoteTransferController)
		{
			KTTransferController *remoteTC
			= [[[KTTransferController alloc] initWithAssociatedDocument:self
			where:kGeneratingRemote] autorelease];
			[self setRemoteTransferController:remoteTC];
		}
		[myRemoteTransferController uploadStaleAssets];
	}
	else if (local)
	{
		if (nil == myLocalTransferController)
		{
			KTTransferController *localTC
			= [[[KTTransferController alloc] initWithAssociatedDocument:self
			where:kGeneratingLocal] autorelease];
			[self setLocalTransferController:localTC];
		}
		[myLocalTransferController uploadStaleAssets];
	}
	else if (remote)
	{
		if (nil == myRemoteTransferController)
		{
			KTTransferController *remoteTC
			= [[[KTTransferController alloc] initWithAssociatedDocument:self
			where:kGeneratingRemote] autorelease];
			[self setRemoteTransferController:remoteTC];
		}
		[myRemoteTransferController uploadStaleAssets];
	}
}

- (IBAction) saveAllToHost:(id)sender
{
	[self cleanupBeforePublishing];
	
	KTHostProperties *hostProperties = [self valueForKeyPath:@"documentInfo.hostProperties"];
	if ([[hostProperties valueForKey:@"localHosting"] intValue])
	{
		if (nil == myLocalTransferController)
		{
			KTTransferController *local
			= [[[KTTransferController alloc] initWithAssociatedDocument:self
			where:kGeneratingLocal] autorelease];
			[self setLocalTransferController:local];
		}
		[myLocalTransferController uploadEverything];
	}		
	
	if ([[hostProperties valueForKey:@"remoteHosting"] intValue])
	{
		if (nil == myRemoteTransferController)
		{
			KTTransferController *remote
			= [[[KTTransferController alloc] initWithAssociatedDocument:self
			where:kGeneratingRemote] autorelease];
			[self setRemoteTransferController:remote];
		}
		[myRemoteTransferController uploadEverything];
	}
}

/*!	Export. Only enabled if we have a remote setup.  Takes the site, published as if it were remote, and saves it somewhere.
 */

- (IBAction) exportAgain:(id)sender
{
	[self cleanupBeforePublishing];
	
	[myExportTransferController uploadEverything];
}

- (void)doExport:sender
{
	NSString *suggestedPath = nil;
	if (nil == myExportTransferController)
	{
		KTTransferController *export
		= [[[KTTransferController alloc] initWithAssociatedDocument:self
		where:kGeneratingRemoteExport] autorelease];
		[self setExportTransferController:export];
	}
	else
	{
		// We keep the old path as the suggested place, for easy replacement.
		suggestedPath = [[[myExportTransferController storagePath] copy] autorelease];
		// Exists already, so clear the path actually used.  
	}
	[myExportTransferController uploadEverythingToSuggestedPath:suggestedPath];	// ASYNC!
	
}

- (IBAction) export:(id)sender
{
	[self cleanupBeforePublishing];
	[self doExport:sender];
	/*
	 if (0 == [[[self hostProperties] objectForKey:@"remoteHosting"] intValue])
	 {
	 NSAlert *messageAlert = [[[NSAlert alloc] init] autorelease];
	 
	 [messageAlert setAlertStyle:NSInformationalAlertStyle];
	 [messageAlert setMessageText:NSLocalizedString(@"Remote Hosting Required for Export",@"")];
	 
	 NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	 NSString *sitesPath = nil;
	 BOOL homeDirectory = (HOMEDIR == [[[self hostProperties] objectForKey:@"localSharedMatrix"] intValue]);
	 if (homeDirectory)
	 {
	 sitesPath = [[NSWorkspace sharedWorkspace] userSitesDirectory];
	 }
	 else
	 {
	 sitesPath = [defaults objectForKey:@"ApacheDocRoot"];
	 }
	 
	 [messageAlert setInformativeText:[NSString stringWithFormat:NSLocalizedString(@"Your website is currently configured to be published only on this computer. After you publish, you can retrieve the files from the following directory:\n\n  %@",@""),sitesPath]];
	 
	 [messageAlert addButtonWithTitle:NSLocalizedString(@"Cancel",@"Cancel")];
	 
	 [messageAlert beginSheetModalForWindow:[[self windowController] window] modalDelegate:nil didEndSelector:nil contextInfo:nil];
	 }
	 else
	 {
	 NSString *remoteSiteURL = [[self hostProperties] remoteSiteURL];
	 if ( (nil == remoteSiteURL) || [remoteSiteURL isEqualToString:@""] || (NSNotFound != [remoteSiteURL rangeOfString:@"?"].location) )
	 {
	 [[self confirmWithWindow:[[self windowController] window]
	 silencingKey:@"ShutUpNoHostExportWarning"
	 canCancel:YES
	 OKButton:NSLocalizedString(@"Export",@"Export confirmation button")
	 silence:nil
	 title:[NSString stringWithFormat:NSLocalizedString(@"Incomplete Host Setup",@"Title for confirmation alert")]
	 format:NSLocalizedString(@"In order to properly export your site, you need to specify the URL where it will be published. (RSS data will be incorrect unless the published URL is specified.)",@"Warning about exporting")]
	 
	 doExport:sender];
	 }
	 else
	 {
	 [self doExport:sender];
	 }			
	 }*/
}


- (IBAction)setupHost:(id)sender
{
	KTHostSetupController* sheetController
	= [[KTHostSetupController alloc] initWithHostProperties:[self valueForKeyPath:@"documentInfo.hostProperties"]];
	
	[NSApp beginSheet:[sheetController window]
	   modalForWindow:[[self windowController] window]
	modalDelegate:self
	   didEndSelector:@selector(setupHostSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:sheetController];
	[NSApp cancelUserAttentionRequest:NSCriticalRequest];
}


- (void)editDOMHTMLElement:(DOMHTMLElement *)anElement withTitle:(NSString *)aTitle;
{
	[[self HTMLInspectorController] setDOMHTMLElement:anElement];	// saves will put back into this node
	[[self HTMLInspectorController] setTitle:aTitle];
	[[self HTMLInspectorController] showWindow:nil];
}

- (void)editKTHTMLElement:(KTAbstractElement *)anElement;
{
	[[self HTMLInspectorController] setKTHTMLElement:anElement];
	[[self HTMLInspectorController] showWindow:nil];
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	DOMNode *selectedDomNode = [self valueForKeyPath:@"windowController.webViewController.currentTextEditingBlock.DOMNode"];
	
	if (selectedDomNode)		// Edit the Editable Rich Text
	{
		if ([selectedDomNode hasChildNodes] )
		{
			DOMNode *firstChild = [selectedDomNode firstChild];
			if ([firstChild isKindOfClass:[DOMHTMLElement class]]
				&& [[((DOMHTMLElement *)firstChild) tagName] isEqualToString:@"SPAN"])
			{
				if ([[((DOMHTMLElement *)firstChild) className] isEqualToString:@"in"])
				{
					// get into the span class="in"
					selectedDomNode = firstChild;	// we will get contents of this
				}
			}
		}
		KTPage *selPage = [[[self windowController] siteOutlineController] selectedPage];
		[self editDOMHTMLElement:(DOMHTMLElement *)selectedDomNode withTitle:[selPage titleText]]; // use title of page
	}
	else	// Edit the HTML Element
	{
		KTAbstractElement *htmlElement = nil;
		KTPagelet *selPagelet = [[self windowController] selectedPagelet];
		if (nil != selPagelet)
		{
			if ([@"sandvox.HTMLElement" isEqualToString:[selPagelet valueForKey:@"pluginIdentifier"]])
			{
				htmlElement = selPagelet;
			}
		}
		if (nil == htmlElement)
		{
			KTPage *selPage = [[[self windowController] siteOutlineController] selectedPage];
			if ([@"sandvox.HTMLElement" isEqualToString:[selPage valueForKey:@"pluginIdentifier"]])
			{
				htmlElement = selPage;
			}
		}
		if (nil != htmlElement)
		{
			[self editKTHTMLElement:htmlElement];
		}
		else
		{
			NSLog(@"Nothing to edit");
			NSBeep();	// nothing to edit; should not happen
		}
	}
}

- (IBAction)viewPublishedSite:(id)sender
{
	NSString *publishedSiteURL = [self publishedSiteURL];
	if ( nil != publishedSiteURL )
	{
		NSURL *URL = [NSURL URLWithString:publishedSiteURL];
		[[NSWorkspace sharedWorkspace] openURL:URL];
	}
}

#pragma mark -
#pragma mark Delegate Methods

- (void)setupHostSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	KTHostSetupController* sheetController = (KTHostSetupController*)contextInfo;
	if (returnCode)
	{
		// init code only for new documents
		NSUndoManager *undoManager = [self undoManager];
		
		//[undoManager beginUndoGrouping];
		//KTStoredDictionary *hostProperties = [[self documentInfo] wrappedValueForKey:@"hostProperties"];
		KTHostProperties *hostProperties = [sheetController properties];
		[self setValue:hostProperties forKeyPath:@"documentInfo.hostProperties"];

		// For diagnostics, log the value of the host properties
		NSLog(@"new hostProperties = %@", [[hostProperties description] condenseWhiteSpace]);

		[self setLocalTransferController:nil];		// clear old settings after we have changed host properties
		[self setRemoteTransferController:nil];
		[self setExportTransferController:nil];
		
		// mark the document as completely stale
		////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on root because host setup ended", NSStringFromSelector(_cmd)));
		
		
// TODO: Make this work again	//[[self stalenessManager] setAllPagesStale:YES];
		
		
		[undoManager setActionName:NSLocalizedString(@"Host Settings", @"Undo name")];
		
		[self fireAutosave:nil];
		
		// Check encoding from host properties
		// Alas, I have no way to test this!
		
		NSString *hostCharset = [hostProperties valueForKey:@"encoding"];
		if ((nil != hostCharset) && ![hostCharset isEqualToString:@""])
		{
			NSString *rootCharset = [[[self root] master] valueForKey:@"charset"];
			if (![[hostCharset lowercaseString] isEqualToString:[rootCharset lowercaseString]])
			{
				[self performSelector:@selector(warnThatHostUsesCharset:) withObject:hostCharset afterDelay:0.0];
			}
		}
	}
	[sheetController autorelease];
}

- (void) warnThatHostUsesCharset:(NSString *)hostCharset
{
	[KSSilencingConfirmSheet alertWithWindow:[[self windowController] window] silencingKey:@"ShutUpCharsetMismatch" title:NSLocalizedString(@"Host Character Set Mismatch", @"alert title when the character set specified on the host doesn't match settings") format:NSLocalizedString(@"The host you have chosen always serves its text encoded as '%@'.  In order to prevent certain text from appearing incorrectly, we suggest that you set your site's 'Character Encoding' property to match this, using the inspector.",@""), [hostCharset uppercaseString]];
}

// deal with save panels
- (void)savePanelDidEnd:(NSSavePanel *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	if ( [((id)contextInfo) isKindOfClass:[NSString class]] && [((id)contextInfo) isEqualToString:@"saveDocumentTo:"] )
	{
		// ok, here we're going to get the filename and move it
		
		// first, close the sheet
		[sheet orderOut:nil];
		
		if ( returnCode == NSOKButton)
		{
			// if ok button, save
			[self autosaveDocument:nil];
			
			// now, copy the document with NSFileManager
			NSString *currentPath = [[self fileURL] path];
			NSString *saveToPath = [sheet filename];
			
			if ( [saveToPath isEqualToString:currentPath] )
			{
				// no need to copy over ourselves
				return;
			}
			
			NSFileManager *fileManager = [NSFileManager defaultManager];
			if ( ![fileManager copyPath:currentPath toPath:saveToPath handler:nil] )
			{
				// didn't work, put up an error
				NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:
				saveToPath, NSFilePathErrorKey,
				NSLocalizedString(@"Unable to copy to path", @"Unable to copy to path"), NSLocalizedDescriptionKey,
				nil];
				NSError *fileError = [NSError errorWithDomain:NSCocoaErrorDomain 
				code:512 // unknown write error 
				userInfo:userInfo];
				[self presentError:fileError];
			}
		}
	}
}

// staleness debugging

- (IBAction)clearStaleness:(id)sender
{
	NSArray *pages = [[self managedObjectContext] allObjectsWithEntityName:@"Page" error:NULL];
	[pages setBool:NO forKey:@"isStale"];
}

- (IBAction)markAllStale:(id)sender
{
	NSArray *pages = [[self managedObjectContext] allObjectsWithEntityName:@"Page" error:NULL];
	[pages setBool:YES forKey:@"isStale"];
}

#pragma mark snapshot support

- (NSDate *)lastSnapshotDate
{
	NSDate *result = nil;
	
	// grab date of last save
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *attrs = [fm fileAttributesAtPath:[self snapshotPath] traverseLink:YES];
	
	// try modDate then creationDate
	result = [attrs valueForKey:NSFileModificationDate];
	if ( nil == result )
	{
		result = [attrs valueForKey:NSFileCreationDate];
	}
	
	return result;
}

- (BOOL)hasValidSnapshot
{
	BOOL result = NO;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *snapshotPath = [self snapshotPath];
	result = [fm fileExistsAtPath:snapshotPath];
	result = result && [[NSFileManager defaultManager] isReadableFileAtPath:snapshotPath];
	
	return result;
}

- (BOOL)createSnapshotDirectoryIfNecessary
{
	NSString *directoryPath = [[self snapshotPath] stringByDeletingLastPathComponent];
	
    NSError *localError = nil;
    BOOL result = [KTUtilities createPathIfNecessary:directoryPath error:&localError];
    
    if ( nil != localError )
	{
		// put up an error alert
    }
    
    return result;
}

/*! returns <fileName>.svxSite */
- (NSString *)snapshotName
{
	NSString *fileName = [[[self fileURL] path] lastPathComponent];
	//return [NSString stringWithFormat:NSLocalizedString(@"Snapshot of %@", "snapshot of"), fileName];
	return fileName;
}

/*! returns ~/Library/Application Support/Sandvox/Snapshots/<documentID> */
- (NSString *)snapshotDirectory
{
	return [[self snapshotPath] stringByDeletingLastPathComponent];
}

/*! returns ~/Library/Application Support/Sandvox/Snapshots/<documentID>/<fileName>.svxSite */
- (NSString *)snapshotPath
{
    if ( nil == mySnapshotPath )
	{
		NSString *snapshotPath = nil;
		
		// construct path
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES);
		if ( [libraryPaths count] == 1 )
        {
			snapshotPath = [libraryPaths objectAtIndex:0];
			snapshotPath = [snapshotPath stringByAppendingPathComponent:[NSApplication applicationName]];
			snapshotPath = [snapshotPath stringByAppendingPathComponent:@"Snapshots"];
			snapshotPath = [snapshotPath stringByAppendingPathComponent:[self documentID]];
			snapshotPath = [snapshotPath stringByAppendingPathComponent:[self snapshotName]];
			[self setSnapshotPath:snapshotPath];
		}
    }
    
    return mySnapshotPath;
}

- (void)setSnapshotPath:(NSString *)aPath
{
    [aPath retain];
    [mySnapshotPath release];
    mySnapshotPath = aPath;
}

# pragma mark ~/Library/Caches 

/*! creates, if necessary, ~/Library/Caches/Sandvox/Sites.noindex/<siteID>/Images */
- (BOOL)createImagesCacheIfNecessary
{
    NSError *localError = nil;
    BOOL result = [KTUtilities createPathIfNecessary:[self imagesCachePath] error:&localError];
    
    if ( nil != localError )
	{
		// put up an error alert
    }
    
    return result;
}

- (NSString *)imagesCachePath	// returns path without resolving symbolic links
{
    return [[self siteCachePath] stringByAppendingPathComponent:@"Images"];
}

- (NSString *)siteCachePath		// returns path without resolving symbolic links
{
    if ( nil == mySiteCachePath )
	{
		NSString *siteCachePath = nil;
		
		// construct path
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES);
		if ( [libraryPaths count] == 1 )
        {
			siteCachePath = [libraryPaths objectAtIndex:0];
			siteCachePath = [siteCachePath stringByAppendingPathComponent:[NSApplication applicationName]];
			siteCachePath = [siteCachePath stringByAppendingPathComponent:@"Sites"];
			siteCachePath = [siteCachePath stringByAppendingPathExtension:@"noindex"];
			siteCachePath = [siteCachePath stringByAppendingPathComponent:[self documentID]];
			[self setSiteCachePath:siteCachePath];
		}
    }
    
    return mySiteCachePath;
}

- (void)setSiteCachePath:(NSString *)aPath
{
    [aPath retain];
    [mySiteCachePath release];
    mySiteCachePath = aPath;
}

#pragma mark -
#pragma mark screenshot for feedback

//  screenshot1 = document window
//  screenshot2 = document sheet, if any
//  screenshot3 = inspector window, if visible
// alternative: use screencapture to write a jpeg of the entire screen to the user's temp directory

- (void)addScreenshotsToReport:(NSMutableDictionary *)report attachmentOwner:(NSString *)attachmentOwner
{
	
	NSWindow *window = [[[[NSApp delegate] currentDocument] windowController] window];
	NSImage *snapshot = [window snapshot];
	if ( nil != snapshot )
	{
		NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
		NSString *snapshotName = [NSString stringWithFormat:@"screenshot-%@.jp2", attachmentOwner];
		
		KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:snapshotName 
																				   data:snapshotData];
		[report setValue:attachment forKey:@"screenshot1"];
		[attachments addObject:@"screenshot1"];
	}
	
	// Also attach any sheet (host setup, etc.)
	if (nil != [window attachedSheet])
	{
		snapshot = [[window attachedSheet] snapshot];
		if ( nil != snapshot )
		{
			NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
			NSString *snapshotName = [NSString stringWithFormat:@"sheet-%@.jp2", attachmentOwner];
			
			KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:snapshotName data:snapshotData];
			[report setValue:attachment forKey:@"screenshot2"];
			[attachments addObject:@"screenshot2"];
		}
	}
	
	// Attach inspector, if visible
	KTInfoWindowController *sharedController = [KTInfoWindowController sharedInfoWindowControllerWithoutLoading];
	if ( nil != sharedController )
	{
		NSWindow *infoWindow = [sharedController window];
		if ( [infoWindow isVisible] )
		{
			snapshot = [infoWindow snapshot];
			if ( nil != snapshot )
			{
				NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
				NSString *snapshotName = [NSString stringWithFormat:@"inspector-%@.jp2", attachmentOwner];
				
				KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:snapshotName data:snapshotData];
				[report setValue:attachment forKey:@"screenshot3"];
				[attachments addObject:@"screenshot3"];
			}
		}
	}
	
}

@end
