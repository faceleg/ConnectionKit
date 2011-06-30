//
//  SVImageRecipe.m
//  Sandvox
//
//  Created by Mike on 30/06/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVImageRecipe.h"

#import "NSData+Karelia.h"
#import "KSURLUtilities.h"

#import <CommonCrypto/CommonDigest.h>


@implementation SVImageRecipe

- (id)initWithSHA1DigestOfSourceMedia:(NSData *)sourceDigest parameters:(NSDictionary *)parameters;
{
    OBPRECONDITION(sourceDigest);
    OBPRECONDITION([parameters count]);
    
    self = [self init];
    
    _sourceDigest = [sourceDigest copy];
    _parameters = [parameters copy];
    
    return self;
}

- (void)dealloc;
{
    [_sourceDigest release];
    [_parameters release];
    
    [super dealloc];
}

@synthesize SHA1DigestOfSourceMedia = _sourceDigest;
@synthesize parameters = _parameters;

#pragma mark Content Hash

- (id)initWithContentHash:(NSData *)hash;
{
    if ([hash length] > CC_SHA1_DIGEST_LENGTH + 4)  // minimum to include a parameter
    {
#define PARAMETERS_START (CC_SHA1_DIGEST_LENGTH + 1)
        
        NSData *paramData = [hash subdataWithRange:NSMakeRange(PARAMETERS_START, [hash length] - PARAMETERS_START)];
        NSString *query = [[NSString alloc] initWithData:paramData encoding:NSASCIIStringEncoding];
        if (query)
        {
            self = [self initWithSHA1DigestOfSourceMedia:[hash subdataWithRange:NSMakeRange(0, CC_SHA1_DIGEST_LENGTH)]
                                              parameters:[NSURL ks_parametersOfQuery:query]];
            
            [query release];
            
            return self;
        }
    }
    
    [self release]; return nil;
}

- (NSData *)contentHash;
{
    NSString *query = [NSURL ks_queryWithParameters:[self parameters]];
    
    return [[self SHA1DigestOfSourceMedia] ks_dataByAppendingData:
            [query dataUsingEncoding:NSASCIIStringEncoding]];
}

#pragma mark Equality

- (BOOL)isEqual:(id)object;
{
    if (object == self) return YES;
    
    if (![object isKindOfClass:[SVImageRecipe class]]) return NO;
    
    BOOL result = ([[self SHA1DigestOfSourceMedia] isEqualToData:[object SHA1DigestOfSourceMedia]] &&
                   [[self parameters] isEqualToDictionary:[object parameters]]);
    return result;
}

#pragma mark NSCopying

- (id)copyWithZone:(NSZone *)zone;
{
    return [self retain];
}

@end
