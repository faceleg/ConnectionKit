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

extern int kMaxNumberOfFreePublishedPages;

@class SVHTMLContext, SVMediaRepresentation;


@protocol SVPublisher <NSObject>

#pragma mark HTML
// When you want to publish HTML, call -beginPublishingHTMLToPath: to obtain a context to write into. It will be correctly set up to handle linking in media etc. Call -close on the context once you're done to let the publishing engine know there will be no more HTML coming.
- (SVHTMLContext *)beginPublishingHTMLToPath:(NSString *)path;


#pragma mark Media
- (NSString *)publishMediaRepresentation:(SVMediaRepresentation *)mediaRep;


#pragma mark Resource Files
- (NSString *)publishResourceAtURL:(NSURL *)fileURL;


#pragma mark Design
- (void)addCSSString:(NSString *)css;
- (void)addCSSWithURL:(NSURL *)cssURL;  // same terminology as SVHTMLContext
//- (void)addGraphicalText:(NSString *)text code:(NSString *)code;


#pragma mark Raw
// Call if you need to publish a raw resource. Publishing engine will take care of creating directories, permissions, etc. for you
- (CKTransferRecord *)publishContentsOfURL:(NSURL *)localURL toPath:(NSString *)remotePath;
- (CKTransferRecord *)publishData:(NSData *)data toPath:(NSString *)remotePath;

- (NSString *)baseRemotePath;


@end


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

@class KTSite, KTPage, SVHTMLTextBlock, KSSimpleURLConnection;
@protocol KTPublishingEngineDelegate;


@interface KTPublishingEngine : NSOperation <SVPublisher>
{
  @private
    KTSite      *_site;
    NSString    *_documentRootPath;
    NSString    *_subfolderPath;    // nil if there is no subfolder
    
    KTPublishingEngineStatus            _status;
    id <KTPublishingEngineDelegate>     _delegate;
    
    SVHTMLContext   *_currentContext;
    
	id <CKConnection>	_connection;
    CKTransferRecord    *_rootTransferRecord;
    CKTransferRecord    *_baseTransferRecord;
    
    NSMutableSet    *_paths;    // all the paths which are in use by the site
    
    NSMutableDictionary *_uploadedMediaReps;
    NSMutableArray      *_newMedia;
    
    NSMutableArray      *_plugInCSS;    // mixture of string CSS snippets, and CSS URLs
    NSMutableDictionary *_graphicalTextBlocks;
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

// Pages
- (BOOL)shouldUploadHTML:(NSString *)HTML encoding:(NSStringEncoding)encoding forPage:(KTPage *)page toPath:(NSString *)uploadPath digest:(NSData **)outDigest;

// Design
- (void)uploadDesignIfNeeded;

- (void)addGraphicalTextBlock:(SVHTMLTextBlock *)textBlock;
- (CKTransferRecord *)uploadMainCSSIfNeeded;
- (BOOL)shouldUploadMainCSSData:(NSData *)mainCSSData toPath:(NSString *)path digest:(NSData **)outDigest;

@end

