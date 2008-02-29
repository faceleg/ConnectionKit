//
//  KTDocument.h
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

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>



#ifdef APP_RELEASE
	#import "Registration.h"
#endif


// publishing mode
typedef enum {
	kGeneratingPreview = 0,
	kGeneratingLocal,
	kGeneratingRemote,
	kGeneratingRemoteExport,
	kGeneratingQuickLookPreview = 10,
} KTHTMLGenerationPurpose;


// Spotlight metadata keys
extern NSString *kKTMetadataAppVersionKey;
extern NSString *kKTMetadataModelVersionKey;
extern NSString *kKTMetadataPageCountKey;
extern NSString *kKTMetadataSiteAuthorKey;
extern NSString *kKTMetadataSiteTitleKey;

@class KTDocumentInfo, KTMediaManager, KTManagedObjectContext, KTTransferController, KTStalenessManager, CIFilter;
@class KTDocWindowController, KTCodeInjectionController, KTHTMLInspectorController, KTPluginDelegatesManager;
@class KTAbstractElement, KTMediaContainer, KTPage;

@interface KTDocument : NSPersistentDocument
{
	// New docs
	IBOutlet NSView			*oNewDocAccessoryView;
	IBOutlet NSPopUpButton	*oNewDocHomePageTypePopup;
	
	@private
	
	KTManagedObjectContext		*myManagedObjectContext;
	NSManagedObjectModel		*myManagedObjectModel;
	KTDocumentInfo				*myDocumentInfo;
	
	KTDocWindowController		*myDocWindowController;
	
	KTHTMLInspectorController	*myHTMLInspectorController;
	
	KTMediaManager				*myMediaManager;
	BOOL						myShouldUpateMediaStorageAtNextSave;
	
	KTPluginDelegatesManager	*myPluginDelegatesManager;
	KTStalenessManager			*myStalenessManager;
	
	KTTransferController		*myLocalTransferController;
	KTTransferController		*myRemoteTransferController;
	KTTransferController		*myExportTransferController;
	
	KTPage						*myRoot;
	BOOL						myUseAbsoluteMediaPaths;

	NSTimer						*myAutosaveTimer;
	NSDate						*myLastSavedTime;	
		
	BOOL myIsSuspendingAutosave;
	BOOL myIsClosing;
	
	NSString *myDocumentID;
    NSString *mySiteCachePath;
	NSString *mySnapshotPath;
	
	int mySnapshotOrBackupUponFirstSave;
	
	NSMutableDictionary	*myTopSidebarsCache;
	NSMutableDictionary	*myBottomSidebarsCache;
	
	
	// Quick Look thumbnail saving. We have to hang onto these till the webview is laoded.
	WebView				*myQuickLookThumbnailWebView;
	NSURL				*mySavingURL;
	NSString			*mySavingType;
	NSSaveOperationType	mySavingOperationType;
	id					mySavingDelegate;			// weak ref
	SEL					mySavingFinishedSelector;
	void				*mySavingContextInfo;
	
	
	// UI
	BOOL	myShowDesigns;				// is designs panel showing?
	BOOL	myDisplaySiteOutline;
	BOOL	myDisplaySmallPageIcons;
	BOOL	myDisplayStatusBar;
	BOOL	myDisplayEditingControls;
	short	mySiteOutlineSize;
	float	myTextSizeMultiplier;
	BOOL	myDisplayCodeInjectionWarnings;
}

+ (NSString *)defaultStoreType;
+ (NSString *)defaultMediaStoreType;
+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)siteURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)mediaURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)mediaStoreURLForDocumentURL:(NSURL *)inURL;
- (NSString *)mediaPath;
- (NSString *)temporaryMediaPath;
- (NSString *)siteDirectoryPath;

- (IBAction)setupHost:(id)sender;

- (KTDocWindowController *)windowController;
- (NSString *)publishedSiteURL;

// cache support
- (BOOL)createImagesCacheIfNecessary;
- (NSString *)imagesCachePath;
- (NSString *)siteCachePath;

// snapshot support
- (IBAction)saveDocumentSnapshot:(id)sender;
- (IBAction)revertDocumentToSnapshot:(id)sender;

- (BOOL)createSnapshotDirectoryIfNecessary;
- (NSString *)snapshotName;
- (NSString *)snapshotDirectory;
- (NSString *)snapshotPath;
- (BOOL)hasValidSnapshot;

// cover for KTDocWindowController method
- (void)siteStructureChanged;
- (BOOL)isClosing;
- (void)setClosing:(BOOL)aFlag;

- (IBAction)clearStaleness:(id)sender;
- (IBAction)markAllStale:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;
- (IBAction)viewPublishedSite:(id)sender;

// Editing

- (void)editDOMHTMLElement:(DOMHTMLElement *)anElement withTitle:(NSString *)aTitle;
- (void)editKTHTMLElement:(KTAbstractElement *)anElement;

- (void)addScreenshotsToReport:(NSMutableDictionary *)report  attachmentOwner:(NSString *)attachmentOwner;

@end


@interface KTDocument ( Alert )
- (void)delayedAlertSheetWithInfo:(NSDictionary *)anInfoDictionary;
- (void)alertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(id)contextInfo;
@end


@interface KTDocument ( CoreData )

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error;

// backup
- (BOOL)backupPath:(NSString *)aPath toPath:(NSString *)anotherPath;
- (NSString *)backupPathForOriginalPath:(NSString *)aPath;

// snapshots
- (void)snapshotPersistentStore:(id)notUsedButRequiredParameter;
- (void)revertPersistentStoreToSnapshot:(id)notUsedButRequiredParameter;

// spotlight
- (BOOL)setMetadataForStoreAtURL:(NSURL *)aStoreURL;

// support
- (void)processPendingChangesAndClearChangeCount;

// notifications
/// these are now just used for debugging purposes
- (void)observeNotificationsForContext:(KTManagedObjectContext *)aManagedObjectContext;
- (void)removeObserversForContext:(KTManagedObjectContext *)aManagedObjectContext;

// exception handling
- (void)resetUndoManager;

// Export/Publishing pagelet cache
- (NSArray *)cachedAllInheritableTopSidebarsForPage:(KTPage *)page;
- (NSArray *)cachedAllInheritableBottomSidebarsForPage:(KTPage *)page;
- (void)clearInheritedSidebarsCaches;
@end


@interface KTDocument ( Lookup )
// derived properties
- (NSString *)domainNameDashes;
- (NSString *)documentLastBuildDate;
- (NSString *)registrationHash;
- (BOOL)hasRSSFeeds;	// determine if we need to show export panel


- (BOOL)useImageReplacementEntryForDesign:(NSString *)aDesign
								uniqueID:(NSString *)aUniqueID
								  string:(NSString *)aString;
- (void)removeImageReplacementEntryForDesign:(NSString *)aDesign	
								   uniqueID:(NSString *)aUniqueID
									 string:(NSString *)aString;

- (NSData *)generatedCSSForDesignBundleIdentifier:(NSString *)aDesignBundleIdentifier
							 managedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

- (NSString *)generatedGoogleSiteMapWithManagedObjectContext:(KTManagedObjectContext *)aManagedObjectContext;

- (NSMutableDictionary *)imageReplacementRegistry;
- (NSMutableDictionary *)replacementImages;

- (NSString *)absoluteURLForResourceFile:(NSString *)aFile;
- (NSString *)URLForDesignBundleIdentifier:(NSString *)aDesignBundleIdentifier;
- (NSString *)pathForReplacementImageName:(NSString *)anImageName designBundleIdentifier:(NSString *)aDesignBundleIdentifier;
- (NSString *)placeholderImagePathForDesignBundleIdentifier:(NSString *)aDesignBundleIdentifier;

- (NSString *)titleHTML;
- (NSString *)siteSubtitleHTML;
- (NSString *)defaultRootPageTitleText;

- (NSString *)language;
- (NSString *)charset;

- (KTPage *)pageForURLPath:(NSString *)path;
@end


@interface KTDocument ( Properties )

- (KTPluginDelegatesManager *)pluginDelegatesManager;
- (KTStalenessManager *)stalenessManager;

- (BOOL)showDesigns;
- (void)setShowDesigns:(BOOL)value;

- (BOOL)displayEditingControls;
- (void)setDisplayEditingControls:(BOOL)value;

- (BOOL)displaySiteOutline;
- (void)setDisplaySiteOutline:(BOOL)value;

- (BOOL)displayStatusBar;
- (void)setDisplayStatusBar:(BOOL)value;

- (BOOL)displaySmallPageIcons;
- (void)setDisplaySmallPageIcons:(BOOL)value;

- (NSRect)documentWindowContentRect;

- (BOOL)isReadOnly;

- (NSIndexSet *)lastSelectedRows;
- (void)setLastSelectedRows:(NSIndexSet *)value;

- (NSSet *)requiredBundlesIdentifiers;
- (void)setRequiredBundlesIdentifiers:(NSSet *)identifiers;

- (KTPage *)root;
- (void)setRoot:(KTPage *)value;

- (short)sourceOutlineSize;
- (void)setSourceOutlineSize:(short)value;

- (float)textSizeMultiplier;
- (void)setTextSizeMultiplier:(float)value;

- (NSDate *)lastSavedTime;
- (void)setLastSavedTime:(NSDate *)aLastSavedTime;

// export/upload

- (KTTransferController *)exportTransferController;
- (void)setExportTransferController:(KTTransferController *)anExportTransferController;

- (KTTransferController *)localTransferController;
- (KTTransferController *)remoteTransferController;

- (BOOL)connectionsAreConnected;
- (void)terminateConnections;

// support

- (id)wrappedValueForKey:(NSString *)aKey;
- (void)setWrappedValue:(id)aValue forKey:(NSString *)aKey;

// these are really for properties stored in defaults
- (id)wrappedInheritedValueForKey:(NSString *)aKey;
- (void)setWrappedInheritedValue:(id)aValue forKey:(NSString *)aKey;
- (void)setPrimitiveInheritedValue:(id)aValue forKey:(NSString *)aKey;

- (KTDocumentInfo *)documentInfo;
- (void)setDocumentInfo:(KTDocumentInfo *)anObject;

- (NSString *)documentID;		// same as siteID property, always in-memory
- (void)setDocumentID:(NSString *)anID;

- (NSTimer *)autosaveTimer;
- (void)setAutosaveTimer:(NSTimer *)aTimer;

- (BOOL)useAbsoluteMediaPaths;
- (void)setUseAbsoluteMediaPaths:(BOOL)flag;

- (KTHTMLInspectorController *)HTMLInspectorController;
- (void)setHTMLInspectorController:(KTHTMLInspectorController *)aController;
@end


@interface KTDocument (Media)
- (KTMediaManager *)mediaManager;

- (BOOL)upateMediaStorageAtNextSave;
- (void)setUpdateMediaStorageAtNextSave:(BOOL)update;
@end


@interface KTDocument (Saving)
// save/autosave
- (IBAction)autosaveDocument:(id)sender;
- (void)cancelAndInvalidateAutosaveTimers;
- (void)fireAutosave:(id)notUsedButRequiredParameter;
- (void)restartAutosaveTimersIfNecessary;
- (void)resumeAutosave;
- (void)suspendAutosave;
@end
