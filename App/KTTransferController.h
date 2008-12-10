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


@interface KTTransferController : NSObject 
{
	KTDocumentInfo	*_documentInfo;
    BOOL            _onlyPublishChanges;
    
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

// Control
- (void)start;
- (void)cancel;

// Connection
- (id <CKConnection>)connection;
- (NSString *)baseRemotePath;

- (CKTransferRecord *)rootTransferRecord;
- (CKTransferRecord *)baseTransferRecord;

@end


@protocol KTTransferControllerDelegate
- (void)transferController:(KTTransferController *)transferController didFailWithError:(NSError *)error;
@end


