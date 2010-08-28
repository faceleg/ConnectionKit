//
//  SVImageMedia.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVMediaProtocol.h"


@interface SVImageMedia : NSObject <SVMedia, NSCopying>
{
  @private
    id <SVMedia>    _mediaRecord;
    NSNumber        *_width;
    NSNumber        *_height;
    NSString        *_type;
}

- (id)initWithSourceMedia:(id <SVMedia>)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height
                     type:(NSString *)type;

@property(nonatomic, retain, readonly) id <SVMedia> mediaRecord;
@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
@property(nonatomic, copy, readonly) NSString *type;
- (BOOL)isNativeRepresentation;

- (NSData *)data;

- (BOOL)isEqualToMediaRepresentation:(SVImageMedia *)otherRep;

@end
