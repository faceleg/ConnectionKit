//
//  SVMediaHasher.m
//  Sandvox
//
//  Created by Mike on 07/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMediaHasher.h"

#import "KSSHA1Stream.h"


@implementation SVMediaHasher

- (id)init
{
    if (self = [super init])
    {
        _hashingOps = [[NSMutableDictionary alloc] init];
        _memoryQueue = [[NSOperationQueue alloc] init];
        
        _diskQueue = [[NSOperationQueue alloc] init];
        [_diskQueue setMaxConcurrentOperationCount:1];
    }
    return self;
}

- (void)dealloc
{
    [_hashingOps release];
    [_diskQueue release];
    [_memoryQueue release];
    
    [super dealloc];
}

- (NSOperation *)addMedia:(SVMedia *)media; // returns the operation being used to hash the media
{
    NSOperation *result = [_hashingOps objectForKey:media];
    if (!result)
    {
        NSData *data = [media mediaData];
        if (data)
        {
            result = [[NSInvocationOperation alloc] initWithTarget:data
                                                          selector:@selector(ks_SHA1Digest)
                                                            object:nil];
            
            [[self inMemoryQueue] addOperation:result];
        }
        else
        {
            result = [[NSInvocationOperation alloc] initWithTarget:[KSSHA1Stream class]
                                                          selector:@selector(SHA1DigestOfContentsOfURL:)
                                                            object:[media mediaURL]];
            
            [[self diskQueue] addOperation:result];
        }
        
        CFDictionarySetValue((CFMutableDictionaryRef)_hashingOps, media, result);
        [result release];
    }
    return result;
}

- (NSData *)SHA1DigestForMedia:(SVMedia *)media;
{
    NSInvocationOperation *op = [_hashingOps objectForKey:media];
    NSData *result = ([op isCancelled] ? nil : [op result]);
    return result;
}

@synthesize diskQueue = _diskQueue;
@synthesize inMemoryQueue = _memoryQueue;

@end
