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

#import "SVRichText.h"
#import "KT.h"
#import "KTAbstractIndex.h"
#import "KTElementPlugInWrapper.h"
#import "KTDesign.h"
#import "SVPagesController.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocumentController.h"
#import "SVDocumentUndoManager.h"
#import "KTSite.h"
#import "KTElementPlugInWrapper.h"
#import "KTHTMLInspectorController.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "KTIndexPluginWrapper.h"
#import "SVInspector.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "KTPage+Internal.h"
#import "SVSidebar.h"
#import "KTSummaryWebViewTextBlock.h"
#import "SVTextBox.h"
#import "KTLocalPublishingEngine.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "KSAbstractBugReporter.h"
#import "KSSilencingConfirmSheet.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSWindow+Karelia.h"
#import "NSURL+Karelia.h"

#import <iMedia/iMedia.h>

#import "Debug.h"                       // Debugging

#import "Registration.h"                // Licensing


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


NSString *kKTDocumentDidChangeNotification = @"KTDocumentDidChange";
NSString *kKTDocumentWillCloseNotification = @"KTDocumentWillClose";


@implementation NSDocument (DatastoreAdditions)

// These are made category methods so Shared code can work generically. These determine document types and URLs.

/*	Returns the URL to the primary document persistent store. This differs dependent on the document UTI.
 *	You can pass in nil to use the default UTI for new documents.
 */
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL type:(NSString *)documentUTI
{
	OBPRECONDITION(inURL);
	
	NSURL *result = nil;
	
	if (!documentUTI || [documentUTI isEqualToString:kKTDocumentUTI])
	{
		result = [inURL URLByAppendingPathComponent:@"datastore" isDirectory:NO];
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

+ (NSURL *)documentURLForDatastoreURL:(NSURL *)datastoreURL;
{
    OBPRECONDITION(datastoreURL);
    OBPRECONDITION([[datastoreURL lastPathComponent] isEqualToString:@"datastore"]);
    
    NSURL *result = [datastoreURL URLByDeletingLastPathComponent];
    return result;
}

+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT(inURL);
	
	NSURL *result = [inURL URLByAppendingPathComponent:@"QuickLook" isDirectory:YES];
	
	OBPOSTCONDITION(result);
	return result;
}

@end



@interface KTDocument ()

- (KTPage *)makeRootPage;

- (void)setupHostSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo;

@end


#pragma mark -


@implementation KTDocument

#pragma mark -
#pragma mark Synthesized properties, can't be in category

@synthesize lastExportDirectory = _lastExportDirectory;


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
        
        
        // Set up managed object context
		_managedObjectContext = [[NSManagedObjectContext alloc] init];
		[[self managedObjectContext] setMergePolicy:NSOverwriteMergePolicy]; // Standard document-like behaviour
		
		NSManagedObjectModel *model = [[self class] managedObjectModel];
		NSPersistentStoreCoordinator *PSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
		[[self managedObjectContext] setPersistentStoreCoordinator:PSC];
		[PSC release];
        
        NSUndoManager *undoManager = [[SVDocumentUndoManager alloc] init];
        [[self managedObjectContext] setUndoManager:undoManager];
        [undoManager release];
        [super setUndoManager:[[self managedObjectContext] undoManager]];
        
        
        // Other ivars
        _filenameReservations = [[NSMutableDictionary alloc] init];
        
        
        // Init UI accessors
		id tmpValue = [self wrappedInheritedValueForKey:@"displaySmallPageIcons"];
		[self setDisplaySmallPageIcons:(tmpValue) ? [tmpValue boolValue] : NO];
    }
	
    return self;
}

/*! initializer for creating a new document
	NB: this is not shown on screen
 */
- (id)initWithType:(NSString *)type error:(NSError **)error
{
	self = [super initWithType:type error:error];
    
    if (self)
    {
        // We really don't want the doc being marked as edited as soon as it's created, so suppress registration
        NSUndoManager *undoManager = [self undoManager];
        [undoManager disableUndoRegistration];
        
        
		// Make a new site to store document properties
        NSManagedObjectContext *context = [self managedObjectContext];
        
        KTSite *site = [NSEntityDescription insertNewObjectForEntityForName:@"Site"
                                                     inManagedObjectContext:context];
        [self setSite:site];
        
        NSDictionary *docProperties = [[NSUserDefaults standardUserDefaults] objectForKey:@"defaultDocumentProperties"];
        if (docProperties)
        {
			NSMutableDictionary *repairedDocProperties = [NSMutableDictionary dictionaryWithDictionary:docProperties];
			[repairedDocProperties removeObjectForKey:@"displayEditingControls"];
			[repairedDocProperties removeObjectForKey:@"displaySiteOutline"];
			[repairedDocProperties removeObjectForKey:@"displayStatusBar"];

// In case there are others, catch the errors
            @try
            {
                [[self site] setValuesForKeysWithDictionary:repairedDocProperties];
            }
            @catch (NSException *exception)
            {
                if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
            }
        }
        
        
        // make a new root
        // POSSIBLE PROBLEM -- THIS WON'T WORK WITH EXTERALLY LOADED BUNDLES...
        KTPage *root = [self makeRootPage]; // no need to assign it; -makeRootPage effectively does that
        OBASSERTSTRING((nil != root), @"root page is nil!");
        
        
        // Create the site Master object
        KTMaster *master = [NSEntityDescription insertNewObjectForEntityForName:@"Master" inManagedObjectContext:[self managedObjectContext]];
        [root setValue:master forKey:@"master"];
        
        
        // Set the design
        KTDesign *design = [[KSPlugInWrapper sortedPluginsWithFileExtension:kKTDesignExtension] firstObjectKS];
        [master setDesign:design];
        
        
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
        [root setTitle:defaultRootPageTitleText];
        
        
        // Set the Favicon
        NSString *faviconPath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
        [master setFaviconWithContentsOfURL:[NSURL fileURLWithPath:faviconPath]];
        
        
        // Create a starter pagelet
        SVTextBox *textBox = [SVTextBox insertNewTextBoxIntoManagedObjectContext:[self managedObjectContext]];
        [textBox setSortKey:[NSNumber numberWithShort:0]];
        [textBox setTitle:@"Test"];
        
        [[textBox body] setString:@"<p>Test paragraph</p>"];
        [[root sidebar] addPageletsObject:textBox];
        
        
        // Finish up
        [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                            object:undoManager];
        [undoManager enableUndoRegistration];
    }
	
	
    return self;
}

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if (self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError])
    {
        
    }
    
    return self;
}

- (KTPage *)makeRootPage
{
    id result = [NSEntityDescription insertNewObjectForEntityForName:@"Page" 
                                              inManagedObjectContext:[self managedObjectContext]];
	OBASSERT(result);
	
	[result setValue:[self site] forKey:@"site"];	// point to yourself
		
    [result setBool:YES forKey:@"isCollection"];	// root is automatically a collection
    [result setAllowComments:[NSNumber numberWithBool:NO]];
    
	return result;
}

- (void)dealloc
{
	[_site release];
    
    [_accessoryViewController release];
    
    [_persistentStoreURL release];
    [_filenameReservations release];
    [_deletedMediaDirectoryName release];
	
	// release context
	[_managedObjectContext release];
    
    [_thread release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Managing the Persistence Objects

/*	The first time the model is loaded, we need to give Fetched Properties sort descriptors.
 */
+ (NSManagedObjectModel *)managedObjectModel
{
	static NSManagedObjectModel *result;
	
	if (!result)
	{
		// grab only Sandvox.mom (ignoring "previous moms" in KTComponents/Resources)
		NSBundle *componentsBundle = [NSBundle mainBundle];
        OBASSERT(componentsBundle);
		
        NSString *modelPath = [componentsBundle pathForResource:@"Sandvox" ofType:@"mom"];
        OBASSERTSTRING(modelPath, [componentsBundle description]);
        
		NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
		OBASSERT(modelURL);
		
		result = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

- (NSManagedObjectContext *)managedObjectContext { return _managedObjectContext; }

/*  Called whenever a document is opened *and* when a new document is first saved.
 */
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)URL
                                           ofType:(NSString *)fileType
                               modelConfiguration:(NSString *)configuration
                                     storeOptions:(NSDictionary *)storeOptions
                                            error:(NSError **)outError
{
	NSPersistentStoreCoordinator *storeCoordinator = [[self managedObjectContext] persistentStoreCoordinator];
	OBPRECONDITION([[storeCoordinator persistentStores] count] == 0);   // This method should only be called the once
    
    
    BOOL result = YES;
	
	/// and we compute the sqlite URL here for both read and write
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:URL type:nil];
	
	// these two lines basically take the place of sending [super configurePersistentStoreCoordinatorForURL:ofType:error:]
	// NB: we're not going to use the supplied configuration or options here, though we could in a Leopard-only version
	result = ([storeCoordinator addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType]
                                             configuration:nil
                                                       URL:storeURL
                                                   options:nil
                                                     error:outError] != nil);
    
    if (result) [self setDatastoreURL:storeURL];
	
	
    return result;
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	return NSBinaryStoreType;
}

- (void)setFileURL:(NSURL *)absoluteURL
{
    // Mark persistent store as moved
    NSURL *storeURL = [self datastoreURL];
    if (storeURL)
    {
        // Also reset the persistent stores' DB connection if needed
        NSPersistentStoreCoordinator *PSC = [[self managedObjectContext] persistentStoreCoordinator];
        OBASSERT([[PSC persistentStores] count] <= 1);
        
        NSPersistentStore *store = [PSC persistentStoreForURL:storeURL];
        OBASSERT(store);
        
        NSURL *newStoreURL = [[self class] datastoreURLForDocumentURL:absoluteURL type:nil];
        [PSC setURL:newStoreURL forPersistentStore:store];
    }
    
    
    [super setFileURL:absoluteURL];
    
    
    // Update media etc. to match
    for (NSString *key in _filenameReservations)
    {
        id <SVDocumentFileWrapper> fileWrapper = [_filenameReservations objectForKey:key];
        if (![fileWrapper isDeletedFromDocument])
        {
            [fileWrapper forceUpdateFromURL:[absoluteURL URLByAppendingPathComponent:key isDirectory:NO]];
        }
    }
}

@synthesize datastoreURL = _persistentStoreURL;

#pragma mark Undo Support

/*  These methods are overridden in the same fashion as NSPersistentDocument
 */

- (BOOL)hasUndoManager { return YES; }

- (void)setHasUndoManager:(BOOL)flag { }

- (void)setUndoManager:(NSUndoManager *)undoManager
{
    // The correct undo manager is stored at initialisation time and can't be changed
}

#pragma mark Managing Document Windows

- (NSString *)displayName
{
    NSString *result = [super displayName];
    
    // For a new document, we want to guess from the site title
    if (![self fileURL])
    {
        NSString *siteTitle = [[[[[self site] rootPage] master] siteTitle] text];
        if ([siteTitle length] > 0)
        {
            result = siteTitle;
        }
    }
    
    return result;
}

#pragma mark Media

- (NSString *)addDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper; // returns the filename reserved
{
    NSString *preferredFilename = [wrapper preferredFilename];
    NSString *result = preferredFilename;
    
    NSUInteger count = 1;
    while ([self isFilenameReserved:result])
    {
        // Adjust the filename ready to try again
        count++;
		NSString *numberedName = [NSString stringWithFormat:
                                  @"%@-%u",
                                  [preferredFilename stringByDeletingPathExtension],
                                  count];
        
		result = [numberedName stringByAppendingPathExtension:[preferredFilename pathExtension]];
    }
    
    // Reserve it
    [_filenameReservations setObject:wrapper forKey:[result lowercaseString]];
    
    return result;
}

- (BOOL)isFilenameReserved:(NSString *)filename;
{
    OBPRECONDITION(filename);
    
    
    // Consult both cache and file system to see if the name is taken
    filename = [filename lowercaseString];
    BOOL result = ([_filenameReservations objectForKey:filename] != nil);
    if (!result)
    {
        result = [[NSFileManager defaultManager] fileExistsAtPath:[[self fileName] stringByAppendingPathComponent:filename]];
    }
    
    // The document also reserves some special cases itself
    if (!result)
    {
        if ([filename hasPrefix:@"index."] || [filename isEqualToString:@"index"] ||
            [filename hasPrefix:@"datastore."] || [filename isEqualToString:@"datastore"] ||
            [filename isEqualToString:@"quicklook"] ||
            [filename isEqualToString:@"contents"])
        {
            result = YES;
        }
    }
    
    return result;
}

- (void)unreserveFilename:(NSString *)filename;
{
    [_filenameReservations removeObjectForKey:[filename lowercaseString]];
}

- (NSSet *)missingMedia;
{
	NSFetchRequest *request = [[[self class] managedObjectModel] fetchRequestTemplateForName:@"ExternalMedia"];
    NSArray *externalMedia = [[self managedObjectContext] executeFetchRequest:request error:NULL];
    
    NSMutableSet *result = [NSMutableSet set];
    
	for (SVMediaRecord *aRecord in externalMedia)
	{
		NSString *path = [[aRecord fileURL] path];
		if (!path ||
            [path isEqualToString:@""] ||
            [path isEqualToString:[[NSBundle mainBundle] pathForImageResource:@"qmark"]] ||
            ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			[result addObject:aRecord];
		}
	}
	
	return result;
}

#pragma mark Document Content Management

/*  Supplement the usual read behaviour by logging host properties and loading document display properties
 */
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	// Should only be called the once
    BOOL result = [self configurePersistentStoreCoordinatorForURL:absoluteURL ofType:typeName modelConfiguration:nil storeOptions:nil error:outError];
    
    
    // Grab the site object
    if (result)
	{
        KTSite *site = [[[self managedObjectContext] site] retain];
        [self setSite:site];
        if (!site)
        {
            if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                          code:NSFileReadCorruptFileError
                                          localizedDescription:NSLocalizedString(@"Site not found", "doc open error")];
            result = NO;
        }
    }
    
    
    if (result)
    {
		// Load up document display properties
		[self setDisplaySmallPageIcons:[[self site] boolForKey:@"displaySmallPageIcons"]];
		
		
        // For diagnostics, log the value of the host properties
		if ([[NSUserDefaults standardUserDefaults] boolForKey:@"LogHostInfoToConsole"])
		{
			KTHostProperties *hostProperties = [[self site] hostProperties];
			NSLog(@"hostProperties = %@", [[hostProperties hostPropertiesReport] condenseWhiteSpace]);
		}
	}
	
	if (result)
	{
        NSString *path = [[self site] lastExportDirectoryPath];
        if (path) self.lastExportDirectory = [NSURL fileURLWithPath:path];
	}
    
    
    // Reserve all the media filenames already in use    
    NSManagedObjectContext *context = [self managedObjectContext];
    NSFetchRequest *request = [[[self class] managedObjectModel] fetchRequestTemplateForName:@"MediaInDocument"];
    NSArray *media = [context executeFetchRequest:request error:NULL];
    
    for (SVMediaRecord *aMediaRecord in media)
    {
        // Media needs to be told its location to be useful
        // Use -fileURL instead of absoluteURL since it accounts for autosave properly
        NSString *filename = [[aMediaRecord filename] lowercaseString];
        NSURL *mediaURL = [[self fileURL] URLByAppendingPathComponent:filename isDirectory:NO];
        [aMediaRecord forceUpdateFromURL:mediaURL];
        
        // Does this match some media already loaded? 
        // Can't call -isFilenameReserved: since it will find the file on disk and return YES
        id <SVDocumentFileWrapper> fileWrapper = [_filenameReservations objectForKey:filename]; 
        if (fileWrapper)
        {
            [aMediaRecord setNextObject:fileWrapper];
        }
        
        [_filenameReservations setObject:aMediaRecord forKey:filename];
    }
        
    
    return result;
}

/*  Saving a document is somewhat complicated, so it's implemented in a dedicated category:
 *  KTDocument+Saving.m
 */

#pragma mark Controller Chain

/*!	Force KTDocument to use a custom subclass of NSWindowController
 */
- (void)makeWindowControllers
{
    NSWindowController *windowController = [[KTDocWindowController alloc] init];
    [self addWindowController:windowController];
    [windowController release];
}

- (void)removeWindowController:(NSWindowController *)windowController
{
	if ( [windowController isEqual:myHTMLInspectorController] )
    {
		[self setHTMLInspectorController:nil];
	}
		
	
    [super removeWindowController:windowController];
}

#pragma mark Changes

/*  Supplement NSDocument by broadcasting a notification that the document did change
 */
- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
    [super updateChangeCount:changeType];
    
    if (changeType == NSChangeDone || changeType == NSChangeUndone)
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:kKTDocumentDidChangeNotification object:self];
    }
}

#pragma mark Closing Documents

- (void)close
{	
	// Allow anyone interested to know we're closing. e.g. KTDocWebViewController uses this
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTDocumentWillCloseNotification object:self];

	
	// Remove temporary media files
    [[self undoManager] removeDeletedMediaDirectory:NULL];
    
	[super close];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"KTDocumentDidClose" object:self];
}

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
				NSMutableString *errorString = [NSMutableString stringWithFormat:@"%u validation errors have occurred.", numErrors];
				NSMutableString *secondary = [NSMutableString string];
				if ( numErrors > 3 )
				{
					[secondary appendFormat:NSLocalizedString(@"The first 3 are:\n", @"To be followed by 3 error messages")];
				}
				
				unsigned i;
				for ( i = 0; i < ((numErrors > 3) ? 3 : numErrors); i++ ) 
				{
					[secondary appendFormat:@"%@\n", [[detailedErrors objectAtIndex:i] localizedDescription]];
				}
				
				NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[inError userInfo]];
				[userInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
				[userInfo setObject:secondary forKey:NSLocalizedRecoverySuggestionErrorKey];

				result = [NSError errorWithDomain:[inError domain] code:[inError code] userInfo:userInfo];
			} 
		}
	}
    
    
    return result;
}

#pragma mark -
#pragma mark UI validation

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
	
	return [super validateMenuItem:menuItem]; 
}

#pragma mark -
#pragma mark Actions

- (IBAction)setupHost:(id)sender
{
	KTHostSetupController* sheetController
	= [[KTHostSetupController alloc] initWithHostProperties:[self valueForKeyPath:@"site.hostProperties"]];
		// LEAKING ON PURPOSE, THIS WILL BE AUTORELEASED IN setupHostSheetDidEnd:
	
	[NSApp beginSheet:[sheetController window]
	   modalForWindow:[self windowForSheet]
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
		if ([aSourceObject respondsToSelector:@selector(title)])
		{
			NSString *itsTitle = [(id)aSourceObject title];
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

/*
 
 I'm bringing this over from 1.6.  We'll want to tailor this appropriately to our new kinds of HTML blocks.
 I'm starting out by getting it working for editing of a text page.
 
 */

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	[self editSourceObject:nil keyPath:nil isRawHTML:YES];
	/* 
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
	 
	 */
}

#pragma mark UI

- (NSOpenPanel *)makeChooseDialog;
{
    NSOpenPanel *result = [NSOpenPanel openPanel];
    
	[result setCanChooseDirectories:NO];
	[result setTreatsFilePackagesAsDirectories:YES];
	[result setAllowsMultipleSelection:NO];
    
	[result setPrompt:NSLocalizedString(@"Insert", "open panel prompt button")];
    
    return result;
}

#pragma mark Delegate Methods

- (void)setupHostSheetDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
	KTHostSetupController* sheetController = (KTHostSetupController*)contextInfo;
	if (returnCode)
	{
		// init code only for new documents
		NSUndoManager *undoManager = [self undoManager];
		
		//[undoManager beginUndoGrouping];
		//KTStoredDictionary *hostProperties = [[self site] wrappedValueForKey:@"hostProperties"];
		KTHostProperties *hostProperties = [sheetController properties];
		[self setValue:hostProperties forKeyPath:@"site.hostProperties"];

		// For diagnostics, log the value of the host properties
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"LogHostInfoToConsole"] )
		{
			NSLog(@"new hostProperties = %@", [[hostProperties hostPropertiesReport] condenseWhiteSpace]);		
		}
		
		// All page and sitemap URLs are now invalid
        [[[self site] rootPage] recursivelyInvalidateURL:YES];
        [self willChangeValueForKey:@"publishedSitemapURL"];
        [self didChangeValueForKey:@"publishedSitemapURL"];
		
		
		
		[undoManager setActionName:NSLocalizedString(@"Host Settings", @"Undo name")];
				
		// Check encoding from host properties
		// Alas, I have no way to test this!
		
		NSString *hostCharset = [hostProperties valueForKey:@"encoding"];
		if ((nil != hostCharset) && ![hostCharset isEqualToString:@""])
		{
			NSString *rootCharset = [[[[self site] rootPage] master] valueForKey:@"charset"];
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
	[KSSilencingConfirmSheet alertWithWindow:[self windowForSheet] silencingKey:@"ShutUpCharsetMismatch" title:NSLocalizedString(@"Host Character Set Mismatch", @"alert title when the character set specified on the host doesn't match settings") format:NSLocalizedString(@"The host you have chosen always serves its text encoded as '%@'.  In order to prevent certain text from appearing incorrectly, we suggest that you set your site's 'Character Encoding' property to match this, using the inspector.",@""), [hostCharset uppercaseString]];
}

#pragma mark -
#pragma mark screenshot for feedback

- (BOOL)mayAddScreenshotsToAttachments;
{
	NSWindow *window = [self windowForSheet];
	return (window && [window isVisible]);
}

//  screenshot1 = document window
//  screenshot2 = document sheet, if any
//  screenshot3 = inspector window, if visible
// alternative: use screencapture to write a jpeg of the entire screen to the user's temp directory

- (void)addScreenshotsToAttachments:(NSMutableArray *)attachments attachmentOwner:(NSString *)attachmentOwner;
{
	
	NSWindow *window = [self windowForSheet];
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
	NSWindowController *sharedController = [[[KSDocumentController sharedDocumentController] inspectors] lastObject];
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
