//
//  SVPublishingHTMLContext.h
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class KTPublishingEngine;

@interface SVPublishingHTMLContext : SVHTMLContext
{
  @private
    KTPublishingEngine  *_publishingEngine;
}

@property(nonatomic, retain) KTPublishingEngine *publishingEngine;

@end
