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


@interface KTTransferController : NSObject 
{
	KTDocumentInfo	*myDocumentInfo;
    BOOL            myOnlyPublishChanges;
    
	id <CKConnection>	myConnection;
    
    NSMutableSet    *myUploadedMedia;
}

- (id)initWithDocumentInfo:(KTDocumentInfo *)aDocumentInfo onlyPublishChanges:(BOOL)publishChanges;

// Accessors
- (KTDocumentInfo *)documentInfo;
- (BOOL)onlyPublishChanges;

- (id <CKConnection>)connection;

// Uploading
- (void)startUploading;

- (NSString *)storagePath;

@end
