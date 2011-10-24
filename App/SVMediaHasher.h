//
//  SVMediaHasher.h
//  Sandvox
//
//  Created by Mike on 07/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMediaRequest.h"


@interface SVMediaHasher : NSObject
{
  @private
    NSMutableDictionary *_hashingOps;
    NSOperationQueue    *_diskQueue;
    NSOperationQueue    *_memoryQueue;
}

- (NSOperation *)addMedia:(SVMedia *)media; // returns the operation being used to hash the media
- (NSData *)SHA1DigestForMedia:(SVMedia *)media;

// The queues that are used to do the work, based on the media type
@property(nonatomic, retain) NSOperationQueue *diskQueue;
@property(nonatomic, retain) NSOperationQueue *inMemoryQueue;

@end
