//
//  SVMediaGatheringPublishingContext.h
//  Sandvox
//
//  Created by Mike on 14/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KTPublishingEngine.h"


@interface SVMediaGatheringPublisher : NSObject <SVPublisher>
{
  @private
    id <SVPublisher>    _mediaPublisher;
}

@property(nonatomic, retain) id <SVPublisher> publishingEngine;

@end
