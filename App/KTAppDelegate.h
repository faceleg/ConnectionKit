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
#import "KSPluginInstallerController.h"

extern BOOL gWantToCatchSystemExceptions;

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
	
	BOOL myAppIsTerminating;
	
	NSPoint myCascadePoint;
}

- (NSArray *) additionalPluginDictionaryForInstallerController:(KSPluginInstallerController *)controller;

- (IBAction) openScreencastLargeSize:(id)sender;
- (IBAction) openScreencastSmallSize:(id)sender;

+ (void) registerDefaults;
+ (BOOL) coreImageAccelerated;
+ (BOOL) fastEnoughProcessor;

- (IBAction)orderFrontPreferencesPanel:(id)sender;
- (IBAction)saveWindowSize:(id)sender;

- (IBAction)showAvailableComponents:(id)sender;
- (IBAction)showAcknowledgments:(id)sender;
- (IBAction)showReleaseNotes:(id)sender;
- (IBAction)showTranscriptWindow:(id)sender;
- (IBAction)showAvailableDesigns:(id)sender;

- (IBAction)showProductPage:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;

- (IBAction)toggleMediaBrowserShown:(id)sender;

- (IBAction)reloadDebugTable:(id)sender;

- (IBAction)showPluginWindow:(id)sender;

@end
