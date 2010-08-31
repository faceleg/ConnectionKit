//
//  SVMediaProtocol.h
//  Sandvox
//
//  Created by Mike on 22/01/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <iMedia/IMBImageItem.h>
#import "SVMedia.h"


@protocol SVMedia <NSObject, IMBImageItem>

- (NSURL *)mediaURL;    // MUST be non-nil when editing, doesn't have to point to real place
- (NSData *)mediaData;  // If the data is already present in memory, return it. Otherwise nil

- (NSString *)preferredFilename;    // what the media would like to named given the chance

@end


#pragma mark -


@interface SVMedia (SVMedia) <SVMedia>
@end