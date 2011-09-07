//
//  SVPublishingDigestStorage.h
//  Sandvox
//
//  Created by Mike on 15/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMediaRequest.h"


@interface SVPublishingDigestStorage : NSObject
{
  @private
    NSMutableSet        *_paths;    // all the paths which are in use by the site
    NSMutableDictionary *_pathsByDigest;
    NSMapTable          *_publishedMediaDigests;
    NSMutableDictionary *_scaledImageCache;
    NSMutableDictionary *_hashingOps;
}

#pragma mark General

- (BOOL)containsPath:(NSString *)path;
- (NSString *)pathForFileWithDigest:(NSData *)digest;
- (void)addPath:(NSString *)path digest:(NSData *)digest;


#pragma mark Media Requests

- (NSData *)digestForMediaRequest:(SVMediaRequest *)request;

// Handy for if the request has already been made, but digest is not yet known
- (BOOL)containsMediaRequest:(SVMediaRequest *)request;

// Returns the canonical request. E.g. if media didn't need to be scaled the returned requested will have the scaling suffix stripped
// Throws an exception if there's a digest already stored for the request, and it doesn't match
- (SVMediaRequest *)addMediaRequest:(SVMediaRequest *)request cachedDigest:(NSData *)digest;

- (void)removeMediaRequest:(SVMediaRequest *)request;

- (NSInvocationOperation *)hashingOperationForMedia:(SVMedia *)media;
- (void)setHashingOperation:(NSInvocationOperation *)op forMedia:(SVMedia *)media;


#pragma mark Data Cache
- (NSData *)dataForMediaRequest:(SVMediaRequest *)request;
- (void)setData:(NSData *)data forMediaRequest:(SVMediaRequest *)request;
- (void)removeDataForMediaRequest:(SVMediaRequest *)request;
- (NSDictionary *)cachedMediaRequestData;   // keys = media requests, objects = data


@end
