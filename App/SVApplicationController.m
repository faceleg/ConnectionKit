//
//  KTAppDelegate.m
//  Marvel
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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
#import "KSProgressPanel.h"
#import "KSRegistrationController.h"
#import "KSSilencingConfirmSheet.h"
#import "KSUtilities.h"
#import "KT.h"
#import "KTAcknowledgmentsController.h"
#import "SVApplicationController.h"
#import "KTApplication.h"
#import "KTDataSourceProtocol.h"
#import "KTDesign.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTDocumentController.h"
#import "KTElementPlugInWrapper.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "KTIndexPluginWrapper.h"
#import "KTPage.h"
#import "SVWelcomeController.h"
#import "KTPrefsController.h"
#import "KTPrefsController.h"
#import "KTReleaseNotesController.h"
#import "KTToolbars.h"
#import "KTTranscriptController.h"

#import "NSApplication+Karelia.h"
#import "NSArray+KTExtensions.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSError+Karelia.h"
#import "NSException+Karelia.h"
#import "NSString+KTExtensions.h"
#import "NSString+Karelia.h"
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
#import <iMedia/iMedia.h>
#import <Sparkle/Sparkle.h>
#import "SVApplicationController.h"

// Triggers to localize for the Comment/trackback stuff
// NSLocalizedString(@"To enable comments, please choose a Weblog Comments provider in the Site Inspector", "Prompt in webview")
// NSLocalizedString(@"Comments", "String_On_Page_Template -- text for link on a blog posting")

// Haloscan
// NSLocalizedString(@"To enable Haloscan comments, enter your Haloscan ID into the Site Inspector", "Prompt in webview")
// NSLocalizedString(@"Comment", "String_On_Page_Template -- text for link on a blog posting")
// NSLocalizedString(@"Other Posts About This", "String_On_Page_Template - description of trackbacks")
// NSLocalizedString(@"Trackback", "String_On_Page_Template - text for trackback link")
// NSLocalizedString(@"Haloscan Comments", "String_On_Page_Template -- text for link on a blog posting")

// JS-Kit
// NSLocalizedString(@"To enable JS-Kit comments, enter your moderator email address into the Site Inspector", "Prompt in webview")
// NSLocalizedString(@"JS-Kit Comments", "String_On_Page_Template -- text for link on a blog posting")

// Disqus
// NSLocalizedString(@"To enable Disqus comments, enter the Disqus short name of this site into the Site Inspector", "Prompt in webview")
// NSLocalizedString(@"Disqus Comments", "String_On_Page_Template -- text for link on a blog posting")

// Intense Debtate
// NSLocalizedString(@"To enable IntenseDebate comments, enter the Account ID of this site into the Site Inspector", "Prompt in webview")
// NSLocalizedString(@"IntenseDebate Comments", "String_On_Page_Template -- text for link on a blog posting")


// Enable this to get an Apple Design Awards Build, pre-licensed.  ALSO DEFINE AN EXPIRATION, DUDE!
// (this is a non-expiring, worldwide, pro license)
// #define APPLE_DESIGN_AWARDS_KEY [@"Nccyr Qrfvta Njneqf Tnyvyrr Pnqv Ubc" rot13]

// TODO: visit every instance of NSLog or LOG(()) to see if it should be an NSAlert/NSError to the user


NSString *kLiveEditableAndSelectableLinksDefaultsKey = @"LiveEditableAndSelectableLinks";

NSString *kSVPrefersPNGImageFormatKey = @"KTPrefersPNGFormat";
NSString *kSVPreferredImageCompressionFactorKey = @"KTPreferredJPEGQuality";


@interface NSArray ( TableDataSource )
- (id)tableView:(NSTableView *)aTableVieRw objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(int)rowIndex;
- (int)numberOfRowsInTableView:(NSTableView *)inTableView;
@end


@interface SVApplicationController ()

- (BOOL) appIsExpired;
- (void)showDebugTableForObject:(id)inObject titled:(NSString *)inTitle;	// a table or array

#if defined(VARIANT_BETA) && defined(EXPIRY_TIMESTAMP)
- (void)warnExpiring:(id)bogus;
#endif
- (void)informAppHasExpired;


@end


@interface NSSQLChannel : NSObject // Apple Private
+ (void)setDebugDefault:(BOOL)flag;
@end


@implementation SVApplicationController


- (NSDate *)referenceTimestamp
{
	return [NSDate dateWithString:@"2006-01-01 00:00:00 -0800"]; // See: Sandvox KTAppDelegate, RegGenerator RegGenerator.h - make sure this corresponds to other apps
}

- (NSString *)licenseFileName
{
	return [NSString stringWithFormat:@".%@.%@", @"WebKit", @"UTF-16"];

}


- (NSString *) additionalProfileStringForFeedback;
{
	NSMutableString *result = [NSMutableString string];
	//  additionalPlugins
	NSArray *extensions = [NSArray arrayWithObjects:kKTElementExtension, kKTIndexExtension, nil];
	NSString *plugins = [KSPlugInWrapper generateReportOfPluginsWithFileExtensions:extensions thirdPartyPluginsOnly:YES];
	if (![plugins isEqualToString:@""])
	{
		[result appendFormat:@"\nAdditional Plug-ins:\n%@\n", plugins];		// DO NOT LOCALIZE
	}

	// Call the following method on KTDesign to get the right plugin path
	NSString *designs = [KTDesign generateReportOfPluginsWithFileExtension:kKTDesignExtension thirdPartyPluginsOnly:YES];
	if (![designs isEqualToString:@""])
	{
		[result appendFormat:@"\nAdditional Designs:\n%@\n", designs];	// DO NOT LOCALIZE
	}
	
	
	NSDocument *document = [[NSDocumentController sharedDocumentController] currentDocument];
    if (document && [document isKindOfClass:[KTDocument class]])
    {
        NSString *urlString = [[[[(KTDocument *)document site] hostProperties] siteURL] absoluteString];
        if (urlString && ![urlString isEqualToString:@""])
        {
            [result appendFormat:@"\nURL:\n%@\n", urlString];
        }
    }
    
    
	return result;
}

- (NSArray *) convertTypesIntoNames:(NSArray *)types;
{
	NSDictionary *lookup = [NSDictionary dictionaryWithObjectsAndKeys:
							NSLocalizedString(@"All types", @"all plugin types, for 'show:' popup menu"), @"",
							NSLocalizedString(@"Pages/Pagelets", @"plugin type for 'show:' popup menu"), @"Element",
							NSLocalizedString(@"Designs", @"plugin type for 'show:' popup menu"), @"Design",
							nil];
	NSMutableArray *result = [NSMutableArray array];
	NSString *aTypeString;
	
	for (aTypeString in types)
	{
		NSString *newTypeString = [lookup objectForKey:aTypeString];
		if (!newTypeString)
		{
			newTypeString = aTypeString;		// fall back to raw type, untranslated :-(
		}
		[result addObject:newTypeString];
	}
	return result;
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


/*!	Needs to be done on initialization, and after resetStandardUserDefaults is called
*/
+ (void)registerDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    
    // BUGSID:36452 - having WebKitDefaultFontSize present seriously screws up text rendering
    [defaults removeObjectForKey:@"WebKitDefaultFontSize"];
    [defaults removeObjectForKey:@"WebKitStandardFont"];
    
    

// TODO: Remove this later (v2.0) once the old contactHomeBase hasn't been around for a while
	id oldContactHomeBase = [defaults  objectForKey:@"contactHomeBase"];
	if (oldContactHomeBase)
	{
		// Copy from Sparkle since he doesn't make this key public; we want to know if has even been set
		NSString *SUEnableAutomaticChecksKey = @"SUEnableAutomaticChecks";
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
		
#ifdef VARIANT_BETA
		[NSNumber numberWithBool:YES],			@"ShowScoutMessages",	// Alerts when there is a "Scout message" from submitting a bug/error
//		@"Beta Testing Reports",				@"AssignSubmission",	// Virtual user for beta testing reports, DON'T go to normal support person when testing
#else
		[NSNumber numberWithBool:NO],			@"ShowScoutMessages",
#endif
		[NSNumber numberWithBool:YES],			@"KTLogToConsole",
		
		[NSNumber numberWithBool:NO],			@"urls in background",
		
		[NSNumber numberWithBool:NO],			@"LogJavaScript",

										 
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
		
		//[NSNumber numberWithBool:YES],			@"BackupWhenSaving",
		//[NSNumber numberWithDouble:600.0],		@"BackupTimeInterval",

		[NSNumber numberWithUnsignedInt:2],			@"BackupOnOpening", // default is to snapshot
	
		[NSNumber numberWithBool:YES],			@"allowCalloutsInIndex",		// should an index have the page's callout.  Initially yes but allow it to be set to no.
										 
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
										 
		@"email@domain.com", @"emailPlaceholder",

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
		[NSNumber numberWithFloat:0.7],			kSVPreferredImageCompressionFactorKey,
		[NSNumber numberWithBool:NO],			kSVPrefersPNGImageFormatKey,
										 
		[NSNumber numberWithBool:YES],			@"KTHaloscanTrackbacks",	// KTHaloscanID is nil initially
		
		[NSNumber numberWithBool:NO],			@"ShowSearchPaths",			// NSLog where items are searched for
		
		[NSNumber numberWithInt:kReportAsk],	@"ReportErrors",
		
		@"sandvox.Aqua",		@"designBundleIdentifier",
		
		[NSMutableArray array],					@"keywords",
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
		[NSNumber numberWithBool:YES], @"collectionHyperlinkPageTitles",
		[NSNumber numberWithBool:NO], @"collectionShowPermanentLink",
		[NSNumber numberWithBool:YES], @"collectionShowSortingControls",
		
		[NSNumber numberWithBool:NO], @"collectionShowSortingControls",
		[NSNumber numberWithInt:0], @"collectionMaxIndexItems",
								@"", @"headerImageDescription",

		[NSNumber numberWithBool:YES], @"propagateInsertPrelude",
		[NSNumber numberWithBool:YES], @"propagateInsertHead",
		[NSNumber numberWithBool:YES], @"propagateInsertBody",
		[NSNumber numberWithBool:YES], @"propagateInsertEndBody",
		
		[NSNumber numberWithBool:NO], @"generateGoogleSitemap",

		[NSNumber numberWithInt:1], @"MediaLoaderMaxThreads",
		
		
		// Properties of document, reverting to preferences if not set in doc.
		
		[NSNumber numberWithBool:NO], @"displaySmallPageIcons",
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
										 
		
		/// whether bundles should -loadLocalFonts, currently used in KTDesigns
		[NSNumber numberWithBool:YES], @"LoadLocalFonts",
										 
		/// whether CKTransferController should set up a parallel verification connection
		[NSNumber numberWithBool:NO], @"ConnectionVerifiesTransfers",
										 
		/// how frequently documents are autosaved as int (converted to NSTimeInternal (double))
		[NSNumber numberWithInt:60], @"AutosaveFrequency",
										 
		/// whether CKTransferController sets permissions on uploads
		[NSNumber numberWithBool:YES], @"ConnectionSetsPermissions",
										 
		/// whether we use secure NSTemporaryDirectory() or ~/Library/Caches/ for upload cache
		[NSNumber numberWithBool:NO], @"DisableSecureUploadCache",
										 
		/// whether the Publishing window is expanded, showing the outline view
		[NSNumber numberWithBool:NO], @"ExpandPublishingWindow",
        
        // See case 39953 & KTExportEngine.m
        [NSNumber numberWithBool:YES], @"ExportShouldReplaceExistingFile",
										 
		/// whether we NSLog() the hostProperties dictionary upon document open/change
		[NSNumber numberWithBool:NO], @"LogHostInfoToConsole",
										 
		[NSNumber numberWithBool:NO], @"JSKitReverseOrder",
		[NSNumber numberWithBool:NO], @"JSKitDisableAvatars",
		[NSNumber numberWithBool:NO], @"JSKitDisableThreading",
		[NSNumber numberWithBool:NO], @"JSKitConfirmModeratorViaEmail",
                                         
        // "Make all links active" checkbox in the Inspector
        [NSNumber numberWithBool:NO], kLiveEditableAndSelectableLinksDefaultsKey,

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
		ControllerDomain, CKTransportDomain, CKStateMachineDomain, CKParsingDomain, CKProtocolDomain, CKConnectionDomain, /* ThreadingDomain, */
		/* StreamDomain, */ CKInputStreamDomain, CKOutputStreamDomain, /* SSLDomain, */ CKQueueDomain, nil];
	
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
	
// TODO: remove this for release.  I just don't want to have this old key around in the user defaults.
	// However, later on, somebody might want to actually override things.
#ifndef DEBUG
	// Copy from Sparkle since he doesn't make this key public; we want to know if has even been set
	NSString *SUFeedURLKey = @"SUFeedURL";
	[defaults removeObjectForKey:SUFeedURLKey];	// NOT storing a feed URL now in defaults, generally
#endif
	
	// If we don't have a feed type in user defaults, get it explicitly from the Info.plist.
	// This allows us to start out with a beta/release type, and keep that type even after we have
	// made a release and somebody was originally getting betas.
	
	NSString *feedType = [[defaults objectForKey:@"KSFeedType"] lowercaseString];
	if (nil == feedType || [feedType isEqualToString:@""])		// 'beta' or 'release' or '' (empty string) for none
	{
		NSString *feedType = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"KSFeedType"] lowercaseString];	// default feed type
		[defaults setObject:feedType forKey:@"KSFeedType"];
	}
	
	[defaults synchronize];
}	

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    [self registerDefaults];
	
	[pool release];
}

@synthesize progressPanel = _progressPanel;

- (id)init
{
    self = [super init];
    if ( self )
    {

		_cascadePoint = NSMakePoint(100, 100);

        _applicationIsLaunching = YES;
		_appIsTerminating = NO;
	}
    return self;
}


- (void)dealloc
{
#ifdef OBSERVE_UNDO
    [[NSNotificationCenter defaultCenter] removeObserver:self];
#endif
	self.progressPanel = nil;
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

- (BOOL) checkForGraylistedLicense:(NSData *)aHash
{
#include "SandvoxGraylistedLicenses.h"

	return [self licenseHash:[aHash bytes] foundInList:grayListDigests ofSize:GRAY_LIST_COUNT];
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
	BOOL result = [super codeIsValid:aCode :outNamed :outLicensee :outIndex :outVersion :outDate :outType :outSource :outPro :outSeats];
	
	if (result && [self checkForGraylistedLicense:gRegistrationHashData] && nil != outPro)
	{
		NSLog(@"Repaired non-pro registration code");
		*outPro = (int)NO;
	}
	return result;
}

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	OBPRECONDITION(menuItem);
	OFF((@"KTAppDelegate validateMenuItem:%@ %@", [menuItem title], NSStringFromSelector([menuItem action])));

	SEL action = [menuItem action];

	
	if (action == @selector(newDocument:))
	{
		return (!gLicenseViolation && ![self appIsExpired]);
	}
	else if (action == @selector(editRawHTMLInSelectedBlock:))
	{
		return [[[NSDocumentController sharedDocumentController] currentDocument] validateMenuItem:menuItem];
	}
	else if (action == @selector(showPluginWindow:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
    else if (action == @selector(toggleMediaBrowserShown:))
    {
        if ([[[IMBPanelController sharedPanelControllerWithoutLoading] window] isVisible])
        {
            [menuItem setTitle:NSLocalizedString(@"Hide Media Browser", @"menu title to hide inspector panel")];
        }
        else
        {
            [menuItem setTitle:NSLocalizedString(@"Show Media Browser", @"menu title to show inspector panel")];
        }
        return YES;
    }
	else if (action == @selector(showReleaseNotes:))
	{
		return [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(openScreencast:))
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
		return YES;
	}

	return YES;
}

// Exceptions specific to Sandvox
// BETA: I've commented some of those out that we want to hear about. Mike.
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
		NSLog(@"PLEASE REPORT THIS TO KARELIA SOFTWARE - support@karelia.com -- %@", [[exception stacktrace] condenseWhiteSpace]);
		
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
#ifndef VARIANT_BETA
		|| ( [name isEqualToString:NSRangeException]
			&& NSNotFound != [reason rangeOfString:@"-[NSBigMutableString characterAtIndex:]: Range or index out of bounds"].location )
#endif
		)
	{
		return NO;
	}
	
#ifndef VARIANT_BETA
	if ( [name isEqualToString:NSInternalInconsistencyException] )
	{
		// catch all Undo exceptions and simply reset
		if ( [reason hasPrefix:@"_registerUndoObject"] )
		{
			LOG((@"caught _registerUndoObject exception, resetting undoManager"));
			KTDocument *document = [self currentDocument];
			[[document undoManager] removeAllActions];
			return NO;
		}
		
		// another stab at undo
		if ( NSNotFound != [reason rangeOfString:@"undo was called with too many nested undo groups"].location )
		{
			LOG((@"caught undo called with too many nested undo groups exception, resetting undoManager"));
			KTDocument *document = [self currentDocument];
			[[document undoManager] removeAllActions];
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
#endif

	
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

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag;
{
	if ([self appIsExpired])
	{
		[self informAppHasExpired];
		return NO;
	}
	
	if (!flag || 0 == [[[NSDocumentController sharedDocumentController] documents] count])	// no visible windows.  However, all visible windows may be minimized..
	{
		[[NSDocumentController sharedDocumentController] showDocumentPlaceholderWindowInitial:NO];
	}
	return NO;
}



/*  We want all errors logged in detail for further analysis later if needed
 */
- (NSError *)application:(NSApplication *)theApplication willPresentError:(NSError *)error
{
    // Log the error to the console for debugging
    // Don't log 259 userInfo ... crashes, see case 34969
    NSString *errorDescription = ([error code] == NSFileReadCorruptFileError) ? [error description] : [error debugDescription];
	NSLog(@"Error: %@", [errorDescription condenseWhiteSpace]);
	
    return error;
}

- (BOOL)applicationOpenUntitledFile:(NSApplication *)theApplication
{
	return YES; // we always return YES to purposefully thwart the NSDocument framework
}

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)theApplication
{
    if ( !_applicationIsLaunching )
    {
        return [[NSUserDefaults standardUserDefaults] boolForKey:@"OpenUntitledFileWhenIconClicked"];
    }
    else
    {
        return NO;
    }
}

- (void)checkQuartzExtreme
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
	[super applicationDidFinishLaunching:aNotification];

	NSFileManager *fm = [NSFileManager defaultManager];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	
    @try
	{
		// Make an empty string for "No Selection" so that empty/0 numeric text fields are empty!
		[NSTextFieldCell setDefaultPlaceholder: @""
									 forMarker: NSNoSelectionMarker
								   withBinding: NSValueBinding];
		
		
		BOOL sufficient = (NSFoundationVersionNumber > 677.22 /* NSFoundationVersionNumber10_5_6 is 677.22 so we want higher. */);
		
		
		if (!sufficient)
		{
			NSRunCriticalAlertPanel(
									@"",
									NSLocalizedString(@"You will need to update Mac OS X 10.5.7 \\U201CLeopard\\U201D (or higher) for this version of Sandvox to function.", @""), 
									NSLocalizedString(@"Quit", @"Quit button"),
									nil,
									nil
									);
			[NSApp terminate:nil];
		}

#ifdef VARIANT_BETA
		NSLog(@"Running build %@", [NSApplication buildVersion]);
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
        if ([self appIsExpired])
		{
			[self informAppHasExpired];
		}
		else
		{
			// WARN OF EXPIRING BETA VERSION -- but not if it's apple design awards or development build.
#ifndef DEBUG
#ifndef APPLE_DESIGN_AWARDS_KEY
			[self warnExpiring:nil];
#endif
#endif
			
			// put up a splash panel with a progress indicator
			_progressPanel = [[KSProgressPanel alloc] init];
			[_progressPanel setMessageText:NSLocalizedString(@"Initializing...",
															"Message while initializing launching application.")];
			[_progressPanel setInformativeText:nil];
			[_progressPanel makeKeyAndOrderFront:self];


			// load plugins
			[_progressPanel setMessageText:NSLocalizedString(@"Loading Plug-ins...", "Message while loading plug-ins.")];
			
			
			// build menus
			[KTElementPlugInWrapper populateMenu:oAddPageletMenu atIndex:0 withPlugins:[KTElementPlugInWrapper pageletPlugins]];
						
			[_progressPanel setMessageText:NSLocalizedString(@"Building Menus...", "Message while building menus.")];
			//[self buildSampleSitesMenu];
			
			BOOL firstRun = [defaults boolForKey:@"FirstRun"];
			
			// If there's no docs open, want to see the placeholder window
			if ([[[NSDocumentController sharedDocumentController] documents] count] == 0)
			{
	#if 0
				NSLog(@"BETA: For now, always creating a new document, to make debugging easier");
				[[NSDocumentController sharedDocumentController] newDocument:nil];
	#else
				[[NSDocumentController sharedDocumentController] showDocumentPlaceholderWindowInitial:!firstRun];	// launching, so try to reopen... unless it's first run.
	#endif
			}
			[_progressPanel performClose:self];
			
			
			// QE check AFTER the welcome message
			[self performSelector:@selector(checkQuartzExtreme) withObject:nil afterDelay:0.0];
		}
	}
	@finally
	{
		[_progressPanel performClose:self];
        self.progressPanel = nil;
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
		
    _applicationIsLaunching = NO; // we're done
}

- (BOOL) appIsExpired;
{
	if (!_checkedExpiration)
	{
#if defined(VARIANT_BETA) && defined(EXPIRY_TIMESTAMP)
		/*
		 unsigned char km[16];
		 GetKeys((void *)km);
		 BOOL overrideKeyPressed = ((km[KeyOption>>3] >> (KeyOption & 7)) & 1) ? 1 : 0;
		 */
		BOOL overrideKeyPressed = 0 != (GetCurrentEventKeyModifiers() & optionKey);
		
		_appIsExpired =
		( !overrideKeyPressed &&
		 [[NSDate dateWithString:EXPIRY_TIMESTAMP] timeIntervalSinceNow] < 0);
#else
		_appIsExpired = NO;
#endif
		_checkedExpiration = YES;
	}
	return _appIsExpired;
}

- (void)informAppHasExpired
{	
	NSRunCriticalAlertPanel(
							NSLocalizedString(@"This version of Sandvox has expired.", @""),
							NSLocalizedString(@"This version of Sandvox is no longer functional. Sandvox will now check for updates; please install the newest version if available.", @""), 
							NSLocalizedString(@"Check for Updates", @"Button title"),
							nil,
							nil
							);
	
	[[self sparkleUpdater] checkForUpdatesInBackground];	// check Sparkle before alerting
}

/*
- (BOOL)iMediaBrowser:(iMediaBrowser *)browser willUseMediaParser:(NSString *)parserClassname forMediaType:(NSString *)media;
{
	BOOL result = YES;
	
	if ([parserClassname isEqualToString:@"iMBGarageBandParser"]) result = NO;		// can't process garage band files
	if ([parserClassname isEqualToString:@"LHDeliciosParser"]) result = NO;	// old code; causes crashes!
	
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
*/

- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	[super applicationWillFinishLaunching:notification];
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	// apparently pool may not be in place yet?
	// see http://lapcatsoftware.com/blog/2007/03/10/everything-you-always-wanted-to-know-about-nsapplication/


	OBASSERT([NSApp isKindOfClass:[KTApplication class]]);	// make sure we instantiated the right kind of NSApplication subclass
	
	// Create a KTDocumentController instance that will become the "sharedInstance".  Do this early.
	[[[KTDocumentController alloc] init] release];
    
    
	// Autosave frequency
    NSTimeInterval interval = [[[NSUserDefaults standardUserDefaults] valueForKey:@"AutosaveFrequency"] doubleValue];
    if (interval < 5)       interval = 60.0;        // if the number is wildly out of range, go back to our default of 60
    if (interval > 5 * 60)  interval = 60.0;

    KTDocumentController *sharedDocumentController = [KTDocumentController sharedDocumentController];
    [sharedDocumentController setAutosavingDelay:interval];
	
			 
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
		
		[self setMenuItemPro:oEditRawHTMLMenuItem];

		
		[self setMenuItemPro:oCodeInjectionMenuItem];
		[self setMenuItemPro:oCodeInjectionLevelMenuItem];
	}
	else
	{

		if (gIsPro || (nil == gRegistrationString))
		{
			;
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
#pragma mark IBActions

- (IBAction)orderFrontPreferencesPanel:(id)sender
{
    [[KTPrefsController sharedController] showWindow:sender];
}

/*!	for manual save... though we're saving it automatically.
*/
- (IBAction)saveWindowSize:(id)sender
{
    NSWindow *window = [[[[NSDocumentController sharedDocumentController] windowControllers] objectAtIndex:0] window];
    NSSize contentSize = [[window contentView] frame].size;
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromSize(contentSize)
                                              forKey:@"DefaultDocumentWindowContentSize"];
}

- (IBAction) showTranscriptWindow:(id)sender
{
    [[KTTranscriptController sharedController] showWindow:sender];
	
	// Clear the transcript if option key was down.  Just a quick hack...
	if ([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask)
	{
		[[KTTranscriptController sharedController] clearTranscript:nil];
	}
}

- (IBAction)showProductPage:(id)sender
{
	NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:[NSApplication applicationName], @"utm_source",
								@"application", @"utm_medium",
								@"utm_campaign", @"product_menu",
						  nil];
	NSString *queryString = [dict formatForHTTP];
	NSString *urlString = [NSString stringWithFormat:
						   @"http://www.sandvox.com/?%@", queryString];
    [[NSWorkspace sharedWorkspace] attemptToOpenWebURL:[NSURL URLWithString:urlString]];
}

- (IBAction)toggleMediaBrowserShown:(id)sender
{
	NSArray* mediaTypes = [NSArray arrayWithObjects:kIMBMediaTypeImage,kIMBMediaTypeAudio,kIMBMediaTypeMovie,kIMBMediaTypeLink,nil];
	IMBPanelController* panelController = [IMBPanelController sharedPanelControllerWithDelegate:self mediaTypes:mediaTypes];

/* TEMP -- PUT BACK IN
	if ( [panelController infoWindowIsVisible] )
	{
		[panelController flipBack:nil];
	}
*/		
	BOOL newValue = ![[panelController window] isVisible];
	
	// set menu to opposite of flag
	if ( newValue )
	{
// PUT BACK IN [panelController setIdentifier:@"Sandvox"];
		[panelController showWindow:sender];
	}
	else
	{
		[panelController close];
	}

	// display Media, if appropriate
}

- (IBAction)editRawHTMLInSelectedBlock:(id)sender
{
	[[[NSDocumentController sharedDocumentController] currentDocument] editRawHTMLInSelectedBlock:sender];
}

- (IBAction) openScreencast:(id)sender
{
	NSURL *url = nil;
	
	NSRect largestScreenFrame = NSZeroRect;
	for (NSScreen *screen in [NSScreen screens])
	{
		NSRect thisFrame = [screen frame];
		if (thisFrame.size.height > largestScreenFrame.size.height
				&& thisFrame.size.width > largestScreenFrame.size.width)
		{
			largestScreenFrame = thisFrame;
		}
	}
	// Leave enough for the dock on the left or right, plus some extra for controller of player, etc.
	// Basically we can play the large size on a MBP, but the smaller one on the MacBook
	if (largestScreenFrame.size.width > 1100 && largestScreenFrame.size.height > 850)
	{
		url = [NSURL URLWithString: @"http://www.karelia.com/screencast/Introduction_to_Sandvox_1024.mov"];
	}
	else
	{
		url = [NSURL URLWithString: @"http://www.karelia.com/screencast/Introduction_to_Sandvox_640.mov"];
	}

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
	
//#ifdef VARIANT_BETA
//	NSString *urlString = @"http://support.karelia.com/?sandvox-beta";
//#else
	NSString *urlString = @"http://support.karelia.com/?sandvox";
//#endif
	NSURL *url = [NSURL URLWithString:urlString];
	[[NSWorkspace sharedWorkspace] attemptToOpenWebURL:url];	
}

#if defined(VARIANT_BETA) && defined(EXPIRY_TIMESTAMP)
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


/*!	Utility method for bindings. If we aren't PNG (or nil), then we're JPEG. */
- (BOOL)preferredImageFormatIsJPEG
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	bool prefersPNG = [defaults boolForKey:@"KTPrefersPNGFormat"];
	return !prefersPNG;
}

- (IBAction)showPluginWindow:(id)sender;
{
	if (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )	// undocumented: option key - only showing new updates.
	{
		[[KSPluginInstallerController sharedController] showWindowForNewVersions:sender];
	}
	else	// normal
	{
		[[KSPluginInstallerController sharedController] showWindow:sender];
	}
}

- (NSArray *) additionalPluginDictionaryForInstallerController:(KSPluginInstallerController *)controller
{
	return nil;
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
	_cascadePoint = [[debugTable window] cascadeTopLeftFromPoint:_cascadePoint];

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
	[self showDebugTableForObject:[KSPlugInWrapper pluginsWithFileExtension:kKTDesignExtension]
                           titled:@"Designs"];
}


- (IBAction)showAvailableComponents:(id)sender
{
	[self showDebugTableForObject:[KSPlugInWrapper pluginsWithFileExtension:kKTElementExtension]
                           titled:@"Available Components: Element Bundles"];
	[self showDebugTableForObject:[KSPlugInWrapper pluginsWithFileExtension:kKTIndexExtension]
							titled:@"Available Components: Index Bundles"];
	[self showDebugTableForObject:[KSPlugInWrapper pluginsWithFileExtension:kKTDesignExtension]
                           titled:@"Available Components: Design Bundles"];
}

#pragma mark -
#pragma mark Support


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
