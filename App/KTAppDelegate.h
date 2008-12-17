//
//  KTAppDelegate.h
//  Sandvox
//
//  Copyright (c) 2004-2008, Karelia Software. All rights reserved.
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

#import "Registration.h"
#import <Cocoa/Cocoa.h>
#import "KSLicensedAppDelegate.h"


extern BOOL gWantToCatchSystemExceptions;

// application-wide, so leaving control with AppDelegate
typedef enum {
	KTShowInfoMenuItemTitle,
	KTHideInfoMenuItemTitle
} KTDisplayInfoMenuItemTitleType;

// application-wide, so leaving control with AppDelegate
typedef enum {
	KTShowMediaMenuItemTitle,
	KTHideMediaMenuItemTitle
} KTDisplayMediaMenuItemTitleType;

enum { KTNoBackupOnOpening = 0, KTBackupOnOpening, KTSnapshotOnOpening }; // tags for IB

@class KTDocument, KTDocumentController;
@interface KTAppDelegate : KSLicensedAppDelegate
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
	IBOutlet NSMenuItem		*oJoinListMenuItem;
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
	IBOutlet NSMenuItem		*oReleaseNotesMenuItem;
	IBOutlet NSMenuItem		*oAcknowledgementsMenuItem;
	IBOutlet NSMenuItem		*oSendFeedbackMenuItem;
	IBOutlet NSMenuItem		*oProductPageMenuItem;


    // we have pages and collections (summary pages)
    IBOutlet NSMenu			*oAddPageMenu;
    IBOutlet NSMenu			*oAddCollectionMenu;
    IBOutlet NSMenu			*oAddPageletMenu;
	

	IBOutlet NSTableView	*oDebugTable;
	IBOutlet NSPanel		*oDebugMediaPanel;
	
    // ivars
	KTDocumentController	*myDocumentController;
	
    BOOL myApplicationIsLaunching;
	
	BOOL myKTDidAwake;
	BOOL myAppIsTerminating;
	
	NSPoint myCascadePoint;
}

- (IBAction) openHigh:(id)sender;
- (IBAction) openLow:(id)sender;

+ (void) registerDefaults;
+ (BOOL) coreImageAccelerated;
+ (BOOL) fastEnoughProcessor;

- (KTDocument *)currentDocument;

- (IBAction)openSampleDocument:(id)sender;

- (IBAction)orderFrontPreferencesPanel:(id)sender;
- (IBAction)saveWindowSize:(id)sender;

- (IBAction)showAvailableComponents:(id)sender;
- (IBAction)showAcknowledgments:(id)sender;
- (IBAction)showReleaseNotes:(id)sender;
- (IBAction)showTranscriptWindow:(id)sender;
- (IBAction)showAvailableMedia:(id)sender;
- (IBAction)showAvailableDesigns:(id)sender;

- (IBAction)showProductPage:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;

- (IBAction)toggleMediaBrowserShown:(id)sender;

- (IBAction)reloadDebugTable:(id)sender;

// methods to allow current document to update menus
//- (void)setCutMenuItemTitle:(KTCutMenuItemTitleType)aKTCutMenuItemTitleType;
//- (void)setCutPagesMenuItemTitle:(KTCutMenuItemTitleType)aKTCutMenuItemTitleType;
//- (void)setCopyMenuItemTitle:(KTCopyMenuItemTitleType)aKTCopyMenuItemTitleType;
//- (void)setCopyPagesMenuItemTitle:(KTCopyMenuItemTitleType)aKTCopyMenuItemTitleType;
//- (void)setDeletePagesMenuItemTitle:(KTDeletePagesMenuItemTitleType)aKTDeletePagesMenuItemTitleType;
//
//- (void)setCreateLinkMenuItemTitle:(KTCreateLinkMenuItemTitleType)aKTCreateLinkMenuItemTitleType;
//- (void)setCreateLinkToolbarItemTitle:(KTCreateLinkMenuItemTitleType)aKTCreateLinkMenuItemTitleType;

- (void)setDisplayMediaMenuItemTitle:(KTDisplayMediaMenuItemTitleType)aKTDisplayMediaMenuItemTitleType;
- (void)setDisplayInfoMenuItemTitle:(KTDisplayInfoMenuItemTitleType)aKTDisplayInfoMenuItemTitleType;

// backups and snapshots
- (BOOL)shouldBackupOnOpening;
- (BOOL)shouldSnapshotOnOpening;
- (void)revertDocument:(KTDocument *)aDocument toSnapshot:(NSString *)aPath;

@end
