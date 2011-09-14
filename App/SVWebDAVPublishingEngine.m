//
//  SVWebDAVPublishingEngine.m
//  Sandvox
//
//  Created by Mike on 14/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVWebDAVPublishingEngine.h"

#import "KTHostProperties.h"
#import "KTSite.h"

#import <DAVKit/DAVKit.h>


@interface SVWebDAVPublishingEngine () <DAVRequestDelegate>
@end


@implementation SVWebDAVPublishingEngine

- (void)createConnection
{
    // Build the request object
    KTHostProperties *hostProperties = [[self site] hostProperties];
    
    NSString *hostName = [hostProperties valueForKey:@"hostName"];
    NSString *protocol = [hostProperties valueForKey:@"protocol"];
    
    NSNumber *port = [hostProperties valueForKey:@"port"];
    
    CKConnectionRequest *request = [[CKConnectionRegistry sharedConnectionRegistry] connectionRequestForName:protocol
                                                                                                        host:hostName 
                                                                                                        port:port];
    
    NSString *username;
    NSString *password;
    BOOL got = [CKDotMacConnection getDotMacAccountName:&username password:&password];
    
    NSURLCredential *credential = (got ?
                                   [NSURLCredential credentialWithUser:username
                                                              password:password
                                                           persistence:NSURLCredentialPersistenceNone] :
                                   nil);
    
    NSURL *URL = [NSURL URLWithString:[NSString stringWithFormat:@"/%@", [credential user]] relativeToURL:[request URL]];
    
    _session = [[DAVSession alloc] initWithRootURL:URL credentials:credential];
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)path;
{
    DAVPutRequest *request = [[DAVPutRequest alloc] initWithPath:path];
    [request setDelegate:self];
    [request setData:data];
    [_session enqueueRequest:request];
    [request release];
    
    return nil;
}

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)path
{
    return [self uploadData:[NSData dataWithContentsOfURL:localURL] toPath:path];
}

// The error can be a NSURLConnection error or a WebDAV error
- (void)request:(DAVRequest *)aRequest didFailWithError:(NSError *)error;
{
}

// The resulting object varies depending on the request type
- (void)request:(DAVRequest *)aRequest didSucceedWithResult:(id)result;
{
}

- (void)requestDidBegin:(DAVRequest *)aRequest;
{
    
}

@end
