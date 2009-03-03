//
//  KTAppDelegate.h
//  Sandvox
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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

@class KTDocument;
@interface KTAppDelegate : KSLicensedAppDelegate
{
    // IBOutlets
    IBOutlet NSMenuItem     *oToggleInfoMenuItem; // used
    IBOutlet NSMenuItem     *oToggleMediaMenuItem; // used
	
	// Pro menu items
	IBOutlet NSMenuItem		*oPasteAsMarkupMenuItem;
	IBOutlet NSMenuItem		*oEditRawHTMLMenuItem;
	IBOutlet NSMenuItem		*oFindSeparator;
	IBOutlet NSMenuItem		*oFindSubmenu;
	
	IBOutlet NSMenuItem		*oCodeInjectionMenuItem;
	IBOutlet NSMenuItem		*oCodeInjectionLevelMenuItem;
	IBOutlet NSMenuItem		*oCodeInjectionSeparator;
	
    IBOutlet NSMenuItem		*oAdvancedMenu;		// the main submenu
	
	// below are outlets of items on that menu
	
	IBOutlet NSMenuItem		*oStandardViewMenuItem;
	IBOutlet NSMenuItem		*oStandardViewWithoutStylesMenuItem;
	IBOutlet NSMenuItem		*oSourceViewMenuItem;
	IBOutlet NSMenuItem		*oDOMViewMenuItem;
	IBOutlet NSMenuItem		*oRSSViewMenuItem;
	IBOutlet NSMenuItem		*oValidateSourceViewMenuItem;

	// do we need this?
	IBOutlet NSMenuItem		*oInstallPluginsMenuItem;
	
    // we have pages and collections (summary pages)
    IBOutlet NSMenu			*oAddPageMenu;
    IBOutlet NSMenu			*oAddCollectionMenu;
    IBOutlet NSMenu			*oAddPageletMenu;
	
	IBOutlet NSTableView	*oDebugTable;
	IBOutlet NSPanel		*oDebugMediaPanel;
	
    // ivars	
    BOOL myApplicationIsLaunching;
	
	BOOL myKTDidAwake;
	BOOL myAppIsTerminating;
	
	NSPoint myCascadePoint;
}

- (IBAction) openScreencastLargeSize:(id)sender;
- (IBAction) openScreencastSmallSize:(id)sender;

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

// methods to allow current document to update application-wide menus
- (void)setDisplayMediaMenuItemTitle:(KTDisplayMediaMenuItemTitleType)aKTDisplayMediaMenuItemTitleType;
- (void)setDisplayInfoMenuItemTitle:(KTDisplayInfoMenuItemTitleType)aKTDisplayInfoMenuItemTitleType;

// backups and snapshots
- (BOOL)shouldBackupOnOpening;
- (BOOL)shouldSnapshotOnOpening;
- (void)revertDocument:(KTDocument *)aDocument toSnapshot:(NSString *)aPath;

@end
