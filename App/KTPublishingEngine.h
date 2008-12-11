//
//  KTTransferController.h
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008 Karelia Software. All rights reserved.
//


#import <Cocoa/Cocoa.h>
#import <Connection/Connection.h>


@class KTDocument, KTDocumentInfo;
@protocol KTTransferControllerDelegate;


@interface KTPublishingEngine : NSObject 
{
	KTDocumentInfo	*_documentInfo;
    BOOL            _onlyPublishChanges;
    
    BOOL    _hasStarted;
    BOOL    _hasFinished;
    
    id <KTTransferControllerDelegate>   _delegate;
    
	id <CKConnection>	_connection;
    CKTransferRecord    *_rootTransferRecord;
    CKTransferRecord    *_baseTransferRecord;
    
    NSMutableSet    *_uploadedMedia;
    NSMutableSet    *_uploadedResources;
}

- (id)initWithDocumentInfo:(KTDocumentInfo *)aDocumentInfo onlyPublishChanges:(BOOL)publishChanges;

// Delegate
- (id <KTTransferControllerDelegate>)delegate;
- (void)setDelegate:(id <KTTransferControllerDelegate>)delegate;

// Accessors
- (KTDocumentInfo *)documentInfo;
- (BOOL)onlyPublishChanges;
- (BOOL)isExporting;

// Control
- (void)start;
- (void)cancel;
- (BOOL)hasStarted;
- (BOOL)hasFinished;

// Connection
- (id <CKConnection>)connection;
- (NSString *)baseRemotePath;

- (CKTransferRecord *)rootTransferRecord;
- (CKTransferRecord *)baseTransferRecord;

@end


@protocol KTTransferControllerDelegate
- (void)publishingEngineDidFinishGeneratingContent:(KTPublishingEngine *)engine;
- (void)publishingEngineDidUpdateProgress:(KTPublishingEngine *)engine;

- (void)publishingEngineDidFinish:(KTPublishingEngine *)engine;
- (void)publishingEngine:(KTPublishingEngine *)engine didFailWithError:(NSError *)error;
@end


