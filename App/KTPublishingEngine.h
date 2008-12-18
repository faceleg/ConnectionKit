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


extern NSString *KTPublishingEngineErrorDomain;
enum {
	KTPublishingEngineErrorAuthenticationFailed,
	KTPublishingEngineErrorNoCredentialForAuthentication,
	KTPublishingEngineNothingToPublish,
};


@class KTDocumentInfo, KTAbstractPage, KTMediaFileUpload, KTHTMLTextBlock;
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
    
    NSMutableDictionary *_graphicalTextBlocks;
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

// Tranfer records
- (CKTransferRecord *)rootTransferRecord;
- (CKTransferRecord *)baseTransferRecord;

@end



@protocol KTPublishingEngineDelegate
- (void)publishingEngine:(KTPublishingEngine *)engine didBeginUploadToPath:(NSString *)remotePath;
- (void)publishingEngineDidFinishGeneratingContent:(KTPublishingEngine *)engine;
- (void)publishingEngineDidUpdateProgress:(KTPublishingEngine *)engine;

- (void)publishingEngineDidFinish:(KTPublishingEngine *)engine;
- (void)publishingEngine:(KTPublishingEngine *)engine didFailWithError:(NSError *)error;
@end


@interface KTPublishingEngine (SubclassSupport)

// Control
- (void)didFinish;
- (void)failWithError:(NSError *)error;

// Connection
- (id <CKConnection>)connection;
- (id <CKConnection>)createConnection;

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;
- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;

// Pages
- (BOOL)shouldUploadHTML:(NSString *)HTML encoding:(NSStringEncoding)encoding forPage:(KTAbstractPage *)page toPath:(NSString *)uploadPath digest:(NSData **)outDigest;

// Media
- (NSSet *)uploadedMedia;
- (void)uploadMediaIfNeeded:(KTMediaFileUpload *)media;

// Design
- (void)uploadDesignIfNeeded;

- (void)addGraphicalTextBlock:(KTHTMLTextBlock *)textBlock;
- (CKTransferRecord *)uploadMainCSSIfNeeded;
- (BOOL)shouldUploadMainCSSData:(NSData *)mainCSSData digest:(NSData **)outDigest;

// Resources
- (NSSet *)resourceFiles;
- (void)uploadResourceFiles;

@end

