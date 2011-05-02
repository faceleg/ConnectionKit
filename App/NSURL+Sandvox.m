//
//  NSURL+Sandvox.m
//  Sandvox
//
//  Created by Mike on 09/09/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "NSURL+Sandvox.h"
#import "KSURLUtilities.h"


@implementation NSURL (Sandvox)

- (NSDictionary *)svQueryParameters; { return [self ks_queryParameters]; }

+ (NSURL *)svURLWithScheme:(NSString *)scheme
                      host:(NSString *)host
                      path:(NSString *)path
           queryParameters:(NSDictionary *)parameters;
{
    return [self ks_URLWithScheme:scheme host:host path:path queryParameters:parameters];
}

@end
