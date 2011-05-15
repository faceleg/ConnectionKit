//
//  SVMediaDigestStorage.m
//  Sandvox
//
//  Created by Mike on 15/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMediaDigestStorage.h"


@implementation SVMediaDigestStorage

- (id)init;
{
    [super init];
    _publishedMediaDigests = [[NSMapTable mapTableWithStrongToStrongObjects] retain];
    return self;
}

- (void)dealloc
{
    [_publishedMediaDigests release];
    [super dealloc];
}

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

- (SVMediaRequest *)addRequest:(SVMediaRequest *)request cachedDigest:(NSData *)digest;
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

@end
