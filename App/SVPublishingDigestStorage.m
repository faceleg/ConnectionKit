//
//  SVPublishingDigestStorage.m
//  Sandvox
//
//  Created by Mike on 15/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPublishingDigestStorage.h"


@implementation SVPublishingDigestStorage

- (id)init;
{
    [super init];
    
    _paths = [[NSMutableSet alloc] init];
    _pathsByDigest = [[NSMutableDictionary alloc] init];
    _publishedMediaDigests = [[NSMapTable mapTableWithStrongToStrongObjects] retain];
    _scaledImageCache = [[NSMutableDictionary alloc] init];
    _hashingOps = [[NSMutableDictionary alloc] init];
    
    return self;
}

- (void)dealloc
{
    [_paths release];
    [_pathsByDigest release];
    [_publishedMediaDigests release];
    [_scaledImageCache release];
    [_hashingOps release];
    
    [super dealloc];
}

#pragma mark General

- (BOOL)containsPath:(NSString *)path; { return [_paths containsObject:path]; }

- (NSString *)pathForFileWithDigest:(NSData *)digest;
{
    return [_pathsByDigest objectForKey:digest];
}

- (void)addPath:(NSString *)path digest:(NSData *)digest;
{
    [_paths addObject:path];
    if (digest) [_pathsByDigest setObject:path forKey:digest];
}

#pragma mark Media

- (NSData *)digestForMediaRequest:(SVMediaRequest *)request;
{
    id result = [_publishedMediaDigests objectForKey:request];
    if (result == [NSNull null]) result = nil;
    
    if (!result && [request isNativeRepresentation])
    {
        NSInvocationOperation *op = [self hashingOperationForMedia:[request media]];
        if (![op isCancelled]) result = [op result];
    }
    
    return result;
}

- (BOOL)containsMediaRequest:(SVMediaRequest *)request;
{
    return ([_publishedMediaDigests objectForKey:request] != nil);
}

- (SVMediaRequest *)addMediaRequest:(SVMediaRequest *)request cachedDigest:(NSData *)digest;
{
    OBPRECONDITION(request);
    
    
    SVMediaRequest *existingRequest;
    id existingDigest;
    if (NSMapMember(_publishedMediaDigests, request, (void **)&existingRequest, (void **)&existingDigest))
    {
        if (digest)
        {
            if (existingDigest == [NSNull null])
            {
                // Remove from the dictionary before replacing so that we're sure the key is the exact request passed in. Do this so scaling suffix is completely applied
                [digest retain];
                [_publishedMediaDigests removeObjectForKey:request];
                [_publishedMediaDigests setObject:digest forKey:request];
                [digest release];
            }
            else
            {
                // Digest shouldn't ever change!
                OBASSERT([digest isEqualToData:existingDigest]);
                
                // Switch to canonical request
                request = existingRequest;
            }
        }
    }
    else
    {
        if (!digest) digest = (id)[NSNull null];    // placeholder while digest is calculated
        [_publishedMediaDigests setObject:digest forKey:request];
    }
    
    
    return request;
}

- (void)removeMediaRequest:(SVMediaRequest *)request;
{
    [_publishedMediaDigests removeObjectForKey:request];
}

- (NSInvocationOperation *)hashingOperationForMedia:(SVMedia *)media;
{
    return [_hashingOps objectForKey:media];
}

- (void)setHashingOperation:(NSInvocationOperation *)op forMedia:(SVMedia *)media;
{
    CFDictionarySetValue((CFMutableDictionaryRef)_hashingOps, media, op);
}

#pragma mark Data Cache

- (NSData *)dataForMediaRequest:(SVMediaRequest *)request;
{
    return [_scaledImageCache objectForKey:request];
}

- (NSDictionary *)cachedMediaRequestData;
{
    return [[_scaledImageCache copy] autorelease];
}

- (void)setData:(NSData *)data forMediaRequest:(SVMediaRequest *)request;
{
    [_scaledImageCache setObject:data forKey:request];
}

- (void)removeDataForMediaRequest:(SVMediaRequest *)request;
{
    [_scaledImageCache removeObjectForKey:request];
}

@end
