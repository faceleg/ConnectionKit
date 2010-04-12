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
}

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord;

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord
                    width:(NSNumber *)width
                   height:(NSNumber *)height;

@property(nonatomic, retain, readonly) SVMediaRecord *mediaRecord;
@property(nonatomic, copy, readonly) NSNumber *width;
@property(nonatomic, copy, readonly) NSNumber *height;

@end
