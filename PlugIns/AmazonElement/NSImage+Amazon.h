//
//  NSImage+Amazon.h
//  AmazonSupport
//
//  Created by Mike on 06/05/2007.
//  Copyright 2007-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "AmazonECSOperation.h"


@interface NSImage (Amazon)

+ (NSImage *)flagForAmazonStore:(AmazonStoreCountry)store;

@end
