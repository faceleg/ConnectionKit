//
//  KTAppDelegate.h
//  Sandvox
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
//
//  THIS SOFTWARE IS PROVIDED BY KARELIA SOFTWARE AND ITS CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//

#ifdef SANDVOX_RELEASE
    #import "Registration.h"
#endif

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import "KSAppDelegate.h"

extern BOOL gWantToCatchSystemExceptions;

typedef enum {
    KTCutMenuItemTitle,
	KTCutPageMenuItemTitle,
	KTCutPagesMenuItemTitle
} KTCutMenuItemTitleType;

typedef enum {
    KTCopyMenuItemTitle,
	KTCopyPageMenuItemTitle,
	KTCopyPagesMenuItemTitle
} KTCopyMenuItemTitleType;

typedef enum {
	KTDeleteCollectionMenuItemTitle,
    KTDeletePageMenuItemTitle,
	KTDeletePagesMenuItemTitle
} KTDeletePagesMenuItemTitleType;

typedef enum {
	KTCreateLinkMenuItemTitle,
	KTEditLinkMenuItemTitle,
	KTCreateLinkDisabledMenuItemTitle
} KTCreateLinkMenuItemTitleType;

typedef enum {
	KTShowInfoMenuItemTitle,
	KTHideInfoMenuItemTitle
} KTDisplayInfoMenuItemTitleType;

typedef enum {
	KTShowMediaMenuItemTitle,
	KTHideMediaMenuItemTitle
} KTDisplayMediaMenuItemTitleType;

enum { KTNoBackupOnOpening = 0, KTBackupOnOpening, KTSnapshotOnOpening }; // tags for IB

extern NSThread *gMainThread;

#define CUT_MENUITEM_TITLE					NSLocalizedString(@"Cut", "Cut MenuItem")
#define CUT_PAGE_MENUITEM_TITLE				NSLocalizedString(@"Cut Page", "Cut Page MenuItem")
#define CUT_PAGES_MENUITEM_TITLE			NSLocalizedString(@"Cut Pages", "Cut Pages MenuItem")

#define COPY_MENUITEM_TITLE					NSLocalizedString(@"Copy", "Copy MenuItem")
#define COPY_PAGE_MENUITEM_TITLE			NSLocalizedString(@"Copy Page", "Copy Page MenuItem")
#define COPY_PAGES_MENUITEM_TITLE			NSLocalizedString(@"Copy Pages", "Copy Pages MenuItem")

#define DELETE_COLLECTION_MENUITEM_TITLE	NSLocalizedString(@"Delete Collection", "Delete Collection MenuItem")
#define DELETE_PAGE_MENUITEM_TITLE			NSLocalizedString(@"Delete Page", "Delete Page MenuItem")
#define DELETE_PAGES_MENUITEM_TITLE			NSLocalizedString(@"Delete Pages", "Delete Pages MenuItem")

#define CREATE_LINK_MENUITEM_TITLE			NSLocalizedString(@"Create Link...", "Create Link... MenuItem")
#define EDIT_LINK_MENUITEM_TITLE			NSLocalizedString(@"Edit Link...", "Edit Link... MenuItem")

#define CREATE_LINK_TOOLBARITEM_TITLE		NSLocalizedString(@"Create Link...", "Create Link... ToolbarItem")
#define EDIT_LINK_TOOLBARITEM_TITLE			NSLocalizedString(@"Edit Link...", "Edit Link... ToolbarItem")

@class KTDocument, KTDocumentController, KTBundleManager, KTDesignManager, KTPrefsController, KTFeedbackReporter;

@interface KTAppDelegate : KSAppDelegate <SUStatusCheckerDelegate>
{
    // IBOutlets
    IBOutlet NSMenuItem     *oToggleAddressBarMenuItem;
    IBOutlet NSMenuItem     *oToggleStatusBarMenuItem;
    IBOutlet NSMenuItem     *oToggleEditingControlsMenuItem;
    IBOutlet NSMenuItem     *oToggleInfoMenuItem;
    IBOutlet NSMenuItem     *oToggleMediaMenuItem;
	IBOutlet NSMenuItem		*oToggleSiteOutlineMenuItem;
    IBOutlet NSMenuItem     *oToggleSmallPageIconsMenuItem;
	IBOutlet NSMenuItem     *oMakeTextLargerMenuItem;
   	IBOutlet NSMenuItem     *oMakeTextSmallerMenuItem;
   	IBOutlet NSMenuItem     *oMakeTextNormalMenuItem;
	
	IBOutlet NSMenuItem		*oSaveMenuItem;
	
	IBOutlet NSMenuItem		*oCutMenuItem;
	IBOutlet NSMenuItem		*oCutPagesMenuItem;
	IBOutlet NSMenuItem		*oCopyMenuItem;
	IBOutlet NSMenuItem		*oCopyPagesMenuItem;
	
	IBOutlet NSMenuItem		*oDeletePagesMenuItem;
	IBOutlet NSMenuItem		*oDeletePageletsMenuItem;
	
	IBOutlet NSMenuItem		*oDuplicateMenuItem;
	
	IBOutlet NSMenuItem		*oOpenSampleSiteMenuItem;
	
	IBOutlet NSMenuItem		*oCreateLinkMenuItem;
	IBOutlet NSMenuItem		*oPasteAsMarkupMenuItem;

    IBOutlet NSMenuItem		*oAdvancedMenu;		// the main submenu
	
	// below are outlets of items on that menu
	
	IBOutlet NSMenuItem		*oStandardViewMenuItem;
	IBOutlet NSMenuItem		*oStandardViewWithoutStylesMenuItem;
	IBOutlet NSMenuItem		*oSourceViewMenuItem;
	IBOutlet NSMenuItem		*oDOMViewMenuItem;
	IBOutlet NSMenuItem		*oRSSViewMenuItem;
	
	// Menus needing network connection (or nearby items in help menu)
	IBOutlet NSMenuItem		*oValidateSourceViewMenuItem;
	IBOutlet NSMenuItem		*oBuyRegisterSandvoxMenuItem;
	IBOutlet NSMenuItem		*oSetupHostMenuItem;
	IBOutlet NSMenuItem		*oExportSiteMenuItem;
	IBOutlet NSMenuItem		*oExportSiteAgainMenuItem;
	IBOutlet NSMenuItem		*oPublishChangesMenuItem;
	IBOutlet NSMenuItem		*oPublishEntireSiteMenuItem;
	
	IBOutlet NSMenuItem		*oCheckForUpdatesMenuItem;
	IBOutlet NSMenuItem		*oInstallPluginsMenuItem;
	
	IBOutlet NSMenuItem		*oEditRawHTMLMenuItem;
	IBOutlet NSMenuItem		*oFindSubmenu;
	IBOutlet NSMenuItem		*oFindSeparator;
	
	IBOutlet NSMenuItem		*oCodeInjectionMenuItem;
	IBOutlet NSMenuItem		*oCodeInjectionLevelMenuItem;
	IBOutlet NSMenuItem		*oCodeInjectionSeparator;
	IBOutlet NSMenuItem		*oViewPublishedSiteMenuItem;
	
	IBOutlet NSMenuItem		*oSandvoxHelpMenuItem;
	IBOutlet NSMenuItem		*oSandvoxQuickStartMenuItem;
	IBOutlet NSMenuItem		*oVideoIntroductionMenuItem;
	IBOutlet NSMenuItem		*oLatestNewsMenuItem;
	IBOutlet NSMenuItem		*oReleaseNotesMenuItem;
	IBOutlet NSMenuItem		*oAcknowledgementsMenuItem;
	IBOutlet NSMenuItem		*oSendFeedbackMenuItem;
	IBOutlet NSMenuItem		*oProductPageMenuItem;

    IBOutlet NSView                 *oGenericProgressView;
    IBOutlet NSTextField            *oGenericProgressTextField;
    IBOutlet NSProgressIndicator    *oGenericProgressIndicator;
    IBOutlet NSImageView			*oGenericProgressImageView;

    // we have pages and collections (summary pages)
    IBOutlet NSMenu			*oAddPageMenu;
    IBOutlet NSMenu			*oAddCollectionMenu;
    IBOutlet NSMenu			*oAddPageletMenu;
	
	IBOutlet NSMenu			*oDebugMenu;

	IBOutlet NSTableView	*oDebugTable;
	IBOutlet NSPanel		*oDebugMediaPanel;
	
	NSPoint myCascadePoint;

    // ivars
    KTBundleManager         *myBundleManager;
	KTDesignManager         *myDesignManager;
	NSMutableData			*myHomeBaseConnectionData;
	NSDictionary			*myHomeBaseDict;

    NSPanel                 *myGenericProgressPanel;
	//KTDocument				*myCurrentDocument;
	
	KTDocumentController	*myDocumentController;
	
	KTFeedbackReporter		*myFeedbackReporter;

    BOOL applicationIsLaunching;
	
	NSString *myNewVersionString;
	NSString *myNewFeatures;
	NSURL *myCurrentAppDownloadURL;
	BOOL myNewsHasChanged;
	
	BOOL myDidAwake;
	BOOL myAppIsTerminating;
	BOOL myHandlingExceptionAlready;

	NSTimer					*mNewsTimer;
	
	
	// NSNetServices
	NSNetServiceBrowser *myNetServiceBrowser;
	NSSocketPort *myNetServicePort;
	NSNetService *myNetService;
	NSString *myNetServiceName;
	NSMutableSet *mySimilarLicenses;
}


- (IBAction) crash:(id)sender;
- (IBAction) generateException:(id)sender;
- (IBAction) reportLatestCrash:(id)sender;
- (IBAction) openHigh:(id)sender;
- (IBAction) openLow:(id)sender;

+ (KTAppDelegate *)sharedInstance;
+ (void) registerDefaults;
+ (BOOL) coreImageAccelerated;
+ (BOOL) fastEnoughProcessor;

- (KTBundleManager *)bundleManager;

- (KTDocument *)currentDocument;
//- (void)setCurrentDocument:(KTDocument *)aDocument;

- (void)updateMenusForDocument:(KTDocument *)aDocument;

- (NSString *)newVersionString;
- (void)setNewVersionString:(NSString *)aNewVersionString;

- (NSString *)newFeatures;
- (void)setNewFeatures:(NSString *)aNewFeatures;

- (NSURL *)currentAppDownloadURL;
- (void)setCurrentAppDownloadURL:(NSURL *)aCurrentAppDownloadURL;

- (BOOL)newsHasChanged;
- (void)setNewsHasChanged:(BOOL)flag;

- (IBAction)toggleLogAllContextChanges:(id)sender;
- (BOOL)logAllContextChanges;

- (BOOL)appIsTerminating;

//- (NSDictionary *)compositeDocumentModel;

- (void) checkRegistrationString:(NSString *)aString;
- (NSString *)registrationReport;

- (KTDocument *)documentWithID:(NSString *)anID;


- (IBAction)openSampleDocument:(id)sender;

- (IBAction)orderFrontLicensingPanel:(id)sender;
- (IBAction)orderFrontPreferencesPanel:(id)sender;
- (IBAction)saveWindowSize:(id)sender;

- (IBAction)showAvailableComponents:(id)sender;
- (IBAction)showNewsWindow:(id)sender;
- (IBAction)showTranscriptWindow:(id)sender;
- (IBAction)getUpdatedApplication:(id)sender;
- (IBAction)showRegistrationWindow:(id)sender;
- (IBAction)showPluginWindow:(id)sender;
- (IBAction)showAvailableMedia:(id)sender;
- (IBAction)showAvailableDesigns:(id)sender;

- (IBAction)showAcknowledgments:(id)sender;
- (IBAction)showDiscussionGroup:(id)sender;
- (IBAction)showProductPage:(id)sender;
- (IBAction)showReleaseNotes:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;
- (IBAction)viewPublishedSite:(id)sender;

- (IBAction)toggleMediaBrowserShown:(id)sender;

- (IBAction)reloadDebugTable:(id)sender;

- (KTDesignManager *)designManager;
- (BOOL) isPro;

- (NSDictionary *)homeBaseDict;
- (void)setHomeBaseDict:(NSDictionary *)aHomeBaseDict;

- (void)showGenericProgressPanelWithMessage:(NSString *)aString image:(NSImage *)anImage;
- (void)updateGenericProgressPanelWithMessage:(NSString *)aString;
- (void)hideGenericProgressPanel;

// methods to allow current document to update menus
- (void)setCutMenuItemTitle:(KTCutMenuItemTitleType)aKTCutMenuItemTitleType;
- (void)setCutPagesMenuItemTitle:(KTCutMenuItemTitleType)aKTCutMenuItemTitleType;
- (void)setCopyMenuItemTitle:(KTCopyMenuItemTitleType)aKTCopyMenuItemTitleType;
- (void)setCopyPagesMenuItemTitle:(KTCopyMenuItemTitleType)aKTCopyMenuItemTitleType;
- (void)setDeletePagesMenuItemTitle:(KTDeletePagesMenuItemTitleType)aKTDeletePagesMenuItemTitleType;

- (void)setCreateLinkMenuItemTitle:(KTCreateLinkMenuItemTitleType)aKTCreateLinkMenuItemTitleType;
- (void)setCreateLinkToolbarItemTitle:(KTCreateLinkMenuItemTitleType)aKTCreateLinkMenuItemTitleType;

- (void)setDisplayMediaMenuItemTitle:(KTDisplayMediaMenuItemTitleType)aKTDisplayMediaMenuItemTitleType;
- (void)setDisplayInfoMenuItemTitle:(KTDisplayInfoMenuItemTitleType)aKTDisplayInfoMenuItemTitleType;

- (void)updateLastOpened;

- (void)updateDuplicateMenuItemForDocument:(KTDocument *)aDocument;

- (BOOL)shouldBackupOnOpening;
- (BOOL)shouldSnapshotOnOpening;
- (void)revertDocument:(KTDocument *)aDocument toSnapshot:(NSString *)aPath;

- (NSThread *)mainThread;

- (void)checkPlaceholderWindow:(id)bogus;

- (void)setMenuItemPro:(NSMenuItem *)aMenuItem;

@end

