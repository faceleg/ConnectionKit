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
    
    return self;
}

- (void)dealloc
{
    [_paths release];
    [_pathsByDigest release];
    [_publishedMediaDigests release];
    [_scaledImageCache release];
    
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

- (NSData *)digestForRequest:(SVMediaRequest *)request;
{
    id result = [_publishedMediaDigests objectForKey:request];
    if (result == [NSNull null]) result = nil;
    return result;
}

- (BOOL)containsRequest:(SVMediaRequest *)request;
{
    return ([_publishedMediaDigests objectForKey:request] != nil);
}

- (SVMediaRequest *)addRequest:(SVMediaRequest *)request
                    cachedData:(NSData *)data
                  cachedDigest:(NSData *)digest;
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
    
    
    if (data)
    {
        [_scaledImageCache setObject:data forKey:request];
    }
    
    
    return request;
}

- (void)removeMediaRequest:(SVMediaRequest *)request;
{
    [_publishedMediaDigests removeObjectForKey:request];
}

@end
