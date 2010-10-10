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


@protocol SVMedia <NSObject>

- (NSURL *)mediaURL;    // MUST be non-nil when editing, doesn't have to point to real place
- (NSData *)mediaData;  // If the data is already present in memory, return it. Otherwise nil

- (NSString *)preferredFilename;    // what the media would like to be named given the chance

- (BOOL)isEqualToMedia:(id <SVMedia>)otherMedia;    // return YES if you can be sure the two objects evaluate to equal data. Implement -isEqual: to call this too please!
@end


#pragma mark -


@interface SVMedia (SVMedia) <SVMedia>
@end


#pragma mark -


@interface NSData (SVMedia)
+ (NSData *)newDataWithContentsOfMedia:(id <SVMedia>)media;
@end

