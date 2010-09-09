//
//  NSURL+Sandvox.m
//  Sandvox
//
//  Created by Mike on 09/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "NSURL+Sandvox.h"
#import "KSURLUtilities.h"


@implementation NSURL (Sandvox)

- (NSDictionary *)svQueryDictionary; { return [self ks_queryDictionary]; }

+ (NSURL *)svURLWithScheme:(NSString *)scheme
                      host:(NSString *)host
                      path:(NSString *)path
           queryDictionary:(NSDictionary *)parameters;
{
    return [self ks_URLWithScheme:scheme host:host path:path queryDictionary:parameters];
}

@end
