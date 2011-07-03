//
//  KTRemotePublishingEngine.h
//  Marvel
//
//  Created by Mike on 29/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTLocalPublishingEngine.h"

#import "CK2SFTPSession.h"


@interface KTRemotePublishingEngine : KTLocalPublishingEngine <CK2SFTPSessionDelegate>

@end
