//
//  KTImageScalingURLProtocol.h
//  Marvel
//
//  Created by Mike on 02/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//


// URLs take the form:
// x-sandvox-image://docID/imageID?size={640.0,640.0}&mode=1&sharpen=1.0&filetype=public.png


#import <Cocoa/Cocoa.h>


extern NSString *KTImageScalingURLProtocolScheme;


@interface KTImageScalingURLProtocol : NSURLProtocol
@end


@interface NSURLRequest (KTImageScalingURLProtocol)
- (NSURL *)scaledImageSourceURL;
@end


@interface NSMutableURLRequest (KTImageScalingURLProtocol)
- (void)setScaledImageSourceURL:(NSURL *)URL;
@end

