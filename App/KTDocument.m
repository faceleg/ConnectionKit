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

#import "KSAbstractBugReporter.h"
#import "KSSilencingConfirmSheet.h"
#import "KT.h"
#import "KTAbstractIndex.h"
#import "KTAppDelegate.h"
#import "KTElementPlugin.h"
#import "KTCodeInjectionController.h"
#import "KTDesign.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocumentController.h"
#import "KTDocumentInfo.h"
#import "KTElementPlugin.h"
#import "KTHTMLInspectorController.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "KTIndexPlugin.h"
#import "KTInfoWindowController.h"
#import "KTManagedObjectContext.h"
#import "KTMaster.h"
#import "KTMediaManager+Internal.h"
#import "KTPage.h"
#import "KTStalenessManager.h"
#import "KTTransferController.h"
#import "KTUtilities.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSWindow+Karelia.h"
#import "NSURL+Karelia.h"

#import <iMediaBrowser/iMediaBrowser.h>

#import "Debug.h"

#import "Registration.h"


@interface KTDocument ( Private )
+ (void)initialize;
- (BOOL)keepBackupFile;
- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel;
- (IBAction)saveAllToHost:(id)sender;
- (IBAction)saveToHost:(id)sender;
- (KTTransferController *)localTransferController;
- (KTTransferController *)remoteTransferController;

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
- (NSDate *)lastSnapshotDate;

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
		myIsSuspendingAutosave = YES;
		LOG((@"%@ init suspending YES", self));
		
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
		
		
        // Create media manager and keep an eye on it
        myMediaManager = [[KTMediaManager alloc] initWithDocument:self];
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
	
	NSSet *pagePlugins = [KTElementPlugin pagePlugins];
	[KTElementPlugin addPlugins:pagePlugins
						 toMenu:[oNewDocHomePageTypePopup menu]
						 target:nil
						 action:nil
					  pullsDown:NO
					  showIcons:YES smallIcons:YES smallText:NO];
	
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
        KTElementPlugin *defaultRootPlugin = [[oNewDocHomePageTypePopup selectedItem] representedObject];
        [self initWithURL:saveURL ofType:type homePagePlugIn:defaultRootPlugin error:error];
		
		
		// Make the initial Sandvox badge
        NSString *initialBadgeBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBadgeBundleIdentifier"];
        if (nil != initialBadgeBundleID && ![initialBadgeBundleID isEqualToString:@""])
        {
            KTElementPlugin *badgePlugin = [KTElementPlugin pluginWithIdentifier:initialBadgeBundleID];
            if (badgePlugin)
            {
                KTPagelet *pagelet = [KTPagelet pageletWithPage:[[self documentInfo] root] plugin:badgePlugin];
                [pagelet setPrefersBottom:YES];
            }
        }
        
        if (![self saveToURL:saveURL ofType:type forSaveOperation:NSSaveOperation error:error])
        {
            [self release];
            return nil;
        }
        
        
		// Is this path a currently open document? if yes, close it!
		NSDocument *openDocument = [[NSDocumentController sharedDocumentController] documentForURL:saveURL];
		if (openDocument)
		{
			[openDocument canCloseDocumentWithDelegate:nil shouldCloseSelector:NULL contextInfo:nil];
			[openDocument close];
		}	
			
			
        
        
        // Hide the doc's extension if requested
        if ([savePanel isExtensionHidden])
        {
            [[NSFileManager defaultManager] setExtensionHiddenAtPath:[saveURL path]];
        }
        
	}
	@finally
	{
		// Hide the progress window
		[[NSApp delegate] hideGenericProgressPanel];
	}
    
	
    return self;
}


/*  Use to create a new document when you already know the home page type and save location.
 */
- (id)initWithURL:(NSURL *)saveURL ofType:(NSString *)type homePagePlugIn:(KTElementPlugin *)plugin error:(NSError **)outError
{
    OBPRECONDITION(plugin);
    
    
    [super initWithType:type error:outError];
    
    
    // Make a new documentInfo to store document properties
    KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
    KTDocumentInfo *documentInfo = [NSEntityDescription insertNewObjectForEntityForName:@"DocumentInfo" inManagedObjectContext:context];
    [self setDocumentInfo:documentInfo];
    
    NSDictionary *docProperties = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultDocumentProperties"];
    if (docProperties)
    {
        [documentInfo setValuesForKeysWithDictionary:docProperties];
    }
    
    
    // make a new root
    // POSSIBLE PROBLEM -- THIS WON'T WORK WITH EXTERALLY LOADED BUNDLES...
    [[plugin bundle] load];
    KTPage *root = [KTPage rootPageWithDocument:self bundle:[plugin bundle]];
    OBASSERTSTRING((nil != root), @"root page is nil!");
    [[self documentInfo] setValue:root forKey:@"root"];
    
    
    // Create the site Master object
    KTMaster *master = [NSEntityDescription insertNewObjectForEntityForName:@"Master" inManagedObjectContext:[self managedObjectContext]];
    [root setValue:master forKey:@"master"];
    
    
    // Set the design
    KTDesign *design = [[KSPlugin sortedPluginsWithFileExtension:kKTDesignExtension] firstObject];
    [master setDesign:design];		
    
    
    // set up root properties that used to come from document defaults
    [master setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"author"] forKey:@"author"];
    [root setBool:YES forKey:@"isCollection"];
    
    [master setValue:[self language] forKey:@"language"];
    [master setValue:[self charset] forKey:@"charset"];
    
    NSString *subtitle = [[NSBundle mainBundle] localizedStringForString:@"siteSubtitleHTML"
                                                                language:[master valueForKey:@"language"]
                                                                fallback:NSLocalizedStringWithDefaultValue(@"siteSubtitleHTML", nil, [NSBundle mainBundle],
                                                                                                           @"This is the subtitle for your site.",
                                                                                                           @"Default introduction statement for a page")];
    [master setValue:subtitle forKey:@"siteSubtitleHTML"];
    
    
    // FIXME: we should load up the properties from a KTPreset
    [root setBool:NO forKey:@"includeTimestamp"];
    [root setInteger:KTCollectionUnsorted forKey:@"collectionSortOrder"];
    [root setBool:NO forKey:@"collectionSyndicate"];
    [root setInteger:0 forKey:@"collectionMaxIndexItems"];
    [root setBool:NO forKey:@"collectionShowPermanentLink"];
    [root setBool:YES forKey:@"collectionHyperlinkPageTitles"];		
    [root setTitleText:[self defaultRootPageTitleText]];
    
    
    NSString *defaultRootIndexIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultRootIndexBundleIdentifier"];
    if (nil != defaultRootIndexIdentifier && ![defaultRootIndexIdentifier isEqualToString:@""])
    {
        KTAbstractHTMLPlugin *plugin = [KTIndexPlugin pluginWithIdentifier:defaultRootIndexIdentifier];
        if (nil != plugin)
        {
            NSBundle *bundle = [plugin bundle];
            [root setValue:defaultRootIndexIdentifier forKey:@"collectionIndexBundleIdentifier"];
            
            Class indexToAllocate = [NSBundle principalClassForBundle:bundle];
            KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:root plugin:plugin] autorelease];
            [root setIndex:theIndex];
        }
    }
    
    [self setLocalTransferController:nil];		// make sure to clear old settings after we have some host properties
    [self setRemoteTransferController:nil];
    [self setExportTransferController:nil];
    
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
                             error:outError];
    if (!didSave) 
	{
        [self release];	return nil;
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
		if ([[self documentInfo] boolForKey:@"isNewDocument"])
		{
			[self setShowDesigns:YES];	// new doc needs designs showing initially
			[[self documentInfo] setBool:NO forKey:@"isNewDocument"];
		}
		else
		{
			[self setShowDesigns:NO];	// assume doc already opened doesn't need to show designs initially
		}
		
		
		// Load up document display properties
		[self setDisplaySmallPageIcons:[[self documentInfo] boolForKey:@"displaySmallPageIcons"]];
		
		
		// establish autosave notifications
//		[self observeNotificationsForContext:(KTManagedObjectContext *)[self managedObjectContext]];
		
		[[self stalenessManager] performSelector:@selector(beginObservingAllPages) withObject:nil afterDelay:0.0];
		
		// A little bit of repair; we need to have language stored in the root if it's not there
		if (![[[[self documentInfo] root] master] valueForKey:@"language"])
		{
			[[[[self documentInfo] root] master] setValue:[self language] forKey:@"language"];
		}

		// For diagnostics, log the value of the host properties
		KTHostProperties *hostProperties = [self valueForKeyPath:@"documentInfo.hostProperties"];
		NSLog(@"hostProperties = %@", [[hostProperties hostPropertiesReport] condenseWhiteSpace]);
	}
    
    
    // We're all setup, ready to allow autosaving
	myIsSuspendingAutosave = NO;
	LOG((@"%@ initWithContentsOfURL suspending NO", self));
	
	return self;
}

#pragma mark dealloc

- (void)dealloc
{
	// no more notifications
	// TODO: FIXME: Chris Hanson indicates that we should be removing each specific observation
	// rather than doing blanket removal
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	
	// no more saving
	[self cancelAndInvalidateAutosaveTimers]; // invalidates and releases myAutosaveTimer
    [myLastSavedTime release]; myLastSavedTime = nil;
	
	[oNewDocAccessoryView release];
		
    [self setDocumentInfo:nil];
    
    [myMediaManager release];
	
    [self setLocalTransferController:nil];
    [self setRemoteTransferController:nil];
    [self setExportTransferController:nil];
    [self setSiteCachePath:nil];
	[mySnapshotURL release];
	
	[myStalenessManager stopObservingAllPages];
	[myStalenessManager release];
	
	// release context
	[myManagedObjectContext release]; myManagedObjectContext = nil;
	
	[super dealloc];
}

/*! returns root as a single page array, used in DebugTable bindings */
- (NSArray *)rootAsArray
{
	return [NSArray arrayWithObject:[[self documentInfo] root]];
}

#pragma mark -
#pragma mark Public Functions

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    BOOL result = [super automaticallyNotifiesObserversForKey:key];
    
    if ([key isEqualToString:@"windowController"])
    {
        result = NO;
    }
    
    return result;
}

/*! return the single KTDocWindowController associated with this document */
- (KTDocWindowController *)windowController
{
	//OBASSERTSTRING(nil != myDocWindowController, @"windowController should not be nil");
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

/*! returns publishSiteURL/sitemap.xml */
- (NSString *)publishedSitemapURL
{
	NSString *result;
    
    NSURL *siteURL = [[[self documentInfo] hostProperties] siteURL];
	if (!siteURL || [[siteURL host] isEqualToString:@"example.com"])
	{
		result = @""; // show placeholder in UI
	}
	else
	{
		NSURL *sitemapURL = [NSURL URLWithString:@"sitemap.xml.gz" relativeToURL:siteURL];
        result = [sitemapURL absoluteString];
	}
	
	return result;
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

/*	Returns the URL to the primary document persistent store. This differs dependent on the document UTI.
 *	You can pass in nil to use the default UTI for new documents.
 */
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL UTI:(NSString *)documentUTI
{
	OBPRECONDITION(inURL);
	
	NSURL *result = nil;
	
	
	if (!documentUTI || [documentUTI isEqualToString:kKTDocumentUTI])
	{
		// Figure the filename
		NSString *filename = @"datastore";
		NSString *defaultStoreType = [KTDocument defaultStoreType];
		if ([defaultStoreType isEqualToString:NSSQLiteStoreType])
		{
			filename = [filename stringByAppendingPathExtension:@"sqlite3"];
		}
		else if ([defaultStoreType isEqualToString:NSXMLStoreType])
		{
			filename = [filename stringByAppendingPathExtension:@"xml"];
		}
		else if ([defaultStoreType isEqualToString:NSBinaryStoreType])
		{
			filename = [filename stringByAppendingPathExtension:@"bplist"];
		}
		else
		{
			filename = [filename stringByAppendingPathExtension:@"unknownType"];
		}
		
		
		// Build the URL
		result = [inURL URLByAppendingPathComponent:filename isDirectory:NO];
	}
	else if ([documentUTI isEqualToString:kKTDocumentUTI_ORIGINAL])
	{
		result = inURL;
	}
	else
	{
		OBASSERT_NOT_REACHED("Unknown document UTI");
	}
	
	
	return result;
}

/*	Returns /path/to/document/Site
 */
+ (NSURL *)siteURLForDocumentURL:(NSURL *)inURL
{
	OBPRECONDITION(inURL);
	
	NSURL *result = [inURL URLByAppendingPathComponent:@"Site" isDirectory:YES];
	
	OBPOSTCONDITION(result);
	return result;
}

+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT(inURL);
	
	NSURL *result = [inURL URLByAppendingPathComponent:@"QuickLook" isDirectory:YES];
	
	OBPOSTCONDITION(result);
	return result;
}

+ (NSURL *)mediaStoreURLForDocumentURL:(NSURL *)docURL
{
	OBASSERT(docURL);
	
	NSURL *result = [docURL URLByAppendingPathComponent:@"media.xml" isDirectory:NO];
	
	OBPOSTCONDITION(result);
	return result;
}

/*! Returns /path/to/document/Site/_Media
 */
+ (NSURL *)mediaURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT(inURL);
	
	NSURL *result = [[self siteURLForDocumentURL:inURL] URLByAppendingPathComponent:@"_Media" isDirectory:YES];
	
	OBPOSTCONDITION(result);
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
	NSString *sandvoxSupportDirectory = [NSApplication applicationSupportPath];

	NSString *mediaFilesDirectory = [sandvoxSupportDirectory stringByAppendingPathComponent:@"Temporary Media Files"];
	NSString *result = [mediaFilesDirectory stringByAppendingPathComponent:[[self documentInfo] siteID]];
	
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

//		[self removeObserversForContext:(KTManagedObjectContext *)[self managedObjectContext]];
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

#pragma mark -
#pragma mark Closing Documents

- (void)close
{	
	LOGMETHOD;
	
	// Allow anyone interested to know we're closing. e.g. KTDocWebViewController uses this
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KTDocumentWillClose" object:self];

	[self suspendAutosave];

	//LOG((@"KTDocument -close"));
	// NB: [self windowController] is nil by the time we get here...

	/// clear Info window before changing selection to try to avoid an odd zombie issue (Case 18771)
	// tell info window to release inspector views and object controllers
	if ( [self isEqual:[[KTInfoWindowController sharedControllerWithoutLoading] associatedDocument]] )
	{
		// close info window
		[[KTInfoWindowController sharedControllerWithoutLoading] clearAll];
	}
	
	[[NSNotificationCenter defaultCenter] postNotificationName:(NSString *)kKTItemSelectedNotification object:nil];	// select nothing

    // is the media browser up?
    if ( nil != [iMediaBrowser sharedBrowserWithoutLoading] )
    {
        // are we closing the last open document?
        if ( [[[KTDocumentController sharedDocumentController] documents] count] == 1 )
        {
            // close media window
            [[NSApp delegate] setDisplayMediaMenuItemTitle:KTShowMediaMenuItemTitle];
            [[iMediaBrowser sharedBrowser] close];
        }
    }
	
	

	// Remove temporary media files
	[[self mediaManager] deleteTemporaryMediaFiles];
	
	[super close];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KTDocumentDidClose" object:self];
}


/*	Called when the user goes to close the document.
 *	By default, if there are unsaved changes NSDocument prompts the user, but we just want to go ahead and save.
 */
- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(id)contextInfo
{
	LOGMETHOD;
	
	
	// In order to inform the delegate, we will have to send this callback at some point
	NSMethodSignature *callbackSignature = [delegate methodSignatureForSelector:shouldCloseSelector];
	NSInvocation *callback = [NSInvocation invocationWithMethodSignature:callbackSignature];
	[callback setTarget:delegate];
	[callback setSelector:shouldCloseSelector];
	[callback setArgument:&self atIndex:2];
	[callback setArgument:&contextInfo atIndex:4];	// Argument 3 will be set from the save result
	
	
	// Stop editing
	BOOL result = [[[self windowController] webViewController] commitEditing];
	if (result) result = [[[self windowController] window] makeFirstResponder:nil];
	
	if (!result)
	{
		[callback setArgument:&result atIndex:3];
		[callback invoke];
		return;
	}
	
	
	// CRITICAL: we need to signal -writeToURL: that we're closing
	[self setClosing:YES];
	
	
	// Close link panel
	if ([[[self windowController] linkPanel] isVisible])
	{
		[[self windowController] closeLinkPanel];
	}
	
	
	// Garbage collect media. Killing plugin inspector views early is a bit of a hack to stop it accessing
    // any garbage collected media.
    [[[self windowController] pluginInspectorViewsManager] removeAllPluginInspectorViews];
	[[self mediaManager] garbageCollect];
	
	
	
	// Is there actually anything to be saved?
	if ([self isDocumentEdited])
	{
		if ([self isReadOnly])
		{
			// Document is read only, offer to Save As...
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
			// Go for it, save the document!
			[self saveToURL:[self fileURL]
					 ofType:[self fileType]
		   forSaveOperation:NSSaveOperation
				   delegate:self
			didSaveSelector:@selector(document:didSaveWhileClosing:contextInfo:)
				contextInfo:[callback retain]];		// Our callback method will release it
		}
	}
	else
	{
		// If there are no changes, we can go ahead with the default NSDocument behavior
		[super canCloseDocumentWithDelegate:delegate shouldCloseSelector:shouldCloseSelector contextInfo:contextInfo];
	}
}

/*	Callback used by above method.
 */
- (void)document:(NSDocument *)document didSaveWhileClosing:(BOOL)didSaveSuccessfully contextInfo:(void  *)contextInfo
{
	NSInvocation *callback = [(NSInvocation *)contextInfo autorelease];	// It was retained at the start
	
	// Let the delegate know if the save was successful or not
	[callback setArgument:&didSaveSuccessfully atIndex:3];
	[callback invoke];
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
	NSError *result = inError;
    
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
				
				result = [NSError errorWithDomain:[inError domain] code:[inError code] userInfo:userInfo];
			} 
		}
	}
    
    
    // Log the error to the console for debugging
    NSLog(@"KTDocument will present error:\n%@", result);
    NSLog(@"Error user info: %@", [[[result userInfo] description] condenseWhiteSpace]);
    
    NSError *underlyingError = [[result userInfo] objectForKey:NSUnderlyingErrorKey];
    if (underlyingError)
    {
        NSLog(@"Underlying error: %@", [[[underlyingError userInfo] description] condenseWhiteSpace]);
    }
    
	
	return result;
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
	OFF((@"KTDocument validateMenuItem:%@ %@", [menuItem title], NSStringFromSelector([menuItem action])));
	
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
		NSURL *siteURL = [[[self documentInfo] hostProperties] siteURL];
		return ( (nil != siteURL)
				 && ![[siteURL host] hasSuffix:@"example.com/"] );
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

- (IBAction)saveDocumentAs:(id)sender
{
	LOG((@"========= beginning Save As... ========="));
// FIXME: the prompt for the panel should really be Save As, not Create
	//[self saveAllContexts]; // could be autosaveDocument
	//[self autosaveDocument:nil];
	
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

- (IBAction)exportAgain:(id)sender
{
	[self cleanupBeforePublishing];
	
	[myExportTransferController uploadEverything];
}

- (void)doExport
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
	[self setExportTransferController:nil];
	[self doExport];
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
	NSURL *siteURL = [[[self documentInfo] root] URL];
	if (siteURL)
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:siteURL];
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
		NSLog(@"new hostProperties = %@", [[hostProperties hostPropertiesReport] condenseWhiteSpace]);

		[self setLocalTransferController:nil];		// clear old settings after we have changed host properties
		[self setRemoteTransferController:nil];
		[self setExportTransferController:nil];
		
		
		// Mark designs and media as stale (pages are handled automatically)
		NSArray *designs = [[self managedObjectContext] allObjectsWithEntityName:@"DesignPublishingInfo" error:NULL];
		[designs setValue:nil forKey:@"versionLastPublished"];
		
		NSArray *media = [[[self mediaManager] managedObjectContext] allObjectsWithEntityName:@"MediaFileUpload" error:NULL];
		[media setBool:YES forKey:@"isStale"];
        
        
        // All page URLs are now invalid
        [[[self documentInfo] root] recursivelyInvalidateURL:YES];
		
		
		
		[undoManager setActionName:NSLocalizedString(@"Host Settings", @"Undo name")];
		
//		[self fireAutosave:nil];
		
		// Check encoding from host properties
		// Alas, I have no way to test this!
		
		NSString *hostCharset = [hostProperties valueForKey:@"encoding"];
		if ((nil != hostCharset) && ![hostCharset isEqualToString:@""])
		{
			NSString *rootCharset = [[[[self documentInfo] root] master] valueForKey:@"charset"];
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
	NSArray *pages = [KTAbstractPage allPagesInManagedObjectContext:[self managedObjectContext]];
	[pages setBool:NO forKey:@"isStale"];
}

- (IBAction)markAllStale:(id)sender
{
	NSArray *pages = [KTAbstractPage allPagesInManagedObjectContext:[self managedObjectContext]];
	[pages setBool:YES forKey:@"isStale"];
}

#pragma mark -
#pragma mark Backup

- (NSURL *)backupURL
{
	NSURL *result = nil;
	
    NSURL *originalURLWithoutFileName = [[self fileURL] URLByDeletingLastPathComponent];
    
    NSString *fileName = [[[self fileURL] lastPathComponent] stringByDeletingPathExtension];
    NSString *fileExtension = [[self fileURL] pathExtension];
    
    NSString *backupFileName = NSLocalizedString(@"Backup of ", "Prefix for backup copy of document");
    OBASSERT(fileName);
    backupFileName = [backupFileName stringByAppendingString:fileName];
    OBASSERT(fileExtension);
    backupFileName = [backupFileName stringByAppendingPathExtension:fileExtension];
    result = [originalURLWithoutFileName URLByAppendingPathComponent:backupFileName isDirectory:NO];
	
	return result;
}

#pragma mark TODO add an error: parameter and pass the error back for communication to user
- (BOOL)backupToURL:(NSURL *)anotherURL;
{
	BOOL result = NO;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *originalPath = [[self fileURL] path];
	
	if ( [fm fileExistsAtPath:originalPath] )
	{			
		NSString *backupPath = [anotherURL path];
		if ( nil != backupPath )
		{
			BOOL okToProceed = YES;
			
			// delete old backup first
			if ( [fm fileExistsAtPath:backupPath] )
			{
				okToProceed = [fm removeFileAtPath:backupPath handler:self];
			}
			
			// make sure the directory exists
			NSString *directoryPath = [backupPath stringByDeletingLastPathComponent];
			NSError *localError = nil;
			okToProceed = [KTUtilities createPathIfNecessary:directoryPath error:&localError];

			if ( okToProceed )
			{
				// grab the date
				NSDate *now = [NSDate date];
				
				// make the backup
				result = [fm copyPath:originalPath toPath:backupPath handler:self];
				
				// update the creation/lastModification times to now
				//  what key is "Last opened" that we see in Finder?
				//  until we know that, only update mod time
				NSDictionary *dateInfo = [NSDictionary dictionaryWithObjectsAndKeys:
										  //now, NSFileCreationDate,
										  now, NSFileModificationDate,
										  nil];
				(void)[fm changeFileAttributes:dateInfo atPath:backupPath];
			}
		}
	}
	
	return result;
}

#pragma mark -
#pragma mark Snapshots

- (IBAction)saveDocumentSnapshot:(id)sender
{
	if ([self hasValidSnapshot])
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
						  format:message] snapshotPersistentStore];
	}
	else
	{
		// nothing to replace, just create the snapshot
		[self snapshotPersistentStore];
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

- (NSDate *)lastSnapshotDate
{
	NSDate *result = nil;
	
	// grab date of last save
	NSFileManager *fm = [NSFileManager defaultManager];
	NSDictionary *attrs = [fm fileAttributesAtPath:[[self snapshotURL] path] traverseLink:YES];
	
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
	NSString *snapshotPath = [[self snapshotURL] path];
	result = [fm fileExistsAtPath:snapshotPath];
	result = result && [[NSFileManager defaultManager] isReadableFileAtPath:snapshotPath];
	
	return result;
}

- (BOOL)createSnapshotDirectoryIfNecessary
{
	NSString *directoryPath = [[self snapshotDirectoryURL] path];
	
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
	NSString *fileName = [[self fileURL] lastPathComponent];
	//return [NSString stringWithFormat:NSLocalizedString(@"Snapshot of %@", "snapshot of"), fileName];
	return fileName;
}

/*! returns ~/Library/Application Support/Sandvox/Snapshots/<siteID> */
- (NSURL *)snapshotDirectoryURL
{
	return [[self snapshotURL] URLByDeletingLastPathComponent];
}

/*! returns ~/Library/Application Support/Sandvox/Snapshots/<siteID>/<fileName>.svxSite */
- (NSURL *)snapshotURL
{
    if (!mySnapshotURL)
	{
		// construct path
		NSURL *appSupportURL = [NSURL fileURLWithPath:[NSApplication applicationSupportPath]];
        mySnapshotURL = [[[appSupportURL
                            URLByAppendingPathComponent:@"Snapshots" isDirectory:YES]
                             URLByAppendingPathComponent:[[self documentInfo] siteID] isDirectory:YES]
                              URLByAppendingPathComponent:[self snapshotName] isDirectory:NO];
        
		[mySnapshotURL retain];
    }
    
    return mySnapshotURL;
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

/*! creates, if necessary, ~/Library/Caches/Sandvox/Sites.noindex/<siteID>/Upload */
- (BOOL)createUploadCacheIfNecessary
{
    NSError *localError = nil;
    BOOL result = [KTUtilities createPathIfNecessary:[self uploadCachePath] error:&localError];
    
    if ( nil != localError )
	{
		// put up an error alert
    }
    
    return result;
}

- (BOOL)clearUploadCache
{
	BOOL result = YES;
	
	// just delete the upload cache directory and recreate it
	NSFileManager *fm = [NSFileManager defaultManager];
	
	if ( [fm fileExistsAtPath:[self uploadCachePath]] )
	{
		result = [fm removeFileAtPath:[self uploadCachePath] handler:nil];
		if ( result )
		{
			result = [self createUploadCacheIfNecessary];
		}
	}
	
	if ( !result )
	{
		NSLog(@"error: unable to clear upload cache");
	}
	
	return result;
}

- (NSString *)uploadCachePath	// returns path without resolving symbolic links
{
	//return [[self siteCachePath] stringByAppendingPathComponent:@"Upload"];
	
	// under Leopard, NSTemporaryDirectory() returns something like /var/folders/3B/3BPx90jsEyay4WyjMQAI6E+++TI/-Tmp-
	NSString *result = NSTemporaryDirectory();
	result = [result stringByAppendingPathComponent:[NSApplication applicationIdentifier]];
	result = [result stringByAppendingPathComponent:[[self documentInfo] siteID]];
	result = [result stringByAppendingPathComponent:@"TmpUploadCache"];
	return result;
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
			siteCachePath = [siteCachePath stringByAppendingPathComponent:[NSApplication applicationIdentifier]];
			siteCachePath = [siteCachePath stringByAppendingPathComponent:@"Sites"];
			siteCachePath = [siteCachePath stringByAppendingPathExtension:@"noindex"];
			siteCachePath = [siteCachePath stringByAppendingPathComponent:[[self documentInfo] siteID]];
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

- (BOOL)mayAddScreenshotsToAttachments;
{
	NSWindow *window = [[[[NSApp delegate] currentDocument] windowController] window];
	return (window && [window isVisible]);
}

//  screenshot1 = document window
//  screenshot2 = document sheet, if any
//  screenshot3 = inspector window, if visible
// alternative: use screencapture to write a jpeg of the entire screen to the user's temp directory

- (void)addScreenshotsToAttachments:(NSMutableArray *)attachments attachmentOwner:(NSString *)attachmentOwner;
{
	
	NSWindow *window = [[[[NSApp delegate] currentDocument] windowController] window];
	NSImage *snapshot = [window snapshotShowingBorder:NO];
	if ( nil != snapshot )
	{
		NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
		NSString *snapshotName = [NSString stringWithFormat:@"screenshot-%@.jp2", attachmentOwner];
		
		KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:snapshotName 
																				   data:snapshotData];
		if (attachment)
		{
			[attachments addObject:attachment];
		}
	}
	
	// Also attach any sheet (host setup, etc.)
	if (nil != [window attachedSheet])
	{
		snapshot = [[window attachedSheet] snapshotShowingBorder:NO];
		if ( nil != snapshot )
		{
			NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
			NSString *snapshotName = [NSString stringWithFormat:@"sheet-%@.jp2", attachmentOwner];
			
			KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:snapshotName data:snapshotData];
			if (attachment)
			{
				[attachments addObject:attachment];
			}
		}
	}
	
	// Attach inspector, if visible
	KTInfoWindowController *sharedController = [KTInfoWindowController sharedControllerWithoutLoading];
	if ( nil != sharedController )
	{
		NSWindow *infoWindow = [sharedController window];
		if ( [infoWindow isVisible] )
		{
			snapshot = [infoWindow snapshotShowingBorder:YES];
			if ( nil != snapshot )
			{
				NSData *snapshotData = [snapshot JPEG2000RepresentationWithQuality:0.40];
				NSString *snapshotName = [NSString stringWithFormat:@"inspector-%@.jp2", attachmentOwner];
				
				KSFeedbackAttachment *attachment = [KSFeedbackAttachment attachmentWithFileName:snapshotName data:snapshotData];
				if (attachment)
				{
					[attachments addObject:attachment];
				}
			}
		}
	}
	
}

@end
