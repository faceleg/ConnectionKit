//
//  KTTransferController.h
//  Marvel
//
//  Created by Dan Wood on 11/23/04.
//  Copyright 2004 B, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <Connection/Connection.h>
#import <Growl/GrowlApplicationBridge.h>


@class KTDocument;

@protocol GrowlApplicationBridgeDelegate, CKConnection;


@interface KTTransferController : NSWindowController <GrowlApplicationBridgeDelegate>
{
	KTDocument *myAssociatedDocumentWeakRef;	// don't use document method; that implies a window controller - NSDocument relationship.
	
	id <CKConnection> myConnection;
	CKTransferController *myController;
	
	NSString *myDocumentRoot;
	NSString *mySubfolder;
	
	unsigned long myPagePermissions;
	unsigned long myDirectoryPermissions;
	NSString *myPublishedURL;
	int myWhere;
	
	BOOL myDoGrowl;
	BOOL myKeepPublishing;
	BOOL myHadFilesToUpload;
	BOOL myPanelIsDisplayed;
	BOOL myInspectorWasDisplayed;
	BOOL mySuspended;

	NSInvocation *myContentAction;
	
	NSMutableDictionary *myUploadedPageDataDigests;
	NSMutableDictionary *myUploadedPagesByPath;
	NSMutableSet		*myUploadedDesigns;
	NSMutableArray		*myPathsCreated;	
	
	NSMutableSet		*myParsedMediaFileUploads;
	NSMutableSet		*myMediaFileUploads;
	
	NSMutableSet		*myParsedResources;
	NSMutableDictionary	*myParsedGraphicalTextBlocks;
			
	// Export Save Panel
	IBOutlet NSView			*oExportPanelAccessoryView;
	IBOutlet NSTextField	*oExportURL;
	IBOutlet NSImageView	*oBadSiteURL;
}

- (id)initWithAssociatedDocument:(KTDocument *)aDocument where:(int)aWhere;

- (KTDocument *)associatedDocument;
- (void)setAssociatedDocument:(KTDocument *)anAssociatedDocument;

- (void)uploadEverything;
- (void)uploadEverythingToSuggestedPath:(NSString *)aSuggestedPath;

- (void)uploadStaleAssets;
- (void)uploadStaleAssetsToSuggestedPath:(NSString *)aSuggestedPath;

- (int)where;
- (void)setWhere:(int)aWhere;

- (NSString *)documentRoot;
- (NSString *)subfolder;
- (NSString *)storagePath;
//- (void)setStoragePath:(NSString *)aStoragePath;

- (void)setConnection:(id <CKConnection>)connection;
- (id <CKConnection>)connection;
- (void)terminateConnection;

- (IBAction)finishTransferAndCloseSheet:(id)sender;
- (void)showIndeterminateProgressWithStatus:(NSString *)msg;

- (NSSet *)uploadedDesigns;

// Upload cache
- (BOOL)createUploadCacheIfNecessary;
- (BOOL)clearUploadCache;
- (NSString *)uploadCachePath;

@end
