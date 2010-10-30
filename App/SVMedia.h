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

- (id)initByReferencingURL:(NSURL *)fileURL;
- (id)initWithContentsOfURL:(NSURL *)URL error:(NSError **)outError;
- (id)initWithContents:(NSData *)data;

@property(nonatomic, copy, readonly) NSURL *mediaURL;
@property(nonatomic, copy, readonly) NSData *mediaData;

@end
