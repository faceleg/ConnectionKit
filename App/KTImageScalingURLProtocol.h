//
//  KTImageScalingURLProtocol.h
//  Marvel
//
//  Created by Mike on 02/01/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//


// URLs take the form:
// x-sandvox-image:///foo/bar.jpg?size={640.0,640.0}&mode=1&sharpen=1.0&filetype=public.png


#import <Cocoa/Cocoa.h>
#import "CIImage+Karelia.h"


extern NSString *KTImageScalingURLProtocolScheme;


@class SVMediaRequest;


@interface NSURL (SandvoxImage)

+ (NSURL *)sandvoxImageURLWithMediaRequest:(SVMediaRequest *)request;

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL queryParameters:(NSDictionary *)query;

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL 
                                 size:(NSSize)size
                          scalingMode:(KSImageScalingMode)scalingMode
                           sharpening:(CGFloat)sharpening
                    compressionFactor:(CGFloat)compression
                             fileType:(NSString *)UTI;

+ (NSDictionary *)sandvoxImageParametersWithSize:(NSSize)size
                                     scalingMode:(KSImageScalingMode)scalingMode
                                      sharpening:(CGFloat)sharpening
                               compressionFactor:(CGFloat)compression
                                        fileType:(NSString *)UTI;


#pragma mark 

+ (NSURL *)sandvoxImageURLWithFileURL:(NSURL *)fileURL scalingProperties:(NSDictionary *)properties;

@end


#pragma mark -


@interface KTImageScalingURLProtocol : NSURLProtocol
{
  @private
    NSOperation *_operation;
}
@end


@interface NSURLRequest (KTImageScalingURLProtocol)
- (NSURL *)scaledImageSourceURL;
@end


@interface NSMutableURLRequest (KTImageScalingURLProtocol)
- (void)setScaledImageSourceURL:(NSURL *)URL;
@end

