//
//  SVImageScalingOperation.h
//  Sandvox
//
//  Created by Mike on 12/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVImageScalingOperation : NSOperation
{
  @private
    NSURL           *_sourceURL;
    NSData          *_result;
    NSURLResponse   *_response;
}

- (id)initWithURL:(NSURL *)url;

@property(nonatomic, copy, readonly) NSData *result;
@property(nonatomic, copy, readonly) NSURLResponse *returnedResponse;

@end
