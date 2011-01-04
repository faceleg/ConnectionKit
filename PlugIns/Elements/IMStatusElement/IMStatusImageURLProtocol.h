//
//  IMStatusImageURLProtocol.h
//  IMStatusElement
//
//  Created by Mike on 03/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface IMStatusImageURLProtocol : NSURLProtocol

+ (NSImage *)imageWithBaseImage:(NSImage *)aBaseImage headline:(NSString *)aHeadline status:(NSString *)aStatus;

+ (NSURL *)URLWithBaseImageURL:(NSURL *)baseURL headline:(NSString *)headline status:(NSString *)status;

+ (NSURL *)baseOnlineImageURL;
+ (NSURL *)baseOfflineImageURL;

@end
