//
//  NSURL+Sandvox.h
//  Sandvox
//
//  Created by Mike on 09/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSURL (Sandvox)

- (NSDictionary *)svQueryParameters;

+ (NSURL *)svURLWithScheme:(NSString *)scheme
                      host:(NSString *)host
                      path:(NSString *)path
           queryParameters:(NSDictionary *)parameters;

@end