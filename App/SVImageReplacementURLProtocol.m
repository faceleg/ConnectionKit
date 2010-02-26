//
//  SVImageReplacementURLProtocol.m
//  Sandvox
//
//  Created by Mike on 26/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageReplacementURLProtocol.h"

#import "NSURL+Karelia.h"


@implementation NSURL (SVImageReplacement)

+ (NSURL *)imageReplacementURLWithRendererURL:(NSURL *)rendererURL
                                       string:(NSString *)string
                                         size:(NSNumber *)size;
{
    OBPRECONDITION([rendererURL isFileURL]);
    OBPRECONDITION(string);
    
    NSURL *baseURL = [NSURL URLWithScheme:@"x-image-replacement"
                                     host:[rendererURL host]
                                     path:[rendererURL path]];
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            string, @"string",
                            size, @"size",
                            nil];
    
    return [self URLWithBaseURL:baseURL parameters:params];
}

@end


#pragma mark -


@implementation SVImageReplacementURLProtocol

@end
