//
//  SVSFTPPublishingEngine.m
//  Sandvox
//
//  Created by Mike on 03/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVSFTPPublishingEngine.h"

#import "KTHostProperties.h"
#import "KTSite.h"


@implementation SVSFTPPublishingEngine

- (id)init;
{
    if (self = [super init])
    {
        _queue = [[NSOperationQueue alloc] init];
        [_queue setMaxConcurrentOperationCount:1];
    }
    
    return self;
}

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
    
    _SFTPSession = [[CK2SFTPSession alloc] initWithURL:[request URL] delegate:self];
}

#pragma mark Upload

- (void)didEnqueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;
{
    [parent addContent:record];
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)path;
{
    CKTransferRecord *result = nil;
    
    CKTransferRecord *parent = [self willUploadToPath:path];
    
    if (_SFTPSession)
    {
        NSInvocation *invocation = [NSInvocation invocationWithSelector:@selector(threaded_writeData:toPath:)
                                                                 target:self
                                                              arguments:NSARRAY(data, path)];
        
        NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithInvocation:invocation];
        [_queue addOperation:op];
        [op release];
        
        
        result = [CKTransferRecord recordWithName:[path lastPathComponent] size:[data length]];
        
        
        if (result)
        {
            [self didEnqueueUpload:result toDirectory:parent];
        }
        else
        {
            NSLog(@"Unable to create transfer record for path:%@ data:%@", path, data); // case 40520 logging
        }
    }
    
    return result;
}

- (void)threaded_writeData:(NSData *)data toPath:(NSString *)path;
{
    NSFileHandle *handle = [_SFTPSession openHandleAtPath:path
                                                    flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                     mode:[self remoteFilePermissions]];
    
    if (!handle)
    {
        NSError *error = [_SFTPSession sessionError];
        
        if ([[error domain] isEqualToString:CK2LibSSH2SFTPErrorDomain] &&
            [error code] == LIBSSH2_FX_NO_SUCH_FILE)
        {
            // Parent directory probably doesn't exist, so create it
            BOOL madeDir = [_SFTPSession createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                                   withIntermediateDirectories:YES
                                                          mode:[self remoteDirectoryPermissions]];
            
            if (madeDir)
            {
                handle = [_SFTPSession openHandleAtPath:path
                                                  flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                   mode:[self remoteFilePermissions]];
            }
        }
    }
    
    [handle writeData:data];
    [handle closeFile];
}

#pragma mark SFTP session delegate

- (void)SFTPSessionDidInitialize:(CK2SFTPSession *)session;
{
    
}

- (void)SFTPSession:(CK2SFTPSession *)session didFailWithError:(NSError *)error;
{
    [_SFTPSession release]; _SFTPSession = nil;
}

- (void)SFTPSession:(CK2SFTPSession *)session didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    [self connection:nil didReceiveAuthenticationChallenge:challenge];
}

@end
