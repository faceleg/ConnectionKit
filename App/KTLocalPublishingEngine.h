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
}

- (id)initWithSite:(KTSite *)site
onlyPublishChanges:(BOOL)publishChanges
         CIContext:(CIContext *)context
             queue:(NSOperationQueue *)coreImageQueue;

- (BOOL)onlyPublishChanges;

@end