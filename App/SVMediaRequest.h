//
//  SVMediaRequest.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVMediaProtocol.h"
#import "Sandvox.h"


@class SVMedia;

@interface SVMediaRequest : NSObject <NSCopying>
{
  @private
    SVMedia         *_media;
    NSNumber        *_width;
    NSNumber        *_height;
    NSString        *_type;
    NSSet           *_colorSpaceModels;
    NSString        *_uploadPath;
    NSString        *_scalingOrConversionPathSuffix;
    SVPageImageRepresentationOptions    _options;
}

- (id)initWithMedia:(SVMedia *)media
              width:(NSNumber *)width
             height:(NSNumber *)height
               type:(NSString *)type
            options:(SVPageImageRepresentationOptions)options
preferredUploadPath:(NSString *)path
      scalingSuffix:(NSString *)suffix;

- (id)initWithMedia:(SVMedia *)media preferredUploadPath:(NSString *)path;   // convenience


#pragma mark Source
@property(nonatomic, retain, readonly) SVMedia *media;
- (SVMediaRequest *)sourceRequest;


#pragma mark Scaling

@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
@property(nonatomic, readonly) SVPageImageRepresentationOptions options;
- (NSDictionary *)imageScalingParameters;

// If scaling was required, add this on to .preferredUploadPath using -ks_stringWithPathSuffix;
@property(nonatomic, copy, readonly) NSString *scalingPathSuffix;


#pragma mark Conversion

// The type of file you want published. nil means to keep in the original format
@property(nonatomic, copy, readonly) NSString *type;

// For images. Contains the CGColorSpaceModel constants AND string equivalents (e.g. kCGImagePropertyColorModelRGB) that are permitted
// If source image's color space model falls within the list, or the list is nil/empty, any scaled/converted image will try to match it. Otherwise, is converted to RGB.
@property(nonatomic, copy, readonly) NSSet *allowedColorSpaceModels;

- (BOOL)isNativeRepresentation;


#pragma mark Upload

// Where the media would ideally like to be placed
@property(nonatomic, copy, readonly) NSString *preferredUploadPath;

- (SVMediaRequest *)requestWithScalingSuffixApplied;

// Given the SHA1 digest of source media, what should the content hash of this request be?
- (NSData *)contentHashWithSourceMediaDigest:(NSData *)digest;


#pragma mark Equality
- (BOOL)isEqualToMediaRequest:(SVMediaRequest *)otherMedia;


@end
