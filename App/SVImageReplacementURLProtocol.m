//
//  SVImageReplacementURLProtocol.m
//  Sandvox
//
//  Created by Mike on 26/02/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageReplacementURLProtocol.h"

#import "KTStringRenderer.h"

#import "NSImage+KTExtensions.h"
#import "NSString+Karelia.h"
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

#pragma mark Registration

+ (void)load
{
    [NSURLProtocol registerClass:self];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
{
    if ([[[request URL] scheme] isEqualToString:@"x-image-replacement"])
    {
        return YES;
    }
    
    return NO;
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
{
    return request;
}

#pragma mark  Init & Dealloc

static NSOperationQueue *sQueue;

+ (void)initialize
{
    if (!sQueue) sQueue = [[NSOperationQueue alloc] init];
}

- (void)dealloc
{
    [_operation removeObserver:self forKeyPath:@"isFinished"];
    [_operation release];
    
    [super dealloc];
}

#pragma mark Loading

- (void)startLoading;
{
    NSURL *URL = [[self request] URL];
    
    
    // What to render with?
    NSURL *compositionURL = [[NSURL alloc] initWithScheme:@"file"
                                                     host:[URL host]
                                                     path:[URL path]];
    KTStringRenderer *renderer = [KTStringRenderer rendererWithFile:[compositionURL path]];
    [compositionURL release];
    
    
    // What text etc. to render?
    NSDictionary *query = [URL queryDictionary];
    NSDictionary *inputs = [[NSDictionary alloc] initWithObjectsAndKeys:
                            [query objectForKey:@"string"], @"String",
                            [query objectForKey:@"size"], @"Size",
                            nil];
    
    
    // Queue up the rendering
    _operation = [[NSInvocationOperation alloc] initWithTarget:renderer
                                                      selector:@selector(imageWithInputs:)
                                                        object:inputs];
    [inputs release];
    
    [_operation addObserver:self forKeyPath:@"isFinished" options:0 context:sQueue];
    [sQueue addOperation:_operation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sQueue)
    {
        // Convert to data
        NSImage *image = [_operation result];
        NSString *MIMEType = [NSString MIMETypeForUTI:(NSString *)kUTTypePNG];
        NSData *data = [image representationForMIMEType:MIMEType];
        
        
        // Generate Response
        NSURLResponse *response = [[NSURLResponse alloc]
                                   initWithURL:[[self request] URL]
                                   MIMEType:MIMEType
                                   expectedContentLength:[data length]
                                   textEncodingName:nil];
        
        [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
        
        [response release];
        
        
        // Report data and finish up
        [[self client] URLProtocol:self didLoadData:data];
        [[self client] URLProtocolDidFinishLoading:self];
    }
    else 
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)stopLoading;
{
    [_operation cancel];
}

@end
