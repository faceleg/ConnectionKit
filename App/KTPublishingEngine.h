//
//  KTExportEngine.h
//  Marvel
//
//  Created by Mike on 12/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//


/*  KTPublishingEngine is an abstract class that provides the general publishing functionality.
 *  It has 2 concrete subclasses, both of which publish to the local file system:
 *
 *      A)  KTExportEngine provides support for simply exporting an entire site.
 *
 *      B)  KTLocalPublishingEngine adds support for staleness management and pinging a server etc.
 *          after publishing is complete. KTLocalPublishingEngine has further subclasses to support
 *          remote publishing.
 */


#import <Cocoa/Cocoa.h>
#import <Connection/Connection.h>
#import "SVPublisher.h"


extern int kMaxNumberOfFreePublishedPages;


#pragma mark -


extern NSString *KTPublishingEngineErrorDomain;
enum {
	KTPublishingEngineErrorAuthenticationFailed,
	KTPublishingEngineErrorNoCredentialForAuthentication,
	KTPublishingEngineNothingToPublish,
};

typedef enum {
    KTPublishingEngineStatusNotStarted,
    KTPublishingEngineStatusGatheringMedia,
    KTPublishingEngineStatusParsing,        // Pages are being parsed one-by-one
    KTPublishingEngineStatusLoadingMedia,   // Parsing has finished, but there is still media to load
    KTPublishingEngineStatusUploading,      // All content has been generated, just waiting for queued uploads now
    KTPublishingEngineStatusFinished,
} KTPublishingEngineStatus;

@class KTSite, KTPage, SVHTMLTextBlock, KSSimpleURLConnection, SVHTMLTemplateParser;
@protocol KTPublishingEngineDelegate;


@interface KTPublishingEngine : NSOperation <SVPublisher>
{
  @private
    KTSite      *_site;
    NSString    *_documentRootPath;
    NSString    *_subfolderPath;    // nil if there is no subfolder
    
    KTPublishingEngineStatus            _status;
    id <KTPublishingEngineDelegate>     _delegate;
    
	id <CKConnection>	_connection;
    CKTransferRecord    *_rootTransferRecord;
    CKTransferRecord    *_baseTransferRecord;
    
    NSMutableSet    *_paths;    // all the paths which are in use by the site
    
    NSMutableDictionary *_uploadedMediaReps;
    NSMutableArray      *_newMedia;
    
    NSMutableArray      *_plugInCSS;    // mixture of string CSS snippets, and CSS URLs
}

- (id)initWithSite:(KTSite *)site
  documentRootPath:(NSString *)docRoot
     subfolderPath:(NSString *)subfolder;

// Delegate
- (id <KTPublishingEngineDelegate>)delegate;
- (void)setDelegate:(id <KTPublishingEngineDelegate>)delegate;

// Accessors
- (KTSite *)site;
- (NSString *)documentRootPath;
- (NSString *)subfolderPath;
- (NSString *)baseRemotePath;

// Control
- (KTPublishingEngineStatus)status;

// Tranfer records
- (CKTransferRecord *)rootTransferRecord;
- (CKTransferRecord *)baseTransferRecord;


#pragma mark Uploads
- (CKTransferRecord *)willUploadToPath:(NSString *)path;  // for subclasses. Returns parent dir
- (void)didEnqueueUpload:(CKTransferRecord *)record
                  toPath:(NSString *)path
        cachedSHA1Digest:(NSData *)digest
             contentHash:(NSData *)contentHash;


#pragma mark Publishing Records
- (NSString *)pathForFileWithSHA1Digest:(NSData *)digest;


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
- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error;

// Connection
- (id <CKConnection>)connection;
- (void)setConnection:(id <CKConnection>)connection;
- (void)createConnection;


@end

