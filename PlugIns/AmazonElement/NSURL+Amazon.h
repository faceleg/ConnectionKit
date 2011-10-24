//
//  NSURL+Amazon.h
//  Amazon List
//
//  Created by Mike on 05/01/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//
//	Methods to make constructing URLs for REST operations easier.


#import <Foundation/Foundation.h>


@interface NSURL ( Amazon )

+ (NSURL *)URLWithBaseURL:(NSURL *)baseURL parameters:(NSDictionary *)parameters;
- (id)initWithBaseURL:(NSURL *)baseURL parameters:(NSDictionary *)parameters;

@end
