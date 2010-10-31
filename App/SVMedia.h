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
    NSURL       *_fileURL;
    WebResource *_webResource;
    
    NSString    *_preferredFilename;
}

- (id)initByReferencingURL:(NSURL *)fileURL;
- (id)initWithContentsOfURL:(NSURL *)URL error:(NSError **)outError;
- (id)initWithWebResource:(WebResource *)resource;
- (id)initWithData:(NSData *)data URL:(NSURL *)URL;

@property(nonatomic, copy, readonly) NSURL *mediaURL;
@property(nonatomic, copy, readonly) NSData *mediaData;
@property(nonatomic, copy, readonly) WebResource *webResource;

@property(nonatomic, copy) NSString *preferredFilename;

@end
