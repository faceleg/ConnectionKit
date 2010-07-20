//
//  SVMediaRepresentation.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVMediaRecord.h"


@interface SVMediaRepresentation : NSObject <NSCopying>
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
                 type:(NSString *)type;

@property(nonatomic, retain, readonly) SVMediaRecord *mediaRecord;
@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;
@property(nonatomic, copy, readonly) NSString *type;
- (BOOL)isNativeRepresentation;

- (NSString *)preferredFilename;    // what the media would like to named given the chance

- (NSData *)data;

- (BOOL)isEqualToMediaRepresentation:(SVMediaRepresentation *)otherRep;

@end
