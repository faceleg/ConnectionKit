//
//  SVMediaDigestStorage.h
//  Sandvox
//
//  Created by Mike on 15/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMediaRequest.h"


@interface SVMediaDigestStorage : NSObject
{
  @private
    NSMapTable          *_publishedMediaDigests;
    
}

- (NSData *)digestForRequest:(SVMediaRequest *)request;

// Handy for if the request has already been made, but digest is not yet known
- (BOOL)containsRequest:(SVMediaRequest *)request;

// Returns the canonical request. E.g. if media didn't need to be scaled the returned requested will have the scaling suffix stripped
// Throws an exception if there's a digest already stored for the request, and it doesn't match
- (SVMediaRequest *)addRequest:(SVMediaRequest *)request cachedDigest:(NSData *)digest;


@end
