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

#import "BDAlias.h"
#import "Debug.h"
#import "KSAbstractBugReporter.h"
#import "KSEmailAddressComboBox.h"
#import "KSNetworkNotifier.h"
#import "KSPluginInstallerController.h"
#import "KSRegistrationController.h"
#import "KSSilencingConfirmSheet.h"
#import "KSUtilities.h"
#import "KT.h"
#import "KTAcknowledgmentsController.h"
#import "KTAppDelegate.h"
#import "KTApplication.h"
#import "KTDataSource.h"
#import "KTDesign.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTDocumentController.h"
#import "KTElementPlugin.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "KTIndexPlugin.h"
#import "KTInfoWindowController.h"
#import "KTMediaManager.h"
#import "KTPage.h"
#import "KTPlaceholderController.h"
#import "KTPrefsController.h"
#import "KTPrefsController.h"
#import "KTReleaseNotesController.h"
#import "KTToolbars.h"
#import "KTTranscriptController.h"
#import "KTUtilities.h"
#import "KTWebView.h"

#import "NSApplication+Karelia.h"
#import "NSArray+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSError+Karelia.h"
#import "NSException+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSString-Utilities.h"
#import "NSToolbar+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import <AmazonSupport/AmazonSupport.h>
#import <Connection/Connection.h>
#import <ExceptionHandling/NSExceptionHandler.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenSaver/ScreenSaver.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <iMediaBrowser/iMediaBrowser.h>
#import <Sparkle/Sparkle.h>

// Triggers to localize for the Comment/trackback stuff

// NSLocalizedString(@"Comment", "String_On_Page_Template -- text for link on a blog posting")
// NSLocalizedString(@"Other Posts About This", "String_On_Page_Template - description of trackbacks")
// NSLocalizedString(@"Trackback", "String_On_Page_Template - text for trackback link")
// NSLocalizedString(@"To enable comments you need to enter your Haloscan ID into the Site Inspector", "Prompt in webview")




// Comment this out if we are not building an expiring demo
#define EXPIRY_TIMESTAMP @"2008-08-05 11:59:59 -0800"

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

- (KTDocument *)openDocumentWithContentsOfURL:(NSURL *)aURL;

@end


@interface NSSQLChannel : NSObject // Apple Private
+ (void)setDebugDefault:(BOOL)flag;
@end


@implementation KTAppDelegate


- (NSDate *)referenceTimestamp
{
	return [NSDate dateWithString:@"2006-01-01 00:00:00 -0800"]; // See: Sandvox KTAppDelegate, RegGenerator RegGenerator.h - make sure this corresponds to other apps
}

- (NSString *)licenseFileName
{
	return [[NSString stringWithFormat:@".%@.%@", @"WebKit", @"UTF-16"] retain];

}


- (NSString *) additionalProfileStringForFeedback;
{
	NSMutableString *result = [NSMutableString string];
	//  additionalPlugins
	NSArray *extensions = [NSArray arrayWithObjects:kKTElementExtension, kKTIndexExtension, nil];
	NSString *plugins = [KSPlugin generateReportOfPluginsWithFileExtensions:extensions thirdPartyPluginsOnly:YES];
	if (![plugins isEqualToString:@""])
	{
		[result appendFormat:@"\nAdditional Plugins:\n%@\n", plugins];
	}

	// Call the following method on KTDesign to get the right plugin path
	NSString *designs = [KTDesign generateReportOfPluginsWithFileExtension:kKTDesignExtension thirdPartyPluginsOnly:YES];
	if (![designs isEqualToString:@""])
	{
		[result appendFormat:@"\nAdditional Designs:\n%@\n", designs];
	}
		
	NSString *urlString = [[[[[self currentDocument] documentInfo] hostProperties] siteURL] absoluteString];
	if (urlString && ![urlString isEqualToString:@""] && ![urlString isEqualToString:@"http://unpublished.karelia.com/"])
	{
		[result appendFormat:@"\nURL:\n%@\n", urlString];
	}
	return result;
}


- (NSArray *) additionalPluginDictionaryForInstallerController:(KSPluginInstallerController *)controller
{
// TODO: load a dictionary from the 
	NSArray *designs = nil; // [nil objectForKey:@"Designs"];
	NSImage *designImage = [NSImage imageNamed:@"designPlaceholder"];
	float scaleFactor = [controller scaleFactor];
	
	NSMutableArray *list = [NSMutableArray array];
	
	//  install (bool), icon (image), title, InfoHTML,
	NSEnumerator *theEnum = [designs objectEnumerator];
	NSDictionary *theDict;

	while ((theDict = [theEnum nextObject]) != nil)
	{
		NSMutableDictionary *adjustedDict = [controller adjustedDictionaryFromDictionary:theDict
																			 placeholder:designImage
																					size:NSMakeSize(100.0 * scaleFactor,65.0 * scaleFactor)
																				  radius:scaleFactor * 6.0];
		if (adjustedDict)
		{
			[list addObject:adjustedDict];
		}
	}
	return list;
}


- (int) the16BitPrime
{
	return 65521;
}
- (int) theBigPrime
{
	return 5003;
}

- (int) the8BitPrime
{
	return 251;
}



- (void) checkRegistrationString:(NSString *)aString	// if not specified, looks in hidden path
{
	BOOL wasNil = (nil == gRegistrationString);

	[super checkRegistrationString:aString];
	
	if (wasNil && gRegistrationString != nil)
	{
		// we are now registered, let's set all open docs as stale
		NSEnumerator *e = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
		KTDocument *cur;
		
		while ( (cur = [e nextObject]) )
		{
			if ([cur isKindOfClass:[KTDocument class]])	// make sure it's a KSDocument
			{
				////LOG((@"~~~~~~~~~ %@ calls markStale:kStaleFamily on root because app is newly registered", NSStringFromSelector(_cmd)));
				///	TODO:	Make this happen again.
				//[[cur root] markStale:kStaleFamily];
			}
		}
	}
}


/*!	Needs to be done on initialization, and after resetStandardUserDefaults is called
*/
+ (void) registerDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

// TODO: Remove this later (v2.0) once the old contactHomeBase hasn't been around for a while
	id oldContactHomeBase = [defaults  objectForKey:@"contactHomeBase"];
	if (oldContactHomeBase)
	{
		[defaults setObject:oldContactHomeBase forKey:SUEnableAutomaticChecksKey];	// move old contactHomeBase key to our new Sparkle one.
		[defaults removeObjectForKey:@"contactHomeBase"];
	}
	
	// If we have already tested this CPU, just get value from the defaults.

    NSMutableDictionary *defaultsBase = [NSMutableDictionary dictionaryWithObjectsAndKeys:
		
								 // General defaults ... app behavior. NOTE: THESE ARE CAPITALIZED
#ifdef DEBUG
		[NSNumber numberWithBool:YES],			@"IncludeDebugMenu",
#else
		[NSNumber numberWithBool:NO],			@"IncludeDebugMenu",
#endif
										 
// For now, we want 
		@"all",									@"metaRobots",
#ifdef APPLE_DESIGN_AWARDS_KEY
		[NSNumber numberWithBool:YES],			@"LiveDataFeeds",		// I want ADA entries to have this on as default
#else
		[NSNumber numberWithBool:NO],			@"LiveDataFeeds",
#endif
		
		[NSNumber numberWithBool:NO],			@"KTLogAllContextChanges",

#ifdef EXPIRY_TIMESTAMP
		[NSNumber numberWithBool:YES],			@"ShowScoutMessages",	// Alerts when there is a "Scout message" from submitting a bug/error
		@"Testing Reports",						@"AssignSubmission",	// Virtual user for testing reports, DON'T go to normal support person when testing
										 
#else
		[NSNumber numberWithBool:NO],			@"ShowScoutMessages",
#endif
		[NSNumber numberWithBool:YES],			@"KTLogToConsole",
		
		[NSNumber numberWithBool:NO],			@"urls in background",
		
		[NSNumber numberWithBool:YES],			@"FirstRun",
		
		[NSNumber numberWithUnsignedInt:5],		@"KeepAtMostNBackups",
		
		[NSNumber numberWithBool:YES],			@"SendCrashReports",
		
		[NSNumber numberWithBool:YES],			@"EscapeNBSP",		// no longer used apparently
		[NSNumber numberWithBool:YES],			@"GetURLsFromSafari",
		[NSNumber numberWithBool:YES],			@"AutoOpenLastOpenedOnLaunch",
		[NSArray array],						@"KSOpenDocuments",
		[NSNumber numberWithBool:YES],			@"OpenUntitledFileWhenIconClicked",
		[NSNumber numberWithBool:YES],			@"ContinuousSpellChecking",
						
		[NSNumber numberWithBool:NO],			@"DisplayInfo",
		
		//[NSNumber numberWithBool:YES],			@"AutosaveDocuments",
		//[NSNumber numberWithBool:YES],			@"BackupWhenSaving",
		//[NSNumber numberWithDouble:600.0],		@"BackupTimeInterval",

		[NSNumber numberWithUnsignedInt:2],			@"BackupOnOpening", // default is to snapshot
	
		
		[NSNumber numberWithBool:NO],			@"AllowPasswordToBeLogged", // for Connection class
		
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
					@"karelsofwa-20",	@"AmazonAssociatesToken",
		
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
		[NSNumber numberWithBool:YES],			@"KTHaloscanTrackbacks",	// KTHaloscanID is nil initially
		
		[NSNumber numberWithBool:NO],			@"ShowSearchPaths",			// NSLog where items are searched for
		
		[NSNumber numberWithInt:kReportAsk],	@"ReportErrors",
		
		@"sandvox.Aqua",		@"designBundleIdentifier",
		
		[NSMutableArray array],					@"keywords",
		[NSNumber numberWithFloat:1.0],			@"textSizeMultiplier",
		[NSDictionary
			dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:0], @"localHosting",
			[NSNumber numberWithInt:0], @"localSharedMatrix",	// 0 = ~ , 1 = computer
			nil],								@"defaultHostProperties",
		
		[NSNumber numberWithShort:0],		@"truncateCharacters",
		[NSNumber numberWithShort:KTCopyMediaAll], @"copyMediaOriginals",
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
		
		
		
		
		/// Whether or not to include original images (instead of images as found on the pages) in image RSS feeds.
		[NSNumber numberWithBool:NO],	@"RSSFeedEnclosuresAreOriginalImages",
				
		nil];
	
	OBASSERT(defaultsBase);

	// Load in the syntax coloring defaults
	NSDictionary *syntaxColorDefaults = [NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"SyntaxColorDefaults" ofType: @"plist"]];
	[defaultsBase addEntriesFromDictionary:syntaxColorDefaults];
	
	NSString *email = [KSEmailAddressComboBox primaryEmailAddress];
	if (email)
	{
		[defaultsBase setObject:email forKey:@"KSEmailAddress"];
	}
			
    [defaults registerDefaults:defaultsBase];
	
	// debugging domains -- we have to set default values to get them to show up in the table.
	NSArray *domains = [NSArray arrayWithObjects:
		ControllerDomain, TransportDomain, StateMachineDomain, ParsingDomain, ProtocolDomain, ConnectionDomain, /* ThreadingDomain, */
		/* StreamDomain, */ InputStreamDomain, OutputStreamDomain, /* SSLDomain, */ QueueDomain, KTMediaLogDomain, nil];
	
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

		// Set these for the next run -- it's probably too late now; the assertion thing may have already been set
#ifdef DEBUG
	[defaults setBool:YES forKey:@"OBShouldThrowOnAssertFailureEnabled"];
	NSLog(@"Aborting on Assertion failures; running build %@", [NSApplication buildVersion]);


#else
	[defaults removeObjectForKey:@"OBShouldThrowOnAssertFailureEnabled"];
	[defaults removeObjectForKey:@"OBShouldAbortOnAssertFailureEnabled"];
#endif
	
	// For beta testers, throw an exception.
#ifdef OMNI_FORCE_ASSERTIONS
	[defaults setBool:YES forKey:@"OBShouldThrowOnAssertFailureEnabled"];
	NSLog(@"Throwing on Assertion failures; running build %@", [NSApplication buildVersion]);

#else
	[defaults removeObjectForKey:@"OBShouldThrowOnAssertFailureEnabled"];
	[defaults removeObjectForKey:@"OBShouldAbortOnAssertFailureEnabled"];
#endif
	
// TODO: remove this for release.  I just don't want to have this old key around in the user defaults.
	// However, later on, somebody might want to actually override things.
#ifndef DEBUG
	[defaults removeObjectForKey:SUFeedURLKey];	// NOT storing a feed URL now in defaults, generally
#endif
	
	// If we don't have a feed type in user defaults, get it explicitly from the Info.plist.
	// This allows us to start out with a beta/release type, and keep that type even after we have
	// made a release and somebody was originally getting betas.
	
	NSString *feedType = [defaults objectForKey:@"KSFeedType"];
	if (nil == feedType || [feedType isEqualToString:@""])		// 'beta' or 'release' or '' (empty string) for none
	{
		NSString *feedType = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"KSFeedType"];	// default feed type
		[defaults setObject:feedType forKey:@"KSFeedType"];
	}
	
	[defaults synchronize];
	OBSetupFromDefaults();
}	

// TODO: make sure that everything used with wrappedInheritedValueForKey gets mentioned here!
+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

#if MAC_OS_X_VERSION_MIN_REQUIRED <= MAC_OS_X_VERSION_10_4
	// Already defined in Leopard
	gMainThread = [NSThread currentThread];
#endif
	
	[self registerDefaults];
	
	[pool release];
}

- (id)init
{
    self = [super init];
    if ( self )
    {

		// fire up a components manager and discover our components

		// force webkit to load so we can log the version early
		(void) [[WebPreferences standardPreferences] setAutosaves:YES];

        // fire up a designs manager and discover our designs
		myCascadePoint = NSMakePoint(100, 100);

        applicationIsLaunching = YES;
		myKTDidAwake = NO;
		myAppIsTerminating = NO;
	}
    return self;
}


- (void)dealloc
{
	[myDocumentController release]; myDocumentController = nil;

#ifdef OBSERVE_UNDO
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif

	[super dealloc];
}

#define SHA1_DIGEST_LENGTH	20

// Override of KSLicensedAppDelegate
- (BOOL) checkForBlacklist:(NSData *)aHash
{
	// BLACKLIST -- subtle non-functionality, for cracked codes.  
#define BLACKLIST_COUNT 1
	unsigned char blacklistDigests[BLACKLIST_COUNT][SHA1_DIGEST_LENGTH] = {
		{ 0xFC,0x8C,0xF1,0xAD,0xDF,0x82,0x45,0x72,0x21,0xFA,0xE7,0x15,0x7B,0x11,0x4A,0x22,0x23,0x7F,0x06,0x20 }, // Nop Chopper Hurly Anomaly Penalty	
	};
	return [self licenseHash:[aHash bytes] foundInList:blacklistDigests ofSize:BLACKLIST_COUNT];
	
}

// Override of KSLicensedAppDelegate
- (BOOL) checkForInvalidLicense:(NSData *)aHash
{
#include "SandvoxInvalidLicenses.h"
	
	return [self licenseHash:[aHash bytes] foundInList:invalidListDigests ofSize:INVALID_LIST_COUNT];
	
}



- (void)awakeFromNib
{
	if ( !myKTDidAwake )
	{
		myKTDidAwake = YES;	// turn this on now so we can load a nib from here
		
		
		// tweak any menus that need tweaking
		[self setCutMenuItemTitle:KTCutMenuItemTitle];
		[self setCopyMenuItemTitle:KTCopyMenuItemTitle];
		[self setDeletePagesMenuItemTitle:KTDeletePageMenuItemTitle];
				
		//NSImage *globe = [NSImage imageNamed:@"globe"];
		//NSImage *trans = [NSImage imageNamed:@"trans16"];
		
		//[oValidateSourceViewMenuItem setImage:globe];
		//[oBuyRegisterSandvoxMenuItem setImage:globe];
		//[oSetupHostMenuItem setImage:globe];
		//[oExportSiteMenuItem setImage:trans];
		//[oExportSiteAgainMenuItem setImage:trans];
		//[oPublishChangesMenuItem setImage:globe];
		//[oPublishEntireSiteMenuItem setImage:globe];
		//[oProductPageMenuItem setImage:globe];
		//[oVideoIntroductionMenuItem setImage:globe];
		//[oInstallPluginsMenuItem setImage:globe];
		//[oCheckForUpdatesMenuItem setImage:globe];

		//[oViewPublishedSiteMenuItem setImage:globe];
		
		// TODO: if we load from the net -- ???? -- then set this on
		// [oReleaseNotesMenuItem setImage:globe];
		//[oAcknowledgementsMenuItem setImage:trans];
		//[oSendFeedbackMenuItem setImage:globe];
		//[oJoinListMenuItem setImage:globe];
	}
	[super awakeFromNib];
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	OBPRECONDITION(menuItem);
	OFF((@"KTAppDelegate validateMenuItem:%@ %@", [menuItem title], NSStringFromSelector([menuItem action])));

	SEL action = [menuItem action];
	
	if (action == @selector(newDocument:))
	{
		return (!gLicenseViolation);
	}
	else if (action == @selector(editRawHTMLInSelectedBlock:))
	{
		return [[self currentDocument] validateMenuItem:menuItem];
	}
	else if (action == @selector(showPluginWindow:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(showReleaseNotes:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(openHigh:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(openLow:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(showEmailListWindow:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(checkForUpdates:))
	{
		return [KSNetworkNotifier isNetworkAvailable] && [[self sparkleUpdater] validateMenuItem:menuItem];
	}
	else if (action == @selector(showRegistrationWindow:))	// hide the globe, and make available, if network is down
	{
		//if ([KSNetworkNotifier isNetworkAvailable])
		//{
		//	NSImage *globe = [NSImage imageNamed:@"globe"];
		//	[menuItem setImage:globe];
		//}
		//else
		//{
		//	[menuItem setImage:nil];
		//}
		return YES;	// OK regardless
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


#pragma mark -svn 
#pragma mark Help

- (NSString *)appHelpURLFragment;		// used to construct the help URLs for this app
{
	return @"z";		// this uses "z" in the URL for help strings
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
			[[KSRegistrationController sharedController] showWindow:nil];
		}
		else
		{
			[[KTPlaceholderController sharedController] showWindow:nil];
		}
	}
	else	// we have a document; close this window
	{
		[[[KTPlaceholderController sharedControllerWithoutLoading] window] orderOut:nil];
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


- (IBAction)loggingConfiguration:(id)sender
{
	[KTLogger configure:self];
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
		
		

		NSString *sysVersion = [NSApplication systemVersion];
//TODO: use Sparkle version check
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
									NSLocalizedString(@"You will need to update to Mac OS X 10.4.11 (using the Software Update menu), or install 10.5 \\U201CLeopard\\U201D for this new version of Sandvox to function.", @""), 
									NSLocalizedString(@"Quit", @"Quit button"),
									nil,
									nil
									);
			[NSApp terminate:nil];
		}
		
#ifdef EXPIRY_TIMESTAMP
		[self performSelector:@selector(warnOrQuitIfExpiring) withObject:nil afterDelay:2.0];
#endif
        
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


		// load plugins
        [self updateGenericProgressPanelWithMessage:NSLocalizedString(@"Loading Plug-ins...",
                                                                      "Message while loading plugins.")];
		// build menus
		[KTElementPlugin addPlugins:[KTElementPlugin pagePlugins]
							 toMenu:oAddPageMenu
							 target:nil
							 action:@selector(addPage:)
						  pullsDown:NO
						  showIcons:YES smallIcons:NO smallText:NO];
		[KTElementPlugin addPlugins:[KTElementPlugin pageletPlugins]
							 toMenu:oAddPageletMenu
							 target:nil
							 action:@selector(addPagelet:)
						  pullsDown:NO
						  showIcons:YES smallIcons:NO smallText:NO];
		
		[KTIndexPlugin addPresetPluginsToMenu:oAddCollectionMenu
									   target:nil
									   action:@selector(addCollection:)
									pullsDown:NO
									showIcons:YES smallIcons:NO smallText:NO];
		
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
		
		BOOL firstRun = [defaults boolForKey:@"FirstRun"];
        if ( firstRun )
        {
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
            
            NSArray *lastOpenedPaths = [defaults arrayForKey:@"KSOpenDocuments"];
            
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
						LOG((@"Can't find '%@'", [lastKnownPath stringByAbbreviatingWithTildeInPath]));
					}
					
                    // is it in the Trash? ([[NSWorkspace sharedWorkspace] userTrashDirectory])
					else if ( NSNotFound != [path rangeOfString:@".Trash"].location )
                    {
                        // path contains localized .Trash, let's skip it
                        [filesInTrash addObject:alias];
						LOG((@"Not opening '%@'; it is in the trash", [path stringByAbbreviatingWithTildeInPath]));
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
						[oGenericProgressImageView display];
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
	
	[super applicationDidFinishLaunching:aNotification];
	
    applicationIsLaunching = NO; // we're done
}

#ifdef EXPIRY_TIMESTAMP

- (void) alertAndQuit
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
- (void) warnOrQuitIfExpiring
{
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
								@"This version of Sandvox is no longer functional. Sandvox will now check for updates; please install the newest version if available.", 
								@"Check for Updates",
								nil,
								nil
								);
		
		// OLD WAY, MAY NOT BE SUPPORTED IN 1.5 ... [[self sparkleUpdater] checkForUpdatesInBackground];	// check Sparkle before alerting
		[[SUUpdater sharedUpdater] checkForUpdatesWithDriver:[[[SUScheduledUpdateDriver alloc] init] autorelease]];
		
		
		// This will allow sparkle time to do its thing.  Then, show the error soon, after user has had a chance to reload.
		[self performSelector:@selector(alertAndQuit) withObject:nil afterDelay:300.0];	// give user enough time to download and install
	}
	
	// WARN OF EXPIRING BETA VERSION -- but not if it's apple design awards or development build.
#ifndef DEBUG
#ifndef APPLE_DESIGN_AWARDS_KEY
	[self warnExpiring:nil];
#endif
#endif
}
#endif

- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;
{
	BOOL result = YES;
	
	if ([parserClassname isEqualToString:@"iMBGarageBandParser"]) result = NO;		// can't process garage band files
	
	LOG((@"iMediaBrowser: willUseMediaParser:%@ forMediaType:%@ -> %d", parserClassname, media, result));
	return result;
}

- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willLoadBrowser:(NSString *)browserClassname;
{
	// TODO: we can take this out after the imedia update
	BOOL result = (	[browserClassname isEqualToString:@"iMBPhotosController"]
				   || 	[browserClassname isEqualToString:@"iMBMusicController"]
				   || 	[browserClassname isEqualToString:@"iMBMoviesController"]
				   || 	[browserClassname isEqualToString:@"iMBLinksController"] );
	
	// compatibility with the new cmeyer branch
	result |= (	[browserClassname isEqualToString:@"iMBPhotosView"]
			   || 	[browserClassname isEqualToString:@"iMBMusicView"]
			   || 	[browserClassname isEqualToString:@"iMBMoviesView"]
			   || 	[browserClassname isEqualToString:@"iMBLinksView"] );
	
	LOG((@"iMediaBrowser: willLoadBrowser:%@ ==> %d", browserClassname, result));
	return result;
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	[super applicationWillFinishLaunching:notification];
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	// apparently pool may not be in place yet?
	// see http://lapcatsoftware.com/blog/2007/03/10/everything-you-always-wanted-to-know-about-nsapplication/
	
	// Force imedia browser to load just so we can get RBSplitView loaded
	[iMediaBrowser class];
	
	// Create a KTDocumentController instance that will become the "sharedInstance".  Do this early.
	myDocumentController = [[KTDocumentController alloc] init];
			 
	// Try to check immediately so we have right info for initialization
	//[self performSelector:@selector(checkRegistrationString:) withObject:nil afterDelay:0.0];
#ifdef APPLE_DESIGN_AWARDS_KEY
#warning -- pre-configuring with registration code for Apple: Apple Design Awards Galilee Cadi Hop
	[self checkRegistrationString:APPLE_DESIGN_AWARDS_KEY];
#else
	[self checkRegistrationString:nil];
#endif
		
	// Fix menus appropriately
	if (nil == gRegistrationString)
	{
		// unregistered, label advanced menu as pro
		[self setMenuItemPro:oAdvancedMenu];
		[self setMenuItemPro:oPasteAsMarkupMenuItem];
		//[oValidateSourceViewMenuItem setImage:[NSImage imageNamed:@"globe"]];
		
		[self setMenuItemPro:oEditRawHTMLMenuItem];
		[self setMenuItemPro:oFindSubmenu];
		[self setMenuItemPro:oCodeInjectionMenuItem];
		[self setMenuItemPro:oCodeInjectionLevelMenuItem];
	}
	else
	{

		if (gIsPro || (nil == gRegistrationString))
		{
			//[oValidateSourceViewMenuItem setImage:[NSImage imageNamed:@"globe"]];
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
	

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication
{
    return NO;
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

#pragma mark -
#pragma mark Accessors

- (KTDocument *)currentDocument
{
	// NOTE: I took out the ivar to try to avoid too many retains. Just using doc controller now.
    return [[NSDocumentController sharedDocumentController] currentDocument];
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


- (IBAction)orderFrontPreferencesPanel:(id)sender
{
    [[KTPrefsController sharedController] showWindow:sender];
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
    [[KTTranscriptController sharedController] showWindow:sender];
	
	// Clear the transcript if option key was down.  Just a quick hack...
	if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
	{
		[[KTTranscriptController sharedController] clearTranscript:nil];
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

- (IBAction)showProductPage:(id)sender
{
    [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:@"http://www.sandvox.com/"]];
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
		[[NSApp delegate] setDisplayMediaMenuItemTitle:KTHideMediaMenuItemTitle];
		[browser setIdentifier:@"Sandvox"];
		[browser showWindow:sender];
	}
	else
	{
		[[NSApp delegate] setDisplayMediaMenuItemTitle:KTShowMediaMenuItemTitle];
		[browser close];
	}

	// display Media, if appropriate
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	[[self currentDocument] editRawHTMLInSelectedBlock:sender];
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

- (IBAction)showAcknowledgments:(id)sender
{
    [[KTAcknowledgmentsController sharedController] showWindow:nil];
}

- (IBAction)showReleaseNotes:(id)sender
{
	if (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )	// undocumented: option key - open in browser
	{
		NSURL *urlToOpen = [[KTReleaseNotesController sharedController] URLToLoad];
		[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:urlToOpen];
	}
	else
	{
		[[KTReleaseNotesController sharedController] showWindow:nil];
	}
}


- (IBAction)openSupportForum:(id)sender
{
	
#ifdef EXPIRY_TIMESTAMP
	NSString *urlString = @"http://support.karelia.com/?sandvox-beta";
#else
	NSString *urlString = @"http://support.karelia.com/?sandvox";
#endif
	NSURL *url = [NSURL URLWithString:urlString];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];	
}

#pragma mark -
#pragma mark Utility Methods

- (void)updateDuplicateMenuItemForDocument:(KTDocument *)aDocument
{
	OBPRECONDITION(aDocument);
	// label duplicate: (order is selected text, selected pagelet, selected page(s))
	KTPagelet *selectedPagelet = [[aDocument windowController] selectedPagelet];
	KTPage *selectedPage = [[[aDocument windowController] siteOutlineController] selectedPage];
	NSArray *selectedPages = [[[aDocument windowController] siteOutlineController] selectedObjects];
	
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
    NSString *marketingVersion = [NSApplication marketingVersion];
    NSString *buildVersion = [NSApplication buildVersion];
    
	NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Sandvox Public Beta", "Alert: Beta Message") 
									 defaultButton:nil 
								   alternateButton:nil 
									   otherButton:nil
						 informativeTextWithFormat:NSLocalizedString(@"You are running Sandvox version %@, build %@.\n\nThis is a Public Beta version and will expire on %@. (We will make a new version available by then.)\n\nIf you find problems, please use \\U201CSend Feedback...\\U201D under the Sandvox menu, or email support@karelia.com.\n\nSince this is BETA software, DO NOT use it with critical data or for critical business functions. Please keep backups of your files and all source material. We cannot guarantee that future versions of Sandvox will be able to open sites created with this version!\n\nUse of this version is subject to the terms and conditions of Karelia Software's Sandvox Beta License Agreement.", "Alert: Beta Informative Text"), marketingVersion, buildVersion, [[NSDate dateWithString:EXPIRY_TIMESTAMP] relativeFormatWithStyle:NSDateFormatterLongStyle]];
	(void)[alert runModal];
#endif
}
#endif


- (KTDocument *)documentWithID:(NSString *)anID
{
	OBPRECONDITION(anID);	OBPRECONDITION(![anID isEmptyString]);
	
    NSEnumerator *e = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    KTDocument *document;

    while ( ( document = [e nextObject] ) )
    {
// FIXME: it would be better to not have KTPluginInstallers added to sharedDocumentController
		if ( [document isKindOfClass:[KTDocument class]] )
		{
			if ([anID isEqualToString:[[document documentInfo] siteID]])
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


#pragma mark -
#pragma mark Debug Methods



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
	[self showDebugTableForObject:[KSPlugin pluginsWithFileExtension:kKTDesignExtension]
                           titled:@"Designs"];
}


- (IBAction)showAvailableComponents:(id)sender
{
	[self showDebugTableForObject:[KSPlugin pluginsWithFileExtension:kKTElementExtension]
                           titled:@"Available Components: Element Bundles"];
	[self showDebugTableForObject:[KSPlugin pluginsWithFileExtension:kKTIndexExtension]
							titled:@"Available Components: Index Bundles"];
	[self showDebugTableForObject:[KSPlugin pluginsWithFileExtension:kKTDataSourceExtension]
                           titled:@"Available Components: Data Source Bundles"];
	[self showDebugTableForObject:[KSPlugin pluginsWithFileExtension:kKTDesignExtension]
                           titled:@"Available Components: Design Bundles"];
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
			OBASSERTSTRING(nil != checkingQCFilePath, @"Cannot find CheckOpenGL.qtz");
			
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
