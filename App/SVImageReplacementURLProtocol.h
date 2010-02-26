//
//  SVImageReplacementURLProtocol.h
//  Sandvox
//
//  Created by Mike on 26/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface NSURL (SVImageReplacement)
+ (NSURL *)imageReplacementURLWithRendererURL:(NSURL *)rendererURL
                                       string:(NSString *)string
                                         size:(NSNumber *)size;
@end


#pragma mark -


@interface SVImageReplacementURLProtocol : NSURLProtocol
{
  @private
    NSInvocationOperation *_operation;
}

@end


