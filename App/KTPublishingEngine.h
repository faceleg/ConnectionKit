//
//  KTExportEngine.h
//  Marvel
//
//  Created by Mike on 12/12/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//
//
//  KTExportEngine provides the publishing functionality for exporting an entire site to a
//  specified directory using CKFileConnection. Its subclass KTPublishingEngine adds to
//  this by offering staleness management and other connection protocols.


#import <Cocoa/Cocoa.h>
#import <Connection/Connection.h>


@class KTDocumentInfo, KTAbstractPage, KTMediaFileUpload;
@protocol KTPublishingEngineDelegate;


@interface KTPublishingEngine : NSObject
{
@private
    KTDocumentInfo	*_documentInfo;
    NSString        *_documentRootPath;
    NSString        *_subfolderPath;    // nil if there is no subfolder
    
    BOOL    _hasStarted;
    BOOL    _hasFinished;
    
    id <KTPublishingEngineDelegate>   _delegate;
    
	id <CKConnection>	_connection;
    CKTransferRecord    *_rootTransferRecord;
    CKTransferRecord    *_baseTransferRecord;
    
    NSMutableSet    *_uploadedMedia;
    NSMutableSet    *_resourceFiles;
}

- (id)initWithSite:(KTDocumentInfo *)site
  documentRootPath:(NSString *)docRoot
     subfolderPath:(NSString *)subfolder;

// Delegate
- (id <KTPublishingEngineDelegate>)delegate;
- (void)setDelegate:(id <KTPublishingEngineDelegate>)delegate;

// Accessors
- (KTDocumentInfo *)site;
- (NSString *)documentRootPath;
- (NSString *)subfolderPath;
- (NSString *)baseRemotePath;

// Control
- (void)start;
- (void)cancel;
- (BOOL)hasStarted;
- (BOOL)hasFinished;

// Connection
- (id <CKConnection>)connection;

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;
- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;

- (CKTransferRecord *)rootTransferRecord;
- (CKTransferRecord *)baseTransferRecord;

// Media
- (NSSet *)uploadedMedia;

// Resources
- (NSSet *)resourceFiles;
- (void)uploadResourceFiles;

@end



@protocol KTPublishingEngineDelegate
- (void)publishingEngineDidFinishGeneratingContent:(KTPublishingEngine *)engine;
- (void)publishingEngineDidUpdateProgress:(KTPublishingEngine *)engine;

- (void)publishingEngineDidFinish:(KTPublishingEngine *)engine;
- (void)publishingEngine:(KTPublishingEngine *)engine didFailWithError:(NSError *)error;
@end


@interface KTPublishingEngine (SubclassSupport)
- (id <CKConnection>)createConnection;

- (BOOL)shouldUploadHTML:(NSString *)HTML encoding:(NSStringEncoding)encoding forPage:(KTAbstractPage *)page toPath:(NSString *)uploadPath digest:(NSData **)outDigest;
- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media;
- (void)uploadGoogleSiteMapIfNeeded;

- (void)didFinish;
@end

