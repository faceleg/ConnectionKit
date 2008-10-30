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
	KTDocumentInfo *myDocumentInfoWeakRef;
}

- (id)initWithDocumentInfo:(KTDocumentInfo *)aDocumentInfo;


// old API
- (id)initWithAssociatedDocument:(KTDocument *)aDocument where:(int)aWhere;
- (void)uploadStaleAssets;
- (void)uploadEverything;
- (void)uploadEverythingToSuggestedPath:(NSString *)aSuggestedPath;
- (NSString *)storagePath;
- (id <AbstractConnectionProtocol>)connection;
- (void)terminateConnection;

@end
