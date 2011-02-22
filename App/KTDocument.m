//
//  KTDocument.m
//  Marvel
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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
#import "KTElementPlugInWrapper.h"
#import "KTDesign.h"
#import "SVPagesController.h"
#import "SVDocumentFileWrapper.h"
#import "KTDocWindowController.h"
#import "KTDocumentController.h"
#import "SVDocumentUndoManager.h"
#import "KTSite.h"
#import "KTElementPlugInWrapper.h"
#import "SVGraphicFactory.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "SVInspector.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "KTPage+Internal.h"
#import "SVPageTemplate.h"
#import "SVPublishingRecord.h"
#import "SVSidebar.h"
#import "KTSummaryWebViewTextBlock.h"
#import "SVTextBox.h"
#import "KTLocalPublishingEngine.h"
#import "KTDesignPlaceholder.h"

#import "NSManagedObjectContext+KTExtensions.h"

#import "KSAbstractBugReporter.h"
#import "KSCaseInsensitiveDictionary.h"
#import "KSSilencingConfirmSheet.h"

#import "NSArray+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWindow+Karelia.h"
#import "KSURLUtilities.h"

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


#define SVPersistentStoreFilename @"index"


@implementation NSDocument (DatastoreAdditions)

// These are made category methods so Shared code can work generically. These determine document types and URLs.

/*	Returns the URL to the primary document persistent store. This differs dependent on the document UTI.
 *	You can pass in nil to use the default UTI for new documents.
 */
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL type:(NSString *)typeName
{
	OBPRECONDITION(inURL);
	
	NSURL *result = nil;
	
	if ([typeName isEqualToString:kSVDocumentTypeName_1_5] || [typeName isEqualToString:kSVDocumentType])
	{
		result = [inURL ks_URLByAppendingPathComponent:@"datastore.sqlite3" isDirectory:NO];
	}
	else if ([typeName isEqualToString:kSVDocumentType_1_0])
	{
		result = inURL;
	}
	else
	{
		result = [inURL ks_URLByAppendingPathComponent:SVPersistentStoreFilename isDirectory:NO];
	}
	
	
	return result;
}

+ (NSURL *)documentURLForDatastoreURL:(NSURL *)datastoreURL;
{
    OBPRECONDITION(datastoreURL);
    OBPRECONDITION([[datastoreURL ks_lastPathComponent] isEqualToString:SVPersistentStoreFilename]);
    
    NSURL *result = [datastoreURL ks_URLByDeletingLastPathComponent];
    return result;
}

+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL
{
	OBASSERT(inURL);
	
	NSURL *result = [inURL ks_URLByAppendingPathComponent:@"QuickLook" isDirectory:YES];
	
	OBPOSTCONDITION(result);
	return result;
}

+ (NSURL *)quickLookPreviewURLForDocumentURL:(NSURL *)inURL;
{
    NSURL *quickLookDirectory = [KTDocument quickLookURLForDocumentURL:inURL];
    NSURL *result = [quickLookDirectory ks_URLByAppendingPathComponent:@"Preview.html"
                                                        isDirectory:NO];
    
    return result;
}

@end



@interface KTDocument ()

- (void)setURLForPersistentStoreUsingFileURL:(NSURL *)absoluteURL;

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
        _filenameReservations = [[KSCaseInsensitiveDictionary alloc] init];
        
        
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
        NSArray *designs = [KSPlugInWrapper sortedPluginsWithFileExtension:kKTDesignExtension];
		NSArray *newRangesOfGroups;
		designs = [KTDesign reorganizeDesigns:designs familyRanges:&newRangesOfGroups];
		
        [master setDesign:[designs firstObjectKS]];
        
        
        // Set up root properties that used to come from document defaults
        [master setValue:[[NSUserDefaults standardUserDefaults] valueForKey:@"author"] forKey:@"author"];
        
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
        
        
        // Create a starter pagelet
        SVGraphicFactory *factory = [[KTElementPlugInWrapper pluginWithIdentifier:@"sandvox.BadgeElement"] graphicFactory];
		if (factory)
		{
			SVGraphic *badge = [factory insertNewGraphicInManagedObjectContext:[self managedObjectContext]];
			[badge setSortKey:[NSNumber numberWithShort:0]];
			
			[badge awakeFromNew];
			[[root sidebar] addPageletsObject:badge];
		}
		else
		{
			LOG((@"Could not find badge element to add to initial document."));
		}

        
        
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
        [self didReadContentsForURL:absoluteURL];
    }
    
    return self;
}

- (id)initForURL:(NSURL *)absoluteDocumentURL withContentsOfURL:(NSURL *)absoluteDocumentContentsURL ofType:(NSString *)typeName error:(NSError **)outError
{
	// This is our first chance to notice that an autosaved document is being reopened.  Abort if option key is held down.
	if (NSNotFound != [[absoluteDocumentContentsURL path] rangeOfString:@"Autosave Information"].location)
	{
		if (GetCurrentEventKeyModifiers() & optionKey)	// Option key -- prevent opening of autosaved document.
		{
			[self release];
			return nil;
		}
	}
    if (self = [super initForURL:absoluteDocumentURL withContentsOfURL:absoluteDocumentContentsURL ofType:typeName error:outError])
    {
        // Correct persistent store URL now that it's finished reading
        [self setURLForPersistentStoreUsingFileURL:absoluteDocumentURL];
        
        
        // Correct media URLs
        //  #61400
        
        
        // Finish up
        [self didReadContentsForURL:absoluteDocumentURL];
    }
    
    return self;
}

- (KTPage *)makeRootPage
{
    // Create page
    SVPagesController *controller = [[SVPagesController alloc] init];
    [controller setManagedObjectContext:[self managedObjectContext]];
    [controller setEntityName:@"Page"];
    
    SVPageTemplate *template = [[SVPageTemplate alloc] initWithCollectionPreset:[NSDictionary dictionary]];
    [controller setEntityNameWithPageTemplate:template];
    [template release];
    
    KTPage *result = [controller newObject];
	OBASSERT(result);
    [controller release];
	
    
    // Configure
	[result setValue:[self site] forKey:@"site"];	// point to yourself
    
    
	return [result autorelease];
}

- (void)dealloc
{
	[_site release];
    
    [_accessoryViewController release];
    
    [_store release];
    [_filenameReservations release];
    [_deletedMediaDirectoryName release];
    [_lastExportDirectory release];
	
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
    
    
    
	// these two lines basically take the place of sending [super configurePersistentStoreCoordinatorForURL:ofType:error:]
	// NB: we're not going to use the supplied configuration or options here, though we could in a Leopard-only version
	NSPersistentStore *store = [storeCoordinator addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType]
                                                              configuration:nil
                                                                        URL:URL
                                                                    options:nil
                                                                      error:outError];
    [self setPersistentStore:store];
    
	return (store != nil);
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	return NSBinaryStoreType;
}

#pragma mark Reading From and Writing to URLs

- (void)openDesignChooser
{
	[[self windowForSheet] doCommandBySelector:@selector(chooseDesign:)];
}

/*!
 *  If the media is not marked as autosaved, returns the URL it should have. Otherwise returns nil.
 */
- (NSURL *)URLForMediaRecord:(SVMediaRecord *)media
                    filename:(NSString *)path
       inDocumentWithFileURL:(NSURL *)docURL;
{
    NSURL *result = nil;
    
    if (/*![media autosaveAlias] &&*/ path)
    {
        if ([path hasPrefix:@"Shared/"] || [path hasPrefix:@"shared/"])
        {
            // Special case; design placeholder image
            // This is kind of a hack to jump to the placeholder I admit; will fix up if we need more
			KTDesign *design = [[[[self site] rootPage] master] design];
			if ([design isKindOfClass:[KTDesignPlaceholder class]])
			{
				// Force design chooser sheet to open if we don't have a design
				[self performSelector:@selector(openDesignChooser) withObject:nil afterDelay:0.0];
			}
			
            NSBundle *bundle = [design bundle];
            NSString *filename = [path lastPathComponent];
            
            NSString *resultPath = [bundle pathForResource:[filename stringByDeletingPathExtension] 
                                                    ofType:[filename pathExtension]];
            
            if (!resultPath)
            {
                resultPath = [[NSBundle mainBundle] pathForResource:[filename stringByDeletingPathExtension] 
                                                             ofType:[filename pathExtension]];
            }
            
            if (resultPath) result = [NSURL fileURLWithPath:resultPath];
        }
        else
        {
            result = [docURL ks_URLByAppendingPathComponent:path isDirectory:NO];
        }
    }
    
    return result;
}

/*  Supplement the usual read behaviour by logging host properties and loading document display properties
 */
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	// Should only be called the once
    NSURL *newStoreURL = [[self class] datastoreURLForDocumentURL:absoluteURL type:nil];
    
    BOOL result = [self configurePersistentStoreCoordinatorForURL:newStoreURL
                                                           ofType:typeName
                                               modelConfiguration:nil
                                                     storeOptions:nil
                                                            error:outError];
    
    
    // Grab the site object
    NSManagedObjectContext *context = [self managedObjectContext];
    if (result)
	{
        KTSite *site = [context site];
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
    NSFetchRequest *request = [[[self class] managedObjectModel] fetchRequestTemplateForName:@"MediaInDocument"];
    NSArray *media = [context executeFetchRequest:request error:NULL];
    
    for (SVMediaRecord *aMediaRecord in media)
    {
        // Media needs to be told its location to be useful
        // Use [self fileURL] instead of absoluteURL since it accounts for autosave properly
        NSString *path = [aMediaRecord filename];
        
        NSURL *mediaURL = [self URLForMediaRecord:aMediaRecord 
                                         filename:path
                            inDocumentWithFileURL:[self fileURL]];
        
        if (mediaURL) [aMediaRecord forceUpdateFromURL:mediaURL];
        
        if (![path hasPrefix:@"Shared/"] && ![path hasPrefix:@"shared/"])
        {
            // Does this match some media already loaded? 
            // Can't call -isFilenameReserved: since it will find the file on disk and return YES
            id <SVDocumentFileWrapper> fileWrapper = [_filenameReservations objectForKey:path]; 
            if (fileWrapper) [aMediaRecord setNextObject:fileWrapper];
            
            [self setDocumentFileWrapper:aMediaRecord forKey:path];
        }
    }
    
    
    return result;
}

- (void)didReadContentsForURL:(NSURL *)URL;
{
    // We really don't want the doc being marked as edited as soon as it's created, so suppress registration
    NSUndoManager *undoManager = [self undoManager];
    [undoManager disableUndoRegistration];
    
    /*
    // Insert media records for any unknown files in the package. #62243
    NSArray *directoryContents = [[NSFileManager defaultManager]
                                  contentsOfDirectoryAtPath:[URL path] error:NULL];
    
    for (NSString *aFilename in directoryContents)
    {
        if ([self isFilenameAvailable:aFilename])
        {
            // Create media record
            NSManagedObjectContext *context = [self managedObjectContext];
            
            SVMediaRecord *record = [SVMediaRecord
                                     mediaByReferencingURL:[URL ks_URLByAppendingPathComponent:aFilename isDirectory:NO]
                                     entityName:@"MediaRecord"
                                     insertIntoManagedObjectContext:context
                                     error:NULL];
            [record setFilename:aFilename]; // mark as already copied into doc
            
            // Record
            [self addDocumentFileWrapper:record];
            
            // Delete immediately so as to dispose of at next save
            [context deleteObject:record];
        }
    }
    */
    
    // Finish up
    [[NSNotificationCenter defaultCenter] postNotificationName:NSUndoManagerCheckpointNotification
                                                        object:undoManager];
    [undoManager enableUndoRegistration];
}

- (void)setFileURL:(NSURL *)absoluteURL
{
    // Mark persistent store as moved
    [self setURLForPersistentStoreUsingFileURL:absoluteURL];
    
    
    [super setFileURL:absoluteURL];
    
    
    // Update media etc. to match
    [[self managedObjectContext] processPendingChanges];
    [[self undoManager] disableUndoRegistration];
    
    NSDictionary *media = [self documentFileWrappers];
    for (NSString *key in media)
    {
        id <SVDocumentFileWrapper> fileWrapper = [media objectForKey:key];
        if (![fileWrapper isDeletedFromDocument])
        {
            NSURL *URL = [self URLForMediaRecord:(SVMediaRecord *)fileWrapper
                                        filename:key
                           inDocumentWithFileURL:absoluteURL];
            
            [fileWrapper forceUpdateFromURL:URL];
        }
    }
    
    [[self managedObjectContext] processPendingChanges];
    [[self undoManager] enableUndoRegistration];
}

- (void)setAutosavedContentsFileURL:(NSURL *)absoluteURL;
{
    [super setAutosavedContentsFileURL:absoluteURL];
    
    // If this the only copy, tell the store its new location
    if (absoluteURL && ![self fileURL])
    {
        [self setURLForPersistentStoreUsingFileURL:absoluteURL];
    }
}

@synthesize persistentStore = _store;

- (void)setURLForPersistentStoreUsingFileURL:(NSURL *)absoluteURL;
{
    NSPersistentStore *store = [self persistentStore];
    if (!store) return;
    
    NSPersistentStoreCoordinator *coordinator = [[self managedObjectContext] persistentStoreCoordinator];
    OBASSERT([[coordinator persistentStores] containsObject:store]);
    
    NSURL *storeURL = nil;
    if (absoluteURL) storeURL = [[self class] datastoreURLForDocumentURL:absoluteURL type:nil];
    
    [coordinator setURL:storeURL forPersistentStore:store];
}

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

- (NSDictionary *)documentFileWrappers; { return [[_filenameReservations copy] autorelease]; }

- (NSString *)keyForDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper;
{
    NSArray *keys = [[self documentFileWrappers] allKeysForObject:wrapper];
    return [keys lastObject];
}

- (NSString *)addDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper; // returns the filename reserved
{
    NSString *preferredFilename = [wrapper preferredFilename];
    NSString *result = preferredFilename;
    
    NSUInteger count = 1;
    while (![self isFilenameAvailable:result])
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
    [self setDocumentFileWrapper:wrapper forKey:result];
    
    return result;
}

- (void)setDocumentFileWrapper:(id <SVDocumentFileWrapper>)wrapper forKey:(NSString *)key;
{
    [_filenameReservations setObject:wrapper forKey:key];
}

- (BOOL)isFilenameAvailable:(NSString *)filename;
{
    OBPRECONDITION(filename);
    
    
    // Consult both cache to see if the name is taken
    BOOL result = ([[self documentFileWrappers] objectForKey:filename] == nil);
    
    
    // The document also reserves some special cases itself
    if (result)
    {
        if ([[filename stringByDeletingPathExtension] isEqualToString:@"index"] ||
            [filename isEqualToString:@"quicklook"] ||
            [filename isEqualToString:@"contents"] ||
            [filename isEqualToString:@"shared"] ||
            [filename isEqualToString:@"theme-files"] ||
            [filename isEqualToString:@"thumbs"])
        {
            result = NO;
        }
    }
    
    
    // Finally, see if there's already an item on disk (such as .svn directory)
    if (result)
    {
        NSURL *docURL = [self fileURL];
        NSURL *url = [docURL ks_URLByAppendingPathComponent:filename isDirectory:NO];
        if ([url isFileURL])
        {
            result = ![[NSFileManager defaultManager] fileExistsAtPath:[url path]];
        }
    }
    
    return result;
}

- (void)unreserveFilename:(NSString *)filename;
{
    [_filenameReservations removeObjectForKey:filename];
}

- (void)designDidChange;
{
    // Placeholder/shared/bundled media
    NSPredicate *predicate = [NSPredicate predicateWithFormat:
                              @"filename beginswith[c] 'Shared/'"];
    
    NSArray *sharedMedia = [[self managedObjectContext]
                            fetchAllObjectsForEntityForName:@"GraphicMedia"
                            predicate:predicate
                            error:NULL];
    
    KTMaster *master = [[[self site] rootPage] master];
    
    for (SVMediaRecord *aMediaRecord in sharedMedia)
    {
        // Replace with a new record
        SVMediaRecord *media = [master makePlaceholdImageMediaWithEntityName:@"GraphicMedia"];
        SVGraphic *graphic = [aMediaRecord valueForKey:@"graphic"];
        [graphic replaceMedia:media forKeyPath:@"media"];
    }
    
    
    // Let all graphics know of the change. Size any embedded images to fit. #105069
	NSArray *graphics = [[self managedObjectContext] fetchAllObjectsForEntityForName:@"Graphic" error:NULL];
	for (SVGraphic *aGraphic in graphics)
	{
		for (id <SVPage> aPage in [aGraphic pages])
		{
			[aGraphic didAddToPage:aPage];
		}
	}
}

- (NSSet *)missingMedia;
{
    NSManagedObjectModel *model = [[self class] managedObjectModel];
	NSFetchRequest *request = [model fetchRequestTemplateForName:@"ExternalMedia"];
    NSArray *externalMedia = [[self managedObjectContext] executeFetchRequest:request error:NULL];
    
    NSMutableSet *result = [NSMutableSet set];
    
	for (SVMediaRecord *aRecord in externalMedia)
	{
		NSString *path = [[aRecord fileURL] path];
		if (!path ||
            [path isEqualToString:@""] ||
            [path isEqualToString:[[NSBundle mainBundle] pathForImageResource:@"MissingMediaQMark"]] ||
            ![[NSFileManager defaultManager] fileExistsAtPath:path])
		{
			[result addObject:aRecord];
		}
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
    if ([[self fileType] isEqualToString:kSVDocumentTypeName])
    {
        NSWindowController *windowController = [[KTDocWindowController alloc] init];
        [self addWindowController:windowController];
        [windowController release];
    }
    else
    {
        [super makeWindowControllers];
    }
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
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));
		
    // "Save a Copy As..." saveDocumentTo:  – why does this need special checking? Mike.
	if ( [menuItem action] == @selector(saveDocumentTo:) )
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

#pragma mark UI

- (NSOpenPanel *)makeChooseDialog;
{
    NSOpenPanel *result = [NSOpenPanel openPanel];
    
	[result setCanChooseDirectories:NO];
	[result setTreatsFilePackagesAsDirectories:NO];	// We don't want to descend into packages
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
		
		KTHostProperties *hostProperties = [sheetController properties];
		[self setValue:hostProperties forKeyPath:@"site.hostProperties"];

		// For diagnostics, log the value of the host properties
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"LogHostInfoToConsole"] )
		{
			NSLog(@"new hostProperties = %@", [[hostProperties hostPropertiesReport] condenseWhiteSpace]);		
		}
        
        
        // Reset publishing records
        for (SVPublishingRecord *aRecord in [[hostProperties rootPublishingRecord] contentRecords])
        {
            [[self managedObjectContext] deleteObject:aRecord]; // context should recurse and delete descendants
        }
        
		
		// All page and sitemap URLs are now invalid
        [[[self site] rootPage] recursivelyInvalidateURL:YES];
		
		
		
		NSUndoManager *undoManager = [self undoManager];
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
