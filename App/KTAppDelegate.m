//
//  KTAppDelegate.m
//  Marvel
//
//  Copyright (c) 2004-2005 Biophony, LLC. All rights reserved.
//

/*
 PURPOSE OF THIS CLASS/CATEGORY:
	Standard application delegate.  Deals with:
		Default Preferences
		Register Value Transformers for binding & UI
		Manage bundles
		Home base connection & licensing
		Opening of documents previously open
		Setting up Crash Reporter
		Display of global windows, menus, etc.
		Debugging Displays

TAXONOMY AND RELATIONSHIP TO OTHER CLASSES:
	x

IMPLEMENTATION NOTES & CAUTIONS:
	x
 */

#import "KTAppDelegate.h"

#import "Debug.h"
#import "BDAlias.h"
#import "KT.h"
#import "KTAcknowledgmentsController.h"
#import "KTApplication.h"
#import "KTBundleManager.h"
#import "KTCrashReporter.h"
#import "KTDesignManager.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTDocumentController.h"
#import "KTFeedbackReporter.h"
#import "KTHostSetupController.h"
#import "KTInfoWindowController.h"
#import "KTNewsController.h"
#import "KTPlaceholderController.h"
#import "KTPrefsController.h"
#import "KTQuickStartController.h"
#import "KTRegistrationController.h"
#import "KTPluginInstallerController.h"
#import "KTReleaseNotesController.h"
#import "KTToolbars.h"
#import "KTTranscriptController.h"
#import "KTWebView.h"
#import "KSUtilities.h"
#import "NSException+Karelia.h"
#import "NSString+KTApplication.h"
#import "NSString-Utilities.h"
#import "NSError+Karelia.h"
#import "NSArray+KTExtensions.h"
#import <AmazonSupport/AmazonSupport.h>
#import <Connection/Connection.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenSaver/ScreenSaver.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <iMediaBrowser/iMediaBrowser.h>
#import <ExceptionHandling/NSExceptionHandler.h>


#import "KSEmailAddressComboBox.h"
#import "KSSilencingConfirmSheet.h"
#import "KTUtilities.h"

#import "KTMediaManager.h"
#import "NSWorkspace+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"

#import "NSApplication+Karelia.h"
#import "AQDataExtensions.h"
#import "KTPage.h"

#import "NSToolbar+Karelia.h"

#ifdef SANDVOX_RELEASE
#import "Registration.h"
#endif

// ? #import </usr/include/objc/objc-class.h>
// ? #import </usr/include/objc/Protocol.h>

#include <openssl/rsa.h>
#include <openssl/sha.h>
#include <openssl/err.h>
#import <netinet/in.h>


enum {
	versionMask = 1+2+4, // 0 = trial license; 1 = license for v. 1; ... 7 = perpetual comp license?
    licenseMask = 8+16,
	paymentMask = 32,	// paypal or other
	proMask = 64,		// pro or normal
	namedMask = 128		// if on, then this is somebody's name; if off, it's an anonymous index
};

const int the16BitPrime = 65521;
const int theBigPrime = 5003;	
const int the8BitPrime = 251;		// fits in 1 byte

// NSLocalizedString(@"Comment", "String_On_Page_Template -- text for link on a blog posting")
// NSLocalizedString(@"Other Posts About This", "String_On_Page_Template - description of trackbacks")
// NSLocalizedString(@"Trackback", "String_On_Page_Template - text for trackback link")
// NSLocalizedString(@"To enable comments you need to enter your Haloscan ID into the Site Inspector", "Prompt in webview")



// See: Sandvox KTAppDelegate, RegGenerator RegGenerator.h - make sure this corresponds to other apps
#define REFERENCE_TIMESTAMP @"2006-01-01 00:00:00 -0800"

// Comment this out if we are not building an expiring demo
#define EXPIRY_TIMESTAMP @"2008-03-15 11:59:59 -0800"

// Enable this to get an Apple Design Awards Build, pre-licensed.  ALSO DEFINE AN EXPIRATION, DUDE!
// (this is a non-expiring, worldwide, pro license)
// #define APPLE_DESIGN_AWARDS_KEY [@"Nccyr Qrfvta Njneqf Tnyvyrr Pnqv Ubc" rot13]

// courtesy http://www.cocoabuilder.com/archive/message/cocoa/2001/7/13/20754
#define KeyShift	0x38
#define KeyControl	0x3b
#define KeyOption	0x3A
#define KeyCommand	0x37
#define KeyCapsLock	0x39
#define KeySpace	0x31
#define KeyTabs		0x30


// TODO: visit every instance of NSLog or LOG(()) to see if it should be an NSAlert/NSError to the user

@interface NSArray ( TableDataSource )
- (id)tableView:(NSTableView *)aTableVieRw objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (int)numberOfRowsInTableView:(NSTableView *)inTableView;
@end


@interface KTAppDelegate ( Private )

- (void)setMenuItemPro:(NSMenuItem *)aMenuItem;
- (BOOL) codeIsValid:(NSString *)aCode
					:(int *)outNamed
					:(NSString **)outLicensee
					:(int *)outIndex
					:(int *)outVersion
					:(NSDate **)outDate		// expiration if version == 0
					:(int *)outType
					:(int *)outSource
					:(int *)outPro
					:(unsigned int *)outSeats;

- (NSMutableDictionary *)dataModelForPlugin:(NSBundle *)aPlugin;
- (void)connectToHomeBase:(NSTimer *)aTimer;
- (void)showDebugTableForObject:(id)inObject titled:(NSString *)inTitle;	// a table or array
- (void)buildSampleSitesMenu;

- (void)warnExpiring:(id)bogus;

- (void)setAppIsTerminating:(BOOL)aFlag;

- (KTDocument *)openDocumentWithContentsOfURL:(NSURL *)aURL;

@end


@interface NSSQLChannel : NSObject // Apple Private
+ (void)setDebugDefault:(BOOL)flag;
@end


@implementation KTAppDelegate

/*!	Needs to be done on initialization, and after resetStandardUserDefaults is called
*/
+ (void) registerDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	
	// If we have already tested this CPU, just get value from the defaults.

    NSMutableDictionary *defaultsBase = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		
								 // General defaults ... app behavior. NOTE: THESE ARE CAPITALIZED
#ifdef DEBUG
		[NSNumber numberWithBool:YES],			@"IncludeDebugMenu",
		[NSNumber numberWithBool:YES],			@"OBShouldAbortOnAssertFailureEnabled",
#else
		[NSNumber numberWithBool:NO],			@"IncludeDebugMenu",
#endif
		@"all",									@"metaRobots",
#ifdef APPLE_DESIGN_AWARDS_KEY
		[NSNumber numberWithBool:YES],			@"LiveDataFeeds",		// I want ADA entries to have this on as default
#else
		[NSNumber numberWithBool:NO],			@"LiveDataFeeds",
#endif
		
		[NSNumber numberWithBool:NO],			@"KTLogAllContextChanges",
		
		[NSNumber numberWithBool:YES],			@"KTLogToConsole",
		
		[NSNumber numberWithBool:NO],			@"urls in background",
		
		[NSNumber numberWithBool:YES],			@"FirstRun",
		
		[NSNumber numberWithUnsignedInt:5],		@"KeepAtMostNBackups",
		
		[NSNumber numberWithBool:YES],			@"SendCrashReports",
		
		[NSNumber numberWithBool:YES],			@"EscapeNBSP",		// no longer used apparently
		[NSNumber numberWithBool:YES],			@"GetURLsFromSafari",
		[NSNumber numberWithBool:YES],			@"AutoOpenLastOpenedOnLaunch",
		[NSArray array],						@"LastOpened",
		[NSNumber numberWithBool:YES],			@"OpenUntitledFileWhenIconClicked",
		[NSNumber numberWithInt:60 * 60 * 6],	@"SecondsBetweenHomeBaseChecks",
		[NSNumber numberWithBool:YES],			@"contactHomeBase",
		[NSNumber numberWithBool:YES],			@"ContinuousSpellChecking",
				
		@"",									@"CrashReporterFromAddress",
		
		[NSNumber numberWithBool:NO],			@"DisplayInfo",
		
		//[NSNumber numberWithBool:YES],			@"AutosaveDocuments",
		//[NSNumber numberWithBool:YES],			@"BackupWhenSaving",
		//[NSNumber numberWithDouble:600.0],		@"BackupTimeInterval",

		[NSNumber numberWithUnsignedInt:2],			@"BackupOnOpening", // default is to snapshot
	
		
		[NSNumber numberWithBool:NO],			@"AllowPasswordToBeLogged", // for Connection class
		[NSNumber numberWithBool:YES],			@"DebugConnection",	// obsolete
		
		[NSNumber numberWithBool:YES],			@"ShowOutlineTooltips",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowPageType",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowIndexType",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowTitle",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowLastUpdated",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowServerPath",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowAuthor",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowShowLanguage",
		//		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowIsDraft",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowNeedsUploading",
		
		[NSNumber numberWithInt:5],				@"MaximumTitlesInCollectionSummary",
		[NSNumber numberWithBool:NO],			@"CreateBackupFileWhenSaving",
		[NSNumber numberWithBool:YES],			@"UseGradientSiteOutlineHilite",
		[NSNumber numberWithBool:NO],			@"UseTexturedDocumentWindows",
		[NSNumber numberWithBool:YES],			@"UseUnifiedToolbarWindows",
		[NSNumber numberWithBool:NO],			@"PathsWithIndexPages",	// should paths end in index.html ?
		// DON'T HAVE DEFAULT VALUE -->	   NSStringFromSize(NSMakeSize(1024, 530)), @"DefaultDocumentWindowContentSize",
		@"",	@"DefaultRootIndexBundleIdentifier",	// no index default on root
		@"sandvox.ArchiveIndex",	@"DefaultArchivesIndexBundleIdentifier",
		@"sandvox.GeneralIndex",	@"DefaultIndexBundleIdentifier",
		@"sandvox.BadgeElement",	@"DefaultBadgeBundleIdentifier",		// can be empty
		@"sandvox.RSSBadgeElement",	@"DefaultRSSBadgeBundleIdentifier",		// can be empty
		@"index.xml", @"RSSFileName",
		@"index", @"htmlIndexBaseName",
		@"archives", @"archivesBaseName",

		@" | ", @"TitleSeparator",
		
		kKTDefaultMediaPath, @"DefaultMediaPath",
		kKTDefaultResourcesPath, @"DefaultResourcesPath",
		[NSNumber numberWithBool:YES], @"RemoveDuplicateReservedMediaRefs",
		
		//								   @"atom.xml", @"AtomFileName",
		[NSNumber numberWithInt:KTXHTMLStrictDocType], @"DocType",
					@"karelsofwa-20",	@"AmazonAssociatesToken",		// TODO: get one for sandvox
		
		[NSNumber numberWithBool:NO],			@"PreferRelativeLinks", // obsolete
		
		[NSNumber numberWithBool:YES],			@"supportTrackbacks",	// obsolete
		@"",									@"haloscanUserName",
		
		[NSNumber numberWithBool:YES], @"DoAnimations",
		[NSNumber numberWithInt:100], @"MaximumDraggedPages",	// don't allow dragging THAT many items
		
		
		// Transition filter & default parameters ... could be changed by somebody savvy
		[NSNumber numberWithFloat:1.0],			@"AnimationTime",
		@"CIRippleTransition",					@"CIFilterNameForAnimation",
		[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithFloat: 200.0],@"inputWidth",
			[NSNumber numberWithFloat: 30.0],@"inputScale",nil], 
		@"CIFilterParameters",
		
        @"http://launch.karelia.com/",		@"HomeBaseURL",	// must end in slash
		[NSNumber numberWithInt:5],				@"LocalHostVerifyTimeout",
		@"/Library/WebServer/Documents",		@"ApacheDocRoot",
		[NSNumber numberWithBool:NO],			@"SetDateFromSourceMaterial",
		[NSNumber numberWithBool:YES],			@"SetDateFromEXIF",		// applies if above is used

		[NSNumber numberWithBool:NO],			@"movie autoplay",
		[NSNumber numberWithBool:YES],			@"movie controller",
		[NSNumber numberWithBool:NO],			@"movie kioskmode",
		[NSNumber numberWithBool:NO],			@"movie loop",
		
		[NSNumber numberWithBool:NO],			@"linkImageToOriginal",
		[NSNumber numberWithBool:YES],			@"shouldIncludeLink",	// For the checkbox of whether there should be ANY link from an image.
		[NSNumber numberWithBool:NO],			@"preferExternalImage",
		
		[NSNumber numberWithFloat:1.0],			@"KTFaviconSharpeningFactor",
		[NSNumber numberWithFloat:0.3],			@"KTSharpeningFactor",
		[NSNumber numberWithFloat:0.7],			@"KTPreferredJPEGQuality",
		[NSNumber numberWithBool:NO],			@"KTPrefersPNGFormat",
		[NSNumber numberWithBool:NO],			@"KTSendMeEmail",
		[NSNumber numberWithBool:YES],			@"KTShowAnnouncements",		// show weblog badge
		[NSNumber numberWithBool:YES],			@"KTHaloscanTrackbacks",	// KTHaloscanID is nil initially
		
		[NSNumber numberWithBool:NO],			@"ShowSearchPaths",			// NSLog where items are searched for
		
		
		@"sandvox.Aqua",		@"designBundleIdentifier",
		
		[NSMutableArray array],					@"keywords",
		[NSNumber numberWithFloat:1.0],			@"textSizeMultiplier",
		[NSDictionary
			dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:0], @"localHosting",
			[NSNumber numberWithInt:0], @"localSharedMatrix",	// 0 = ~ , 1 = computer
			nil],								@"defaultHostProperties",
		
		[NSNumber numberWithShort:0],		@"truncateCharacters",
		[NSNumber numberWithShort:KTCopyMediaAutomatic], @"copyMediaOriginals",
		[NSNumber numberWithShort:KTSummarizeAutomatic], @"collectionSummaryType",
		[NSNumber numberWithShort:NSDateFormatterMediumStyle], @"timestampFormat",
		[NSNumber numberWithBool:YES], @"timestampShowTime",
		[NSNumber numberWithShort:KTTimestampCreationDate], @"timestampType",
		
		[NSNumber numberWithBool:YES], @"enableImageReplacement",
		@"html", @"fileExtension",
		
		[NSNumber numberWithBool:NO], @"DebugImageReplacement",
		
		// Don't need these unless/until we support multiple formats
		//		[NSNumber numberWithBool:NO], @"collectionGenerateAtom",
		//		[NSNumber numberWithBool:YES], @"collectionGenerateRSS",
		[NSNumber numberWithBool:NO], @"headerImageHidesH1",
		[NSNumber numberWithBool:YES], @"collectionHyperlinkPageTitles",
		[NSNumber numberWithBool:NO], @"collectionShowPermanentLink",
		[NSNumber numberWithBool:YES], @"collectionShowSortingControls",
		
		[NSNumber numberWithBool:NO], @"collectionShowSortingControls",
		[NSNumber numberWithInt:0], @"collectionMaxIndexItems",
								@"", @"headerImageDescription",

		@"", @"insertPrelude",
		@"", @"insertHead",
		@"", @"insertBody",
		@"", @"insertEndBody",
		
		[NSNumber numberWithBool:YES], @"propagateInsertPrelude",
		[NSNumber numberWithBool:YES], @"propagateInsertHead",
		[NSNumber numberWithBool:YES], @"propagateInsertBody",
		[NSNumber numberWithBool:YES], @"propagateInsertEndBody",
		
		@"", @"googleSiteVerification",
		@"", @"googleAnalyticsID",
		[NSNumber numberWithBool:NO], @"generateGoogleSitemap",

		[NSNumber numberWithInt:1], @"MediaLoaderMaxThreads",
		
		
		// Properties of document, reverting to preferences if not set in doc.
		
		[NSNumber numberWithBool:YES], @"displayStatusBar",
		[NSNumber numberWithBool:NO], @"displaySmallPageIcons",
		[NSNumber numberWithBool:YES], @"displaySiteOutline",
		@"", @"author",		// used to be NSFullUserName() but that puts the user's name on the title bar which people might not notice!
		
		// Connection timeout value 
		[NSNumber numberWithFloat:30.0], @"connectionTimeoutValue",
		
		@"0644", @"pagePermissions",
		[NSNumber numberWithBool:NO], @"deletePagesWhenPublishing",
		
		@"NSHost", @"hostResolver",
		
		
		// Amazon
		[AmazonECSOperation associateKeyDefaults], @"AmazonAssociateIDs",
		[NSNumber numberWithBool:NO], @"DebugAmazonListService",
		
		
		// THIS MIGHT BE NIL -- it should be last to not destroy the rest of the dictionary
		[KSEmailAddressComboBox primaryEmailAddress], DEFAULTS_ADDRESS_KEY,
		
		
		/// Whether or not to include original images (instead of images as found on the pages) in image RSS feeds.
		[NSNumber numberWithBool:NO],	@"RSSFeedEnclosuresAreOriginalImages",
		
		
		/// defaults to change .Mac publishing settings
		@"/Sites/", @"DotMacDocumentRoot",
		@"mac.com", @"DotMacDomainName",
		@"http://www.mac.com/", @"DotMacHomePageURL",
		@"http://homepage.mac.com/?/", @"DotMacStemURL",
		
		/// setting DotMacPersonalDomain will automatically override all DotMac* defaults
		@"", @"DotMacPersonalDomain",
		
		
		
		nil];
	
	OBASSERT(defaultsBase);

	// Load in the syntax coloring defaults
	NSDictionary *syntaxColorDefaults = [NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"SyntaxColorDefaults" ofType: @"plist"]];
	[defaultsBase addEntriesFromDictionary:syntaxColorDefaults];
			
    [defaults registerDefaults:defaultsBase];
	
	// debugging domains -- we have to set default values to get them to show up in the table.
	NSArray *domains = [NSArray arrayWithObjects:
		ControllerDomain, TransportDomain, StateMachineDomain, ParsingDomain, ProtocolDomain, ConnectionDomain, /* ThreadingDomain, */
		/* StreamDomain, */ InputStreamDomain, OutputStreamDomain, /* SSLDomain, */ QueueDomain, nil];
	
	NSEnumerator *theEnum = [domains objectEnumerator];
	NSString *aDomain;
	
	while (nil != (aDomain = [theEnum nextObject]) )
	{
		NSString *defaultsKey = [@"KTLoggingLevel." /* KTLogKeyPrefix */ stringByAppendingString:aDomain];
		if (nil == [defaults objectForKey:defaultsKey])
		{
			[defaults setInteger:DEFAULT_LEVEL forKey:defaultsKey];
		}
	}
}	

// TODO: make sure that everything used with wrappedInheritedValueForKey gets mentioned here!
+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#if MAC_OS_X_VERSION_MIN_REQUIRED < MAC_OS_X_VERSION_10_5
	// Already defined in Leopard
	gMainThread = [NSThread currentThread];
#endif
	
	[self registerDefaults];
	
	// Register my transformers.
	// Note: for some useful math operation transformers, see
	// http://homepage.mac.com/oscarmv/OMVFPValueTransformers.sitx

/*
	NSValueTransformer *theTransformer;

//	theTransformer = [[[RowHeightTransformer alloc] init] autorelease];
//	[NSValueTransformer setValueTransformer:theTransformer
//									forName:@"RowHeightTransformer"];

	// killing for now -- having problems with this crashing webkit!
	// TRYGIN AGAIN
	theTransformer = [[[RichTextHTMLTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"RichTextHTMLTransformer"];

	theTransformer = [[[ContainerIsEmptyTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"ContainerIsEmptyTransformer"];

	theTransformer = [[[ContainerIsNotEmptyTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"ContainerIsNotEmptyTransformer"];

	theTransformer = [[[EscapeHTMLTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"EscapeHTMLTransformer"];

	theTransformer = [[[CharsetToEncodingTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"CharsetToEncodingTransformer"];
	
	theTransformer = [[[StripHTMLTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"StripHTMLTransformer"];

	theTransformer = [[[TrimTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"TrimTransformer"];

	theTransformer = [[[StringToNumberTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"StringToNumberTransformer"];
	
	theTransformer = [[[TrimFirstLineTransformer alloc] init] autorelease];
	[NSValueTransformer setValueTransformer:theTransformer
									forName:@"TrimFirstLineTransformer"];
*/
	[pool release];
}

+ (KTAppDelegate *)sharedInstance
{
    return [NSApp delegate];
}

- (id)init
{
    self = [super init];
    if ( self )
    {
		// force webkit to load so we can log the version early
		(void) [[WebPreferences standardPreferences] setAutosaves:YES];

        // fire up a components manager and discover our components
        myBundleManager = [[KTBundleManager allocWithZone:[self zone]] init];

        // fire up a designs manager and discover our designs
		myDesignManager = [[KTDesignManager allocWithZone:[self zone]] init];
		myCascadePoint = NSMakePoint(100, 100);

        applicationIsLaunching = YES;
		myDidAwake = NO;
		myAppIsTerminating = NO;
	}
    return self;
}


- (void)dealloc
{
	[mNewsTimer invalidate];
	[mNewsTimer release]; mNewsTimer = nil;
	[mySimilarLicenses release]; mySimilarLicenses = nil;

    [myNetServiceBrowser stop];
	[myNetServiceBrowser release]; myNetServiceBrowser = nil;
	[myNetServicePort release]; myNetServicePort = nil;
    [myNetService stop];
	[myNetService release];	myNetService = nil;
	[myNetServiceName release]; myNetServiceName = nil;
	
	//[myDocumentController autorelease];
    [myDocumentController release]; myDocumentController = nil;
    [myBundleManager release]; myBundleManager = nil;
	[myDesignManager release]; myDesignManager = nil;

    [myGenericProgressPanel release]; myGenericProgressPanel = nil;
    
    [myFeedbackReporter release]; myFeedbackReporter = nil;
    
    if ( nil != myHomeBaseDict )
    {
        [myHomeBaseDict release]; myHomeBaseDict = nil;
    }
    if ( nil != myHomeBaseConnectionData )
    {
        [myHomeBaseConnectionData release]; myHomeBaseConnectionData = nil;
    }
    
    [self setNewVersionString:nil];
    [self setNewFeatures:nil];
    [self setCurrentAppDownloadURL:nil];
	
#ifdef OBSERVE_UNDO
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif

	[super dealloc];
}

- (void)awakeFromNib
{
	if ( !myDidAwake )
	{
		myDidAwake = YES;	// turn this on now so we can load a nib from her
		
		// set up a reusable, generic progress panel
		if ( nil == myGenericProgressPanel )
		{
			myGenericProgressPanel = [[NSPanel alloc] initWithContentRect:[oGenericProgressView bounds]
																styleMask:NSTitledWindowMask
																  backing:NSBackingStoreBuffered
																	defer:YES];
			[myGenericProgressPanel setTitle:[NSApplication applicationName]];
			[myGenericProgressPanel setContentView:oGenericProgressView];
			[myGenericProgressPanel setLevel:NSModalPanelWindowLevel];
		}
		
		// tweak any menus that need tweaking
		[self setCutMenuItemTitle:KTCutMenuItemTitle];
		[self setCopyMenuItemTitle:KTCopyMenuItemTitle];
		[self setDeletePagesMenuItemTitle:KTDeletePageMenuItemTitle];
				
		// see if we should add the Debug menu
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"IncludeDebugMenu"] )
		{
			[NSBundle loadNibNamed:@"DebugMenu" owner:self];
			
			NSMenuItem *debugMenu = [[[NSMenuItem alloc] initWithTitle:@"Debug" action:nil keyEquivalent:@""] autorelease];	// do not localize
			[debugMenu setSubmenu:oDebugMenu];
			[oDebugMenu setTitle:@"Debug"];	// do not localize
			[[NSApp mainMenu] addItem:debugMenu];
		}

		NSImage *globe = [NSImage imageNamed:@"globe"];
		//NSImage *trans = [NSImage imageNamed:@"trans16"];
		
		[oValidateSourceViewMenuItem setImage:globe];
		[oBuyRegisterSandvoxMenuItem setImage:globe];
		[oSetupHostMenuItem setImage:globe];
		//[oExportSiteMenuItem setImage:trans];
		//[oExportSiteAgainMenuItem setImage:trans];
		[oPublishChangesMenuItem setImage:globe];
		[oPublishEntireSiteMenuItem setImage:globe];
		[oProductPageMenuItem setImage:globe];
		[oVideoIntroductionMenuItem setImage:globe];
		[oInstallPluginsMenuItem setImage:globe];
		[oCheckForUpdatesMenuItem setImage:globe];

		[oViewPublishedSiteMenuItem setImage:globe];
		[oLatestNewsMenuItem setImage:globe];
		//[oReleaseNotesMenuItem setImage:trans];
		//[oAcknowledgementsMenuItem setImage:trans];
		[oSendFeedbackMenuItem setImage:globe];
		
	}
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	OBPRECONDITION(menuItem);
	//LOG((@"asking app delegate to validate menu item: %@", [menuItem title]));

	SEL action = [menuItem action];
	
	if (action == @selector(newDocument:))
	{
		return (!gLicenseViolation);
	}
	else if ( action == @selector(viewPublishedSite:) )
	{
		return NO; // no document has handled it, so there's no site to view
	}
	else if (action == @selector(editRawHTMLInSelectedBlock:))
	{
		return [[self currentDocument] validateMenuItem:menuItem];
	}
	else if (action == @selector(showPluginWindow:))
	{
		return nil != [self homeBaseDict];
	}
	
	return YES;
}

- (void)revertDocument:(KTDocument *)aDocument toSnapshot:(NSString *)aPath
{
	OBPRECONDITION(aDocument);
	OBPRECONDITION(aPath);
	// hang on to paths
	NSString *documentPath = [[[[aDocument fileURL] path] copy] autorelease];
	NSString *documentDirectory = [documentPath stringByDeletingLastPathComponent];
	NSString *documentName = [documentPath lastPathComponent];
	NSString *snapshotPath = [aDocument snapshotPath];
	NSString *snapshotDirectory = [snapshotPath stringByDeletingLastPathComponent];
	
	// close document
	[aDocument close];
	
	// perform file operations using Workspace
	NSArray *files = nil;
	int tag = 0;
	
	// recycle document
	files = [NSArray arrayWithObject:[documentPath lastPathComponent]];
	BOOL didMoveDocumentToTrash = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation 
																				  source:documentDirectory
																			 destination:nil
																				   files:files 
																					 tag:&tag];
	if ( !didMoveDocumentToTrash )
	{
		// alert the user
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Revert Failed", "alert: revert failed")
										 defaultButton:NSLocalizedString(@"OK", "OK Button")
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"Sandvox was unable to put the current version of the document in the Trash before reverting. This is done as a safety precaution. The document will not be reverted. Please check the Trash for any problems or remove the document at %@ manually.",
																		 "alert: could not Trash document"), documentPath];
		
		(void)[alert runModal];
		
		// reopen the document
//		[[KTDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:documentPath]
//																			   display:YES
//																				 error:nil];
		[self openDocumentWithContentsOfURL:[NSURL fileURLWithPath:documentPath]];
		
		return;
	}
	
	// copy snapshot to document location
	NSString *destPath = [documentDirectory stringByAppendingPathComponent:[snapshotPath lastPathComponent]];
	BOOL didRevert = [[NSFileManager defaultManager] copyPath:snapshotPath toPath:destPath handler:nil];

	// OLD WAY -- PROBLEMATIC
//	files = [NSArray arrayWithObject:[snapshotPath lastPathComponent]];
//	BOOL didRevert = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceCopyOperation 
//																	source:snapshotDirectory
//															   destination:documentDirectory
//																	 files:files 
//																	   tag:&tag];
	if ( !didRevert )
	{
		// alert the user
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Revert Failed", "alert: revert failed")
										 defaultButton:NSLocalizedString(@"OK", "OK Button")
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"Sandvox was unable to revert using the current snapshot. Please drag the document %@ out of the Trash and reopen it to continue using it. Please also check that the directory %@ is readable.",
																		 "alert: could not revert document"), documentName, [snapshotDirectory stringByDeletingLastPathComponent]];
		
		(void)[alert runModal];
		return;
	}
	
	// open reverted document
//	[[KTDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL fileURLWithPath:documentPath]
//																		   display:YES
//																			 error:nil];
	[self openDocumentWithContentsOfURL:[NSURL fileURLWithPath:documentPath]];
}








// Exceptions specific to Sandvox

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender
   shouldHandleException:(NSException *)exception 
					mask:(unsigned int)aMask
{
	NSString *name = [exception name];
	NSString *reason = [exception reason];
	
	// we want to log this.
	
	if ( [name isEqualToString:NSInvalidArgumentException]
		&& NSNotFound != [reason rangeOfString:@"passed DOMRange"].location  )
		
	{
		NSLog(@"PLEASE REPORT THIS TO KARELIA SOFTWARE - support@karelia.com -- %@", [[[exception userInfo] objectForKey:NSStackTraceKey] condenseWhiteSpace]);
		
		return NO;
	}
	
	if ([name isEqualToString:NSImageCacheException]
		|| [name isEqualToString:@"GIFReadingException"]
		|| [name isEqualToString:@"NSRTFException"]
		|| ( [name isEqualToString:NSInternalInconsistencyException]
			&& [reason hasPrefix:@"lockFocus"] ) 		// hmm, this wasn't noticed in case 6266.  Keep an eye on this!
		
		|| ( [name isEqualToString:NSInvalidArgumentException]
			&& NSNotFound != [reason rangeOfString:@"passed DOMRange"].location )
		
		|| ( [name isEqualToString:NSGenericException]
			&& NSNotFound != [reason rangeOfString:@"-[QCPatch portForKey:]: There is no port with key"].location )
		
		|| ( [name isEqualToString:NSRangeException]
			&& NSNotFound != [reason rangeOfString:@"-[NSBigMutableString characterAtIndex:]: Range or index out of bounds"].location )
		
		)
	{
		return NO;
	}
	
	if ( [name isEqualToString:NSInternalInconsistencyException] )
	{
		// catch all Undo exceptions and simply reset
		if ( [reason hasPrefix:@"_registerUndoObject"] )
		{
			LOG((@"caught _registerUndoObject exception, resetting undoManager"));
			KTDocument *document = [self currentDocument];
			[document resetUndoManager];
			return NO;
		}
		
		// another stab at undo
		if ( NSNotFound != [reason rangeOfString:@"undo was called with too many nested undo groups"].location )
		{
			LOG((@"caught undo called with too many nested undo groups exception, resetting undoManager"));
			KTDocument *document = [self currentDocument];
			[document resetUndoManager];
			return NO;
		}
	}
	
	if ( [name isEqualToString:NSObjectInaccessibleException] )
	{
		if ( [reason isEqualToString:@"CoreData could not fulfill a fault."] )
		{
			LOG((@"caught core data deleted object exception, ignoring"));
			// should change the selection to the root
			return NO;
		}
	}
	
	if ( [name isEqualToString:NSRangeException] )
	{
		NSString *stacktrace = [exception stacktrace];
		if ( NSNotFound != [stacktrace rangeOfString:@"+[CKHTTPResponse canConstructResponseWithData:]"].location )
		{
			return NO;
		}
		if ( NSNotFound != [stacktrace rangeOfString:@"-[DotMacConnection processResponse:]"].location )
		{
			return NO;
		}
	}
	return [super exceptionHandler:sender shouldHandleException:exception mask:aMask];
}














#pragma mark -
#pragma mark NSApplication Delegate

- (NSError *)application:(NSApplication *)theApplication willPresentError:(NSError *)inError
{
	//LOG((@"willPresentError: %@", inError));
	return inError;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
	if ( nil == [theApplication modalWindow] )
	{
		[self checkPlaceholderWindow:nil];
	}
	return YES; // we always return YES to purposefully thwart the NSDocument framework
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication
{
    if ( !applicationIsLaunching )
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"OpenUntitledFileWhenIconClicked"];
    }
    else
    {
        return NO;
    }
}

- (void)showGenericProgressPanelWithMessage:(NSString *)aString image:(NSImage *)anImage
{
	if (nil == anImage)
	{
		anImage = [NSImage imageNamed:@"AppIcon"];
	}
	if (nil == aString) aString = @"";	/// defense against nil
    [oGenericProgressImageView setImage:anImage];
    [oGenericProgressTextField setStringValue:aString];
    [oGenericProgressIndicator setUsesThreadedAnimation:YES];
    [oGenericProgressIndicator startAnimation:self];
    [myGenericProgressPanel center];
    [myGenericProgressPanel makeKeyAndOrderFront:self];
}

- (void)updateGenericProgressPanelWithMessage:(NSString *)aString
{
	if (nil == aString) aString = @"";	/// defense against nil
    [oGenericProgressTextField setStringValue:aString];
    [oGenericProgressTextField displayIfNeeded];
}

- (void)hideGenericProgressPanel
{
    [oGenericProgressIndicator stopAnimation:self];
    [oGenericProgressIndicator setUsesThreadedAnimation:NO];
    [myGenericProgressPanel orderOut:nil];
}

- (void)checkPlaceholderWindow:(id)bogus
{
	int windowCount = 0;
	NSEnumerator *theEnum = [[NSApp windows] objectEnumerator];
	NSWindow *aWindow;

	while (nil != (aWindow = [theEnum nextObject]) )
	{
		//LOG((@"%@ %@ visible:%d", aWindow, [aWindow title], [aWindow isVisible]));
		if (![aWindow isExcludedFromWindowsMenu] && [aWindow isVisible] && ![aWindow isKindOfClass:[NSPanel class]])
		{
			windowCount++;
		}
	}
	//LOG((@"%d windows menu items; allWindows = %@", windowCount, [[NSApp windows] description]));
		
	if ( nil == [NSApp modalWindow] && 0 == windowCount )
	{
		OFF((@"0 windows; so showing placeholder/violation window", windowCount));
		if (gLicenseViolation)		// license violation dialog should open, not the new/open
		{
			[[KTRegistrationController sharedRegistrationController] showWindow:nil];
		}
		else
		{
			[[KTPlaceholderController sharedPlaceholderController] showWindow:nil];
		}
	}
	else	// we have a document; close this window
	{
		[[[KTPlaceholderController sharedPlaceholderControllerWithoutLoading] window] orderOut:nil];
		OFF((@"%d windows; so closing placeholder window", windowCount));
	}
}

- (void)checkQuartzExtreme:(id)bogus
{
	// check Quartz Extreme compatibility
	BOOL qcEnabled = CGDisplayUsesOpenGLAcceleration(kCGDirectMainDisplay);
	if (!qcEnabled)
	{
		NSString *qxPart1 = NSLocalizedString(@"Advanced title creation is only available on Macs that support Quartz Extreme.",@"Quartz Extreme Comment");
		NSString *qxPart2 = NSLocalizedString(@"(Quartz Extreme functionality is supported by the following video GPUs: NVIDIA GeForce2 MX and later, or any AGP-based ATI RADEON GPU. A minimum of 16MB VRAM is required.)",@"Quartz Extreme Comment");
		NSString *qxPart3 = NSLocalizedString(@"Sandvox will still function perfectly well, but not be able to create fancy page titles.",@"Quartz Extreme Comment");
		
		[KSSilencingConfirmSheet
			alertWithWindow:nil
			   silencingKey:@"shutUpQuartzExtreme"
					  title:NSLocalizedString(@"Quartz Extreme Not Available", "Title of alert")
					 format:@"%@\n\n%@\n\n%@", qxPart1, qxPart2, qxPart3];
	}	
}


- (IBAction) reportLatestCrash:(id)sender
{
	[[KTCrashReporter sharedInstance] runAlert];
}

- (IBAction)loggingConfiguration:(id)sender
{
	[KTLogger configure:self];
}

- (void)checkCrashLog:(id)bogus
{
	// Inspired by UKCrashReporter
	NSString*		appName = [[NSProcessInfo processInfo] processName];	// NOT CFBundleExecutable!
	NSString*		crashLogsFolder = [@"~/Library/Logs/CrashReporter/" stringByExpandingTildeInPath];
	NSString*		crashLogName = [appName stringByAppendingString: @".crash.log"];
	NSString*		crashLogPath = [crashLogsFolder stringByAppendingPathComponent: crashLogName];
	NSDictionary*	fileAttrs = [[NSFileManager defaultManager] fileAttributesAtPath: crashLogPath traverseLink: YES];
	NSDate*			lastTimeCrashLogged = (fileAttrs == nil) ? nil : [fileAttrs fileModificationDate];
	NSDate*			lastTimeCrashReported = [[NSUserDefaults standardUserDefaults] objectForKey: @"LastCrashReportDate"];

	if( lastTimeCrashLogged )	// We have a crash log file and its mod date? Means we crashed sometime in the past.
	{
		// If we never before reported a crash or the last report lies before the last crash:
		if( nil == lastTimeCrashReported || [lastTimeCrashReported compare: lastTimeCrashLogged] == NSOrderedAscending )
		{
			//NSLog(@"Crash Log: %@ last changed %@, last reported %@", [crashLogPath stringByAbbreviatingWithTildeInPath], lastTimeCrashLogged, lastTimeCrashReported);

			[[KTCrashReporter sharedInstance] runAlert];
			[[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey: @"LastCrashReportDate"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
		else
		{
			//NSLog(@"Crash Log: %@ last changed %@, last reported %@ (not reporting)", [crashLogPath stringByAbbreviatingWithTildeInPath], lastTimeCrashLogged, lastTimeCrashReported);
		}
	}
	else	// this shouldn't happen unless 
	{
		//NSLog(@"No crash log found: %@", [crashLogPath stringByAbbreviatingWithTildeInPath]);
	}
}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSFileManager *fm = [NSFileManager defaultManager];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//	LOG((@"applicationDidFinishLaunching:... called from thread %X machine = %@", [NSThread currentThread], [KTApplication machineName]));
	
    //LOG((@"Sandvox: applicationDidFinishLaunching: %@", aNotification));
	@try
	{
		
		// just to be sure, make sure that webview is loaded
		(void) [KTWebView class];
		
		
		
		
		
		// Make an empty string for "No Selection" so that empty/0 numeric text fields are empty!
		[NSTextFieldCell setDefaultPlaceholder: @""
									 forMarker: NSNoSelectionMarker
								   withBinding: NSValueBinding];
		
		

		NSDictionary *systemVersionDict = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
		NSString *sysVersion = [systemVersionDict objectForKey:@"ProductVersion"];
		if (nil != sysVersion)
		{
			BOOL sufficient = NO;
			// Check system version 
			NSArray *versionPieces = [sysVersion componentsSeparatedByString:@"."];
			if ([versionPieces count] >= 1 && [[versionPieces objectAtIndex:0] intValue] == 10)
			{
				if ([versionPieces count] >= 2)
				{
					if ([[versionPieces objectAtIndex:1] intValue] == 4)
					{
						sufficient = ([[versionPieces objectAtIndex:2] intValue] >= 11);	// Need 10.4.11 +
					}
					else if ([[versionPieces objectAtIndex:1] intValue] >= 5)
					{
						sufficient = YES;	// Need 10.5.x
					}
				}
			}
			else
			{
				sufficient = YES;	// major version not 10 ... so 11 ?  Assume OK I guess
			}
			
			if (!sufficient)
			{
				NSRunCriticalAlertPanel(
										@"",
										NSLocalizedString(@"You will need to update to Mac OS X 10.4.11 (using the Software Update menu), or install 10.5 \"Leopard\" for this new version of Sandvox to function.", @""), 
										NSLocalizedString(@"Quit", @"Quit button"),
										nil,
										nil
										);
				[NSApp terminate:nil];
			}
		}
		
#ifdef EXPIRY_TIMESTAMP

#ifndef DEBUG
#warning ------- This build has been set to expire, see EXPIRY_TIMESTAMP in KTAppDelegate
#endif
		
		unsigned char km[16];
		GetKeys((void *)km);
		BOOL overrideKeyPressed = ((km[KeyOption>>3] >> (KeyOption & 7)) & 1) ? 1 : 0;
		
		if ( !overrideKeyPressed &&
			([[NSDate dateWithString:EXPIRY_TIMESTAMP] timeIntervalSinceNow] < 0) )
		{
			NSRunCriticalAlertPanel(
                                    @"This version of Sandvox has expired.",
                                    @"This version of Sandvox is no longer functional. Please contact Karelia Software for an update.", 
                                    @"Quit",
                                    nil,
                                    nil
                                    );
			[NSApp terminate:nil];
		}

// WARN OF EXPIRING BETA VERSION -- but not if it's apple design awards or development build.
#ifndef DEBUG
#ifndef APPLE_DESIGN_AWARDS_KEY
	[self warnExpiring:nil];
#endif
#endif

#endif
        
		BOOL firstRun = [defaults boolForKey:@"FirstRun"];


// log SQL statements
#ifdef DEBUG_SQL
        // via http://weblog.bignerdranch.com/?p=12
        Class PrivateClass;
        PrivateClass = NSClassFromString(@"NSSQLConnection");
        if ( Nil != PrivateClass )
        {
            [PrivateClass setDebugDefault:YES];
        }
#endif
        
        
		// put up a splash panel with a progress indicator
		[self showGenericProgressPanelWithMessage:NSLocalizedString(@"Initializing...",
                                                                    "Message while initializing launching application.")
											image:nil];

		// connect to homebase.  (It won't actually do it if the pref is not checked)
		int interval = [defaults integerForKey:@"SecondsBetweenHomeBaseChecks"];
		if (interval < 60 * 60)
		{
			interval = 60 * 60;	// if a very small number, set it to an hour.
		}
		if (0 != interval)	// don't connect if zero interval
		{
			mNewsTimer = [NSTimer
					scheduledTimerWithTimeInterval:interval
											target:self
										  selector:@selector(connectToHomeBase:)
										  userInfo:nil
										   repeats:YES];
			// do it now
			[self connectToHomeBase:nil];
		}

		// load plugins
        [self updateGenericProgressPanelWithMessage:NSLocalizedString(@"Loading Plug-Ins...",
                                                                      "Message while loading plugins.")];
		[myBundleManager loadAllPluginClassesOfType:kKTPageExtension instantiate:NO];
		[myBundleManager loadAllPluginClassesOfType:kKTIndexExtension instantiate:NO];
		[myBundleManager loadAllPluginClassesOfType:kKTDataSourceExtension instantiate:NO];

		// build menus
		[myBundleManager addPlugins:[myBundleManager pagePlugins]
								   toMenu:oAddPageMenu
								   target:nil
								   action:@selector(addPage:)
								pullsDown:NO
								showIcons:YES];
		[myBundleManager addPlugins:[myBundleManager pageletPlugins]
								   toMenu:oAddPageletMenu
								   target:nil
								   action:@selector(addPagelet:)
								pullsDown:NO
								showIcons:YES];
		
		[myBundleManager addPresetPluginsOfType:kKTIndexExtension
										 toMenu:oAddCollectionMenu
										 target:nil
										 action:@selector(addCollection:)
									  pullsDown:NO
									  showIcons:YES];
		
        [self updateGenericProgressPanelWithMessage:NSLocalizedString(@"Building Menus...",
                                                                      "Message while building menus.")];
		[self buildSampleSitesMenu];
		
		if ( [defaults boolForKey:@"DisplayInfo"] )
		{
			[self setDisplayInfoMenuItemTitle:KTHideInfoMenuItemTitle];
		}
		else
		{
			[self setDisplayInfoMenuItemTitle:KTShowInfoMenuItemTitle];
		}
		
        if ( firstRun )
        {
			// Set a baseline date of last crash reporting
			[defaults setObject:[NSDate date] forKey: @"LastCrashReportDate"];
			[defaults synchronize];
			[self performSelector:@selector(checkPlaceholderWindow:) 
					   withObject:nil
					   afterDelay:0.0];
			
        }
        else
        {
            [self updateGenericProgressPanelWithMessage:NSLocalizedString(@"Searching for previously opened documents...",
                                                                          "Message while checking documents.")];
            
            // figure out if we should create or open document(s)
            BOOL openLastOpened = [defaults boolForKey:@"AutoOpenLastOpenedOnLaunch"];
            
            NSArray *lastOpenedPaths = [defaults arrayForKey:@"LastOpened"];
            
            NSMutableArray *filesFound = [NSMutableArray array];
            NSMutableArray *filesNotFound = [NSMutableArray array];
            NSMutableArray *filesInTrash = [NSMutableArray array];
            
            // figure out what documents, if any, we can and can't find
            if ( openLastOpened && (nil != lastOpenedPaths) && ([lastOpenedPaths count] > 0) )
            {
                NSEnumerator *enumerator = [lastOpenedPaths objectEnumerator];
                id aliasData;
                while ( ( aliasData = [enumerator nextObject] ) )
                {
                    BDAlias *alias = [BDAlias aliasWithData:aliasData];
                    NSString *path = [alias fullPath];
					if (nil == path)
					{
						NSString *lastKnownPath = [alias lastKnownPath];
						[filesNotFound addObject:lastKnownPath];
						LOG((@"Can't find '%@'", lastKnownPath));
					}
					
                    // is it in the Trash? ([[NSWorkspace sharedWorkspace] userTrashDirectory])
					else if ( NSNotFound != [path rangeOfString:@".Trash"].location )
                    {
                        // path contains localized .Trash, let's skip it
                        [filesInTrash addObject:alias];
						LOG((@"Not opening '%@'; it is in the trash", path));
                    }
                    else
                    {
                        [filesFound addObject:alias];
                    }
                }
            }
            // run through the possibilities
            if ( openLastOpened 
				 && ([lastOpenedPaths count] > 0) 
				 && ([[[KTDocumentController sharedDocumentController] documents] count] == 0) )
            {
                // open whatever used to be open
                if ( [filesFound count] > 0 )
                {
                    NSEnumerator *e = [filesFound objectEnumerator];
                    BDAlias *alias;
                    while ( ( alias = [e nextObject] ) )
                    {
                        NSString *path = [alias fullPath];
                        
                        // check to make sure path is valid
                        if ( ![[NSFileManager defaultManager] fileExistsAtPath:path] )
                        {
                            [filesNotFound addObject:path];
                            continue;
                        }				
                        
                        NSString *message = [NSString stringWithFormat:@"%@ %@...", NSLocalizedString(@"Opening", "Alert Message"), [fm displayNameAtPath:[path stringByDeletingPathExtension]]];
                        [oGenericProgressTextField setStringValue:message];
                        [oGenericProgressImageView setImage:[NSImage imageNamed:@"document"]];
                        [oGenericProgressTextField displayIfNeeded];
                        
                        NSURL *fileURL = [NSURL fileURLWithPath:path];
                        
                        NSError *localError = nil;
                        KTDocument *previouslyOpenDocument = nil;
                        NSDocumentController *controller = [NSDocumentController sharedDocumentController];
                        @try
                        {
                            previouslyOpenDocument = [controller openDocumentWithContentsOfURL:fileURL display:YES error:&localError];
                        }
                        @catch (NSException *exception)
                        {
                            LOG((@"open document (%@) threw %@", fileURL, exception));
                            // Apple bug, I think -- if it couldn't open it, it is in some weird open state even though we didn't get it.
                            // So get the document pointer from the URL.
                            previouslyOpenDocument = (KTDocument *)[controller documentForURL:fileURL];
                            if (nil != previouslyOpenDocument)
                            {
                                // remove its window controller
                                NSWindowController *windowController = [previouslyOpenDocument windowController];
                                if (nil != windowController)
                                {
                                    [previouslyOpenDocument removeWindowController:windowController];
                                }
                                [previouslyOpenDocument close];
                                previouslyOpenDocument = nil;
                            }
                        }
                        
                        if ( nil != localError )
                        {
                            LOG((@"openDocument error:%@", localError));
                        }
                    }
                }
                
                // put up an alert showing any files not found (files in Trash are ignored)
                if ( [filesNotFound count] > 0 )
                {
                    NSString *missingFiles = [NSString string];
                    unsigned int i;
                    for ( i = 0; i < [filesNotFound count]; i++ )
                    {
						NSString *toAdd = [[filesNotFound objectAtIndex:i] lastPathComponent];
						toAdd = [fm displayNameAtPath:toAdd];
						
                        missingFiles = [missingFiles stringByAppendingString:toAdd];
                        if ( i < ([filesNotFound count]-1) )
                        {
                            missingFiles = [missingFiles stringByAppendingString:@", "];
                        }
                        else if ( i == ([filesNotFound count]-1) && i > 0 )	// no period if only one item
                        {
                            missingFiles = [missingFiles stringByAppendingString:@"."];
                        }
                    }

					[self hideGenericProgressPanel];	// hide this FIRST

                    NSAlert *alert = [[NSAlert alloc] init];
                    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"OK Button")];
                    [alert setMessageText:NSLocalizedString(@"Unable to locate previously opened files.", @"alert: Unable to locate previously opened files.")];
                    [alert setInformativeText:missingFiles];
                    [alert setAlertStyle:NSWarningAlertStyle];
                    
                    [alert runModal];
                    [alert release];
                }
            }
            
			[self hideGenericProgressPanel];
			[self performSelector:@selector(checkPlaceholderWindow:) 
					   withObject:nil
					   afterDelay:0.0];

			
			// Still in the "not first run" branch ... 
			if ([defaults boolForKey:@"SendCrashReports"])
			{
				[self performSelector:@selector(checkCrashLog:) withObject:nil afterDelay:3.0];
			}
        }
		
		// QE check AFTER the welcome message
		[self performSelector:@selector(checkQuartzExtreme:) withObject:nil afterDelay:0.0];

	}
	@finally
	{
		[self hideGenericProgressPanel];
	}

	
	// Now that progress pane is gone, we can deal with modal alert
			
#ifdef OBSERVE_UNDO
	// register for undo notifications so we can log them
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
	
    NSArray *notifications = [NSArray arrayWithObjects:
		NSUndoManagerCheckpointNotification,
		NSUndoManagerDidOpenUndoGroupNotification,
		NSUndoManagerDidRedoChangeNotification,
		NSUndoManagerDidUndoChangeNotification,
		NSUndoManagerWillCloseUndoGroupNotification,
		NSUndoManagerWillRedoChangeNotification,
		NSUndoManagerWillUndoChangeNotification,
		nil];
    
    NSEnumerator *e = [notifications objectEnumerator];
    NSString *notification;
    while ( notification = [e nextObject] ) 
	{
		[center addObserver:self
				   selector:@selector(logUndoNotification:)
					   name:notification
					 object:nil];
    }	
#endif

	// Copy font collection into user's font directory if it's not there
	// Check default first -- that will allow user to change name without it being rewritten
	if (![defaults boolForKey:@"Installed FontCollection 2"])	/// change default key to allow update to happen
	{
		NSString * fontCollection = [[NSBundle mainBundle] pathForResource: @"Web-safe Mac:Windows" ofType: @"collection"];
		NSString* fontCollectionFile = [@"~/Library/FontCollections/Web-safe Mac:Windows.collection" stringByExpandingTildeInPath];
		
		// copy into place even if it exists, so we can replace previosu version which should not have included Times
		[fm copyPath:fontCollection toPath:fontCollectionFile handler:nil];
		
		[defaults setBool:YES forKey:@"Installed FontCollection 2"];
	}
	
    applicationIsLaunching = NO; // we're done
}

- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;
{
	BOOL result = YES;
	
	if ([parserClassname isEqualToString:@"iMBGarageBandParser"]) result = NO;		// can't process garage band files
	
	LOG((@"iMediaBrowser: willUseMediaParser:%@ forMediaType:%@ -> %d", parserClassname, media, result));
	return result;
}

- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willLoadBrowser:(NSString *)browserClassname;
{
	BOOL result = (	[browserClassname isEqualToString:@"iMBPhotosController"]
				|| 	[browserClassname isEqualToString:@"iMBMusicController"]
				|| 	[browserClassname isEqualToString:@"iMBMoviesController"]
				|| 	[browserClassname isEqualToString:@"iMBLinksController"] );
	LOG((@"iMediaBrowser: willLoadBrowser:%@ ==> %d", browserClassname, result));
	return result;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	// apparently pool may not be in place yet?
	// see http://lapcatsoftware.com/blog/2007/03/10/everything-you-always-wanted-to-know-about-nsapplication/
	
	[iMediaBrowser class];	// force imedia browser to load just so we can get RBSplitView loaded
	
	// create a KTDocumentController instance that will become the "sharedInstance".  Do this early.
	myDocumentController = [[KTDocumentController alloc] init];
	
	// Try to check immediately so we have right info for initialization
	//[self performSelector:@selector(checkRegistrationString:) withObject:nil afterDelay:0.0];
#ifdef APPLE_DESIGN_AWARDS_KEY
#warning -- pre-configuring with registration code for Apple: Apple Design Awards Galilee Cadi Hop
	[self checkRegistrationString:APPLE_DESIGN_AWARDS_KEY];
#else
	[self checkRegistrationString:nil];
#endif

	// Show Welcome alert if unlicensed, or the Apple Design Awards entry
	if (nil == gRegistrationString )
	{
		[[KTQuickStartController sharedController] performSelector:@selector(doWelcomeAlert:) withObject:nil afterDelay:0.0];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setBool:YES forKey:@"ToldAboutScreencast"];
		[defaults synchronize];
	}		
		
		
	// Fix menus appropriately
	if (nil == gRegistrationString)
	{
		// unregistered, label advanced menu as pro
		[self setMenuItemPro:oAdvancedMenu];
		[self setMenuItemPro:oPasteAsMarkupMenuItem];
		[oValidateSourceViewMenuItem setImage:[NSImage imageNamed:@"globe"]];
		
		[self setMenuItemPro:oEditRawHTMLMenuItem];
		[self setMenuItemPro:oFindSubmenu];
		[self setMenuItemPro:oCodeInjectionMenuItem];
		[self setMenuItemPro:oCodeInjectionLevelMenuItem];
	}
	else
	{
//#warning In version 1.0.3, we can probably safely remove this since customers will have been informed of screencast by then.
//		// Show the new-video-available, but ONLY if never seen the alert before
//		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
//		if (![defaults boolForKey:@"ToldAboutScreencast"])
//		{
//			[[KTQuickStartController sharedController] performSelector:@selector(doWelcomeAlert:) withObject:nil afterDelay:0.0];
//			[defaults setBool:YES forKey:@"ToldAboutScreencast"];
//			[defaults synchronize];
//		}

		if (gIsPro || (nil == gRegistrationString))
		{
			[oValidateSourceViewMenuItem setImage:[NSImage imageNamed:@"globe"]];
		}
		else
		{
			[[oAdvancedMenu menu] removeItem:oAdvancedMenu];	// web view menu
			oAdvancedMenu = nil;
			
			[[oFindSubmenu menu] removeItem:oFindSubmenu];
			oFindSubmenu = nil;

			[[oEditRawHTMLMenuItem menu] removeItem:oEditRawHTMLMenuItem];
			oEditRawHTMLMenuItem = nil;
			
			[[oCodeInjectionMenuItem menu] removeItem:oCodeInjectionMenuItem];
			oCodeInjectionMenuItem = nil;
			
			[[oCodeInjectionLevelMenuItem menu] removeItem:oCodeInjectionLevelMenuItem];
			oCodeInjectionLevelMenuItem = nil;

			[[oFindSeparator menu] removeItem:oFindSeparator];
			oFindSeparator = nil;
			
			[[oCodeInjectionSeparator menu] removeItem:oCodeInjectionSeparator];
			oCodeInjectionSeparator = nil;
			
			oStandardViewMenuItem = nil;
			oStandardViewWithoutStylesMenuItem = nil;
			oSourceViewMenuItem = nil;
			oDOMViewMenuItem = nil;
			oRSSViewMenuItem = nil;
			oValidateSourceViewMenuItem = nil;
			
			[[oPasteAsMarkupMenuItem menu] removeItem:oPasteAsMarkupMenuItem];
			oPasteAsMarkupMenuItem = nil;
		}
	}	
	[pool release];

}
	
#include <openssl/sha.h>

#define SHA1_CTX			SHA_CTX
#define SHA1_DIGEST_LENGTH	SHA_DIGEST_LENGTH

- (NSData *)hashDataFromLicenseString:(NSString *)aCode	// can be nil
{
	NSString *cleanedString = [[aCode stringByRemovingCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]] lowercaseString];
	NSData *stringData = [cleanedString dataUsingEncoding:NSUTF8StringEncoding];
	NSData *result = [stringData sha1Digest];
	return result;
}

- (int) calculateStringChecksum:(NSString *)aWord :(int)aPrime
{
	OBPRECONDITION(aWord);
	int len = [aWord length];
	len = MIN(len, 12);			// Don't check past 12th character, only 12 will fit into 64 bits
	NSString *lowerWord = [aWord lowercaseString];
	long long total = 0;
	int i;
	for ( i = 0 ; i < len ; i++ )
	{
		unichar theChar = [lowerWord characterAtIndex:i] - 'a';
		total *= 26;
		total += theChar;		// basically make it like a 5-bit number
	}
	return total % aPrime;
}

- (BOOL) codeIsValid:(NSString *)aCode
					:(int *)outNamed
					:(NSString **)outLicensee	// RETAINS if created
					:(int *)outIndex
					:(int *)outVersion
					:(NSDate **)outDate		// RETAINS if created; expiration if version == 0
					:(int *)outType
					:(int *)outSource
					:(int *)outPro
					:(unsigned int *)outSeats
{
	OBPRECONDITION(aCode);
	NSMutableString *cleanedString = [NSMutableString stringWithString:aCode];
	[cleanedString replace:[NSString stringWithUnichar:0] with:@""];		// remove NULLs.  Not likely but it could conceivably happen
	
	NSArray *codeComponents = [cleanedString componentsSeparatedByWhitespace];	// newlines, option-space, etc.
	int count = [codeComponents count];
	if (count <  4)
	{
		LOG((@"code doesn't have enough components"));
		return NO;
	}
	
	int flags		= [self calculateStringChecksum:[codeComponents objectAtIndex:count-2] :theBigPrime];
	
	int version = flags & versionMask;
	BOOL isNamed = 0 != (flags & namedMask);
	int isPro = (flags & proMask) / proMask;
	int paymentIndex = (flags & paymentMask) / paymentMask;
	int licenseIndex = (flags & licenseMask) / 8;
	
	long long stringChecksumTotal = 0;
	
	int i;
	for ( i = 0 ; i < count-1; i++ )
	{
		NSString *word = [codeComponents objectAtIndex:i];
		NSString *cleanedWord = [[word stringByRemovingCharactersInSet:[[NSCharacterSet letterCharacterSet] invertedSet]] lowercaseString];
		
		int length = [cleanedWord length];
		// Test checksum < 256, len >= 3 except for name components
		if (!isNamed || (i >= count - 3))
		{
			int wordChecksum = [self calculateStringChecksum:cleanedWord :theBigPrime];
			if (length < 3)
			{
				LOG((@"word %@ < 3 chars", cleanedWord));
				return NO;
			}
			if (wordChecksum > 255)
			{
				LOG((@"word %@ checksum illegal, = %d", cleanedWord, wordChecksum));
				return NO;
			}
		}
		
		int charIndex;
		for (charIndex = 0 ; charIndex < length ; charIndex++)
		{
			int c = [cleanedWord characterAtIndex:charIndex] - 'a';
			stringChecksumTotal = stringChecksumTotal * 2 + c;		// shift each one by 1 bit
		}
	}
	int expectedChecksum = stringChecksumTotal % the8BitPrime;
	NSString *finalWord = [codeComponents objectAtIndex:count-1];
	int checksumValue = [self calculateStringChecksum:finalWord :theBigPrime];
	if (expectedChecksum != checksumValue)
	{
		LOG((@"expectedChecksum %d != given checksum %d from %@", expectedChecksum, checksumValue, finalWord));
		return NO;
	}
	
	int fortnights	= [self calculateStringChecksum:[codeComponents objectAtIndex:count-3] :theBigPrime];
	float secondsPerFortnight = 14 * 24 * 60 * 60;
	NSTimeInterval timeIntervalToAdd = (float)fortnights * secondsPerFortnight;
	NSDate *embeddedDate = [NSDate dateWithString:REFERENCE_TIMESTAMP];
	embeddedDate = [embeddedDate addTimeInterval:timeIntervalToAdd ];
	
	NSTimeInterval sinceStoredDate = [[NSDate date] timeIntervalSinceDate:embeddedDate];
	
	int daysSince = sinceStoredDate / (60 * 60 * 24);
	if (0 == version)	// make sure current time is not AFTER the given date
	{
		if (daysSince > 0)
		{
			LOG((@"It looks like you've expired"));
			return NO;
		}
	}
	else	// Make sure that the given date is in the past
	{
		if (daysSince < 0)
		{
			LOG((@"It looks like the generation date is in the future; this is bad?"));
			return NO;
		}
	}

	int seats = 0;
	if (kSiteLicense == licenseIndex)
	{
		seats	= [self calculateStringChecksum:[codeComponents objectAtIndex:count-4] :theBigPrime];
		if (seats < 5 || seats > 255)
		{
			LOG((@"Invalid site-license seats number"));
			return NO;
		}
	}
	
	// If everything is valid, return new values
	if (outNamed)
	{
		*outNamed = isNamed;
	}
	if (outLicensee && isNamed)
	{
		int namePosition = (kSiteLicense == licenseIndex) ? count-4 : count-3;
		NSArray *justName = [codeComponents subarrayWithRange:NSMakeRange(0,namePosition)];
		*outLicensee = [[justName componentsJoinedByString:@" "] retain];
	}
	if (outIndex && !isNamed)
	{
		int loByte = [self calculateStringChecksum:[codeComponents objectAtIndex:0] :theBigPrime];
		int hiByte = [self calculateStringChecksum:[codeComponents objectAtIndex:1] :theBigPrime];
		*outIndex = hiByte * 256 + loByte;
	}
	if (outVersion)
	{
		*outVersion = version;
	}
	if (outDate)
	{
		*outDate = [embeddedDate retain];
	}
	if (outType)
	{
		*outType = licenseIndex;
	}
	if (outSource)
	{
		*outSource = paymentIndex;
	}
	if (outPro)
	{
		*outPro = isPro;
	}
	if (outSeats)
	{
		*outSeats = seats;
	}
	return YES;
}


- (NSString *)registrationReport
{
	if (nil == gRegistrationString)
	{
		return @"None";		// DO NOT LOCALIZE
	}
	// Now calculate summary 
	NSMutableString *buf = [NSMutableString string];
	if (nil != gLicensee)
	{
		[buf appendFormat:@"%@ - ", gLicensee];
	}
	switch (gLicenseType)
	{
		case kSingleLicense:
			[buf appendString:@"S"];
			break;
		case kHouseholdLicense:
			[buf appendString:@"H"];
			break;
		case kSiteLicense:
			[buf appendString:@"L"];
			break;
		case kWorldwideLicense:
			[buf appendString:@"W"];
			break;
	}
	if (gIsPro)
	{
		[buf appendString:@"+p"];
	}
	[buf appendFormat:@" V%d ", gLicenseVersion];
	if (0 == gLicenseVersion)
	{
		[buf appendString:@"X: "];
	}
	[buf appendString:[gLicenseDate description]];
	if (gLicenseIsBlacklisted)
	{
		[buf appendString:@" #"];		// Easy way to tell that request comes from blacklisted user
	}
	OBPOSTCONDITION([buf length]);
	return buf;
}

- (void) checkRegistrationString:(NSString *)aString	// if not specified, looks in hidden path
{
	NSString *regString = aString;
	NSString *path = nil;
	BOOL readingFromInternalFile = (nil == aString);
	BOOL wasNil = (nil == gRegistrationString);
	
	[gLicensee				release];	gLicensee			= nil;
	[gLicenseDate			release];	gLicenseDate		= nil;
	[gRegistrationString	release];	gRegistrationString	= nil;
	[gRegistrationHash		release];	gRegistrationHash	= nil;
	
	// OK, so far so good.  Read file
	if (readingFromInternalFile)
	{
		NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
		path = [libraryPaths objectAtIndex:0];
		
		path = [NSString pathWithComponents:
			[NSArray arrayWithObjects:path, [NSApplication applicationName], gFunnyFileName, nil]];	// nice and obscure strings and file name
		NSData *data = [NSData dataWithContentsOfFile:path];
		
		// Decrypt using the funny file name PLUS the user name -- meaning that the file won't work if it's somebody else's account
		NSData *decodedData = [data dataDecryptedWithPassword:[NSString stringWithFormat:@"%@%@", gFunnyFileName, NSUserName()]];
		if (nil !=decodedData)
		{
			regString = [[[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding] autorelease];
		}
	}

	NSData *hash = [self hashDataFromLicenseString:regString];

	// sneakily put in a global that the registration was checked (even if there is no license!
	gRegistrationWasChecked = -1;

	if (!regString)
	{
		LOG((@"Could not read file at %@", path));
		gRegistrationFailureCode = kKTCouldNotReadLicenseFile;
		goto FAILURE;
	}
	
	// Keep hash as a string for use by feed
	gRegistrationHash = [[hash base64Encoding] retain];

	// BLACKLIST -- subtle non-functionality, for cracked codes.  
#define BLACKLIST_COUNT 1
	unsigned char blacklistDigests[BLACKLIST_COUNT][SHA1_DIGEST_LENGTH] = {
{ 0xFC,0x8C,0xF1,0xAD,0xDF,0x82,0x45,0x72,0x21,0xFA,0xE7,0x15,0x7B,0x11,0x4A,0x22,0x23,0x7F,0x06,0x20 }, // Nop Chopper Hurly Anomaly Penalty	
	};
	int i;
	for (i = 0 ; i < BLACKLIST_COUNT; i++)
	{
		int compareResult = memcmp([hash bytes], blacklistDigests[i], SHA1_DIGEST_LENGTH);
		if (0 == compareResult)
		{
			LOG((@"Code '%@' is blacklisted -- setting time bombs", regString));
			gLicenseIsBlacklisted = 1;		// non-zero means we are blacklisted, but otherwise continue!
			break;	// no point in continuing to check
		}
	}

	BOOL valid = YES;		// start out true, then if a truly invalid we will set to NO
	
#include "SandvoxInvalidLicenses.h"
	
	for (i = 0 ; i < INVALID_LIST_COUNT; i++)
	{
		int compareResult = memcmp([hash bytes], invalidListDigests[i], SHA1_DIGEST_LENGTH);
		if (0 == compareResult)
		{
			LOG((@"Code '%@' is not valid -- not enabling code", regString));
			valid = NO;
			break;	// no point in continuing to check
		}
	}
	
	
// Check license.  If invalidated above, this will act as if license is not valid.	
	
	valid &= [self codeIsValid:regString :nil :&gLicensee :nil :&gLicenseVersion :&gLicenseDate :&gLicenseType :nil :&gIsPro :&gSeats];
	
	if (valid)
	{		
		gRegistrationString = [regString retain];
		gRegistrationFailureCode = kKTLicenseOK;

//		LOG((@"gLicensee = %@, gLicenseVersion = %d, gLicenseDate = %@, gLicenseType = %d, gIsPro = %d", gLicensee, gLicenseVersion, gLicenseDate, gLicenseType, gIsPro));
	}
	else
	{
		LOG((@"Code '%@' failed to validate", regString));
		gRegistrationFailureCode = kKTLicenseCheckFailed;
	}
	
FAILURE:	

#ifdef DEBUG
		if (kKTLicenseOK != gRegistrationFailureCode)
		{
			NSLog(@"failure = %d", gRegistrationFailureCode);
		}
#endif


//	LOG((@"Report: %@", [self registrationReport]));

	// Post notification,
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTBadgeUpdateNotification object:nil]; 
	
	
	// Set up zeroconf
	
	if (nil != gRegistrationString && nil == myNetService)
	{
		// Start looking for other services, with a timeout
		myNetServiceBrowser = [[NSNetServiceBrowser alloc] init];
		[myNetServiceBrowser setDelegate:self];
		[myNetServiceBrowser searchForServicesOfType:@"_sandvox._tcp." inDomain:@""];
		
		// Soon, stop looking for other similar licenses; let other instances with this license
		// that come on-line force a quit, not this instance.
		[self performSelector:@selector(cancelNetServicesBrowser:) withObject:myNetServiceBrowser afterDelay:20.0];
	
		// Publish this one's presence
		
		myNetServicePort = [[NSSocketPort port] retain];
		
		struct sockaddr_in addrIn = *(struct sockaddr_in *)[[myNetServicePort address] bytes];
		int port = addrIn.sin_port;
		myNetServiceName = [[NSString alloc] initWithFormat:@"%@: %@",
			NSFullUserName(),
			[((NSString *)SCDynamicStoreCopyComputerName(NULL, NULL)) autorelease]];
		
		myNetService = [[NSNetService alloc] initWithDomain:@""
													   type:@"_sandvox._tcp."
													   name:myNetServiceName
													   port:port];
		NSData *hashTXTData = [NSNetService dataFromTXTRecordDictionary:
							 [NSDictionary dictionaryWithObjectsAndKeys: hash, @"hash", nil]];
		BOOL succeededSettingTXT = [myNetService setTXTRecordData:hashTXTData];
		if (!succeededSettingTXT)
		{
			LOG((@"couldn't set TXT data"));
		}
		[myNetService setDelegate:self];
		[myNetService publish];
	}
	else if (nil == gRegistrationString && nil != myNetService)
	{
		[myNetServiceBrowser stop];
		[myNetServiceBrowser release];
		myNetServiceBrowser = nil;
		[myNetServicePort release];
		myNetServicePort = nil;
		[myNetService stop];
		[myNetService release];
		myNetService = nil;
	}
	
	if (wasNil && gRegistrationString != nil)
	{
		// we are now registered, let's set all open docs as stale
		NSEnumerator *e = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
		KTDocument *cur;
		
		while ( (cur = [e nextObject]) )
		{
			if ([cur isKindOfClass:[KTDocument class]])	// make sure it's a KTDocument
			{
				////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on root because app is newly registered", NSStringFromSelector(_cmd)));
///	TODO:	Make this happen again.
				//[[cur root] markStale:kStaleFamily];
			}
		}
	}
}

- (void)netService:(NSNetService *)sender didUpdateTXTRecordData:(NSData *)data
{
	if (nil == mySimilarLicenses)
	{
		mySimilarLicenses = [[NSMutableSet alloc] init];
	}
	LOG((@"%@ %@ %@", NSStringFromSelector(_cmd), sender, data ));
	NSDictionary *dict = [NSNetService dictionaryFromTXTRecordData:data];
	NSString *hashBase64 = [[dict objectForKey:@"hash"] base64Encoding];
	if ([hashBase64 isEqualToString:gRegistrationHash])
	{
		[mySimilarLicenses addObject:[sender name]];
		BOOL violation = NO;
		switch (gLicenseType)
		{
			case kSingleLicense:
				violation = YES;
				break;
			case kHouseholdLicense:
				violation = ([mySimilarLicenses count] + 1 > kKTMaxLicensesPerHousehold);
				break;
			case kSiteLicense:
				violation = ([mySimilarLicenses count] + 1 > gSeats);
				break;
		}
		if (violation)
		{
			gLicenseIsBlacklisted = YES;	// act blacklisted for now so you can't publish
			gLicenseViolation = YES;	// this will help the registration controller prompt
			
			[[NSDocumentController sharedDocumentController] closeAllDocumentsWithDelegate:nil
																	   didCloseAllSelector:nil
																			   contextInfo:nil];

			[[KTRegistrationController sharedRegistrationController] showWindow:sender];
			
		}
	}
	else
	{
		[mySimilarLicenses removeObject:[sender name]];
	}

}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didFindService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
	if (![[aNetService name] isEqualToString:myNetServiceName])
	{
		// LOG((@"Another Service --> %@ %@ more=%d name='%@' myName ='%@'", NSStringFromSelector(_cmd), aNetService, moreComing, [aNetService name], myNetServiceName ));
		if (NSNotFound != [[aNetService description] rangeOfString:@"local."].location)
		{
			// LOG((@"This is on local. -- not monitoring."));
		}
		else
		{
			[aNetService setDelegate:self];
			[aNetService startMonitoring];
		}
	}
	else
	{
		// LOG((@"My Service --> %@ %@ more=%d name='%@'", NSStringFromSelector(_cmd), aNetService, moreComing, [aNetService name] ));
	}
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)aNetServiceBrowser didRemoveService:(NSNetService *)aNetService moreComing:(BOOL)moreComing
{
	[aNetService stopMonitoring];
}

- (void)cancelNetServicesBrowser:(NSNetServiceBrowser *)aBrowser
{
	[aBrowser stop];
}

- (void)applicationWillTerminate:(NSNotification *)aNotification
{
    //LOG((@"Sandvox: applicationWillTerminate: %@", aNotification));
    
    // we're no longer a FirstRun
    [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"FirstRun"];
    [[NSUserDefaults standardUserDefaults] synchronize];
	
	[self setAppIsTerminating:YES];
#ifdef DEBUG
	if (nil != [[[NSProcessInfo processInfo] environment] objectForKey:@"MallocStackLogging"])
	{
		char cmd[256];
		sprintf(cmd, "/usr/bin/leaks %d > /tmp/Sandvox_%d.leaks", getpid(), getpid());
		printf("%s", cmd);
		printf("\n");
		system(cmd);
		sprintf(cmd, "open /tmp/Sandvox_%d.leaks", getpid() );
		printf("%s", cmd);
		printf("\n");
		system(cmd);
	}
#endif
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender	// called from dock-quitting very early; need to updateLastOpened first and then don't save it again!
{
	[[KTDocumentController sharedDocumentController] closeAllDocumentsWithDelegate:nil
															   didCloseAllSelector:NULL
																	   contextInfo:NULL];
		

	return NSTerminateNow;
}

// Font Panel capabilities -- restrict what effects we can do.
/// put back in effects that people might want.
- (unsigned int)validModesForFontPanel:(NSFontPanel *)fontPanel
{
	return (  NSFontPanelFaceModeMask
			  | NSFontPanelSizeModeMask
			  | NSFontPanelCollectionModeMask
			//  | NSFontPanelUnderlineEffectModeMask
			//  | NSFontPanelStrikethroughEffectModeMask
			  | NSFontPanelTextColorEffectModeMask
			  | NSFontPanelDocumentColorEffectModeMask
			//  | NSFontPanelShadowEffectModeMask		// only sort of works
			  );
}

#pragma mark -
#pragma mark Sparkle delegate

- (BOOL)updaterShouldSendProfileInfo
{
	// we're not going to track profile info, for now
	// but we want to use sparkle+ as it's being actively developed
	return NO;
}

- (void)statusChecker:(SUStatusChecker *)statusChecker
         foundVersion:(NSString *)versionString
         isNewVersion:(BOOL)isNewVersion 
{ 
    if ( nil == versionString ) 
    { 
        LOG((@"warning: Sparkle+ could not GET new version information")); 
        return; 
    } 
    LOG((@"Sparkle+: appcast version is %@", versionString)); 
    LOG((@"Sparkle+: appcast version is newest? %@", isNewVersion ? @"Yes" : @"No")); 
} 

#pragma mark -
#pragma mark Document communication

/*!	Update menus or whatever is global based on the given document coming to the front
*/
-(void)updateMenusForDocument:(KTDocument *)aDocument
{
	OBPRECONDITION(aDocument);
    if ( [aDocument showDesigns] )
    {
        [oToggleAddressBarMenuItem setTitle:NSLocalizedString(@"Hide Designs", @"menu title to hide designs bar")];
    }
    else
    {
        [oToggleAddressBarMenuItem setTitle:NSLocalizedString(@"Show Designs", @"menu title to show design bar")];
    }

    if ([aDocument displayEditingControls] )
    {
        [oToggleEditingControlsMenuItem setTitle:NSLocalizedString(@"Hide Editing Markers", @"menu title to hide Editing Markers")];
    }
    else
    {
        [oToggleEditingControlsMenuItem setTitle:NSLocalizedString(@"Show Editing Markers", @"menu title to show Editing Markers")];
    }
	
    if ( [aDocument displayStatusBar] )
    {
        [oToggleStatusBarMenuItem setTitle:NSLocalizedString(@"Hide Status Bar", @"menu title to hide status bar")];
    }
    else
    {
        [oToggleStatusBarMenuItem setTitle:NSLocalizedString(@"Show Status Bar", @"menu title to show status bar")];
    }

    if ( [[aDocument windowController] sidebarIsCollapsed] )
    {
        [oToggleSiteOutlineMenuItem setTitle:NSLocalizedString(@"Show Site Outline", @"menu title to show site outline")];
        [oToggleSiteOutlineMenuItem setToolTip:NSLocalizedString(@"Shows the outline of the site on the left side of the window. Window must be wide enough to accomodate it.", @"Tooltip: menu tooltip to show site outline")];
    }
    else
    {
		[oToggleSiteOutlineMenuItem setTitle:NSLocalizedString(@"Hide Site Outline", @"menu title to hide site outline")];
        [oToggleSiteOutlineMenuItem setToolTip:NSLocalizedString(@"Collapses the outline of the site from the left side of the window.", @"menu tooltip to hide site outline")];
	}
	
	[self updateDuplicateMenuItemForDocument:aDocument];
}

- (void)updateLastOpened
{
    NSMutableArray *aliases = [NSMutableArray array];
    NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    KTDocument *document;
    while ( ( document = [enumerator nextObject] ) )
    {
		if ([document isKindOfClass:[KTDocument class]])	// make sure it's a KTDocument
		{
			if ( [[[document fileName] pathExtension] isEqualToString:kKTDocumentExtension] 
				 && ![[document fileName] hasPrefix:[[NSBundle mainBundle] bundlePath]]  )
			{
				BDAlias *alias = [BDAlias aliasWithPath:[document fileName] relativeToPath:[NSHomeDirectory() stringByResolvingSymlinksInPath]];
				if (nil == alias)
				{
					// couldn't find relative to home directory, so just do absolute
					alias = [BDAlias aliasWithPath:[document fileName]];
				}
				if ( nil != alias )
				{
					NSData *aliasData = [[[alias aliasData] copy] autorelease];
					[aliases addObject:aliasData];
				}
			}
		}
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:aliases]
                                              forKey:@"LastOpened"];
	BOOL synchronized = [[NSUserDefaults standardUserDefaults] synchronize];
	if (!synchronized)
	{
		NSLog(@"Unable to synchronize defaults");
	}
}

#pragma mark -
#pragma mark Accessors

- (KTDocument *)currentDocument
{
	// NOTE: I took out the ivar to try to avoid too many retains. Just using doc controller now.
    return [[NSDocumentController sharedDocumentController] currentDocument];
}

- (NSDictionary *)homeBaseDict
{
    return myHomeBaseDict;
}
- (void)setHomeBaseDict:(NSDictionary *)aHomeBaseDict
{
    [myHomeBaseDict release];
    myHomeBaseDict = [aHomeBaseDict copy];
}

- (NSString *)newVersionString
{
    return myNewVersionString; 
}

- (void)setNewVersionString:(NSString *)aNewVersionString
{
    [aNewVersionString retain];
    [myNewVersionString release];
    myNewVersionString = aNewVersionString;
}

- (NSString *)newFeatures
{
    return myNewFeatures; 
}

- (void)setNewFeatures:(NSString *)aNewFeatures
{
    [aNewFeatures retain];
    [myNewFeatures release];
    myNewFeatures = aNewFeatures;
}

- (NSURL *)currentAppDownloadURL
{
    return myCurrentAppDownloadURL; 
}

- (void)setCurrentAppDownloadURL:(NSURL *)aCurrentAppDownloadURL
{
    [aCurrentAppDownloadURL retain];
    [myCurrentAppDownloadURL release];
    myCurrentAppDownloadURL = aCurrentAppDownloadURL;
}

- (BOOL)newsHasChanged
{
    return myNewsHasChanged;
}

- (void)setNewsHasChanged:(BOOL)flag
{
    myNewsHasChanged = flag;
}

- (BOOL)appIsTerminating
{
	return myAppIsTerminating;
}

- (void)setAppIsTerminating:(BOOL)aFlag
{
	myAppIsTerminating = aFlag;
}

#pragma mark -
#pragma mark IBActions

- (IBAction)openSampleDocument:(id)sender
{
	NSURL *fileURL = [sender representedObject];
	
	if ( (nil != fileURL) && [fileURL isKindOfClass:[NSURL class]] )
	{
		NSError *localError = nil;
		[[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:fileURL display:YES error:&localError];
		
//		if ( nil != sample )
//		{
//			[sample setReadOnly:YES];
//		}
		
		if ( nil != localError )
		{
			[NSApp presentError:localError];
		}
	}
}

- (KTDocument *)openDocumentWithContentsOfURL:(NSURL *)aURL
{
	OBPRECONDITION(aURL);
	OBPRECONDITION([aURL scheme]);
    // before we do *anything*, grab currentDocument to see if we already have a window on-screen
    KTDocument *currentDocument = [[NSDocumentController sharedDocumentController] currentDocument];

    //  now, open newly saved document w/ isNewDocument = YES
    NSError *localError = nil;
    KTDocument *newDocument = [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:aURL
                                                                                                     display:YES
                                                                                                       error:&localError];
    
    // clean up if it didn't work out
    if ( nil == newDocument )
    {
        if ( nil != localError )
        {
            [NSApp presentError:localError];
        }
        
        return nil;
    }
    
    // position on screen
    if ( nil != currentDocument && [currentDocument isKindOfClass:[KTDocument class]] )
    {
        NSWindow *currentWindow = [[currentDocument windowController] window];
        NSRect currentFrame = [currentWindow frame];
        NSPoint currentTopLeft = NSMakePoint(currentFrame.origin.x,(currentFrame.origin.y+currentFrame.size.height));
        NSPoint newTopLeft = [currentWindow cascadeTopLeftFromPoint:currentTopLeft];
        [[[newDocument windowController] window] setFrameTopLeftPoint:newTopLeft];
    }
    else
    {
        [[[newDocument windowController] window] center];
    }
	    
    return newDocument;    
}

- (IBAction)orderFrontLicensingPanel:(id)sender
{
//    if ( nil == oLicensingPanel ) {
//        [NSBundle loadNibNamed:@"Licensing" owner:self];
//    }
//
//    [oLicensingPanel center];
//    [oLicensingPanel makeKeyAndOrderFront:sender];
}

- (IBAction)orderFrontPreferencesPanel:(id)sender
{
    [[KTPrefsController sharedPrefsController] showWindow:sender];
}

/*!	for manual save... though we're saving it automatically.
*/
- (IBAction)saveWindowSize:(id)sender
{
    NSWindow *window = [[[[self currentDocument] windowControllers] objectAtIndex:0] window];
    NSSize contentSize = [[window contentView] frame].size;
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromSize(contentSize)
                                              forKey:@"DefaultDocumentWindowContentSize"];
}

- (IBAction) showTranscriptWindow:(id)sender
{
    [[KTTranscriptController sharedTranscriptController] showWindow:sender];
	
	// Clear the transcript if option key was down.  Just a quick hack...
	if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
	{
		[[KTTranscriptController sharedTranscriptController] clearTranscript:nil];
	}
}

- (IBAction) showNewsWindow:(id)sender
{
    [[KTNewsController sharedNewsController] showWindow:sender];
}

- (IBAction)showRegistrationWindow:(id)sender
{
	[[KTRegistrationController sharedRegistrationController] showWindow:sender];

}

- (IBAction)showPluginWindow:(id)sender;
{
	if (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )	// undocumented: option key - only showing new updates.
	{
		[[KTPluginInstallerController sharedController] showWindowForNewVersions:sender];
	}
	else	// normal
	{
		[[KTPluginInstallerController sharedController] showWindow:sender];
	}
}

// Invoked when update badge is clicked.  May just directly open the URL if the shut-up has been chosen.

- (IBAction) getUpdatedApplication:(id)sender
{
	// Immediately download if the option key is held down
	if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
	{
		if (nil != myCurrentAppDownloadURL)
		{
			[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:myCurrentAppDownloadURL];
		}
		else
		{
			NSBeep();
		}
	}
	else	// put up a dialog to confirm the 
	{	
		[[[NSWorkspace sharedWorkspace]
			confirmWithWindow:nil
				 silencingKey:@"shutUpDownloadWarn"
					canCancel:YES OKButton:NSLocalizedString(@"Download", @"Download Button Title")
					  silence:NSLocalizedString(@"Immediately download without this warning", @"checkbox title")
						title:[NSString stringWithFormat:
									NSLocalizedString(@"Upgrade to Sandvox %@?", @"Question for title of warning"),
									[self newVersionString]]
					   format:NSLocalizedString(@"Do you wish to download the upgrade to version %@ of Sandvox? (You are running version %@.)\n\n%@",
												@"question for download warning -- followed by details of update"),
					[self newVersionString],
					[[NSBundle mainBundle] version],
					[self newFeatures]
				]
			attemptToOpenWebURL:myCurrentAppDownloadURL];
	}
}

// Similar to above, but brings up a dialog automatically when phoned home and there is a new version.
// Shutting up will cause this warning not to appear again
- (void) notifyNewVersionAvailable:(id)bogus
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *noAlertKey = @"shutUpNewVersionAlert";
	
	if (![defaults boolForKey:noAlertKey])	// show alert if we haven't been told to stop
	{
		[[[NSWorkspace sharedWorkspace]
				confirmWithWindow:nil
					 silencingKey:@"shutUpNewVersionAlert"
						canCancel:YES OKButton:NSLocalizedString(@"Download", @"Download Button Title")
						  silence:NSLocalizedString(@"Do not show this message when a new version is available",@"checkbox to stop showing alert when a new version of Sandvox is available")
							title:NSLocalizedString(@"A new version of Sandvox is available", @"title of alert")
						   format:NSLocalizedString(@"Do you wish to download the upgrade to version %@ of Sandvox? (You are running version %@.)\n\n%@",
													@"question for download warning -- followed by details of update"),
			[self newVersionString],
			[[NSBundle mainBundle] version],
			[self newFeatures]
			]
				attemptToOpenWebURL:myCurrentAppDownloadURL];
		
		// Store this new version in the defaults, so that we won't remind about this new version any more.
		[defaults setObject:[self newVersionString] forKey:@"lastNotifiedVersion"];
		[defaults synchronize];
	}
}

- (IBAction)showAvailableMedia:(id)sender
{
	/// disabling for 1.2.1 unless we figure out a non-crashing media inspector
	if ( 1 ) return; 
	
//	if ( nil == oDebugMediaPanel )
//	{
//		[NSBundle loadNibNamed:@"MediaInspector" owner:self];
//	}
//	[oDebugMediaObjectController setContent:self];
//	[oDebugMediaPanel setFrameUsingName:@"Media Inspector"];
//	[oDebugMediaPanel orderFront:nil];
}

- (IBAction)hideAvailableMedia:(id)sender
{
	/// disabling for 1.2.1 unless we figure out a non-crashing media inspector
	if ( 1 ) return; 

//	[oDebugMediaObjectController setContent:nil];
//	[oDebugMediaPanel orderOut:nil];
}

- (IBAction)showFeedbackReporter:(id)sender
{
	if ( nil == myFeedbackReporter )
	{
		myFeedbackReporter = [KTFeedbackReporter sharedInstance];
	}
	[myFeedbackReporter showReportWindow:self];
}

- (IBAction)showReleaseNotes:(id)sender
{
    [[KTReleaseNotesController sharedController] showWindow:nil];
}

- (IBAction)showAcknowledgments:(id)sender
{
    [[KTAcknowledgmentsController sharedController] showWindow:nil];
}

- (IBAction)showProductPage:(id)sender
{
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.sandvox.com/"]];
}

- (IBAction)showDiscussionGroup:(id)sender
{
    //[[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://secure.karelia.com/fogbugz/?beta"]];
}

- (IBAction)toggleMediaBrowserShown:(id)sender
{
	
	iMediaBrowser *browser = [iMediaBrowser sharedBrowserWithDelegate:self];
	
	if ( [browser infoWindowIsVisible] )
	{
		[browser flipBack:nil];
	}
		
	BOOL newValue = ![[browser window] isVisible];
	
	// set menu to opposite of flag
	if ( newValue )
	{
		[[KTAppDelegate sharedInstance] setDisplayMediaMenuItemTitle:KTHideMediaMenuItemTitle];
		[browser setIdentifier:@"Sandvox"];
		[browser showWindow:sender];
	}
	else
	{
		[[KTAppDelegate sharedInstance] setDisplayMediaMenuItemTitle:KTShowMediaMenuItemTitle];
		[browser close];
	}

	// display Media, if appropriate
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	[[self currentDocument] editRawHTMLInSelectedBlock:sender];
}

- (IBAction)viewPublishedSite:(id)sender
{
	[[self currentDocument] viewPublishedSite:sender];
}

- (IBAction) openHigh:(id)sender
{
	NSURL *url = [NSURL URLWithString: @"http://www.karelia.com/screencast/Introduction_to_Sandvox_1024.mov"];
	if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];	
	}
	else
	{
		BOOL opened = [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url]
									  withAppBundleIdentifier:@"com.apple.quicktimeplayer" 
													  options:NSWorkspaceLaunchAsync
							   additionalEventParamDescriptor:nil launchIdentifiers:nil];
		if (!opened)
		{
			// try to open some other way
			[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];	
		}
	}
}

- (IBAction) openLow:(id)sender
{
	NSURL *url = [NSURL URLWithString: @"http://www.karelia.com/screencast/Introduction_to_Sandvox_640.mov"];
	if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
	{
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];	
	}
	else
	{
		BOOL opened = [[NSWorkspace sharedWorkspace] openURLs:[NSArray arrayWithObject:url]
									  withAppBundleIdentifier:@"com.apple.quicktimeplayer" 
													  options:NSWorkspaceLaunchAsync
							   additionalEventParamDescriptor:nil launchIdentifiers:nil];
		if (!opened)
		{
			// try to open some other way
			[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];	
		}
	}
}

#pragma mark -
#pragma mark Utility Methods

- (void)updateDuplicateMenuItemForDocument:(KTDocument *)aDocument
{
	OBPRECONDITION(aDocument);
	// label duplicate: (order is selected text, selected pagelet, selected page(s))
	KTPagelet *selectedPagelet = [[aDocument windowController] selectedPagelet];
	KTPage *selectedPage = [[[aDocument windowController] siteOutlineController] selectedPage];
	NSArray *selectedPages = [(NSSet *)[[[aDocument windowController] siteOutlineController] selectedPages] allObjects];
	
	if ( [[aDocument windowController] selectedDOMRangeIsEditable] )
	{
		[oDuplicateMenuItem setTitle:NSLocalizedString(@"Duplicate", "menu title to duplicate generic item")];
	}
	else if ( nil != selectedPagelet )
	{
		[oDuplicateMenuItem setTitle:NSLocalizedString(@"Duplicate Pagelet", "menu title to duplicate pagelet")];
	}
	else if ( (nil != selectedPage) && ![selectedPage isRoot] )
	{
		if ( [selectedPage isCollection] )
		{
			[oDuplicateMenuItem setTitle:NSLocalizedString(@"Duplicate Collection", "menu title to duplicate a collection")];
		}
		else
		{
			[oDuplicateMenuItem setTitle:NSLocalizedString(@"Duplicate Page", "menu title to duplicate a single page")];
		}
	}
	else if ( ([selectedPages count] > 1) && ![selectedPages containsRoot] )
	{
		[oDuplicateMenuItem setTitle:NSLocalizedString(@"Duplicate Pages", "menu title to duplicate multiple pages")];
	}
	else
	{
		[oDuplicateMenuItem setTitle:NSLocalizedString(@"Duplicate", "menu title to duplicate generic item")];
	}	
}

#ifdef EXPIRY_TIMESTAMP
- (void)warnExpiring:(id)bogus
{
#ifndef DEBUG
    NSString *appVersion = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleShortVersionString"];
    NSString *appBuildNumber = [[[NSBundle mainBundle] infoDictionary] valueForKey:@"CFBundleVersion"];
    
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Sandvox Public Beta", "Alert: Beta Message") 
									 defaultButton:nil 
								   alternateButton:nil 
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"You are running Sandvox version %@, build %@.\n\nThis is a Public Beta version and will expire on %@. (We will make a new version available by then.)\n\nIf you find problems, please use \\U201CSend Feedback...\\U201D under the Help menu, or email support@karelia.com.\n\nSince this is BETA software, DO NOT use it with critical data or for critical business functions. Please keep backups of your files and all source material. We cannot guarantee that future versions of Sandvox will be able to open sites created with this version!\n\nUse of this version is subject to the terms and conditions of Karelia Software's Sandvox Beta License Agreement.", "Alert: Beta Informative Text"), appVersion, appBuildNumber, [[NSDate dateWithString:EXPIRY_TIMESTAMP] relativeFormatWithStyle:NSDateFormatterLongStyle]];
	(void)[alert runModal];
#endif
}
#endif

- (void)connectToHomeBase:(NSTimer *)inTimer
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if (![defaults boolForKey:@"contactHomeBase"])
	{
		return;	// do nothing if we aren't supposed to contact home base
	}
	
	/// check for sparkle update
    [[[SUStatusChecker statusCheckerForDelegate:self] retain] checkForUpdatesInBackground]; 

	// One of the first things we should do is kick off a visit to the host site, so this stuff will be returned ASAP.
	NSString *appVersionString = [[NSBundle mainBundle] version];
    NSDictionary *systemVersionDict = [NSDictionary dictionaryWithContentsOfFile:@"/System/Library/CoreServices/SystemVersion.plist"];
	NSString *sysVersion = [systemVersionDict objectForKey:@"ProductVersion"];
	if (nil == sysVersion)
	{
		sysVersion = @"";
	}
	// This could use -[NSBundle preferredLocalizationsFromArray:forPreferences:]
	// http://www.cocoabuilder.com/archive/message/cocoa/2003/4/24/84070
	// but that would return strings like "English" not "en" which is what we want.
	
	NSArray *langArray = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleLanguages"];
#define MAX_LANGUAGES_TO_TRANSMIT 4
	if ([langArray count] > MAX_LANGUAGES_TO_TRANSMIT)
	{
		langArray = [langArray subarrayWithRange:NSMakeRange(0,MAX_LANGUAGES_TO_TRANSMIT)];
	}
	NSString *languagesString = [langArray componentsJoinedByString:@","];

	NSString *urlString = [NSString stringWithFormat:@"%@sandvox.plist?v=%@&os=%@&l=%@", [defaults objectForKey:@"HomeBaseURL"], appVersionString, sysVersion, languagesString
		];
	// LOG((@"connecting to homebase; URL = %@", urlString));
	
	NSURLRequest *theRequest
	=	[NSURLRequest requestWithURL:[NSURL URLWithString:[urlString encodeLegally]]
						 cachePolicy:NSURLRequestReloadIgnoringCacheData
					 timeoutInterval:15.0];
	// create the connection with the request and start loading the data
	NSURLConnection *theConnection=[[NSURLConnection alloc] initWithRequest:theRequest delegate:self];
	if (theConnection)
	{
		// Create the NSMutableData that will hold
		// the received data
		myHomeBaseConnectionData=[[NSMutableData alloc] init];
	} else {
		// inform the user that the download could not be made
		NSLog(@"unable to set up connection to home base");

	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	OBPRECONDITION(connection);
	OBPRECONDITION(response);
    // this method is called when the server has determined that it
    // has enough information to create the NSURLResponse
	// it can be called multiple times, for example in the case of a
	// redirect, so each time we reset the data.
    [myHomeBaseConnectionData setLength:0];


	if ([response respondsToSelector:@selector(statusCode)])
	{
		int statusCode = [((NSHTTPURLResponse *)response) statusCode]; 
		if (statusCode >= 400)
		{
			[connection cancel];
			[self connection:connection didFailWithError:[NSError errorWithHTTPStatusCode:statusCode URL:[response URL]]];
		}
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	OBPRECONDITION(connection);
	OBPRECONDITION(data);
    // append the new data to the myHomeBaseConnectionData
    [myHomeBaseConnectionData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	OBPRECONDITION(connection);
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // do something with the data
	NSString *errorMessage = nil;
	NSDictionary *root
	= [NSPropertyListSerialization propertyListFromData:myHomeBaseConnectionData
									   mutabilityOption:NSPropertyListMutableContainers
												 format:nil
									   errorDescription:&errorMessage];

	if (nil != root)
	{
		DJW((@"Got Home Base Dict"));
		[self setHomeBaseDict:root];
		
		BOOL shouldUpdateFeed = YES;
		NSDate *feedDate = [root objectForKey:@"feedDate"];
		if (nil != feedDate)
		{
			NSDate *lastSawFeedDate = [defaults objectForKey:@"lastSawFeedDate"];
			if (nil != lastSawFeedDate)
			{
				NSTimeInterval since = [feedDate timeIntervalSinceDate:lastSawFeedDate];
				
				shouldUpdateFeed = (since > 60.0);		// slop of 5 minutes in case file was updated soon thereafter
			}
		}
		[self setNewsHasChanged:shouldUpdateFeed];
		
		[self setNewVersionString:[root objectForKey:@"CurrentAppVersionNumber"]];
		[self setNewFeatures:[root objectForKey:@"CurrentAppFeatures"]];
		
		if (nil != myNewVersionString && ![myNewVersionString isEqualToString:[defaults objectForKey:@"lastNotifiedVersion"]])
		{
			/// turning off new app notification in favor of using sparkle
			///[self performSelector:@selector(notifyNewVersionAvailable:) withObject:nil afterDelay:30.0];
		}
		
		NSString *downloadURLString = [root objectForKey:@"CurrentAppDownloadURL"];
		NSURL *downloadURL = nil;
		if (nil != downloadURLString)
		{
			downloadURL = [NSURL URLWithString:[downloadURLString encodeLegally]];
		}
		[self setCurrentAppDownloadURL:downloadURL];
		
		// Post notification to cause badges to be updated
		[[NSNotificationCenter defaultCenter] postNotificationName:kKTBadgeUpdateNotification
															object:nil]; 
	}
	else
	{
		NSLog(@"error reading home base data: %@", errorMessage);
		[self setHomeBaseDict:nil];
	}

    // release the connection, and the data object
    [connection release];
    [myHomeBaseConnectionData release];
	myHomeBaseConnectionData = nil;

}

// Dan explains why connection, the passed in param, is released in these method:
// "Well, the connection needs to survive across runloops. One way would be to set
// it as an ivar, but in this case, it's retained before the connection starts, 
// and then when the connection is done (either failing or succeeding), it's released
// when it's no longer needed. I don't see a problem with that."

- (void)connection:(NSURLConnection *)connection
		didFailWithError:(NSError *)error
{
	OBPRECONDITION(connection);
	OBPRECONDITION(error);
    // release the connection, and the data object
    [connection release];
    [myHomeBaseConnectionData release];
	myHomeBaseConnectionData = nil;
    // inform the user
    NSLog(@"Connection failed! Error - %@ %@",
          [error localizedDescription],
          [[[[error userInfo] objectForKey:NSErrorFailingURLStringKey] description] condenseWhiteSpace]);

}

#pragma mark -
#pragma mark Utility Methods

- (KTBundleManager *)bundleManager
{
	OBPOSTCONDITION(myBundleManager);
    return myBundleManager;
}

- (KTDocument *)documentWithID:(NSString *)anID
{
	OBPRECONDITION([anID length]);
    NSEnumerator *e = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    KTDocument *document;

    while ( ( document = [e nextObject] ) )
    {
// FIXME: it would be better to not have KTPluginInstallers added to sharedDocumentController
		if ( [document isKindOfClass:[KTDocument class]] )
		{
			if ( [anID isEqualToString:[document documentID]] )
			{
				return document;
			}
		}
    }

    return nil;
}

/*!	Utility method for bindings. If we aren't PNG (or nil), then we're JPEG. */
- (BOOL)preferredImageFormatIsJPEG
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	bool prefersPNG = [defaults boolForKey:@"KTPrefersPNGFormat"];
	return !prefersPNG;
}

- (KTDesignManager *)designManager
{
	OBPOSTCONDITION(myDesignManager);
	return myDesignManager;
}

// Required because a pagelet, page asks if pro
- (BOOL) isPro
{
	return gIsPro;
}

//- (BOOL)shouldAutosave
//{
//	//return [[NSUserDefaults standardUserDefaults] boolForKey:@"AutosaveDocuments"];
//	return YES;
//}

//- (BOOL)shouldBackup
//{
//	return [[NSUserDefaults standardUserDefaults] boolForKey:@"BackupWhenSaving"];
//}

- (BOOL)shouldBackupOnOpening
{
	return ( KTBackupOnOpening == [[NSUserDefaults standardUserDefaults] integerForKey:@"BackupOnOpening"]);
}

- (BOOL)shouldSnapshotOnOpening
{
	return ( KTSnapshotOnOpening == [[NSUserDefaults standardUserDefaults] integerForKey:@"BackupOnOpening"]);
}


- (NSThread *)mainThread
{
	OBPOSTCONDITION(gMainThread);
	return gMainThread;
}

#pragma mark -
#pragma mark Debug Methods

- (IBAction) crash:(id)sender
{
	*((int*)(-1)) = 0;
}
- (IBAction) generateException:(id)sender
{
	
//	[NSException raise:NSInvalidArgumentException format:@"%@: %s: passed DOMRange %p has a different document (%p) to the current document (%p)", self, __FUNCTION__, 10102, 1234, 456];
	NSArray *theArray = [NSArray array];
	id foo = [theArray objectAtIndex:99];
	NSLog(@"foo = %@", foo);
}


- (void)showDebugTableForObject:(id)inObject titled:(NSString *)inTitle	// a table or array
{
	OBPRECONDITION(inObject);
	OBPRECONDITION([inTitle length]);
	[NSBundle loadNibNamed:@"DebugTable" owner:self];
	NSTableView *debugTable = oDebugTable;
	oDebugTable = nil;	// clear out, not using any more.

	[debugTable setDataSource: inObject];
	[debugTable setDelegate: inObject];

	[[debugTable window] setTitle:inTitle];

	// cascade the window.
	myCascadePoint = [[debugTable window] cascadeTopLeftFromPoint:myCascadePoint];

	[[debugTable window] orderFront:nil];
}

- (IBAction)reloadDebugTable:(id)sender;
{
	// HACK below!
	NSTableView *table = [[[[[[sender superview] superview] subviews] objectAtIndex:0] subviews] objectAtIndex:0];
	if ([table respondsToSelector:@selector(reloadData)])
	{
		[table reloadData];
	}
	else
	{
		NSBeep();
		NSLog(@"reloadDebugTable can't reload data");
	}
}

- (IBAction)showAvailableDesigns:(id)sender;
{
	[self showDebugTableForObject:[myDesignManager designs]
                           titled:@"Designs"];
}


- (IBAction)showAvailableComponents:(id)sender
{
	KTBundleManager *components = [self bundleManager];

	[self showDebugTableForObject:[components pluginsOfType:kKTPageExtension]
                           titled:@"Available Components: Page Bundles"];
	[self showDebugTableForObject:[components pluginsOfType:kKTElementExtension]
                           titled:@"Available Components: Page Element Bundles"];
	[self showDebugTableForObject:[components pluginsOfType:kKTPageletExtension]
                           titled:@"Available Components: Pagelet Bundles"];
	[self showDebugTableForObject:[components pluginsOfType:kKTIndexExtension]
							titled:@"Available Components: Index Bundles"];
	[self showDebugTableForObject:[components pluginsOfType:kKTDataSourceExtension]
                           titled:@"Available Components: Data Source Bundles"];
}

#pragma mark -
#pragma mark Support

- (void)buildSampleSitesMenu
{
	// iterate through every file in Sample Sites,
	// setting representedObject to NSURL of location
	
	// original Sample Sites in IB were "iPod Adventures", "Girlfriends", and "Voice Lessons"
	NSMenu *submenu = [[NSMenu alloc] initWithTitle:@""];

	NSArray *paths = [[NSBundle mainBundle] pathsForResourcesOfType:kKTDocumentExtension inDirectory:kKTSampleSitesDirectory];
	NSEnumerator *e = [paths objectEnumerator];
	NSString *samplePath;
	while ( (samplePath = [e nextObject]) )
	{
		NSURL *fileURL = [NSURL fileURLWithPath:samplePath];
		NSString *title = [[samplePath lastPathComponent] stringByDeletingPathExtension];
		NSMenuItem *menuItem = [[NSMenuItem alloc] initWithTitle:title 
														   action:@selector(openSampleDocument:) 
													keyEquivalent:@""];
		[menuItem setTarget:self];
		[menuItem setRepresentedObject:fileURL];
		
		[submenu addItem:menuItem];
		[menuItem release];
	}
	
    [submenu setAutoenablesItems:NO];
	[oOpenSampleSiteMenuItem setSubmenu:submenu];
	[submenu release];
}

/*! changes title of oCutMenuItem to match aKTCutMenuItemTitleType */
- (void)setCutMenuItemTitle:(KTCutMenuItemTitleType)aKTCutMenuItemTitleType
{
	switch ( aKTCutMenuItemTitleType )
	{
		case KTCutMenuItemTitle:
			[oCutMenuItem setTitle:CUT_MENUITEM_TITLE];
			break;
		case KTCutPageMenuItemTitle:
			[oCutMenuItem setTitle:CUT_PAGE_MENUITEM_TITLE];
			break;
		case KTCutPagesMenuItemTitle:
			[oCutMenuItem setTitle:CUT_PAGES_MENUITEM_TITLE];
			break;
		default:
			[oCutMenuItem setTitle:CUT_MENUITEM_TITLE];
			break;
	}
	//LOG((@"Cut is now %@", [oCutMenuItem title]));
}

/*! changes title of oCutPagesMenuItem to match aKTCutMenuItemTitleType */
- (void)setCutPagesMenuItemTitle:(KTCutMenuItemTitleType)aKTCutMenuItemTitleType
{
	switch ( aKTCutMenuItemTitleType )
	{
		case KTCutPageMenuItemTitle:
			[oCutPagesMenuItem setTitle:CUT_PAGE_MENUITEM_TITLE];
			break;
		case KTCutPagesMenuItemTitle:
			[oCutPagesMenuItem setTitle:CUT_PAGES_MENUITEM_TITLE];
			break;
		default:
			[oCutPagesMenuItem setTitle:CUT_PAGE_MENUITEM_TITLE];
			break;
	}
	//LOG((@"Cut Page(s) is now %@", [oCutPagesMenuItem title]));
}

/*! changes title of oCopyMenuItem to match aKTCopyMenuItemTitleType */
- (void)setCopyMenuItemTitle:(KTCopyMenuItemTitleType)aKTCopyMenuItemTitleType
{
	switch ( aKTCopyMenuItemTitleType )
	{
		case KTCopyMenuItemTitle:
			[oCopyMenuItem setTitle:COPY_MENUITEM_TITLE];
			break;
		case KTCopyPageMenuItemTitle:
			[oCopyMenuItem setTitle:COPY_PAGE_MENUITEM_TITLE];
			break;
		case KTCopyPagesMenuItemTitle:
			[oCopyMenuItem setTitle:COPY_PAGES_MENUITEM_TITLE];
			break;
		default:
			[oCopyMenuItem setTitle:COPY_MENUITEM_TITLE];
			break;
	}
	//LOG((@"Copy is now %@", [oCopyMenuItem title]));
}

/*! changes title of oCopyPagesMenuItem to match aKTCopyMenuItemTitleType */
- (void)setCopyPagesMenuItemTitle:(KTCopyMenuItemTitleType)aKTCopyMenuItemTitleType
{
	switch ( aKTCopyMenuItemTitleType )
	{
		case KTCopyPageMenuItemTitle:
			[oCopyPagesMenuItem setTitle:COPY_PAGE_MENUITEM_TITLE];
			break;
		case KTCopyPagesMenuItemTitle:
			[oCopyPagesMenuItem setTitle:COPY_PAGES_MENUITEM_TITLE];
			break;
		default:
			[oCopyPagesMenuItem setTitle:COPY_PAGE_MENUITEM_TITLE];
			break;
	}
	//LOG((@"Copy Page(s) is now %@", [oCopyPagesMenuItem title]));
}

/*! changes title of oDeletePagesMenuItem to match aKTDeletePagesMenuItemTitleType */
- (void)setDeletePagesMenuItemTitle:(KTDeletePagesMenuItemTitleType)aKTDeletePagesMenuItemTitleType
{
	switch ( aKTDeletePagesMenuItemTitleType )
	{
		case KTDeleteCollectionMenuItemTitle:
			[oDeletePagesMenuItem setTitle:DELETE_COLLECTION_MENUITEM_TITLE];
			break;
		case KTDeletePageMenuItemTitle:
			[oDeletePagesMenuItem setTitle:DELETE_PAGE_MENUITEM_TITLE];
			break;
		case KTDeletePagesMenuItemTitle:
			[oDeletePagesMenuItem setTitle:DELETE_PAGES_MENUITEM_TITLE];
			break;
		default:
			[oDeletePagesMenuItem setTitle:DELETE_PAGE_MENUITEM_TITLE];
			break;
	}
	//LOG((@"Delete Page(s) is now %@", [oDeletePagesMenuItem title]));
}

// these two Create Link methods could be combined
- (void)setCreateLinkMenuItemTitle:(KTCreateLinkMenuItemTitleType)aKTCreateLinkMenuItemTitleType
{
	switch ( aKTCreateLinkMenuItemTitleType )
	{
		case KTCreateLinkMenuItemTitle:
			[oCreateLinkMenuItem setTitle:CREATE_LINK_MENUITEM_TITLE];
			break;
		case KTEditLinkMenuItemTitle:
			[oCreateLinkMenuItem setTitle:EDIT_LINK_MENUITEM_TITLE];
			break;
		case KTCreateLinkDisabledMenuItemTitle:
		default:
			[oCreateLinkMenuItem setTitle:CREATE_LINK_MENUITEM_TITLE];
			break;
	}
}

- (void)setCreateLinkToolbarItemTitle:(KTCreateLinkMenuItemTitleType)aKTCreateLinkMenuItemTitleType
{
	NSToolbar *toolbar = [[[[self currentDocument] windowController] window] toolbar];
	NSToolbarItem *toolbarItem = [toolbar itemWithIdentifier:@"showLinkPanel:"];
	
	switch ( aKTCreateLinkMenuItemTitleType )
	{
		case KTEditLinkMenuItemTitle:
			[toolbarItem setLabel:TOOLBAR_EDIT_LINK];
			[toolbarItem setToolTip:TOOLTIP_EDIT_LINK];
			break;
		case KTCreateLinkDisabledMenuItemTitle:
		case KTCreateLinkMenuItemTitle:
		default:
			[toolbarItem setLabel:TOOLBAR_CREATE_LINK];
			[toolbarItem setToolTip:TOOLTIP_CREATE_LINK];
			break;
	}
}


- (void)setDisplayInfoMenuItemTitle:(KTDisplayInfoMenuItemTitleType)aKTDisplayInfoMenuItemTitleType
{
	if ( aKTDisplayInfoMenuItemTitleType == KTHideInfoMenuItemTitle )
	{
		[oToggleInfoMenuItem setTitle:NSLocalizedString(@"Hide Inspector", @"menu title to hide inspector panel")];
	}
	else
	{
		[oToggleInfoMenuItem setTitle:NSLocalizedString(@"Show Inspector", @"menu title to show inspector panel")];
	}
}

- (void)setDisplayMediaMenuItemTitle:(KTDisplayMediaMenuItemTitleType)aKTDisplayMediaMenuItemTitleType
{
	if ( aKTDisplayMediaMenuItemTitleType == KTHideMediaMenuItemTitle )
	{
		[oToggleMediaMenuItem setTitle:NSLocalizedString(@"Hide Media Browser", @"menu title to hide inspector panel")];
	}
	else
	{
		[oToggleMediaMenuItem setTitle:NSLocalizedString(@"Show Media Browser", @"menu title to show inspector panel")];
	}
}

/*! sets aMenuItem to display PRO icon  */
- (void)setMenuItemPro:(NSMenuItem *)aMenuItem
{
	NSAttributedString *oldTitle = [aMenuItem attributedTitle];
	NSDictionary *attrDict = nil;
	if (nil == oldTitle)
	{
		attrDict = [NSDictionary dictionaryWithObjectsAndKeys:
			[NSFont systemFontOfSize:([NSFont systemFontSize]+1.0)], NSFontAttributeName,
			nil];
		// No attributed string, so setup the title, we have to hand-tune the font size apparently
		oldTitle = [[[NSMutableAttributedString alloc] initWithString:[aMenuItem title] attributes:attrDict] autorelease];
	}
	else
	{
		attrDict = [oldTitle attributesAtIndex:0 effectiveRange:nil];
	}

	NSAttributedString *spaceString = [[[NSAttributedString alloc] initWithString:@" " attributes:attrDict] autorelease];

    // setup the image cell, with hand-tuned baseline!
    NSTextAttachmentCell *cell = [[[NSTextAttachmentCell alloc] initImageCell:[NSImage imageNamed:@"PRO.png"]] autorelease];
    NSTextAttachment *attachment = [[[NSTextAttachment alloc] init] autorelease];
    [attachment setAttachmentCell:cell];
    NSMutableAttributedString *newString = [[[NSMutableAttributedString alloc] initWithAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]] autorelease];
    [newString addAttributes:attrDict range:NSMakeRange(0,[newString length])];
	
	float baselineOffset = -2.0;		// default if no para style
	NSParagraphStyle *paraStyle = [attrDict objectForKey:NSParagraphStyleAttributeName];
	if (nil != paraStyle)
	{
		float minimumLineHeight = [paraStyle minimumLineHeight];
		NSFont *fontUsed = [attrDict objectForKey:NSFontAttributeName];
		baselineOffset = (minimumLineHeight - [fontUsed xHeight]) / 2.0 - 4.0;
	}
	
	[newString addAttribute:NSBaselineOffsetAttributeName
					  value:[NSNumber numberWithFloat:baselineOffset]
					  range:NSMakeRange(0,[newString length])];
		
	// set the attributed string
	[newString appendAttributedString:spaceString];
    [newString appendAttributedString:oldTitle];

    // set the menu
    [aMenuItem setAttributedTitle:newString];
}

/*! resets aMenuItem back to its original target, action, title, and representedObject */
- (void)setMenuItemRegular:(NSMenuItem *)aMenuItem
{
    NSDictionary *dict = [aMenuItem representedObject];
    [aMenuItem setTarget:nil];
    [aMenuItem setAction:NSSelectorFromString([dict objectForKey:@"action"])];
    [aMenuItem setTitle:[dict objectForKey:@"title"]];
    [aMenuItem setRepresentedObject:[dict objectForKey:@"representedObject"]];
}

- (IBAction)toggleLogAllContextChanges:(id)sender
{
	BOOL flagOn = ([sender state] == NSOnState) ? YES : NO;
	[[NSUserDefaults standardUserDefaults] setBool:flagOn forKey:@"KTLogAllContextChanges"];
}

- (BOOL)logAllContextChanges
{
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"KTLogAllContextChanges"];
}

/*! log undo-related notifications */
- (void)logUndoNotification: (NSNotification *) notification
{
   LOG((@"%@", [notification name]));
}

// Only allow for ripple animation if we have two/dual processors or better.  An Intel core solo just doesn't cut it!
// I tested the ripple animation on the fastest single-processor G5 and it didn't cut it either.
// And the fastest G4s weren't good enough.

+ (BOOL) fastEnoughProcessor
{
	int processors = MPProcessors();
	if (processors < 2) return NO;
	
    SInt32 gestaltReturnValue;
    int gestaltResult = Gestalt(gestaltNativeCPUtype, &gestaltReturnValue);
	if (noErr != gestaltResult) NSLog(@"gestalt returned: %d", gestaltResult);
	
	if (gestaltReturnValue <= gestaltCPUG47450)
	{
		return NO;	// G4, G3 and before are definitely not fast enough
	}
	return YES;		// if we got here, we have something newer than a G4, and dual processor.
					// FUTURE: maybe some newer single-processor CPUs will be OK...
}

/*!	Calculate if core image is accelerated only if it's not already known
*/

+ (BOOL) coreImageAccelerated
{	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *key = [NSString stringWithFormat:@"CoreImageAccelerated %@", [[KSUtilities MACAddress] base64Encoding]];
	if (nil == [defaults objectForKey:key])
	{
		// First check if Quart Extreme is enabled
		BOOL result = CGDisplayUsesOpenGLAcceleration(kCGDirectMainDisplay);

		// If so, now check if Core Image is accelerated. 
		if (result)
		{
			NSString *checkingQCFilePath = [[NSBundle mainBundle] pathForResource:@"CheckOpenGL" ofType:@"qtz"];
			NSAssert(nil != checkingQCFilePath, @"Cannot find CheckOpenGL.qtz");
			
			NSOpenGLPixelFormatAttribute	attributes[] = {
				NSOpenGLPFAAccelerated,
				NSOpenGLPFANoRecovery,
				(NSOpenGLPixelFormatAttribute)0
			};
			NSOpenGLPixelFormat*	format = [[NSOpenGLPixelFormat alloc] initWithAttributes:attributes];
			NSOpenGLContext*		context = [[NSOpenGLContext alloc] initWithFormat:format shareContext:nil];
			CGLContextObj			cgl_ctx = [context CGLContextObj];
			if(cgl_ctx)
			{
				glViewport(0, 0, 100, 100);
			}
			QCRenderer*				renderer = [[QCRenderer alloc] initWithOpenGLContext:context pixelFormat:format file:checkingQCFilePath];
			
			[renderer renderAtTime:0.0 arguments:nil];
			
			id resultID = [renderer valueForOutputKey:@"Core_Image_Accelerated"];
			
			// Get the real value
			result = [resultID intValue];
			
			
			[renderer release];
			[context release];
			[format release];
		}
		[defaults setBool:result forKey:key];
		[defaults synchronize];
	}
	return [defaults boolForKey:key];
}	

@end

@implementation NSArray ( TableDataSource )

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *result = nil;
	id obj = [self objectAtIndex:rowIndex];
	if ([obj respondsToSelector:@selector(objectForKey:)])
	{
		NSString *ident = [aTableColumn identifier];
		unsigned int colNum = [ident intValue] - 1; // 0 or 1 or 2...
		NSArray *allValues = [obj allValues];
		if (colNum < [allValues count])
		{
			result = [[[allValues objectAtIndex:colNum] description] condenseWhiteSpace];
		}
	}
	else
	{
		result = [obj description];
	}
	return result;
}

- (int)numberOfRowsInTableView:(NSTableView *)inTableView
{
	return [self count];
}

@end

@implementation NSDictionary ( TableDataSource )

// Show key in column zero, value in column 1. Sort the keys.

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
{
	NSString *result = nil;
	NSArray *allKeys = [[self allKeys] sortedArrayUsingSelector:@selector(caseInsensitiveCompare:)];
	id key = [allKeys objectAtIndex:rowIndex];

	NSString *ident = [aTableColumn identifier];
	int colNum = [ident intValue] - 1; // 0 or 1 or 2...
	if (0 == colNum)
	{
		result = [key description];
	}
	else
	{
		result = [[[self objectForKey:key] description] condenseWhiteSpace];
	}
	return result;
}

- (int)numberOfRowsInTableView:(NSTableView *)inTableView
{
	return [self count];
}

@end

// FIXME: apparently something was displaying a KTStoredArray in a tableview -- debug table?
// KTStoredArray is now a deprecated class

//#import "KTStoredArray.h"
//
//@implementation KTStoredArray ( TableDataSource )
//
//- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex
//{
//	NSString *result = nil;
////	id obj = [[self storedArray] objectAtIndex:rowIndex];
//	id obj = [self objectAtIndex:rowIndex];
//	if ([obj respondsToSelector:@selector(objectForKey:)])
//	{
//		NSString *ident = [aTableColumn identifier];
//		unsigned int colNum = [ident intValue] - 1; // 0 or 1 or 2...
//		NSArray *allValues = [obj allValues];
//		if (colNum < [allValues count])
//		{
//			result = [[[allValues objectAtIndex:colNum] description] condenseWhiteSpace];
//		}
//	}
//	else
//	{
//		result = [obj description];
//	}
//	return result;
//}
//
//- (int)numberOfRowsInTableView:(NSTableView *)inTableView
//{
////	return [[self storedArray] count];
//	return [self count];
//}
//
//@end
