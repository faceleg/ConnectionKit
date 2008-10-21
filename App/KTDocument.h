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

#import "KTDocumentControllerChain.h"


extern NSString *KTDocumentDidChangeNotification;
extern NSString *KTDocumentWillCloseNotification;


extern NSString *KTDocumentWillSaveNotification;


@class KTDocumentInfo, KTMediaManager, KTTransferController, KTStalenessManager;
@class KTDocWindowController, KTHTMLInspectorController;
@class KTAbstractElement, KTPage, KTElementPlugin;


@interface KTDocument : NSPersistentDocument <KTDocumentControllerChain>
{
@private
	
	// Standard document behaviour additions
    BOOL                myIsClosing;
    NSThread    *myThread;
	
    
    // KT
    NSManagedObjectContext		*myManagedObjectContext;
	KTDocumentInfo				*myDocumentInfo;			// accessor in category method
	
	KTMediaManager				*myMediaManager;
	
    KTStalenessManager			*myStalenessManager;
	
	KTDocWindowController		*myDocWindowController;
	KTHTMLInspectorController	*myHTMLInspectorController;
	
	KTTransferController		*myLocalTransferController;
	KTTransferController		*myRemoteTransferController;
	KTTransferController		*myExportTransferController;
					
	
	// UI
	BOOL	myShowDesigns;						// accessor in category method
	BOOL	myDisplaySiteOutline;				// accessor in category method
	BOOL	myDisplaySmallPageIcons;			// accessor in category method
	BOOL	myDisplayStatusBar;					// accessor in category method
	BOOL	myDisplayEditingControls;			// accessor in category method
//	short	mySiteOutlineSize;
	BOOL	myDisplayCodeInjectionWarnings;		// accessor in category method
    
    
    // Saving
    unsigned            mySaveOperationCount;
    NSSaveOperationType myLastSavePanelSaveOperation;
    
    WebView             *_quickLookThumbnailWebView;
    NSLock              *_quickLookThumbnailLock;
}

+ (NSString *)defaultStoreType;
+ (NSString *)defaultMediaStoreType;

+ (NSURL *)datastoreURLForDocumentURL:(NSURL *)inURL UTI:(NSString *)documentUTI;
+ (NSURL *)siteURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)quickLookURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)mediaURLForDocumentURL:(NSURL *)inURL;
+ (NSURL *)mediaStoreURLForDocumentURL:(NSURL *)inURL;
- (NSString *)mediaPath;
- (NSString *)temporaryMediaPath;
- (NSString *)siteDirectoryPath;


- (id)initWithType:(NSString *)type rootPlugin:(KTElementPlugin *)plugin error:(NSError **)error;


- (IBAction)setupHost:(id)sender;
- (IBAction)export:(id)sender;
- (IBAction)exportAgain:(id)sender;
- (IBAction)saveToHost:(id)sender;
- (IBAction)saveAllToHost:(id)sender;

// Controller chain
- (KTDocWindowController *)windowController;

// Upload cache
- (BOOL)createUploadCacheIfNecessary;
- (BOOL)clearUploadCache;
- (NSString *)uploadCachePath;

// backup support
- (BOOL)backupToURL:(NSURL *)anotherPath;
- (NSURL *)backupURL;

- (BOOL)isClosing;

- (IBAction)clearStaleness:(id)sender;
- (IBAction)markAllStale:(id)sender;

- (IBAction)editRawHTMLInSelectedBlock:(id)sender;
- (IBAction)viewPublishedSite:(id)sender;

// Editing

- (void)addScreenshotsToAttachments:(NSMutableArray *)attachments attachmentOwner:(NSString *)attachmentOwner;
- (BOOL)mayAddScreenshotsToAttachments;

- (void)editSourceObject:(NSObject *)aSourceObject keyPath:(NSString *)aKeyPath  isRawHTML:(BOOL)isRawHTML;

@end


@interface KTDocument ( CoreData )

//- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url 
//										   ofType:(NSString *)fileType 
//							   modelConfiguration:(NSString *)configuration 
//									 storeOptions:(NSDictionary *)storeOptions 
//											error:(NSError **)error

// this method is deprecated in Leopard, but we must continue to use its signature for Tiger
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url 
										   ofType:(NSString *)fileType 
											error:(NSError **)error;

// spotlight
- (BOOL)setMetadataForStoreAtURL:(NSURL *)aStoreURL error:(NSError **)outError;

// exception handling
- (void)resetUndoManager;

@end


@interface KTDocument ( Lookup )

// derived properties
- (BOOL)hasRSSFeeds;	// determine if we need to show export panel

- (NSString *)titleHTML;
- (NSString *)siteSubtitleHTML;
- (NSString *)defaultRootPageTitleText;

- (NSString *)language;
- (NSString *)charset;

- (KTPage *)pageForURLPath:(NSString *)path;
@end


@interface KTDocument (Properties)

- (KTMediaManager *)mediaManager;
- (KTStalenessManager *)stalenessManager;

- (NSThread *)thread;
- (void)setThread:(NSThread *)thread;

// export/upload

- (KTTransferController *)exportTransferController;
- (void)setExportTransferController:(KTTransferController *)anExportTransferController;

- (KTTransferController *)localTransferController;
- (KTTransferController *)remoteTransferController;

- (BOOL)connectionsAreConnected;

// support

// these are really for properties stored in defaults
- (id)wrappedInheritedValueForKey:(NSString *)aKey;
//- (void)setWrappedInheritedValue:(id)aValue forKey:(NSString *)aKey;

- (KTDocumentInfo *)documentInfo;
- (void)setDocumentInfo:(KTDocumentInfo *)anObject;

- (KTHTMLInspectorController *)HTMLInspectorController;
- (KTHTMLInspectorController *)HTMLInspectorControllerWithoutLoading;
- (void)setHTMLInspectorController:(KTHTMLInspectorController *)aController;

- (BOOL)showDesigns;
- (void)setShowDesigns:(BOOL)value;

// Display properties
- (BOOL)displayEditingControls;
- (void)setDisplayEditingControls:(BOOL)value;

- (BOOL)displaySiteOutline;
- (void)setDisplaySiteOutline:(BOOL)value;

- (BOOL)displayStatusBar;
- (void)setDisplayStatusBar:(BOOL)value;

- (BOOL)displaySmallPageIcons;
- (void)setDisplaySmallPageIcons:(BOOL)value;

- (NSRect)documentWindowContentRect;

@end


@interface KTDocument (Saving)

- (BOOL)isSaving;

#pragma mark Snapshots
- (IBAction)saveDocumentSnapshot:(id)sender;
- (void)saveSnapshotWithDelegate:(id)delegate didSaveSnapshotSelector:(SEL)selector contextInfo:(void *)contextInfo;
- (BOOL)saveSnapshot:(NSError **)error;

- (IBAction)revertDocumentToSnapshot:(id)sender;

+ (NSURL *)snapshotsDirectoryURL;
- (NSURL *)snapshotDirectoryURL;
- (NSURL *)snapshotURL;

- (BOOL)hasValidSnapshot;
- (NSDate *)lastSnapshotDate;

#pragma mark Other
- (void)processPendingChangesAndClearChangeCount;

@end

