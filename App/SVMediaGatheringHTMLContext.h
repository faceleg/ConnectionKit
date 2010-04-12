//
//  SVMediaGatheringHTMLContext.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@interface SVMediaGatheringHTMLContext : SVHTMLContext
{
  @private
    NSMutableSet    *_mediaReps;
}

@property(nonatomic, copy, readonly) NSSet *mediaRepresentations;

@end
