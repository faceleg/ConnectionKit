//
//  SVImageReplacementURLProtocol.m
//  Sandvox
//
//  Created by Mike on 26/02/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "SVImageReplacementURLProtocol.h"

#import "KTStringRenderer.h"

#import "NSImage+KTExtensions.h"
#import "NSString+Karelia.h"
#import "NSURL+Karelia.h"

#import "KSError.h"
#import "KSURLUtilities.h"


@implementation NSURL (SVImageReplacement)

+ (NSURL *)imageReplacementURLWithRendererURL:(NSURL *)rendererURL
                                       string:(NSString *)string
                                         size:(NSNumber *)size;
{
    OBPRECONDITION(rendererURL);
    OBPRECONDITION([rendererURL isFileURL]);
    
    if (!string) string = @"";
    
    NSDictionary *params = [NSDictionary dictionaryWithObjectsAndKeys:
                            string, @"string",
                            size, @"size",
                            nil];
    
    return [NSURL ks_URLWithScheme:@"x-image-replacement"
                              host:[rendererURL host]
                              path:[rendererURL path]
                   queryParameters:params];
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

static void * sOperationObservation = &sOperationObservation;

- (void)startLoading;
{
    NSURL *URL = [[self request] URL];
    
    
    // What to render with?
    NSURL *compositionURL = [URL ks_URLWithScheme:@"file"];
    KTStringRenderer *renderer = [KTStringRenderer rendererWithFile:[compositionURL path]];
    if (!renderer)
    {
        NSError *error = [KSError errorWithDomain:NSURLErrorDomain
                                             code:NSURLErrorResourceUnavailable
                                              URL:compositionURL];
        [[self client] URLProtocol:self didFailWithError:error];
    }
    
    
    // What text etc. to render?
    NSDictionary *query = [URL ks_queryParameters];
    NSDictionary *inputs = [[NSDictionary alloc] initWithObjectsAndKeys:
                            [query objectForKey:@"string"], @"String",
                            [query objectForKey:@"size"], @"Size",
                            nil];
    
    
    // Queue up the rendering
    _operation = [[NSInvocationOperation alloc] initWithTarget:renderer
                                                      selector:@selector(imageWithInputs:)
                                                        object:inputs];
    [inputs release];
    
    [_operation addObserver:self forKeyPath:@"isFinished" options:0 context:sOperationObservation];
    [sQueue addOperation:_operation];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == sOperationObservation)
    {
        // Convert to data
        NSImage *image = [_operation result];
        NSData *data = [image PNGRepresentation];
        
        
        // Generate Response
        NSURLResponse *response = [[NSURLResponse alloc]
                                   initWithURL:[[self request] URL]
                                   MIMEType:[KSWORKSPACE ks_MIMETypeForType:(NSString *)kUTTypePNG]
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
