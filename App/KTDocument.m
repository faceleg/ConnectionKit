//
//  KTDocument.m
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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
#import "KTMaster+Internal.h"
#import "KTMediaManager+Internal.h"
#import "KTPage+Internal.h"
#import "KTPluginInspectorViewsManager.h"
#import "KTStalenessManager.h"
#import "KTSummaryWebViewTextBlock.h"
#import "KTLocalPublishingEngine.h"
#import "KTUtilities.h"

#import "NSApplication+Karelia.h"
#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSObject+Karelia.h"
//#import "NSWorkspace+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSWindow+Karelia.h"
#import "NSURL+Karelia.h"

#import <iMediaBrowser/iMediaBrowser.h>

#import "Debug.h"

#import "Registration.h"


// Trigger Localization ... thes are loaded with the [[` ... ]] directive

// NSLocalizedStringWithDefaultValue(@"skipNavigationTitleHTML", nil, [NSBundle mainBundle], @"Site Navigation", @"Site navigation title on web pages (can be empty if link is understandable)")
// NSLocalizedStringWithDefaultValue(@"backToTopTitleHTML", nil, [NSBundle mainBundle], @" ", @"Back to top title, generally EMPTY")
// NSLocalizedStringWithDefaultValue(@"skipSidebarsTitleHTML", nil, [NSBundle mainBundle], @"Sidebar", @"Sidebar title on web pages (can be empty if link is understandable)")
// NSLocalizedStringWithDefaultValue(@"skipNavigationLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip navigation LINK on web pages"), @"skipNavigationLinkHTML",
// NSLocalizedStringWithDefaultValue(@"skipSidebarsLinkHTML", nil, [NSBundle mainBundle], @"[Skip]", @"Skip sidebars LINK on web pages"), @"skipSidebarsLinkHTML",
// NSLocalizedStringWithDefaultValue(@"backToTopLinkHTML", nil, [NSBundle mainBundle], @"[Back To Top]", @"back-to-top LINK on web pages"), @"backToTopLinkHTML",

// NSLocalizedStringWithDefaultValue(@"navigateNextHTML",		nil, [NSBundle mainBundle], @"Next",		@"alt text of navigation button"),	@"navigateNextHTML",
// NSLocalizedStringWithDefaultValue(@"navigateListHTML",		nil, [NSBundle mainBundle], @"List",		@"alt text of navigation button"),	@"navigateListHTML",
// NSLocalizedStringWithDefaultValue(@"navigatePreviousHTML",	nil, [NSBundle mainBundle], @"Previous",	@"alt text of navigation button"),	@"navigatePreviousHTML",
// NSLocalizedStringWithDefaultValue(@"navigateMainHTML",		nil, [NSBundle mainBundle], @"Main",		@"text of navigation button"),		@"navigateMainHTML",


NSString *KTDocumentDidChangeNotification = @"KTDocumentDidChange";
NSString *KTDocumentWillCloseNotification = @"KTDocumentWillClose";


@interface KTDocument (Private)

- (void)setClosing:(BOOL)aFlag;

- (void)setLocalTransferController:(KTLocalPublishingEngine *)aLocalTransferController;
- (void)setRemoteTransferController:(KTLocalPublishingEngine *)aRemoteTransferController;
- (void)setupHostSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


#pragma mark -


@implementation KTDocument

#pragma mark -
#pragma mark Init & Dealloc

/*! designated initializer for all NSDocument instances. Common initialization to new doc and opening a doc */
- (id)init
{
	if (gLicenseViolation)
	{
		NSBeep();
        [self release];
		return nil;
	}
	
    
    if (self = [super init])
	{
		[self setThread:[NSThread currentThread]];
        
        
        // Init UI accessors
		NSNumber *tmpValue = [self wrappedInheritedValueForKey:@"displaySiteOutline"];
		[self setDisplaySiteOutline:(tmpValue) ? [tmpValue boolValue] : YES];
		
		tmpValue = [self wrappedInheritedValueForKey:@"displayStatusBar"];
		[self setDisplayStatusBar:(tmpValue) ? [tmpValue boolValue] : YES];
		
		tmpValue = [self wrappedInheritedValueForKey:@"displayEditingControls"];
		[self setDisplayEditingControls:(tmpValue) ? [tmpValue boolValue] : YES];
		
		tmpValue = [self wrappedInheritedValueForKey:@"displaySmallPageIcons"];
		[self setDisplaySmallPageIcons:(tmpValue) ? [tmpValue boolValue] : NO];
		
		
        // Create media manager
        myMediaManager = [[KTMediaManager alloc] initWithDocument:self];
    }
	
    return self;
}

/*! initializer for creating a new document
	NB: this is not shown on screen
 */
- (id)initWithType:(NSString *)type error:(NSError **)error
{
 	NOTYETIMPLEMENTED;
    return nil;
}
    
- (id)initWithType:(NSString *)type rootPlugin:(KTElementPlugin *)plugin error:(NSError **)error
{
	self = [super initWithType:type error:error];
    
    if (self)
    {
        // Make a new documentInfo to store document properties
        NSManagedObjectContext *context = [self managedObjectContext];
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
        KTDesign *design = [[KSPlugin sortedPluginsWithFileExtension:kKTDesignExtension] firstObjectKS];
        [master setDesign:design];
		[self setShowDesigns:YES];
        
        
        // Set up root properties that used to come from document defaults
        [master setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"author"] forKey:@"author"];
        [root setBool:YES forKey:@"isCollection"];
        
        // This probably should use -[NSBundle preferredLocalizationsFromArray:forPreferences:]
        // http://www.cocoabuilder.com/archive/message/cocoa/2003/4/24/84070
        // though there's a problem ... that will return a string like "English" not "en"
        NSString *language = [[[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"] objectAtIndex:0];
        [master setValue:language forKey:@"language"];
        [master setValue:@"UTF-8" forKey:@"charset"];
        
        
        NSString *defaultRootPageTitleText = [[NSBundle mainBundle] localizedStringForString:@"defaultRootPageTitleText"
                                                                                    language:language
                                                                                    fallback:
                                              NSLocalizedStringWithDefaultValue(@"defaultRootPageTitleText", nil, [NSBundle mainBundle], @"Home Page", @"Title of initial home page")];
        [root setTitleText:defaultRootPageTitleText];
     }
	
	
    return self;
}

- (void)dealloc
{
	// no more notifications
	// TODO: FIXME: Chris Hanson indicates that we should be removing each specific observation
	// rather than doing blanket removal
    [[NSNotificationCenter defaultCenter] removeObserver:self];
				
    [self setDocumentInfo:nil];
    
    [myMediaManager release];
	
	// release context
	[myManagedObjectContext release]; myManagedObjectContext = nil;
    
    [myThread release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Debug?

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

/*! returns publishSiteURL/sitemap.xml */
- (NSString *)publishedSitemapURL
{
	NSString *result;
    
    NSURL *siteURL = [[[self documentInfo] hostProperties] siteURL];
	if (!siteURL)
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
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL type:(NSString *)documentUTI
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
	
	// Do *NOT* use DefaultMediaPath -- this is the place in the document, not the published site!
	NSURL *result = [[self siteURLForDocumentURL:inURL] URLByAppendingPathComponent:@"_Media" isDirectory:YES];
	
	OBPOSTCONDITION(result);
	return result;
}

- (NSURL *)mediaDirectoryURL;
{
	/// This could be calculated from [self fileURL], but that doesn't work when making the very first save
	NSPersistentStoreCoordinator *storeCordinator = [[self managedObjectContext] persistentStoreCoordinator];
	NSURL *storeURL = [storeCordinator URLForPersistentStore:[[storeCordinator persistentStores] firstObjectKS]];
	NSURL *docURL = [storeURL URLByDeletingLastPathComponent];
	
    NSURL *result = [[self class] mediaURLForDocumentURL:docURL];
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
		NSURL *storeURL = [storeCordinator URLForPersistentStore:[[storeCordinator persistentStores] firstObjectKS]];
		docURL = [storeURL URLByDeletingLastPathComponent];
	}
	
	NSString *result = [[KTDocument siteURLForDocumentURL:docURL] path];
	return result;
}

- (void)setFileURL:(NSURL *)absoluteURL
{
    NSPersistentStoreCoordinator *PSC = [[self managedObjectContext] persistentStoreCoordinator];
    if ([PSC respondsToSelector:@selector(setURL:forPersistentStore:)]) // supported on 10.5 and later
    {
        NSURL *oldURL = [[self fileURL] copy];
        [super setFileURL:absoluteURL];
        
        
        if (oldURL)
        {
            // Also reset the persistent stores' DB connection if needed
            OBASSERT([[PSC persistentStores] count] <= 1);
            id store = [PSC persistentStoreForURL:[[self class] datastoreURLForDocumentURL:oldURL type:nil]];
            if (store)
            {
                NSURL *newStoreURL = [[self class] datastoreURLForDocumentURL:absoluteURL type:nil];
                [PSC performSelector:@selector(setURL:forPersistentStore:) withObject:newStoreURL withObject:store];
            }
            
            PSC = [[[self mediaManager] managedObjectContext] persistentStoreCoordinator];
            OBASSERT([[PSC persistentStores] count] <= 1);
            store = [PSC persistentStoreForURL:[[self class] mediaStoreURLForDocumentURL:oldURL]];
            if (store)
            {
                NSURL *newStoreURL = [[self class] mediaStoreURLForDocumentURL:absoluteURL];
                [PSC performSelector:@selector(setURL:forPersistentStore:) withObject:newStoreURL withObject:store];
            }
            
            [oldURL release];
        }
    }
    else
    {
        [super setFileURL:absoluteURL];
    }
}

#pragma mark -
#pragma mark Controller Chain

/*! return the single KTDocWindowController associated with this document */
- (KTDocWindowController *)windowController
{
	//OBASSERTSTRING(nil != myDocWindowController, @"windowController should not be nil");
	return myDocWindowController;
}

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

		[[self windowController] selectionDealloc];
		
		// suspend webview updating
		//[[[self windowController] webViewController] setSuspendNextWebViewUpdate:SUSPEND];
		//[NSObject cancelPreviousPerformRequestsWithTarget:[[self windowController] webViewController] selector:@selector(doDelayedRefreshWebViewOnMainThread) object:nil];
		[[self windowController] setSelectedPagelet:nil];
		
		// suspend outline view updating
		///[[self windowController] siteOutlineDeallocSupport];
				
		// final clean up, we're done
		[(KTDocWindowController *)windowController documentControllerDeallocSupport];
		
		// balance retain in makeWindowControllers
		[myDocWindowController release]; myDocWindowController = nil;
	}
    else if ( [windowController isEqual:myHTMLInspectorController] )
    {
		[self setHTMLInspectorController:nil];
	}
		
	
    [super removeWindowController:windowController];
}

/*  The document is the end of the chain    */
- (id <KTDocumentControllerChain>)parentController { return nil; }

- (KTDocument *)document { return self; }

#pragma mark -
#pragma mark Changes

/*  Supplement NSDocument by broadcasting a notification that the document did change
 */
- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
    [super updateChangeCount:changeType];
    
    if (changeType == NSChangeDone || changeType == NSChangeUndone)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:KTDocumentDidChangeNotification object:self];
    }
}

- (void)processPendingChangesAndClearChangeCount
{
	LOGMETHOD;
	[[self managedObjectContext] processPendingChanges];
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
}

#pragma mark -
#pragma mark Closing Documents

- (void)close
{	
	LOGMETHOD;
    
    
    [self setClosing:YES];
	
	// Allow anyone interested to know we're closing. e.g. KTDocWebViewController uses this
	[[NSNotificationCenter defaultCenter] postNotificationName:KTDocumentWillCloseNotification object:self];

	
	/// clear Info window before changing selection to try to avoid an odd zombie issue (Case 18771)
	// tell info window to release inspector views and object controllers
	if ([[KTInfoWindowController sharedControllerWithoutLoading] associatedDocument] == self)
	{
		// close info window
		[[KTInfoWindowController sharedController] clearAll];
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
	//LOGMETHOD;
	
	
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
		[self setClosing:NO];
        
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
	
	
	// Go for it, save the document!
    // We used to only do this if there were changes, but as the undo manager delays reporting to
    // until the end of the event loop, -isDocumentEdited may not be accurate. case 40879
    [self saveToURL:[self fileURL]
             ofType:[self fileType]
   forSaveOperation:NSSaveOperation
           delegate:self
    didSaveSelector:@selector(document:didSaveWhileClosing:contextInfo:)
        contextInfo:[callback retain]];		// Our callback method will release it
}

/*	Callback used by above method.
 */
- (void)document:(NSDocument *)document didSaveWhileClosing:(BOOL)didSaveSuccessfully contextInfo:(void  *)contextInfo
{
	[self setClosing:didSaveSuccessfully];
    
    NSInvocation *callback = [(NSInvocation *)contextInfo autorelease];	// It was retained at the start
	
	// Let the delegate know if the save was successful or not
	[callback setArgument:&didSaveSuccessfully atIndex:3];
	[callback invoke];
}

- (BOOL)isClosing { return myIsClosing; }

- (void)setClosing:(BOOL)aFlag { myIsClosing = aFlag; }

#pragma mark -
#pragma mark Error Presentation

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
    
    
    return result;
}

#pragma mark -
#pragma mark UI validation

- (BOOL)validateToolbarItem:(NSToolbarItem *)toolbarItem
{
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
	// "Save As..." saveDocumentAs:
	if ( [menuItem action] == @selector(saveDocumentAs:) )
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
	else if ( [menuItem action] == @selector(editRawHTMLInSelectedBlock:) )
	{
		// Yes if:  we are in a block of editable HTML, or if the selected pagelet or page is HTML.
		
		if ([[[[self windowController] webViewController] currentTextEditingBlock] DOMNode]) return YES;
		
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
	
	// no undo after publishing
	[[self undoManager] removeAllActions];
}

- (IBAction)setupHost:(id)sender
{
	KTHostSetupController* sheetController
	= [[KTHostSetupController alloc] initWithHostProperties:[self valueForKeyPath:@"documentInfo.hostProperties"]];
		// LEAKING ON PURPOSE, THIS WILL BE AUTORELEASED IN setupHostSheetDidEnd:
	
	[NSApp beginSheet:[sheetController window]
	   modalForWindow:[[self windowController] window]
	modalDelegate:self
	   didEndSelector:@selector(setupHostSheetDidEnd:returnCode:contextInfo:)
		  contextInfo:sheetController];
	[NSApp cancelUserAttentionRequest:NSCriticalRequest];
}


- (void)editSourceObject:(NSObject *)aSourceObject keyPath:(NSString *)aKeyPath  isRawHTML:(BOOL)isRawHTML;
{
	[[self HTMLInspectorController] setHTMLSourceObject:aSourceObject];	// saves will put back into this node
	[[self HTMLInspectorController] setHTMLSourceKeyPath:aKeyPath];
	
	
	NSString *title = @"";
	if (isRawHTML)
	{
		// Get title of page/pagelet we are editing
		if ([aSourceObject respondsToSelector:@selector(titleText)])
		{
			NSString *itsTitle = [((KTAbstractElement *)aSourceObject) titleText];
			if (nil != itsTitle && ![itsTitle isEqualToString:@""])
			{
				title = itsTitle;
			}
		}
	}
	[[self HTMLInspectorController] setTitle:title];
	[[self HTMLInspectorController] setFromEditableBlock:!isRawHTML];

	[[self HTMLInspectorController] showWindow:nil];
}


- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	BOOL result = [[[self windowController] webViewController] commitEditing];

	if (result)
	{
		BOOL isRawHTML = NO;
		KTHTMLTextBlock *textBlock = [self valueForKeyPath:@"windowController.webViewController.currentTextEditingBlock"];
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
			KTPagelet *selPagelet = [[self windowController] selectedPagelet];
			if (nil != selPagelet)
			{
				if (![@"sandvox.HTMLElement" isEqualToString:[selPagelet valueForKey:@"pluginIdentifier"]])
				{
					sourceObject = nil;		// no, don't try to edit a non-rich text
				}
				else
				{
					sourceObject = selPagelet;
				}
			}
			
			if (nil == sourceObject)	// no appropriate pagelet selected, try page
			{
				sourceObject = [[[self windowController] siteOutlineController] selectedPage];
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
            
			[self editSourceObject:sourceObject keyPath:sourceKeyPath isRawHTML:isRawHTML];
		}
	}
	else
	{
		NSLog(@"Cannot commit editing to edit HTML");
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
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"LogHostInfoToConsole"] )
		{
			NSLog(@"new hostProperties = %@", [[hostProperties hostPropertiesReport] condenseWhiteSpace]);		
		}
		
		// Mark designs and media as stale (pages are handled automatically)
		NSArray *designs = [[self managedObjectContext] allObjectsWithEntityName:@"DesignPublishingInfo" error:NULL];
		[designs setValue:nil forKey:@"versionLastPublished"];
        
        [[[[self documentInfo] root] master] setPublishedDesignCSSDigest:nil];
		
		NSArray *media = [[[self mediaManager] managedObjectContext] allObjectsWithEntityName:@"MediaFileUpload" error:NULL];
		[media setBool:YES forKey:@"isStale"];
        
        
        // All page and sitemap URLs are now invalid
        [[[self documentInfo] root] recursivelyInvalidateURL:YES];
        [self willChangeValueForKey:@"publishedSitemapURL"];
        [self didChangeValueForKey:@"publishedSitemapURL"];
		
		
		
		[undoManager setActionName:NSLocalizedString(@"Host Settings", @"Undo name")];
				
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

- (void)warnThatHostUsesCharset:(NSString *)hostCharset
{
	[KSSilencingConfirmSheet alertWithWindow:[[self windowController] window] silencingKey:@"ShutUpCharsetMismatch" title:NSLocalizedString(@"Host Character Set Mismatch", @"alert title when the character set specified on the host doesn't match settings") format:NSLocalizedString(@"The host you have chosen always serves its text encoded as '%@'.  In order to prevent certain text from appearing incorrectly, we suggest that you set your site's 'Character Encoding' property to match this, using the inspector.",@""), [hostCharset uppercaseString]];
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
