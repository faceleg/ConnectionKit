//
//  SVMedia.h
//  Sandvox
//
//  Created by Mike on 27/08/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVMedia : NSObject
{
  @private
    NSURL   *_fileURL;
    NSData  *_data;
}

- (id)initWithURL:(NSURL *)fileURL;

@property(nonatomic, copy, readonly) NSURL *fileURL;
@property(nonatomic, copy, readonly) NSData *data;

@end
