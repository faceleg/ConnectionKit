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

#import "BDAlias.h"
#import "KT.h"
#import "KTAcknowledgmentsController.h"
#import "KTApplication.h"
#import "KTBundleManager.h"
#import <Sandvox.h>
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
#import "NSException+Karelia.h"
#import "NSString+KTApplication.h"
#import "NSString-Utilities.h"
#import "SandvoxPrivate.h"
#import "NSError+Karelia.h"
#import "NSArray+KTExtensions.h"
#import <AmazonSupport/AmazonSupport.h>
#import <Connection/Connection.h>
#import <ExceptionHandling/NSExceptionHandler.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenSaver/ScreenSaver.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <iMediaBrowser/iMediaBrowser.h>

#ifdef SANDVOX_RELEASE
#import "Registration.h"
#endif

// ? #import </usr/include/objc/objc-class.h>
// ? #import </usr/include/objc/Protocol.h>

#include <openssl/rsa.h>
#include <openssl/sha.h>
#include <openssl/err.h>
#import <netinet/in.h>

NSThread *gMainThread = nil;
BOOL gWantToCatchSystemExceptions = NO;

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

// THIS IS FROM DTS WORK-AROUND
// Define HACKAROUND to 1 to hack around <rdar://problem/4191740>.

#define HACKAROUND 1
#if HACKAROUND

typedef void (*SignalHandler)(int sig, siginfo_t *sip, void *scp);

static SignalHandler gNSExceptionHandlerUncaughtSignalHandler;

static void HackySignalHandler(int sig, siginfo_t *sip, void *scp)
{
	// LIKE NSLog -- fprintf(stderr, "HackySignalHandler (sig=%s, sip=%p, scp=%p)\n", sys_signame[sig], sip, scp);
	gNSExceptionHandlerUncaughtSignalHandler(sig, sip, scp);
}

#endif

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
		@"sandvox.RichTextElement",		@"DefaultRootPageBundleIdentifier",
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
		[KTEmailAddressComboBox primaryEmailAddress], DEFAULTS_ADDRESS_KEY,
		
		
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

	gMainThread = [NSThread currentThread];

	[self registerDefaults];
	
	// Register my transformers.
	// Note: for some useful math operation transformers, see
	// http://homepage.mac.com/oscarmv/OMVFPValueTransformers.sitx

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

		NSExceptionHandler *handler = [NSExceptionHandler defaultExceptionHandler];
		OBASSERT(handler);
		// From Steve Gehrman:
		// turn off some of the NSLogs (was NSLogAndHandleEveryExceptionMask)
		// Applescript and DefaultFolder have some issues with no window visible
		int mask = (
					
					NSLogUncaughtExceptionMask|
					NSLogUncaughtSystemExceptionMask|
					NSLogUncaughtRuntimeErrorMask|
					NSHandleUncaughtExceptionMask|
					NSHandleUncaughtSystemExceptionMask|
					NSHandleUncaughtRuntimeErrorMask|
					NSLogTopLevelExceptionMask|
					NSHandleTopLevelExceptionMask|
					// NSLogOtherExceptionMask|
					NSHandleOtherExceptionMask
					);
			
		[handler setExceptionHandlingMask:mask];
		[handler setDelegate:self];
		
#if HACKAROUND
        // Get the old signal handler, which is the one installed by NSExceptionHandler.

        gNSExceptionHandlerUncaughtSignalHandler = (SignalHandler) signal(SIGSEGV, SIG_DFL);
        
        // Install our signal handlers, using sigaction so that we can specify SA_SIGINFO so 
        // that we get the extra arguments passed to the signal handler.
        
        {
			int              err;
            struct sigaction sa;
			
            sa.sa_sigaction = HackySignalHandler;
            sa.sa_flags = SA_SIGINFO;
            sigemptyset(&sa.sa_mask);
			
            err = sigaction(SIGSEGV, &sa, NULL);
            assert(err == 0);
            err = sigaction(SIGBUS,  &sa, NULL);
            assert(err == 0);
        }
#endif

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
		
		// not sure where to put this, but we need to set up the class
		[NSDateFormatter setDefaultFormatterBehavior:NSDateFormatterBehavior10_4];
		
//		LOG((@"Environment = %@", [[NSProcessInfo processInfo] environment]));

	}

    return self;
}

// Sort of documented here:
// http://developer.apple.com/documentation/Cocoa/Conceptual/Exceptions/Tasks/ControllingAppResponse.html
// Also check out:
// http://www.cocoadev.com/index.pl?StackTraces
// and
// http://developer.apple.com/technotes/tn2004/tn2123.html
//
// December 2003 MacTech

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender
   shouldHandleException:(NSException *)exception 
					mask:(unsigned int)aMask
{
//#warning ------ TEMPOARY OVER-LOGGING
//	NSLog(@"exc = %@: %@ %@ %@", exception, [exception name], [exception reason], [[exception userInfo] description]);
	
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
	
	// Normally we want to ignore these so that the crash handler can do its thing.  If we turn on gWantToCatchSystemExceptions then we can catch crashes
	//
	if (!gWantToCatchSystemExceptions && ([name isEqualToString:@"NSUncaughtSystemExceptionException"] 
										 || [name isEqualToString:@"NSUncaughtRuntimeErrorException"]) )
	{
		return NO;
	}

	if (myHandlingExceptionAlready)
	{
		NSLog(@"Not handling exception, we are already in exception handler.  %@", exception);
		return NO;
	}
		
	@try
	{
		myHandlingExceptionAlready = YES;	// below might fail or recurse -- this should help prevent recursion.
		// Do my own logging, even though we have mask to log 
		LOG((@"Parsed stack trace (mask=%d):\n%@", aMask, [[[exception userInfo] objectForKey:NSStackTraceKey] condenseWhiteSpace]));
	}
	@finally
	{
		myHandlingExceptionAlready = NO;
	}
	return YES;
	// Note: based on article on Dec 2003 macTech
}

- (BOOL)exceptionHandler:(NSExceptionHandler *)sender shouldLogException:(NSException *)exception mask:(unsigned int)aMask
{
    return NO;
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
		
		[KTSilencingConfirmSheet
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
	

	// LOG((@"thread at app launch = %p", gMainThread));

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
	
	
	// find transactions of what we refund.  For each parent transaction ID, find it in gmail and get the license code.
	
#define INVALID_LIST_COUNT 143
	
unsigned char invalidListDigests[INVALID_LIST_COUNT][SHA1_DIGEST_LENGTH] = {
{ 0x6F,0xD9,0x8B,0xCF,0x1C,0x1B,0x77,0x44,0xD5,0x94,0x0E,0xEB,0xFE,0x6E,0x80,0xF6,0x94,0xDA,0x8D,0x25 }, // P Canavan Only Chob Deanery
{ 0x05,0x78,0xD2,0xAD,0xF5,0x6F,0x4A,0xB0,0xDC,0x34,0x28,0xD3,0xDE,0xED,0xAF,0x7E,0x3B,0x1F,0x21,0xED }, // Mike Lane Pestify Chob Eonism
{ 0xDE,0x29,0x3E,0x58,0x4C,0x12,0x73,0x90,0x60,0x41,0x0B,0xF4,0xF3,0x33,0xE8,0x8C,0xB2,0xC6,0x1E,0xC9 }, // Scott Bennett Chuff Warrior Scratch
{ 0xAB,0xB0,0x53,0x8F,0x48,0x1A,0x70,0x8E,0x9E,0x87,0x50,0x58,0x2B,0xB3,0x05,0xE1,0xDF,0x2C,0x21,0x99 }, // Ernesto Martinez-Ordaz Only Air Mudland
{ 0x84,0x95,0x60,0xB0,0xA4,0xEA,0x19,0xA7,0x34,0x0A,0xBA,0x5B,0x9A,0x61,0x1F,0xA0,0x2C,0xAB,0xB0,0x74 }, // Efron Hirsch Peckish Silked Owl

{ 0xB7,0x12,0x79,0xBF,0x1E,0xEB,0x9D,0xC4,0xC6,0x37,0xA3,0xE4,0xC4,0xA4,0x7B,0x1B,0x18,0x9D,0x54,0x13 }, // Jim Steward Chuff Silked Appease
{ 0x90,0xC2,0x66,0xE0,0xA1,0x04,0x2D,0xA8,0x17,0x81,0x8F,0x2E,0x46,0x42,0x9D,0xC1,0xF3,0xCF,0x18,0xD2 }, // guenter bolzern Unnaked Joust Revelry
{ 0x33,0x04,0x0C,0x50,0x89,0xAC,0xE5,0x47,0x31,0xC4,0xD1,0x0E,0x1A,0xD7,0xFD,0x2C,0x76,0x73,0x72,0x24 }, // M SLOOS Blan Rheinic Paludal
{ 0x60,0x35,0x30,0x9A,0x8A,0x67,0x40,0x2E,0xF0,0x5E,0x8A,0xBA,0xC1,0x97,0x6D,0xC5,0x87,0x6F,0xFA,0x7E }, // Jacob Salomons Spurge Rheinic Tyee .... Upgrade to "Pro" license
{ 0xD1,0x7D,0x6F,0xDD,0xA0,0xC9,0x2B,0x70,0x1B,0xA1,0x47,0x94,0x29,0x33,0x37,0x6A,0xCC,0xBB,0x62,0x86 }, // Jake Salomons Spurge Untress Neaten

{ 0x70,0xE4,0xE5,0x92,0x40,0x79,0x71,0x65,0xD6,0xE5,0x9C,0x5F,0x07,0x54,0x1C,0xE6,0xD9,0xC0,0x17,0x54 }, // Joseph Liberti Balled Silked Jestful
{ 0x54,0xAA,0x73,0x46,0xEF,0xC7,0x8B,0x69,0xE3,0xDC,0x39,0x85,0xD2,0x5E,0x4D,0xB9,0x78,0x5C,0xE6,0x34 }, // michael day Tiepin Untress Ropes
{ 0xFE,0x8B,0x17,0x19,0xE9,0xB0,0xBA,0x49,0xA2,0xA4,0x48,0xAB,0x96,0xE2,0xF6,0xC6,0xF4,0x77,0xA8,0x0F }, // Marty Ma Unnaked Air Chumpy
{ 0x9F,0x5F,0x8F,0xB9,0x43,0xE7,0x8C,0x2E,0xAB,0x82,0xB1,0xB8,0xF3,0x6E,0x54,0xA8,0x25,0x3D,0xEC,0x61 }, // Kyan Mulligan Galilee Stion Carman
{ 0x6A,0x23,0x88,0x80,0xEC,0x09,0x01,0xD0,0xAE,0x88,0xF6,0x85,0xC4,0x19,0x07,0xE7,0x0F,0x8E,0x07,0x7D }, // Kerry Millerick Unnaked Chob Reglaze

{ 0x96,0x80,0x6F,0x96,0x8A,0x23,0x94,0x2F,0xF4,0x7E,0x10,0xD7,0x3C,0xF2,0x0F,0x0C,0x8F,0xFA,0x9C,0x07 }, // Winston Wolff Caret Teleuto Coaxial
{ 0x7C,0x1D,0x3A,0x9D,0x31,0x58,0x16,0xCB,0xAD,0x93,0x82,0xF3,0x6A,0x6E,0x8F,0x48,0x15,0xC8,0xD6,0x1D }, // Tom Hubbard Comanic Roomed Cuprose
{ 0xDE,0x8D,0x23,0x1B,0xE8,0x68,0x21,0x2F,0x4E,0xC2,0x15,0x52,0xFA,0x81,0x46,0xA3,0xF7,0xB7,0xB7,0x57 }, // Serge Grandbois Opposed Chob Instar
{ 0xC5,0x2C,0xF7,0xD7,0xAE,0xB0,0xE6,0x5C,0x97,0x1F,0x9E,0xED,0x4C,0x63,0x53,0x8F,0x63,0x69,0xFA,0x0C }, // David Walkerden Soakage Buttle Captor
{ 0xF1,0x4C,0x78,0xA6,0x75,0xC0,0x5A,0xEA,0x4A,0x92,0x28,0x7D,0x6B,0x92,0x9B,0x6F,0x5C,0x17,0xAA,0x38 }, // Chris Offutt Addle Stion Comanic

{ 0x51,0xF1,0x0F,0xE5,0x12,0xC2,0xDF,0x4A,0xBE,0x96,0x76,0x17,0xFA,0x5C,0x98,0x07,0x5A,0x68,0x7B,0x42 }, // Daniel Pfisterer Beehead Stion Thocht -- CHARGEBACK!  (unresolved)
{ 0x92,0x87,0x88,0x6E,0x20,0xB1,0xB6,0x83,0x10,0x0D,0x3D,0xD3,0xD1,0xF3,0x2D,0xC9,0x00,0xA4,0xA9,0xD8 }, // gaga gagaga Lateral Teleuto Shicker -- CHARGEBACK
{ 0xE7,0xED,0x6D,0x6E,0x11,0xFD,0xC5,0x32,0x30,0x68,0xB2,0xF9,0x38,0xEC,0x0F,0xD6,0x7B,0xB1,0xD3,0xA3 }, // Justin Padawer Galilee Distain Volcano
{ 0x03,0x87,0x40,0xC7,0xBF,0xD4,0x64,0xC9,0xD0,0x4E,0xF0,0x48,0xD5,0x06,0x5B,0x02,0xB8,0x10,0x83,0x3F }, // Justin Padawer Wigtail Expound Radiale
{ 0x30,0xF5,0xD5,0x0D,0x1B,0x20,0xAF,0xB1,0xAD,0xE2,0xF2,0x87,0x98,0x1E,0x7C,0xAC,0xFB,0x48,0xD6,0xD8 }, // Robert Sayman Sarking Roomed Camused -- REVERSED PAYMENT

{ 0xE4,0x25,0x83,0xB4,0xC7,0xFE,0x1F,0x02,0x99,0xB5,0x99,0x15,0x84,0x69,0xA6,0x5D,0x5C,0x7F,0xF1,0x64 }, // kent allen Addle Distain Preface -- CHARGEBACK (unresolved)
{ 0x31,0xFC,0x88,0x44,0x9F,0x15,0xDD,0x25,0x03,0x04,0x7D,0x9F,0x84,0x69,0x9C,0x1A,0xAF,0x4B,0xB9,0xF2 }, // Shane Anderson Caret Expound Sizing		
{ 0x7E,0xCE,0xA2,0xAF,0xBC,0xED,0xCF,0x2F,0x96,0xB3,0x3F,0x73,0x6F,0x42,0x09,0x83,0x82,0xBE,0x79,0xF9 }, // Mark Maederer Replay Otosis Gestate
{ 0xB5,0x69,0xCE,0xC8,0xA1,0x61,0x36,0x3D,0xF7,0x03,0xA9,0x68,0xCD,0xDD,0x70,0x03,0x8D,0x38,0x24,0xB7 }, // Allan louis Releap Warrior Gigback
{ 0xD8,0x90,0x45,0xD1,0xAB,0x8F,0xAD,0x14,0x2F,0xD8,0x00,0x37,0xD3,0x09,0x8F,0x46,0xD3,0x18,0xD7,0xF8 }, // Dustin Webber Senna Teleuto Waffly

{ 0xD5,0xC3,0x85,0xCD,0x93,0xDA,0xC4,0xF6,0x3B,0x87,0x20,0x35,0xDA,0xBC,0xBD,0xE5,0xB2,0x3D,0xDF,0xE0 }, // Melissa cho Waspy Over Camion
{ 0x65,0xA0,0xEA,0xAC,0x58,0x2B,0xE8,0x5F,0x9A,0x95,0xB2,0xC1,0x22,0x45,0xBB,0xFC,0x35,0xFC,0xDD,0xDD }, // kody stitz Cockpit Otosis Fooster
{ 0x57,0xFA,0xC2,0x7E,0x57,0x02,0xB1,0x80,0x40,0x40,0x34,0x25,0x7A,0x80,0x0F,0x15,0x73,0xB1,0x53,0xB9 }, // Mark Spomer Twarly Distain Pantle
{ 0x2D,0xE1,0xAB,0x3F,0x11,0xB4,0x4B,0x90,0xC3,0x7B,0x01,0x10,0x1A,0x4D,0xCB,0x07,0x79,0xF6,0x36,0x0C }, // Jeff Duska Culprit Chob Ennead		
{ 0xFF,0x52,0xC5,0x34,0x6E,0x94,0xB8,0x53,0x6B,0x8A,0xB8,0x83,0x23,0x32,0xA1,0xBA,0xF2,0x36,0x1C,0xF1 }, // Melissa C Tipton Gogo Jackal Outeat	

{ 0x7E,0xC8,0x87,0xED,0xE7,0x36,0x14,0xBF,0xFC,0x74,0x7C,0x7E,0xBD,0xC9,0xF6,0xD9,0x7B,0x63,0x62,0x35 }, // FRANCOISE INGRAIN LUDOT Danner Tought Urging -- he downgraded to pro non-household.
{ 0x00,0x33,0xCE,0x9F,0xB0,0x9C,0x67,0x61,0x46,0x3B,0x40,0xE0,0x15,0xC0,0x50,0xF2,0x85,0x77,0x43,0xDF }, // Mark Smith Flews Air Loofie
{ 0x14,0xB5,0x59,0x34,0x4A,0x8F,0x06,0x32,0x5E,0x01,0x04,0x4E,0x74,0xFC,0x28,0xF1,0x98,0x68,0x32,0x99 }, // Alina Balean Betail Silked Unlie
{ 0x0F,0x39,0xC9,0x39,0x15,0xA8,0xF7,0x14,0x0B,0xCB,0x02,0xF0,0x46,0x9D,0xB0,0x6F,0xE2,0x36,0x7B,0x19 }, // Reinardo Funez Intil Awny Upbotch
{ 0x46,0xD5,0x48,0x4B,0x5C,0xAB,0x2E,0xB4,0xC9,0xB6,0x79,0xF2,0x4D,0x6B,0xD8,0x85,0x2A,0x90,0xB9,0x0C }, // Shelley Cochran Brither Awny Ileus

{ 0xC8,0xE6,0xD5,0xE3,0x46,0xC7,0x4E,0x04,0x4E,0x4E,0xE6,0xE7,0xCE,0x1E,0x0A,0x51,0xA6,0x4E,0xCC,0x1A }, // Edmond Cadieux Solicit Chob Hassock		
{ 0xE9,0x9D,0xFF,0xE9,0x12,0xD1,0x71,0x85,0xB8,0x7D,0x8A,0x24,0x8C,0xDA,0xAC,0x38,0x2D,0xD5,0x2A,0xF0 }, // Ade Horovitz Rotifer Misstep Rheinic
{ 0x85,0x30,0xB2,0xB8,0x72,0x68,0xC3,0x0F,0x99,0xB9,0x55,0x8F,0x5B,0x40,0x2C,0xE0,0x6B,0x69,0xF6,0x2E }, // Diane Wolf Unsolar Jackal Stayer
{ 0x5C,0x71,0xA8,0x80,0x81,0x06,0xE3,0xD3,0x42,0xC3,0x71,0x8B,0x20,0x75,0xB5,0x7D,0xD0,0xB1,0x54,0xBF }, // Frank Varney Crambid Stion Brool
{ 0xFE,0x81,0x17,0xEE,0xFB,0x2D,0xC9,0x57,0xEC,0x37,0xB5,0x4C,0x1D,0x5C,0x80,0x09,0xF8,0x89,0xC4,0xE8 }, // BETSY BACHILLER Outeat Awny Tripart

{ 0x00,0x1D,0xCF,0xFF,0x72,0xA9,0xD7,0x64,0xC9,0x40,0x28,0x2E,0x2E,0xEF,0x1B,0x48,0x58,0x8E,0x38,0x90 }, // dave whitby Impages Morris Crepy
{ 0x6B,0xB5,0x36,0x5B,0xC9,0xCE,0x98,0x1C,0xB9,0xE2,0xF2,0xFA,0xD2,0xA4,0x15,0x4F,0x9C,0x1C,0xE0,0x5B }, // Susan Evans Saunter Air Vined -- double purchase
{ 0xDB,0xF6,0x69,0x10,0x47,0x36,0x98,0x9C,0x86,0x4E,0x4F,0xBE,0x5B,0x8A,0xFC,0xDB,0x45,0x67,0x4B,0x49 }, // Alma Maria Ballet Teleuto Setter -- weird fraud problem
{ 0x83,0xAC,0xA9,0xF8,0xEC,0xDF,0xBD,0x13,0x4F,0xE4,0x3E,0xBC,0x56,0x3E,0xD8,0x94,0x72,0x0D,0x15,0xB1 }, // Shawn Medero Shortly Rheinic Whoof
{ 0xF3,0x62,0x95,0x22,0xA0,0x3F,0xF1,0x0B,0xC3,0x73,0x73,0xC6,0x2F,0x89,0xE7,0xA2,0x0D,0xCC,0x07,0x70 }, // Jennifer Rudolph Waffle Silked Postman

{ 0x2C,0x63,0x04,0xBA,0x09,0x35,0xE6,0xFD,0x35,0x95,0x4F,0xAA,0xFE,0x5F,0xD3,0x17,0x78,0x72,0x78,0x40 }, // Michael Baycroft Smiler Silked Noded
{ 0xD8,0x9B,0xBD,0xF1,0xFE,0xAE,0x20,0xCF,0x8A,0xF1,0xED,0x14,0x86,0x7D,0x24,0x43,0x43,0x4C,0xD8,0x3C }, // Nancy Lefebure Quantic Silked Netlike	 (just a licensee change)	
{ 0x37,0xBC,0x18,0x81,0x02,0x55,0x3C,0xCE,0xA1,0x85,0xBE,0xA7,0x2D,0xE3,0x7F,0xE8,0xC7,0xF6,0x1B,0xB5 }, // Andrew Myers Geode Viner Ladify (license change)		
{ 0x80,0xE4,0x62,0x8A,0x28,0xCC,0x7A,0x9D,0x8E,0x7A,0x85,0x4A,0x21,0x76,0xD1,0xAF,0x36,0x57,0xEE,0xE6 }, // Michael Palumbo Golland Rheinic Acmite	
{ 0xD6,0x9D,0xDC,0xA6,0xF9,0x21,0x35,0x2D,0xD5,0x5D,0xB2,0x06,0x1D,0x8C,0x52,0xBC,0x49,0x52,0x25,0xF6 }, // Ryan Matthews Blady Awny Juloid

{ 0xFB,0x5D,0x81,0x70,0x90,0x59,0xC6,0xB7,0x34,0x27,0x9C,0x4E,0x83,0xC3,0x8E,0x18,0x8A,0x76,0x3D,0x90 }, // Olivia Oquendo Opposer Warrior Hutlet  (dispute)
{ 0xD1,0x8F,0x1A,0x72,0x0F,0xEC,0x9D,0x83,0xB4,0xFF,0x9C,0xAA,0xDD,0x63,0xA0,0x1A,0x18,0xB2,0x99,0xB3 }, // Helena Chung Rawhide Buttle Whole
{ 0x3F,0x9C,0x37,0x38,0x43,0x6B,0xC4,0xC7,0x1D,0xAD,0x64,0xDE,0xAD,0x65,0x33,0x1F,0x56,0x7B,0x39,0x63 }, // Barbara Engstrom Visive Warrior Bonnaz	
{ 0xD9,0xA8,0xF1,0xF3,0xBA,0x2B,0xDC,0xF6,0x0B,0x3E,0xB4,0x00,0x0E,0xC6,0xEE,0x95,0x1C,0x8B,0xB5,0x09 }, // John Duggan Visive Silked Imbat
{ 0xE3,0x0D,0x72,0xDA,0xA7,0x31,0xBE,0x56,0xDA,0x9F,0x10,0x2A,0x96,0xD5,0x20,0x5E,0xE8,0x41,0xA5,0xCE }, // Stephen Blust Preface Jackal Misrate	

{ 0x18,0x73,0x69,0x26,0xD9,0xF6,0xDC,0x74,0x42,0xFD,0xAF,0x13,0xB7,0xDB,0x1C,0xCD,0x65,0x17,0x72,0x97 }, // Rudy Mortier Golland Silked Printed (accidentally double payed)
{ 0x33,0xB0,0x4E,0x3A,0x27,0x70,0x8D,0x1F,0x04,0x18,0x5E,0x8D,0xCA,0x77,0xDF,0xE9,0x9F,0x30,0xAD,0x7A }, // Matthew Trevino Clobber Over Halfway
{ 0x0D,0xB9,0x99,0xFE,0xEB,0xFE,0x6E,0xCC,0x48,0x73,0xBC,0x02,0x6C,0xD9,0x95,0x1E,0xD7,0xAA,0xE7,0xA5 }, // morrison stepp Katuka Logger Octuply
{ 0x3F,0x42,0x71,0x33,0x9B,0x8F,0x6F,0xBE,0x38,0xE5,0x9B,0xBD,0x61,0x65,0x7A,0xEB,0x52,0xC5,0xC8,0xF2 }, // Philip Elias Opposer Awny Moneron [forgot to blacklist earlier!]
{ 0xD2,0x08,0xD8,0x2D,0xB1,0xEA,0xC6,0x89,0x2D,0x75,0xE0,0x41,0x8F,0xD9,0xF2,0x80,0x48,0x7C,0xC1,0x36 }, // Andrew Colton Sizing Warrior Betalk

{ 0x08,0xC8,0xBF,0xDB,0x59,0x30,0xF1,0xFF,0xCE,0x3D,0xC8,0x24,0xD2,0xC7,0x02,0xCF,0x81,0xAF,0x09,0x66 }, // Thomas Krieglstein Priss Joust Surplus
{ 0xBC,0xEF,0x32,0x3F,0x37,0x83,0x35,0x5E,0x86,0x00,0x38,0xEF,0x95,0xB1,0x89,0x4A,0x4A,0xFA,0x90,0x24 }, // Richard McFarlane Hontish Jackal Woo
{ 0x33,0x5B,0x48,0x6E,0xB4,0xAC,0x3B,0xE6,0x40,0x1C,0x13,0x3E,0x42,0x59,0xD8,0x09,0x15,0x40,0x72,0x19 }, // Eric Gilbert Unlid Logger Churchy
{ 0xDD,0x8E,0x99,0xED,0x97,0x6B,0x8B,0xEC,0x67,0x8E,0x0D,0x9D,0x13,0x22,0x47,0xCE,0x28,0x24,0xDE,0x5B }, // Darin J Snyder Unlie Awny Tarsome
{ 0x5D,0xF9,0x76,0x44,0x08,0xCE,0x64,0x8F,0x43,0x24,0xE2,0x19,0xED,0x84,0xF4,0xF7,0x59,0x0A,0x0F,0x4F }, // Diane Wilson Stoper Warrior Upblaze

{ 0x14,0x89,0x2A,0x76,0x4C,0x96,0x6A,0xDA,0xB2,0x30,0x87,0xFC,0x28,0xD6,0xD0,0x00,0x4D,0x22,0x1A,0x90 }, // Shaun Frost Setter Distain Tiller
{ 0xBC,0x07,0xCD,0xFE,0x91,0x55,0x9F,0xC3,0x66,0xE3,0xF1,0x29,0xD3,0xED,0x42,0x6E,0xE1,0x9F,0x4F,0x7F }, // William Luckie Bottom Chob Susu
{ 0x3C,0x74,0x7C,0xBB,0xC3,0xAD,0xDD,0x51,0x93,0x84,0x79,0x51,0x2A,0x9B,0x97,0x5F,0x8E,0xFE,0x35,0x35 }, // YANNIC DE BAETS Corf Awny Axiate
{ 0xF9,0x4D,0xD9,0x2A,0x7E,0x9F,0x99,0xF8,0x9A,0xF9,0x08,0x39,0xD1,0x95,0x2A,0xD5,0x73,0xEC,0x47,0x71 }, // susan warren Smutchy Logger Cost
{ 0xF8,0xB1,0x21,0xF6,0x34,0x43,0x3A,0x4E,0xAC,0x2E,0x3A,0xFA,0x89,0xFC,0x5A,0x44,0x36,0xBB,0x17,0xB6 }, // Susan Allen Broke Air Unsun

{ 0xAC,0x63,0x1C,0xEF,0x62,0xA0,0x04,0xDF,0x6D,0xB9,0x16,0x2A,0xFA,0xD7,0x17,0xA3,0xED,0x91,0xC5,0xCB }, // Scott Gruby Quisle Over Upflung
{ 0x65,0x01,0xEC,0xFB,0x1A,0xBA,0xA4,0x0B,0x66,0x21,0x7D,0x83,0xD8,0xEF,0x77,0x13,0xC6,0xC6,0x94,0xF6 }, // Anderson Santos Duskly Jackal Rubrify
{ 0xEB,0xF4,0xB2,0xB3,0x71,0xDF,0xF9,0xCF,0x8D,0x06,0x78,0x73,0x49,0x7F,0xB9,0x2E,0x04,0xA1,0x9D,0x6A }, // Daragh Dunn Passage Rheinic Wir
{ 0x86,0xB2,0x3A,0x70,0xF4,0xCA,0x3E,0x51,0x58,0x82,0xA8,0x94,0x0D,0xD0,0x02,0x0E,0x55,0xAD,0x1A,0x01 }, // Mary Emily McCutcheon Upbotch Over Striped
{ 0xEE,0xEA,0x53,0xA1,0xA8,0xDA,0x9F,0x68,0xE8,0x24,0x32,0x78,0xE0,0x21,0xAD,0x26,0x9E,0x10,0xD2,0x20 }, // Eric D Howell Setter Chob Sutor

{ 0xCE,0xDC,0x61,0xE5,0x5C,0x9A,0x96,0x2C,0x61,0xC9,0x20,0x95,0xF7,0x7B,0x31,0x75,0xDD,0x7B,0x59,0x09 }, // LaQula Walker Becuna Otosis Minded
{ 0x9A,0xB5,0x83,0x79,0xB8,0x73,0xAB,0xB7,0x4F,0xE1,0x66,0x9B,0xB1,0xE0,0x39,0xF2,0xDB,0x28,0x68,0xC7 }, // Jason Knight Becuna Untress Mirror
{ 0x25,0x3A,0xE2,0x9E,0x67,0x97,0x55,0x03,0x8F,0x31,0xFC,0xEA,0xA1,0x29,0x18,0xE3,0x63,0x80,0xE4,0x24 }, // Job Bakama Upbotch Over Plumply
{ 0x45,0x8B,0x12,0x04,0xD8,0xAA,0x60,0x28,0x20,0xBE,0xA5,0x6C,0x15,0xEF,0x20,0x27,0x92,0x0F,0x9C,0xA1 }, // Christopher Cooper Caltrap Jackal Opposed
{ 0x60,0x17,0xE0,0x7A,0xC3,0xF1,0x2D,0x1E,0xD1,0x9C,0x3E,0x9B,0x2A,0x81,0xD5,0x87,0x10,0x4B,0xB5,0xCB }, // jonathan johnson Vexedly Silked Lobelin

{ 0xAD,0xA5,0xC6,0x71,0x24,0x79,0x62,0x19,0x6B,0x49,0x42,0xF3,0x43,0xCF,0xC9,0x19,0x4E,0x94,0x04,0xA5 }, // Yan Zou Caltrap Awny Bleo
{ 0x56,0xBF,0xB4,0x44,0x29,0xF7,0x29,0x4C,0xFC,0xDF,0xD6,0xFB,0x79,0x00,0x25,0x12,0xD8,0xDF,0x60,0x05 }, // Arthur Reilly Bumble Expound Loving
{ 0x2D,0xD5,0x21,0x22,0x5A,0x62,0x67,0x1E,0x4C,0x81,0xC9,0xA4,0x62,0x5F,0xC4,0xC3,0x06,0x74,0x6D,0x4F }, // Robert Stockwood Vexedly Teleuto Pingle
{ 0x50,0x04,0xDF,0x56,0x8F,0xE3,0xB5,0x7E,0xBE,0x69,0xBB,0x25,0xF2,0x4E,0xE8,0xF4,0xEA,0xC6,0x2A,0x80 }, // Greg Hayward Bumble Awny Overlow
{ 0x2F,0x4E,0x1F,0xF2,0x87,0x89,0x6B,0x35,0xF5,0xF9,0x65,0x77,0xBF,0x40,0x60,0xF8,0x21,0x9E,0x78,0xFA }, // Don Fitz-Roy Nourish Awny Topknot

{ 0x3E,0x02,0xD2,0xCB,0xBC,0x93,0x04,0xF1,0x30,0xB9,0xD2,0xA1,0xA9,0x68,0x46,0x31,0x91,0xDC,0x49,0xAE }, // Daryoush Naghibzadeh Brique Otosis Mention
{ 0x1E,0x65,0x19,0x2E,0x82,0x46,0xF2,0x5E,0xA0,0x86,0x54,0x23,0x62,0xC8,0x22,0x3A,0x7D,0x50,0xCB,0x0D }, // Terrell Burks Brique Expound Jours
{ 0x44,0x1E,0x07,0xEA,0xE3,0x8B,0xEA,0x8F,0xD6,0x3F,0x12,0xA8,0x1B,0x7A,0x7F,0x5A,0x21,0x2F,0x9A,0xE3 }, // Preston Lanier Helper Rheinic Rollock
{ 0x43,0x60,0x2E,0x87,0x0A,0x9C,0x96,0xF1,0x0E,0xCF,0xB4,0x1D,0x56,0x22,0x29,0xAB,0x49,0x2A,0xC6,0x17 }, // Michael Watts Rubrify Awny Oracle
{ 0x95,0x97,0xB9,0xDF,0x55,0x19,0x41,0x86,0xD4,0x79,0x19,0x5F,0xE7,0x55,0xEA,0xAE,0x4B,0xDA,0x1D,0x7A }, // Carolyne McCourtie Corn Chob Heteric

{ 0xB8,0x61,0xC6,0x30,0xCB,0x07,0x03,0x16,0xDA,0xD2,0x09,0x3E,0xFF,0xF6,0x2A,0x01,0xEF,0x12,0xA5,0x35 }, // Matvey Kalachev Acorn Chob Turbo
{ 0x5A,0xFA,0x0D,0x7C,0x29,0xF6,0x9E,0xEA,0xE1,0x76,0xDD,0xE8,0xC9,0xB7,0x57,0x3C,0x2B,0x2D,0x0E,0xB1 }, // Timothy White Sunn Misstep Hitcher
{ 0x91,0x29,0x40,0x1B,0x88,0x6E,0x7B,0x42,0xD9,0xFC,0xBB,0xF7,0x7C,0xA0,0x22,0x2A,0xFF,0x6A,0x82,0xDF }, // Andrey Tverdokhleb Acorn Teleuto Streak
{ 0x28,0x7E,0x09,0xC8,0x4F,0x65,0x43,0x95,0x87,0x27,0x3B,0xAE,0x27,0x8D,0x6A,0xDB,0xB3,0x62,0x44,0x74 }, // Felix Belanger Inkroot Awny Mispick
{ 0x23,0x76,0x85,0x9B,0x44,0x4C,0xF9,0x6D,0xA3,0xB1,0x60,0xDC,0xBA,0x6B,0x38,0x32,0x53,0xAC,0x35,0x49 }, // Michael Saelee Adytum Over Over

{ 0x7A,0x7D,0xE1,0xEA,0x09,0x6F,0x62,0x26,0x32,0xEE,0xE3,0x9B,0xF1,0xC2,0x38,0x3E,0xF3,0x41,0x31,0x86 }, // Stephen Ridgway Perplex Over Voiced
{ 0x6C,0x89,0x53,0x68,0x1E,0xE7,0x59,0xEA,0xA0,0x3A,0x93,0x00,0x3F,0x3C,0x01,0xC5,0xAE,0xF4,0xB2,0xFE }, // Kenneth Mcdonald Undye Over Thorax [reissue]
{ 0x48,0x34,0x13,0x12,0x09,0xC4,0xBC,0x87,0xCC,0x1F,0xB8,0xCA,0x5C,0xDE,0x5B,0x65,0xC8,0x04,0x85,0xE3 }, // Kenneth McDonald Churchy Rheinic Outbeam [original]
{ 0xC5,0xB3,0x5A,0x42,0x3A,0x73,0xE0,0x05,0xEB,0x90,0x13,0x10,0x17,0xEB,0xF2,0xC5,0x35,0xF6,0x25,0x0E }, // Steve Grundmeier Perplex Rheinic Tinlike
{ 0x60,0xD3,0x85,0xD8,0xB8,0xC1,0x9B,0x6A,0xC0,0xD6,0x7E,0x01,0x47,0xC3,0x69,0xFD,0x00,0x75,0x18,0xF3 }, // Candace Baptiste Waffly Awny Cryable

{ 0x97,0x4E,0x1B,0x77,0xC7,0xC7,0x91,0x06,0xF5,0xD1,0x7C,0x56,0xB2,0xBE,0x6D,0x64,0xA2,0x35,0x9F,0xC9 }, // Joseph Babiak Waffly Distain Baffy
{ 0x7D,0x84,0x09,0xCF,0xDE,0x78,0xA7,0xFD,0xC4,0x11,0x9B,0xC6,0x52,0xFD,0x2D,0xEB,0xFE,0xD5,0xC6,0x17 }, // Sharon May Carga Distain Lasset
{ 0xF8,0x41,0x9A,0x39,0x0A,0x94,0xFF,0x08,0xBD,0xEC,0xE3,0xC2,0x8E,0xEF,0xA2,0x3E,0xC0,0xC8,0x4A,0xC9 }, // Elizabeth Wells Pinic Silked Rajah
{ 0x6A,0x0F,0xEF,0x67,0x30,0x1A,0xA4,0x68,0x57,0x47,0xAB,0xBD,0xFC,0x5D,0x9A,0x0B,0x2C,0x5A,0x74,0x53 }, // Michael Vargas Laroid Rheinic Turret
{ 0x80,0xC1,0xC6,0xA3,0x14,0xAF,0x37,0x3D,0x29,0x21,0xF0,0xC2,0xA2,0x3F,0x57,0x79,0x57,0x7A,0xD2,0x37 }, // Christopher Hanada Inkroot Rheinic Pay

{ 0x4D,0x6D,0xBF,0xC4,0xC9,0x53,0x7F,0x12,0x58,0x42,0xA5,0xB6,0xCF,0x3E,0xBB,0x50,0x46,0x6B,0x7F,0x1A }, // Jane Janssen Hogbush Rheinic Loukoum
{ 0xAE,0x45,0x5B,0x13,0xB7,0x3D,0xDB,0x40,0x0D,0x9D,0x64,0x90,0x5F,0xAC,0xE0,0x12,0x33,0xBC,0xB4,0xB8 }, // andre gemme Exitus Teleuto Palely
{ 0x61,0x77,0x6A,0x4B,0x45,0x06,0x85,0x2A,0x97,0x66,0x35,0x3A,0xAB,0x26,0xF3,0xB7,0xD7,0xA8,0xA5,0x69 }, // Christine Zanutto Whidder Air Skulk
{ 0x47,0x7B,0x3E,0xF3,0x49,0x3A,0x61,0xDD,0xB5,0xDB,0xC9,0x8E,0x48,0x72,0x21,0xF4,0x88,0x4A,0x76,0xF1 }, // Eric Ransom Tunket Distain Sunfast
{ 0xE0,0x90,0x4B,0x0D,0x75,0x26,0xBF,0x88,0xBB,0xBC,0xD2,0xC7,0x5A,0x17,0x73,0x81,0x9C,0xBC,0xAB,0x98 }, // Carmen McKay Aby Silked Dispark

{ 0x98,0xD2,0x99,0x33,0x19,0x18,0x72,0x82,0x1C,0xE0,0xCD,0xA9,0x0B,0x86,0x54,0xC3,0x60,0xD1,0xA4,0x8F }, // Mirko Messar Laroid Expound Veuve
{ 0xE8,0xAE,0xE3,0x58,0xE2,0x36,0x59,0x90,0x76,0xB5,0x11,0xD3,0x6F,0x61,0xDF,0x99,0xC7,0x08,0x53,0x5E }, // Daniel Tatar Swarmer Chob Hogbush
{ 0x95,0xE2,0xB5,0x74,0x72,0x67,0x3F,0x72,0xF8,0x1A,0x90,0x6F,0x82,0x55,0x9A,0x31,0x94,0x1F,0xE7,0x05 }, // Jeffrey Van der Sluis Whidder Rheinic Crambly
{ 0x51,0xE4,0x5D,0x07,0x9B,0x3B,0x3B,0x05,0x0F,0xE9,0x1E,0x40,0x39,0x6C,0x08,0x24,0xE4,0x59,0xFD,0x22 }, // Scott Bagger Slugger Teleuto Unclog
{ 0x59,0x35,0x17,0x79,0x72,0xFB,0xD5,0x34,0xE2,0x5E,0x40,0x79,0x43,0xCA,0x2C,0x3C,0xEC,0xD2,0xE1,0xB5 }, // MASAHIKO IMAJO Swarmer Awny Works

{ 0xF3,0xD9,0x04,0x7E,0xC1,0xF4,0x60,0x79,0xA2,0x2E,0x9C,0x02,0x4A,0xC6,0x02,0x5A,0x6D,0x43,0x75,0xCB }, // Joseph Pagano Injunct Wog Hacksaw
{ 0xB6,0x83,0x30,0x67,0xD0,0x6E,0x19,0x04,0x61,0x1B,0x4D,0xEA,0x4F,0x3C,0x1E,0x4B,0xFB,0x97,0x2F,0x57 }, // Stefan Kuhle Farce Teleuto Squoze
{ 0x95,0x00,0x09,0xFD,0x54,0x66,0x12,0xC9,0x5D,0xF4,0x67,0xE2,0x05,0xB0,0x73,0x57,0xC6,0x46,0xBA,0xA5 }, // stuart poltrock Peacher Unbored Living
{ 0x42,0xB9,0x61,0x61,0xFE,0x5A,0x83,0x93,0x41,0x62,0x5E,0x94,0xA2,0x45,0x3A,0x4D,0x3F,0x51,0x57,0x07 }, // Jason Weinberger Dogfish Chob Privy
{ 0x3E,0xCD,0xB5,0xFE,0x6F,0xF2,0xA9,0xF3,0xFF,0xDF,0x08,0x68,0x11,0xBF,0x19,0xFC,0x43,0x53,0x90,0x09 }, // David Bennett Dogfish Over Valley

{ 0x28,0xA1,0x61,0x60,0xD3,0x93,0x04,0x34,0x08,0xAA,0xD5,0x16,0x8A,0x6D,0x04,0x2D,0x45,0x3C,0xAA,0x66 }, // Link Dupont Dogfish Distain Remail
{ 0x19,0xB0,0x3F,0x81,0xD1,0xD9,0xEF,0xD7,0xDE,0x15,0xD9,0xB9,0xB4,0x6F,0x8C,0xD4,0x87,0xD4,0x39,0xC9 }, // Charlotte Laidler Plectre Awny Cramble
{ 0x68,0x9C,0xE4,0x3E,0x3A,0x04,0xB7,0x02,0x59,0xD7,0x61,0x4E,0x91,0x4F,0xD6,0xD8,0x95,0x91,0xC8,0x1B }, // Kaung-Fen Chau Unhired Distain Widener
{ 0x14,0x3A,0x45,0x9F,0x7A,0x9A,0x1D,0x23,0x1D,0x86,0xD0,0x93,0xCA,0x07,0x85,0x1D,0x30,0xE3,0x85,0x71 }, // David Rice Tucking Air Helldog
{ 0xA6,0x5F,0x3B,0x02,0x17,0xC0,0x98,0x50,0x39,0x8D,0xEA,0x3E,0x9F,0x38,0x94,0x69,0xD2,0x61,0xB5,0xAC }, // Thomas Cesarini Tucking Distain Shrew

{ 0x31,0xE2,0xDD,0x57,0xF5,0x5F,0xB7,0x1B,0x2A,0xB7,0xB3,0xC2,0xD5,0x93,0xFD,0xF8,0x39,0x48,0x3C,0x52 }, // Colleen Coble Talky Silked Skulk
{ 0x3C,0xBD,0xAD,0x5B,0xE6,0x2C,0x53,0x65,0xBD,0xA7,0x5F,0xFF,0xE8,0x51,0xDA,0x1D,0x5C,0x44,0x9D,0x31 }, // Aaron Wainscoat Unfact Rheinic Berate
{ 0xC8,0xDF,0x6D,0x69,0xE0,0x80,0x73,0xC9,0x65,0xFC,0xD9,0x12,0x26,0x5A,0xD9,0xD7,0xC5,0x27,0x50,0x61 }, // fran harris Parfait Chob Axmaker
{ 0x69,0x20,0xC5,0x98,0xA2,0x17,0x77,0x95,0x71,0xAB,0xFC,0x16,0xC6,0x17,0x77,0x65,0xD6,0x25,0x6D,0x4C }, // Lynda McKenzie Tuftlet Air Bedirty
{ 0xF8,0xC8,0x1C,0x79,0x7E,0x06,0x01,0x70,0x08,0x60,0xBD,0x01,0xC5,0x91,0xDC,0x0B,0x80,0xD1,0xDA,0x71 }, // Florence McLean Slugger Distain Photoma

{ 0x83,0xE2,0x1C,0xF3,0x01,0xFC,0xB8,0x4B,0xA3,0x31,0x64,0x8B,0x16,0xB3,0x41,0x35,0xBD,0x84,0xD1,0x21 }, // Michael Petrucci Youthen Chob Unsolid
{ 0xA7,0x15,0xE0,0x4D,0xD9,0x61,0xA7,0xC8,0x19,0x48,0xC0,0x3B,0x75,0x9C,0xDA,0x6F,0x41,0xF1,0x9A,0xB1 }, // Amanda Boal Decant Distain Locking
{ 0x0C,0x22,0x6D,0x18,0x26,0xB8,0xA2,0x75,0x61,0x92,0x94,0x85,0x97,0x90,0x94,0x20,0xC4,0xBD,0xDC,0xC2 }, // Quang Tran Tuftlet Silked Imino
{ 0x6F,0x2C,0x04,0xCB,0x67,0x91,0x90,0xB1,0x48,0x8C,0x7E,0x5F,0x44,0x8C,0xA5,0x46,0x25,0x44,0xF6,0x0A }, // Mitchell Winston Sumac Over Knagged
{ 0x99,0xAA,0x76,0xED,0xB7,0xB4,0x6B,0x39,0xE9,0x38,0x2E,0xF0,0x21,0x7B,0x68,0x12,0x4D,0x1C,0x37,0x0B }, // Gary Pierson Listing Unbored Nates

// ^^^ 140

{ 0x9B,0xC8,0x65,0xFF,0x34,0x44,0x85,0xDB,0x7D,0xDD,0x58,0x72,0x00,0x5E,0x58,0x6C,0x74,0x51,0xC3,0xEA }, // Anthony Marinelli Moneric Unbored Torse
{ 0xC5,0x8E,0x72,0x27,0x62,0x09,0xF3,0x95,0xA5,0x0E,0xBE,0x81,0xA9,0x39,0x78,0xB6,0x6F,0x4E,0x88,0x9F }, // Roland Jefferson Moneric Over Morris
{ 0xF3,0xC8,0x93,0x98,0xE7,0x38,0x5B,0xFA,0x28,0x4C,0x57,0x7F,0x2E,0x99,0x09,0x80,0xEB,0x48,0x4F,0xB6 }, // Mark Short Blister Joust Arrah


//		
//	
// ^^^^ new blacklist (invalid list) entries go here.  Update the count at the start of the array.
//
//
//
//
//
};
	
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

- (IBAction)XnewDocument:(id)sender
{
	@try
	{
		NSError *localError = nil;
		// bring up a standalone Save As... panel (Create Site)
		NSSavePanel *savePanel = [NSSavePanel savePanel];
		
		[savePanel setTitle:NSLocalizedString(@"New Site",@"Save Panel Title")];
		[savePanel setPrompt:NSLocalizedString(@"Create",@"Create Button")];
		[savePanel setCanSelectHiddenExtension:YES];
		[savePanel setRequiredFileType:kKTDocumentExtension];
		[savePanel setCanCreateDirectories:YES];
		
		int saveResult = [savePanel runModalForDirectory:nil file:nil];
		
		if ( NSFileHandlingPanelCancelButton == saveResult )
		{
			return; // user cancelled, do nothing
		}
		
		NSURL *saveURL = [savePanel URL];
		
		// if !cancel and valid fileName
		//  put up a progress bar
		NSImage *newDocumentImage = [NSImage imageNamed:@"document.icns"];
		NSString *progressMessage = NSLocalizedString(@"Creating Site...",@"Creating Site...");
		[self showGenericProgressPanelWithMessage:progressMessage image:newDocumentImage];
		
		// is this path a currently open document? if yes, close it!
		if ( nil != [[NSDocumentController sharedDocumentController] documentForURL:saveURL] )
		{
			KTDocument *document = [[NSDocumentController sharedDocumentController] documentForURL:saveURL];
			[document canCloseDocumentWithDelegate:nil shouldCloseSelector:NULL contextInfo:nil];
			[document close];
		}	
		
		// do we already have a file there? remove it
		NSFileManager *fm = [NSFileManager defaultManager];
		if ( [fm fileExistsAtPath:[saveURL path]] )
		{
			// is saveURL path writeable?
			if ( ![fm isWritableFileAtPath:[saveURL path]] )
			{
				[self hideGenericProgressPanel];
				
				//  put up an error that the previous file is not writable
				NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"Unable to create new document.",@"Alert: Unable to create new document.")]
							  forKey:NSLocalizedDescriptionKey]; // message text
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"The path %@ is not writeable.",@"Alert: The path %@ is not writeable."), [saveURL path]]
							  forKey:NSLocalizedFailureReasonErrorKey]; // informative text
				
				NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:errorInfo];
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				(void)[errorAlert runModal];
				
				return;
			}
			
			if ( ![fm removeFileAtPath:[saveURL path] handler:nil] )
			{
				[self hideGenericProgressPanel];
				
				//  put up an error that the previous file could not be overwritten
				NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"Unable to create new document.",@"Alert: Unable to create new document.")]
							  forKey:NSLocalizedDescriptionKey]; // message text
				[errorInfo setObject:[NSString stringWithFormat:
					NSLocalizedString(@"Could not remove pre-existing file at path %@.",@"Alert: Could not remove pre-existing file at path %@."), [saveURL path]]
							  forKey:NSLocalizedFailureReasonErrorKey]; // informative text
				
				NSError *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:errorInfo];
				NSAlert *errorAlert = [NSAlert alertWithError:error];
				(void)[errorAlert runModal];
				
				return;
			}
		}
		
		//  tell document controller to open new, untitled document w/o displaying
		KTDocument *newDocument = [[NSDocumentController sharedDocumentController] openUntitledDocumentAndDisplay:NO error:&localError];
		
		if ( nil == newDocument )
		{
			[self hideGenericProgressPanel];
			if ( nil != localError )
			{
				[NSApp presentError:localError];
			}
			return;
		}
		else
		{
			if ([savePanel isExtensionHidden])
			{
				[fm performSelector:@selector(setExtensionHiddenAtPath:) withObject:[saveURL path] afterDelay:1.0];
			}
		}
		
		//  set the site title
//		NSString *siteNameFormatString = NSLocalizedString(@"%@\\U2019s Site", "Default Site Title");
//		NSString *siteName = [NSString stringWithFormat:siteNameFormatString, NSFullUserName()];
		NSString *siteName = [fm displayNameAtPath:[[saveURL path] stringByDeletingPathExtension]];
		[[[newDocument root] master] setValue:siteName forKey:@"siteTitleHTML"];
        
        
        // set the favicon
        KTPage *root = [newDocument root];
		NSString *faviconPath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
		KTMediaContainer *faviconMedia = [[root mediaManager] mediaContainerWithPath:faviconPath];
		[[root valueForKey:@"master"] setValue:[faviconMedia identifier] forKey:@"faviconMediaIdentifier"];
		
		
		//  tell document context to save: at valid fileName
		BOOL didSave = [newDocument writeToURL:saveURL 
										ofType:kKTDocumentExtension 
							  forSaveOperation:NSSaveAsOperation
						   originalContentsURL:nil 
										 error:&localError];
		if ( !didSave )
		{
			[self hideGenericProgressPanel];
			if ( nil != localError )
			{
				[NSApp presentError:localError];
			}
			return;
		}
		
		//  close document
		[newDocument close];
		
        // open the new document at the end of the runloop
        [self performSelector:@selector(openDocumentWithContentsOfURL:) withObject:saveURL afterDelay:0.0];
	}
	@finally		// don't leave without closing this!
	{
		[self hideGenericProgressPanel];
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
	NSString *key = [NSString stringWithFormat:@"CoreImageAccelerated %@", [[KTUtilities MACAddress] base64Encoding]];
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
