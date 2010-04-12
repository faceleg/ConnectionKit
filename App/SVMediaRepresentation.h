//
//  SVMediaRepresentation.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@class SVMediaRecord;


@interface SVMediaRepresentation : NSObject
{
  @private
    SVMediaRecord   *_mediaRecord;
    NSNumber        *_width;
    NSNumber        *_height;
    NSString        *_type;
}

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord;

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height
                 fileType:(NSString *)type;

@property(nonatomic, retain, readonly) SVMediaRecord *mediaRecord;
@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
@property(nonatomic, copy, readonly) NSString *fileType;
- (BOOL)isNativeRepresentation;

- (NSData *)data;

@end
