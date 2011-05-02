//
//  SVPublishingHTMLContext.h
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVHTMLContext.h"


@class SVMediaRequest, KSSHA1Stream, KSOutputStreamWriter;
@protocol SVPublisher;


@interface SVPublishingHTMLContext : SVHTMLContext
{
  @private
    id <SVPublisher>    _publisher;
    NSString            *_path;
    
    // Change tracking
    NSUInteger              _disableChangeTracking;
    KSSHA1Stream            *_contentHashStream;
    KSOutputStreamWriter    *_contentHashDataOutput;
    
    // Media
    NSUInteger  _didAddMediaWithoutPath;
    
    // Event loop
    NSUInteger  _disableRunningEventLoop;
}

- (id)initWithUploadPath:(NSString *)path
               publisher:(id <SVPublisher>)publisher;

- (NSURL *)addMediaWithRequest:(SVMediaRequest *)request;
- (BOOL)didAddMediaWithoutPath;

@end
