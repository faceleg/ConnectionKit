//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 27/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "SVMediaProtocol.h"


@interface SVMedia : NSObject <SVMedia>
{
  @private
    NSURL   *_fileURL;
    NSData  *_data;
}

- (id)initWithURL:(NSURL *)fileURL;

@property(nonatomic, copy, readonly) NSURL *mediaURL;

@end
