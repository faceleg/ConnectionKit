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
}

- (id)initWithMediaRecord:(SVMediaRecord *)mediaRecord;

@property(nonatomic, retain, readonly) SVMediaRecord *mediaRecord;

@end
