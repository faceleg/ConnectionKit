//
//  KTAppDelegate.h
//  Sandvox
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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

#import "KSLicensedAppDelegate.h"
#import <iMedia/iMedia.h>

extern BOOL gWantToCatchSystemExceptions;


extern NSString *kSVOpenDocumentsKey;
extern NSString *kSVLiveDataFeedsKey;
extern NSString *kSVSetDateFromSourceMaterialKey;
extern NSString *kLiveEditableAndSelectableLinksDefaultsKey;

extern NSString *kSVPrefersPNGImageFormatKey;
extern NSString *kSVPreferredImageCompressionFactorKey;


enum { KTNoBackupOnOpening = 0, KTBackupOnOpening, KTSnapshotOnOpening }; // tags for IB


@class KTDocument, KSProgressPanel, KSPluginInstallerController;

@interface SVApplicationController : KSLicensedAppDelegate <IMBParserControllerDelegate>
{	
	IBOutlet NSMenuItem		*oInsertRawHTMLMenuItem;		// put other graphics after this item		
	IBOutlet NSMenuItem		*oInsertExternalLinkMenuItem;	// put page submenu after this
	IBOutlet NSMenuItem		*oAboutSandvoxMenuItem;			// put Sparkle Item after this
	IBOutlet NSMenuItem		*oPreferencesMenuItem;			// put Separator, then Buy/Register Sandvox after this
	IBOutlet NSMenuItem		*oToggleFullScreenMenuItem;		// Remove this, and the separator after it
    
#ifndef MAC_APP_STORE
	SUUpdater *_sparkleUpdater;
#endif
	
    // ivars	
    BOOL _applicationIsLaunching;
	BOOL _appIsTerminating;
	BOOL _appIsExpired;
	BOOL _checkedExpiration;
			
	NSPoint _cascadePoint;
}

- (NSArray *) additionalPluginDictionaryForInstallerController:(KSPluginInstallerController *)controller;

- (IBAction) openScreencast:(id)sender;

+ (void) registerDefaults;
+ (BOOL) coreImageAccelerated;
+ (BOOL) fastEnoughProcessor;
- (BOOL) appIsExpired;

- (IBAction)orderFrontPreferencesPanel:(id)sender;
- (IBAction)emptyCache:(id)sender;
- (IBAction)saveWindowSize:(id)sender;

- (IBAction)showAcknowledgments:(id)sender;
- (IBAction)showReleaseNotes:(id)sender;
- (IBAction)showTranscriptWindow:(id)sender;
- (IBAction) showWelcomeWindow:(id)sender;

- (IBAction)showProductPage:(id)sender;

- (IBAction)toggleMediaBrowserShown:(id)sender;

- (IBAction)showPluginWindow:(id)sender;

- (NSString *)appRegCode;		// for use by JoinListController

#ifndef MAC_APP_STORE
@property (retain) SUUpdater *sparkleUpdater;
#endif

@end
