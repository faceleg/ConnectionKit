//
//  SVMediaRequest.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
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
}

- (id)initWithMedia:(SVMedia *)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height
                     type:(NSString *)type
      preferredUploadPath:(NSString *)path;

@property(nonatomic, retain, readonly) SVMedia *media;
@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
@property(nonatomic, copy, readonly) NSString *type;
- (BOOL)isNativeRepresentation;

- (NSString *)preferredUploadPath;    // what the media would like to be placed given the chance

@end
