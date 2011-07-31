//
//  SVWorkspaceIconProtocol.m
//  Sandvox
//
//  Created by Mike on 05/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWorkspaceIconProtocol.h"

#import "NSImage+KTExtensions.h"

#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"

#import "KSError.h"
#import "KSThreadProxy.h"
#import "KSWorkspaceUtilities.h"
#import "KSURLUtilities.h"


@implementation SVWorkspaceIconProtocol

+ (NSURL *)URLForWorkspaceIconOfURL:(NSURL *)fileURL;
{
    return ([fileURL isFileURL] ? [fileURL ks_URLWithScheme:@"x-sandvox-workspace-icon"] : nil);
}

+ (void)load
{
    [NSURLProtocol registerClass:self];
}

+ (BOOL)canInitWithRequest:(NSURLRequest *)request;
{
    NSURL *URL = [request URL];
    return ([[URL scheme] isEqualToString:@"x-sandvox-workspace-icon"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;
{
    return request;
}

- (void)startLoading
{
    NSURL *URL = [[[self request] URL] ks_URLWithScheme:@"file"];
    
    NSError *error;
    NSString *type = [NSString UTIForFileAtPath:[URL path]];
    
    if (type)
    {
        NSImage *icon = [KSWORKSPACE iconForFileType:type];
        NSImageRep *bestRep = [icon ks_largestRepresentation];
        if (bestRep) [icon setSize:[bestRep size]];
        
        NSData *png = [icon PNGRepresentation];
        if (png)
        {
            NSURLResponse *response = [[NSURLResponse alloc] initWithURL:URL
                                                               MIMEType:(NSString *)kUTTypePNG
                                                  expectedContentLength:[png length]
                                                       textEncodingName:nil];
            
            [[self client] URLProtocol:self
                    didReceiveResponse:response
                    cacheStoragePolicy:NSURLCacheStorageAllowed];
            [response release];
            
            [[self client] URLProtocol:self didLoadData:png];
            
            [[self client] URLProtocolDidFinishLoading:self];
        }
        else
        {
            error = [KSError errorWithDomain:NSURLErrorDomain
                                        code:NSURLErrorResourceUnavailable
                  localizedDescriptionFormat:NSLocalizedString(@"Couldn't get icon for file: %@", "error"), URL];
            
            [[self client] URLProtocol:self didFailWithError:error];
        }
    }
    else
    {
        error = [KSError errorWithDomain:NSCocoaErrorDomain
                                    code:NSFileReadUnknownError
              localizedDescriptionFormat:@"Couldn't determine type of file: %@", URL];
        [[self client] URLProtocol:self didFailWithError:error];
    }
}

- (void)stopLoading; { }

@end
