//
//  KTTransferController.h
//  Marvel
//
//  Created by Terrence Talbot on 10/30/08.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//


#import "KTPublishingEngine.h"


@interface KTLocalPublishingEngine : KTPublishingEngine 
{
	BOOL    _onlyPublishChanges;
    
  @private
    NSDictionary        *_publishingRecordsByPath;
    NSMutableDictionary *_publishingRecordsBySHA1Digest;
    NSMutableSet        *_pathsBeingHashed;
}

- (id)initWithSite:(KTSite *)aDocumentInfo onlyPublishChanges:(BOOL)publishChanges;
- (BOOL)onlyPublishChanges;

@end