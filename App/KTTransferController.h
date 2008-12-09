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
    
	id <CKConnection>	myConnection;
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

- (id <CKConnection>)connection;

// Uploading
- (void)startUploading;

- (NSString *)baseRemotePath;

@end


@protocol KTTransferControllerDelegate
- (void)transferController:(KTTransferController *)transferController didFailWithError:(NSError *)error;
@end


