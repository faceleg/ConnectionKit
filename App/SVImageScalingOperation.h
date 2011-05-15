//
//  SVImageScalingOperation.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVMediaProtocol.h"


@class SVMediaRequest;

@interface SVImageScalingOperation : NSOperation
{
  @private
    id <SVMedia>    _sourceMedia;
    NSDictionary    *_parameters;
    NSData          *_result;
    NSURLResponse   *_response;
}

- (id)initWithMedia:(id <SVMedia>)media parameters:(NSDictionary *)params;
- (id)initWithURL:(NSURL *)url;

@property(nonatomic, copy, readonly) NSData *result;
@property(nonatomic, copy, readonly) NSURLResponse *returnedResponse;

// Convenience
+ (NSData *)dataWithMediaRequest:(SVMediaRequest *)request response:(NSURLResponse **)response;

@end
