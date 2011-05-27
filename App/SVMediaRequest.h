//
//  SVMediaRequest.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVMediaProtocol.h"


@class SVMedia;

@interface SVMediaRequest : NSObject <NSCopying>
{
  @private
    SVMedia         *_media;
    NSNumber        *_width;
    NSNumber        *_height;
    NSString        *_type;
    NSString        *_uploadPath;
    NSString        *_scalingOrConversionPathSuffix;
}

- (id)initWithMedia:(SVMedia *)media
              width:(NSNumber *)width
             height:(NSNumber *)height
               type:(NSString *)type
preferredUploadPath:(NSString *)path
      scalingSuffix:(NSString *)suffix;

- (id)initWithMedia:(SVMedia *)media preferredUploadPath:(NSString *)path;   // convenience


#pragma mark Source
@property(nonatomic, retain, readonly) SVMedia *media;
- (SVMediaRequest *)sourceRequest;


#pragma mark Scaling

@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
- (NSDictionary *)imageScalingParameters;

// If scaling was required, add this on to .preferredUploadPath using -ks_stringWithPathSuffix;
@property(nonatomic, copy, readonly) NSString *scalingPathSuffix;


#pragma mark Scaling/Conversion
@property(nonatomic, copy, readonly) NSString *type;
- (BOOL)isNativeRepresentation;


#pragma mark Upload

// Where the media would ideally like to be placed
@property(nonatomic, copy, readonly) NSString *preferredUploadPath;

- (SVMediaRequest *)requestWithScalingSuffixApplied;

// Given the SHA1 digest of source media, what should the content hash of this request be?
- (NSData *)contentHashWithMediaDigest:(NSData *)digest;


#pragma mark Equality
- (BOOL)isEqualToMediaRequest:(SVMediaRequest *)otherMedia;


@end
