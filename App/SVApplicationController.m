//
//  KTAppDelegate.m
//  Marvel
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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

#import "SVApplicationController.h"

#import "BDAlias.h"
#import "KSExceptionReporter.h"
#import "KSEmailAddressComboBox.h"
#import "KSNetworkNotifier.h"
#import "KSPluginInstallerController.h"
#import "KSProgressPanel.h"
#import "KSRegistrationController.h"
#import "KSSilencingConfirmSheet.h"
#import "KSUtilities.h"
#import "KT.h"
#import "KTAcknowledgmentsController.h"
#import "KTApplication.h"
#import "KTDataSourceProtocol.h"
#import "KTDesign.h"
#import "KTDocWindowController.h"
#import "KTDocument.h"
#import "KTSite.h"
#import "KTDocumentController.h"
#import "KTElementPlugInWrapper.h"
#import "KTHostProperties.h"
#import "KTHostSetupController.h"
#import "KTPage.h"
#import "SVGraphicFactory.h"
#import "KTPrefsController.h"
#import "KTReleaseNotesController.h"
#import "KTToolbars.h"
#import "KTTranscriptController.h"
#import "SVWelcomeController.h"
#import "KSExceptionReporter.h"

#import "NSString+KTExtensions.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSError+Karelia.h"
#import "NSException+Karelia.h"
#import "NSString+Karelia.h"
#import "NSToolbar+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSMenuItem+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "SVPageTemplate.h"
#import "KSURLUtilities.h"

#import <AmazonSupport/AmazonSupport.h>
#import <Connection/Connection.h>
#import <ExceptionHandling/NSExceptionHandler.h>
#import <iMedia/iMedia.h>
#import <OpenGL/CGLMacro.h>
#import <Quartz/Quartz.h>
#import <ScreenSaver/ScreenSaver.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <Sparkle/Sparkle.h>
#import <JSTalk/JSTalk.h>

#import "Debug.h"

// The second line of these pairs really should be equivalent to LocalizedStringForString since they
// are in the target language.

// Triggers to localize for the Comment/trackback stuff
// NSLocalizedString(@"Configure Comments…", "Prompt in webview")

// Disqus
// NSLocalizedString(@"Configure Disqus…", "Prompt in webview")
// NSLocalizedString(@"Disqus Comments", "String_On_Page_Template -- text for link on a blog posting")

// Intense Debate
// NSLocalizedString(@"Configure IntenseDebate…", "Prompt in webview")
// NSLocalizedString(@"IntenseDebate Comments", "String_On_Page_Template -- text for link on a blog posting")

// Facebook Comments
// NSLocalizedString(@"Configure Facebook Comments…", "Prompt in webview")
// NSLocalizedString(@"Facebook Comments", "String_On_Page_Template -- text for link on a blog posting")


// Enable this to get an Apple Design Awards Build, pre-licensed.  ALSO DEFINE AN EXPIRATION, DUDE!
// (this is a non-expiring, worldwide, pro license)
// #define APPLE_DESIGN_AWARDS_KEY [@"Nccyr Qrfvta Njneqf Tnyvyrr Pnqv Ubc" rot13]

// TODO: visit every instance of NSLog or LOG(()) to see if it should be an NSAlert/NSError to the user


NSString *kSVOpenDocumentsKey = @"SVOpenDocuments";

NSString *kSVLiveDataFeedsKey = @"LiveDataFeeds";
NSString *kSVSetDateFromSourceMaterialKey = @"SetDateFromSourceMaterial";
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

#if !defined(VARIANT_RELEASE) && defined(EXPIRY_TIMESTAMP)
- (void)warnExpiring:(id)bogus;
#endif
- (void)informAppHasExpired;


@end


#pragma mark -


@implementation SVApplicationController


- (NSDate *)referenceTimestamp
{
	return [NSDate dateWithString:@"2006-01-01 00:00:00 -0800"]; // See: Sandvox KTAppDelegate, RegGenerator RegGenerator.h - make sure this corresponds to other apps
}

- (NSString *)licenseFileName
{
	return [NSString stringWithFormat:@".%@.%@", @"WebKit", @"UTF-16"];

}

// Factory override to get application-specific objects instantiated.

- (NSString *)convertClassName:(NSString *)className
{
	if ([className isEqualToString:@"KSFeedbackReporter"]) return @"KTFeedbackReporter";
	
	return className;	
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
							NSLocalizedString(@"Objects", @"plugin type for 'show:' popup menu"), @"Element",
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

- (NSInteger) requiredLicenseVersion
{
	return 2;		// this is version 2 of Sandvox, so we need a Sandvox 2 license. We'll fail if Sandvox 1.
}


/*!	Needs to be done on initialization, and after resetStandardUserDefaults is called
*/
+ (void)registerDefaults
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

#ifdef SUPPRESS_IMEDIA_PPC
	if (NSHostByteOrder() == NS_LittleEndian)
#endif
	{
		[IMBConfig registerDefaultValues];
		[IMBConfig setShowsGroupNodes:NO];
	}
#ifdef SUPPRESS_IMEDIA_PPC
#ifndef VARIANT_RELEASE
	else
	{
		NSLog(@"BETA: PPC, Not configuring iMedia");
	}
#endif
#endif

    
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
// For now, we want 
		@"all",									@"metaRobots",
#ifdef APPLE_DESIGN_AWARDS_KEY
		[NSNumber numberWithBool:YES],			kSVLiveDataFeedsKey,		// I want ADA entries to have this on as default
#else
		[NSNumber numberWithBool:NO],			kSVLiveDataFeedsKey,
#endif
		
#ifndef VARIANT_RELEASE
		[NSNumber numberWithBool:YES],			@"ShowScoutMessages",	// Alerts when there is a "Scout message" from submitting a bug/error
		@"Beta Testing Reports",				@"AssignSubmission",	// Virtual user for beta testing reports, DON'T go to normal support person when testing
#else
		[NSNumber numberWithBool:NO],			@"ShowScoutMessages",
#endif
		[NSNumber numberWithBool:YES],			@"KTLogToConsole",
		
		[NSNumber numberWithBool:NO],			@"urls in background",
		
		[NSNumber numberWithBool:NO],			@"LogJavaScript",

										 
		[NSNumber numberWithBool:YES],			@"FirstRun",
		
		[NSNumber numberWithUnsignedInt:5],		@"KeepAtMostNBackups",
		
		[NSNumber numberWithBool:YES],			@"SendCrashReports",
		[NSNumber numberWithBool:YES],			@"ShowWelcomeWindow",
		
		[NSNumber numberWithBool:YES],			@"EscapeNBSP",		// no longer used apparently
		[NSNumber numberWithBool:YES],			@"GetURLsFromSafari",
		[NSNumber numberWithBool:YES],			@"AutoOpenLastOpenedOnLaunch",
		[NSNumber numberWithBool:YES],			@"OpenUntitledFileWhenIconClicked",
						
		[NSNumber numberWithBool:NO],			@"DisplayInfo",
		
		//[NSNumber numberWithBool:YES],			@"BackupWhenSaving",
		//[NSNumber numberWithDouble:600.0],		@"BackupTimeInterval",

		[NSNumber numberWithUnsignedInt:2],			@"BackupOnOpening", // default is to snapshot
	
		[NSNumber numberWithBool:YES],			@"allowCalloutsInIndex",		// should an index have the page's callout.  Initially yes but allow it to be set to no.
										 
		[NSNumber numberWithBool:NO],			@"AllowPasswordToBeLogged", // for Connection class
		
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowPageType",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowIndexType",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowTitle",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowLastUpdated",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowServerPath",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowAuthor",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowShowLanguage",
		//		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowIsDraft",
		[NSNumber numberWithBool:YES],			@"OutlineTooltipShowNeedsUploading",
		
		[NSNumber numberWithInt:20],				@"MaximumTitlesInCollectionSummary",
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
					@"karelsofwa-20",	@"AmazonAssociatesToken",
		
		[NSNumber numberWithBool:NO],			@"PreferRelativeLinks", // obsolete
				
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
		[NSNumber numberWithBool:NO],			kSVSetDateFromSourceMaterialKey,
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
										 		
		[NSNumber numberWithBool:NO],			@"ShowSearchPaths",			// NSLog where items are searched for
		
		[NSNumber numberWithInt:kReportAsk],	@"ReportErrors",
										 
										 
		[NSNumber numberWithInt:90],			@"GalleryPercentWidth",
		[NSNumber numberWithInt:90],			@"GalleryPercentHeight",

		
		@"sandvox.Aqua",		@"designBundleIdentifier",
		
		[NSMutableArray array],					@"keywords",
		[NSDictionary
			dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:0], @"localHosting",
			[NSNumber numberWithInt:0], @"localSharedMatrix",	// 0 = ~ , 1 = computer
			nil],								@"defaultHostProperties",
		
		[NSNumber numberWithShort:0],		@"truncateCharacters",
		[NSNumber numberWithShort:KTSummarizeAutomatic], @"collectionSummaryType",
		[NSNumber numberWithShort:NSDateFormatterMediumStyle], @"timestampFormat",
		[NSNumber numberWithBool:YES], @"timestampShowTime",
		[NSNumber numberWithShort:KTTimestampCreationDate], @"timestampType",
		
		[NSNumber numberWithBool:NO], @"enableImageReplacement",
		@"html", @"fileExtension",
		
		[NSNumber numberWithBool:NO], @"DebugImageReplacement",
		
		// Don't need these unless/until we support multiple formats
		//		[NSNumber numberWithBool:NO], @"collectionGenerateAtom",
		//		[NSNumber numberWithBool:YES], @"collectionGenerateRSS",
		[NSNumber numberWithBool:YES], @"collectionHyperlinkPageTitles",
		[NSNumber numberWithBool:NO], @"collectionShowPermanentLink",
		[NSNumber numberWithBool:YES], @"collectionShowSortingControls",
		
		[NSNumber numberWithBool:NO], @"collectionShowSortingControls",
		[NSNumber numberWithInt:0], @"collectionMaxSyndicatedPagesCount",
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
		[NSNumber numberWithInt:30], @"AutosaveFrequency",
										 
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
										 
		[NSNumber numberWithBool:YES], @"ShowCodeInjectionInPreview",

		[NSNumber numberWithInt:21844], kKSCurrentAppBuildVersionDefaultsKey, // if last version lanched is less than this, re-welcome to try and get signup again.

										 
		nil];
	
	OBASSERT(defaultsBase);

	// Load in the syntax coloring defaults
	NSDictionary *syntaxColorDefaults = [NSDictionary dictionaryWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"SyntaxColorDefaults" ofType: @"plist"]];
	[defaultsBase addEntriesFromDictionary:syntaxColorDefaults];
	
	NSString *email = [KSEmailAddressComboBox primaryEmailAddress];
	if (email) [defaultsBase setObject:email forKey:@"KSEmailAddress"];
			
    
    
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
	if (nil == feedType || [feedType isEqualToString:@""])		// 'beta' or 'release' or 'alpha...' or '' (empty string) for none
	{
		feedType = [[[NSBundle mainBundle] objectForInfoDictionaryKey:@"KSFeedType"] lowercaseString];	// default feed type
		[defaults setObject:feedType forKey:@"KSFeedType"];
	}
	
	[defaults synchronize];
}	

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    [self registerDefaults];
    
#ifdef DEBUG
    [KSExtensibleManagedObject setLogsObserversWhenTurningIntoFault:YES];
#endif
	
	[pool release];
}

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

	[super dealloc];
}


// This is for use by the feedback reporter.  Might be also useful in JSTalk.
- (KTDocument *)currentDocument
{
	// NOTE: I took out the ivar to try to avoid too many retains. Just using doc controller now.
    return [[NSDocumentController sharedDocumentController] currentDocument];
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

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	OBPRECONDITION(menuItem);
	VALIDATION((@"%s %@",__FUNCTION__, menuItem));

	BOOL result = YES; 	// default to YES so we don't have to do special validation for each action. Some actions might say NO.
	
	SEL action = [menuItem action];

	
	if (action == @selector(newDocument:))
	{
		result = (!gLicenseViolation && ![self appIsExpired]);
	}
	else if (action == @selector(showPluginWindow:))
	{
		result = [KSNetworkNotifier isNetworkAvailable];
	}
    else if (action == @selector(toggleMediaBrowserShown:))
    {
#ifdef SUPPRESS_IMEDIA_PPC
		if (NSHostByteOrder() == NS_LittleEndian)
#endif
		{
			if ([IMBPanelController isSharedPanelControllerLoaded] &&
				[[[IMBPanelController sharedPanelController] window] isVisible])
			{
				[menuItem setTitle:NSLocalizedString(@"Hide Media Browser", @"menu title to hide inspector panel")];
			}
			else
			{
				[menuItem setTitle:NSLocalizedString(@"Show Media Browser", @"menu title to show inspector panel")];
			}
		}
#ifdef SUPPRESS_IMEDIA_PPC
		else
		{
			result = NO;		// no imedia browser on PPC for now ... crashing a lot!
#ifndef VARIANT_RELEASE
				NSLog(@"BETA: validate iMedia item FALSE for being on PPC");
#endif
		}
#endif
    }
	else if (action == @selector(showReleaseNotes:))
	{
		result = [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(openScreencast:))
	{
		result = [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(showEmailListWindow:))
	{
		result = [KSNetworkNotifier isNetworkAvailable];
	}
	else if (action == @selector(checkForUpdates:))
	{
		result = [KSNetworkNotifier isNetworkAvailable] && [[self sparkleUpdater] validateMenuItem:menuItem];
	}

	return result;
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
#ifdef VARIANT_RELEASE
		|| ( [name isEqualToString:NSRangeException]
			&& NSNotFound != [reason rangeOfString:@"-[NSBigMutableString characterAtIndex:]: Range or index out of bounds"].location )
#endif
		)
	{
		return NO;
	}
	
#ifdef VARIANT_RELEASE
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
//    NSError *underlyingError = [[error userInfo] objectForKey:NSUnderlyingErrorKey];
#ifdef RELEASE
	NSLog(@"Error: %@", [errorDescription condenseWhiteSpace]);
#else
    NSLog(@"Error: %@", errorDescription);
#endif
	
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
		
		// This may or may not be needed, depending on what version of Safari/WebKit is installed in 10.5.7.  But this check
		// will help us to know if we are using an old WebKit.
		//
		// (FWIW, 10.5.7 seems to come with WebKit version 5525.28.3 whatever that means!)
		
		sufficient = [DOMRange instancesRespondToSelector:@selector(intersectsNode:)];
		if (!sufficient)
		{
			NSRunCriticalAlertPanel(
									@"",
									NSLocalizedString(@"You will need to update to a newer version of Safari for this version of Sandvox to function.", @""), 
									NSLocalizedString(@"Quit", @"Quit button"),
									nil,
									nil
									);
			[NSApp terminate:nil];
		}

#ifndef VARIANT_RELEASE
		NSLog(@"BETA: Running build %@", [NSApplication buildVersion]);
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
#if !defined(VARIANT_RELEASE) && defined(EXPIRY_TIMESTAMP)
			[self warnExpiring:nil];
#endif
			// TODO: I've turned off the progress panel for now. In my opinion the app is fast enough to launch now that we don't need the panel. If this is confirmed, take out the panel code completely. Mike.
            
			/*/ put up a splash panel with a progress indicator
			_progressPanel = [[KSProgressPanel alloc] init];
			[_progressPanel setMessageText:NSLocalizedString(@"Initializing…",
															"Message while initializing launching application.")];
			[_progressPanel setInformativeText:nil];
			[_progressPanel makeKeyAndOrderFront:self];*/
			
            
            // Populate the Insert menu
            NSMenuItem *item = nil;
            SVGraphicFactory *factory = nil;
            NSMenu *insertMenu = [oInsertRawHTMLMenuItem menu];
            NSUInteger index = [insertMenu indexOfItem:oInsertRawHTMLMenuItem];
            
            // Raw HTML
            SVGraphicFactory *rawHTMLFactory = [SVGraphicFactory rawHTMLFactory];
            [oInsertRawHTMLMenuItem setTag:[SVGraphicFactory tagForFactory:rawHTMLFactory]];
            [oInsertRawHTMLMenuItem setRepresentedObject:rawHTMLFactory];
            
            // More
            item = [SVGraphicFactory menuItemWithGraphicFactories:[SVGraphicFactory moreGraphicFactories]
															title:NSLocalizedString(@"More", @"menu item")
												  withDescription:NO];
            [[[item submenu] itemArray] makeObjectsPerformSelector:@selector(setImage:)
                                                        withObject:nil];
            [insertMenu insertItem:item atIndex:(index+1)];
            
            // Indexes
            item = [SVGraphicFactory menuItemWithGraphicFactories:[SVGraphicFactory indexFactories]
															title:NSLocalizedString(@"Indexes", "menu item")
												  withDescription:NO];
            [[[item submenu] itemArray] makeObjectsPerformSelector:@selector(setImage:)
                                                        withObject:nil];
            [insertMenu insertItem:item atIndex:index]; 
            
            // Media Placeholder
            factory = [SVGraphicFactory mediaPlaceholderFactory];
            item = [factory makeMenuItemWithDescription:NO];
            [item setImage:nil];
            [insertMenu insertItem:item atIndex:index];
            
            
			// Presets. First needs shortcut
            NSMenu *pageMenu = [oInsertExternalLinkMenuItem menu];
			[SVPageTemplate populateMenu:pageMenu
                       withPageTemplates:[SVPageTemplate pageTemplates]
                                   index:0
                            includeIcons:NO];
            
            [[pageMenu itemAtIndex:0] setKeyEquivalent:@"N"];
            

            // Text box item
            factory = [SVGraphicFactory textBoxFactory];
            item = [factory makeMenuItemWithDescription:NO];
            [item setImage:nil];
            [insertMenu insertItem:item atIndex:index];
            
            
            
            
            
            
			[SVGraphicFactory insertItemsWithGraphicFactories:[SVGraphicFactory moreGraphicFactories]
                                                       inMenu:oMoreGraphicsMenu
                                                      atIndex:0
											  withDescription:NO];
            [SVGraphicFactory insertItemsWithGraphicFactories:[SVGraphicFactory indexFactories]
                                                 inMenu:oIndexesMenu
                                                      atIndex:0
											  withDescription:NO];
				
            
			BOOL firstRun = [defaults boolForKey:@"FirstRun"];
			
			// If there's no docs open, want to see the placeholder window
			if ([[[NSDocumentController sharedDocumentController] documents] count] == 0)
			{
	#if 0
				NSLog(@"BETA: For now, always creating a new document, to make debugging easier");
				[[NSDocumentController sharedDocumentController] newDocument:nil];
	#else
				if (!firstRun)
				{
					[[NSDocumentController sharedDocumentController] showDocumentPlaceholderWindowInitial:!firstRun];	// launching, so try to reopen... unless it's first run.
				}
	#endif
			}
			
			
			// QE check AFTER the welcome message
			[self performSelector:@selector(checkQuartzExtreme) withObject:nil afterDelay:0.0];
		}
	}
	@finally
	{
		//[_progressPanel performClose:self];
	}

	
	// Now that progress pane is gone, we can deal with modal alert
	
	NSNotificationCenter *center = [NSNotificationCenter defaultCenter];

#ifdef OBSERVE_UNDO
	// register for undo notifications so we can log them
	
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

	[center addObserver:self selector:@selector(exceptionReporterFinished:) name:kKSExceptionReporterFinishedNotification object:nil];
	
	// Copy font collection into user's font directory if it's not there
	// Check default first -- that will allow user to change name without it being rewritten
	if (![defaults boolForKey:@"Installed FontCollection 2"])	/// change default key to allow update to happen
	{
		NSString * fontCollection = [[NSBundle mainBundle] pathForResource: @"Web-safe Mac:Windows" ofType: @"collection"];
		NSString* fontCollectionFile = [@"~/Library/FontCollections/Web-safe Mac:Windows.collection" stringByExpandingTildeInPath];
		
		// copy into place even if it exists, so we can replace previous version which should not have included Times
		[fm copyItemAtPath:fontCollection toPath:fontCollectionFile error:NULL];
		
		[defaults setBool:YES forKey:@"Installed FontCollection 2"];
	}
	
	[JSTalk listen];
    
    
    // Preload iPhoto parser for later access to keywords. #16297
    [[IMBLibraryController sharedLibraryControllerWithMediaType:kIMBMediaTypeImage] reload];
    
	
#ifndef VARIANT_RELEASE
	NSLog(@"BETA: Host order = %ld which means %@",
		  NSHostByteOrder() , 
		  (NSHostByteOrder() == NS_LittleEndian) ? @"i386" : @"ppc"
		  );
#endif
	
    _applicationIsLaunching = NO; // we're done
}

- (void) exceptionReporterFinished:(NSNotification *)aNotification
{
	NSLog(@"Problem reported; now quitting.");
	exit(0);
}

- (BOOL) appIsExpired;
{
	if (!_checkedExpiration)
	{
#if !defined(VARIANT_RELEASE) && defined(EXPIRY_TIMESTAMP)
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
							NSLocalizedString(@"Check for Updates", @"button title"),
							nil,
							nil
							);
	
	[[self sparkleUpdater] checkForUpdatesInBackground];	// check Sparkle before alerting
}


- (BOOL) parserController:(IMBParserController*)inController didLoadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType
{
	
	if ([inParser isKindOfClass:[IMBFlickrParser class]])
	{
		// if (IMBRunningOnSnowLeopardOrNewer())
		{
			IMBFlickrParser* flickrParser = (IMBFlickrParser*)inParser;
			flickrParser.delegate = self;
			
			// For your actual app, you would put in the hard-wired strings here.
			
			flickrParser.flickrAPIKey = @"263df73e82720248908c08946c4303ad";		// Karelia's key
			flickrParser.flickrSharedSecret = @"e91e1638196e3c3d";					// Karelia's shared secret
		}
//		else
//		{
//			return NO;		// disable Flickr on Leopard! Crashy!
//		}
		
	}		// end IMBFlickrParser code
	return YES;
}

- (BOOL) parserController:(IMBParserController*)inController shouldLoadParser:(NSString*)inParserClassName forMediaType:(NSString*)inMediaType;
{
	BOOL result = YES;
	
	if ([inParserClassName isEqualToString:@"IMBGarageBandParser"]) result = NO;		// can't process garage band files
	if ([inParserClassName isEqualToString:@"IMBImageCaptureParser"]) result = NO;		// NOT READY FOR PRIME TIME YET.
	
	OFF((@"iMediaBrowser: willUseMediaParser:%@ forMediaType:%@ -> %d", inParserClassName, inMediaType, result));
	return result;
}

- (void) parserController:(IMBParserController*)inController willUnloadParser:(IMBParser*)inParser forMediaType:(NSString*)inMediaType;
{
	OFF((@"iMediaBrowser: willUnloadParser:%@ forMediaType:%@", inParser, inMediaType));
}


- (void)applicationWillFinishLaunching:(NSNotification *)notification
{
	[super applicationWillFinishLaunching:notification];

	/*
	 
	 If/when we want to use the iPhoto parser as a utility to convert useless keyword numbers on the pasteboard
	 from iPhoto, we can use this to get the iPhoto parser to convert.
	 
	NSArray* mediaTypes = [NSArray arrayWithObjects:kIMBMediaTypeImage,kIMBMediaTypeAudio,kIMBMediaTypeMovie,kIMBMediaTypeLink,nil];
	(void) [IMBPanelController sharedPanelControllerWithDelegate:self mediaTypes:mediaTypes];

	IMBParser *iPhotoParser = [[IMBParserController sharedParserController] registeredParserOfClass:@"IMBiPhotoParser" forMediaType:@"image"]; 
	DJW((@"My iphoto parser = %@", iPhotoParser));
	*/
	
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];	// apparently pool may not be in place yet?
	// see http://lapcatsoftware.com/blog/2007/03/10/everything-you-always-wanted-to-know-about-nsapplication/
    
    
    // Enlarge standard URL cache since we're using it to cache scaled images
#define MIN_DISK_CACHE 100000000
    NSURLCache *cache = [NSURLCache sharedURLCache];
    if ([cache diskCapacity] < MIN_DISK_CACHE)
    {
        [cache setDiskCapacity:MIN_DISK_CACHE];
    }


	OBASSERT([NSApp isKindOfClass:[KTApplication class]]);	// make sure we instantiated the right kind of NSApplication subclass
	
	// Create a KTDocumentController instance that will become the "sharedInstance".  Do this early.
	[[[KTDocumentController alloc] init] release];
    
    
	// Autosave frequency
    NSTimeInterval interval = [[[NSUserDefaults standardUserDefaults] valueForKey:@"AutosaveFrequency"] doubleValue];
    if (interval < 5)       interval = 60.0;        // if the number is wildly out of range, go back to our default of 60
    if (interval > 5 * 60)  interval = 60.0;

    KTDocumentController *sharedDocumentController = [KTDocumentController sharedDocumentController];
    [sharedDocumentController setAutosavingDelay:interval];
    
    
    // Prepare iMedia
    [[IMBParserController sharedParserController] setDelegate:self];
	
			 
	// Try to check immediately so we have right info for initialization
	//[self performSelector:@selector(checkRegistrationString:) withObject:nil afterDelay:0.0];
#ifdef APPLE_DESIGN_AWARDS_KEY
#warning -- pre-configuring with registration code for Apple: Apple Design Awards Galilee Cadi Hop
	[self checkRegistrationString:APPLE_DESIGN_AWARDS_KEY];
#else
	[self checkRegistrationString:nil];
#endif

#ifndef NSAppKitVersionNumber10_7
#define NSAppKitVersionNumber10_7 1100  // wild ass guess for now...
#endif
    
    
	// Fix menus appropriately
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
			  | NSFontPanelShadowEffectModeMask		// allow shadows even if it's not going to render on all browsers
			  );
}

#pragma mark -
#pragma mark IBActions

- (IBAction)orderFrontPreferencesPanel:(id)sender
{
    [[KTPrefsController sharedController] showWindow:sender];
}

- (IBAction)emptyCache:(id)sender;
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:NSLocalizedString(@"Are you sure you want to empty the cache?", "alert message")];
    [alert addButtonWithTitle:NSLocalizedString(@"Empty", "button")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", "button")];
    
    if ([alert runModal] == NSAlertFirstButtonReturn)
    {
        [[NSURLCache sharedURLCache] removeAllCachedResponses];
    }
    
    [alert release];
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


- (IBAction) showWelcomeWindow:(id)sender
{
	[[SVWelcomeController sharedController] showWindowAndBringToFront:YES initial:NO];
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
	NSURL *url = [[NSURL URLWithString:@"http://www.sandvox.com/"] ks_URLWithQueryParameters:dict];
    [KSWORKSPACE attemptToOpenWebURL:url];
}

- (IBAction)toggleMediaBrowserShown:(id)sender
{
#ifdef SUPPRESS_IMEDIA_PPC

#ifndef VARIANT_RELEASE
	if (NSHostByteOrder() != NS_LittleEndian)
	{
		NSLog(@"BETA: toggleMediaBrowserShown: should not be allowed!");
	}
#endif

#endif

	NSArray* mediaTypes = [NSArray arrayWithObjects:kIMBMediaTypeImage,kIMBMediaTypeAudio,kIMBMediaTypeMovie,kIMBMediaTypeLink,nil];
	IMBPanelController* panelController = [IMBPanelController sharedPanelControllerWithDelegate:self mediaTypes:mediaTypes];

	if ([panelController respondsToSelector:@selector(infoWindowIsVisible)] &&
        [panelController infoWindowIsVisible])
	{
		[panelController flipBack:nil];
	}

	BOOL newValue = ![[panelController window] isVisible];
	
	// set menu to opposite of flag
	if ( newValue )
	{
		[panelController.window setTitle:NSLocalizedString(@"Media Browser", @"title for window")];
		[panelController showWindow:sender];
	}
	else
	{
		[panelController close];
	}

	// display Media, if appropriate
}

- (IBAction) openScreencast:(id)sender
{
	NSURL *url = [NSURL URLWithString: @"http://distrib.karelia.com/videos/Ch1_through_7.mp4"];
	if  (([[NSApp currentEvent] modifierFlags]&NSAlternateKeyMask) )
	{
		[KSWORKSPACE attemptToOpenWebURL:url];	
	}
	else
	{
		BOOL opened = [KSWORKSPACE openURLs:[NSArray arrayWithObject:url]
									  withAppBundleIdentifier:@"com.apple.QuickTimePlayerX" 
													  options:NSWorkspaceLaunchAsync
							   additionalEventParamDescriptor:nil launchIdentifiers:nil];
		if (!opened)
		{
			opened = [KSWORKSPACE openURLs:[NSArray arrayWithObject:url]
						withAppBundleIdentifier:@"com.apple.quicktimeplayer" 
										options:NSWorkspaceLaunchAsync
				 additionalEventParamDescriptor:nil launchIdentifiers:nil];
			if (!opened)
			{
				// try to open some other way
				[KSWORKSPACE attemptToOpenWebURL:url];	
			}
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
		[KSWORKSPACE attemptToOpenWebURL:urlToOpen];
	}
	else
	{
		[[KTReleaseNotesController sharedController] showWindow:nil];
	}
}


- (IBAction)openSupportForum:(id)sender
{
	
	NSString *urlString = @"http://www.karelia.com/forum/";
	NSURL *url = [NSURL URLWithString:urlString];
	[KSWORKSPACE attemptToOpenWebURL:url];	
}

#if !defined(VARIANT_RELEASE) && defined(EXPIRY_TIMESTAMP)
- (void)warnExpiring:(id)bogus
{
#ifndef DEBUG
    NSString *marketingVersion = [NSApplication marketingVersion];
    NSString *buildVersion = [NSApplication buildVersion];
    
#ifdef VARIANT_BETA
	NSAlert *alert = [NSAlert alertWithMessageText:@"Sandvox Public Beta" 		// Not bothering to localize this beta text.
									 defaultButton:nil 
								   alternateButton:nil 
									   otherButton:nil
						 informativeTextWithFormat:@"You are running Sandvox version %@, build %@.\n\nThis is a Public Beta version and will expire %@. (We will make a new version available by then.)\n\nIf you find problems, please use \"Send Feedback…\" under the Sandvox menu, or email testing@karelia.com.\n\nSince this is BETA software, DO NOT use it with critical data or for critical business functions. Please keep backups of your files and all source material. We cannot guarantee that future versions of Sandvox will be able to open sites created with this version!\n\nUse of this version is subject to the terms and conditions of Karelia Software's Sandvox Beta License Agreement.", marketingVersion, buildVersion, [[NSDate dateWithString:EXPIRY_TIMESTAMP] relativeFormatWithStyle:NSDateFormatterLongStyle options:kLowercaseRelativeDate]];
#endif
#ifdef VARIANT_ALPHA
	NSAlert *alert = [NSAlert alertWithMessageText:@"Sandvox Alpha"		// Not bothering to localize this alpha text.
									 defaultButton:nil 
								   alternateButton:nil 
									   otherButton:nil
						 informativeTextWithFormat:@"You are running Sandvox version %@, build %@.\n\nThis is a private alpha version and will expire %@. (We will make a new version available by then.)\n\nIf you find problems, please use \"Send Feedback…\" under the Sandvox menu, or email testing@karelia.com.\n\nSince this is ALPHA software, DO NOT use it with critical data or for critical business functions. Please keep backups of your files and all source material. We cannot guarantee that future versions of Sandvox will be able to open sites created with this version!\n\nUse of this version is subject to the terms and conditions of Karelia Software's Sandvox Beta License Agreement.", marketingVersion, buildVersion, [[NSDate dateWithString:EXPIRY_TIMESTAMP] relativeFormatWithStyle:NSDateFormatterLongStyle options:kLowercaseRelativeDate]];
#endif
	
	
	
	(void)[alert runModal];
#endif
}
#endif


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
	[self showDebugTableForObject:[KSPlugInWrapper pluginsByIdentifierWithFileExtension:kKTDesignExtension]
                           titled:@"Designs"];
}


- (IBAction)showAvailableComponents:(id)sender
{
	[self showDebugTableForObject:[KSPlugInWrapper pluginsByIdentifierWithFileExtension:kKTElementExtension]
                           titled:@"Available Components: Element Bundles"];
	[self showDebugTableForObject:[KSPlugInWrapper pluginsByIdentifierWithFileExtension:kKTIndexExtension]
							titled:@"Available Components: Index Bundles"];
	[self showDebugTableForObject:[KSPlugInWrapper pluginsByIdentifierWithFileExtension:kKTDesignExtension]
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
