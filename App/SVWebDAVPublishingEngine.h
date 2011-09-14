//
//  SVWebDAVPublishingEngine.h
//  Sandvox
//
//  Created by Mike on 14/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "KTMobileMePublishingEngine.h"


@class DAVSession;


@interface SVWebDAVPublishingEngine : KTMobileMePublishingEngine
{
  @private
    DAVSession  *_session;
}

@end
