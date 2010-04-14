//
//  SVMediaGatheringPublishingContext.h
//  Sandvox
//
//  Created by Mike on 14/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "KTPublishingEngine.h"


@interface SVMediaGatheringPublishingContext : NSObject <SVPublishingContext>
{
  @private
    id <SVPublishingContext>    _mediaPublisher;
}

@property(nonatomic, retain) id <SVPublishingContext> publishingEngine;

@end
