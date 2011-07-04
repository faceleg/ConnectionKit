//
//  SVSFTPPublishingEngine.h
//  Sandvox
//
//  Created by Mike on 03/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KTRemotePublishingEngine.h"

#import "CK2SFTPSession.h"


@interface SVSFTPPublishingEngine : KTRemotePublishingEngine <CK2SFTPSessionDelegate>
{
  @private
    CK2SFTPSession      *_SFTPSession;
    NSOperationQueue    *_queue;
}

@end
