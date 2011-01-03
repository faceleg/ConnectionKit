//
//  SVMediaRequest.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-11 Karelia Software. All rights reserved.
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

- (id)initWithMedia:(SVMedia *)media
              width:(NSNumber *)width
             height:(NSNumber *)height
               type:(NSString *)type
preferredUploadPath:(NSString *)path;

- (id)initWithMedia:(SVMedia *)media;   // convenience

@property(nonatomic, retain, readonly) SVMedia *media;
@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
@property(nonatomic, copy, readonly) NSString *type;


#pragma mark Scaling
- (BOOL)isNativeRepresentation;
- (NSDictionary *)imageScalingParameters;


- (NSString *)preferredUploadPath;    // what the media would like to be placed given the chance

@end
