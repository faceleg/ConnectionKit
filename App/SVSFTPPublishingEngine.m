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
#import "KSThreadProxy.h"


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

- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error
{
    if (!didPublish)
    {
        // Stop any pending ops
        [_queue cancelAllOperations];
        
        // Close the connection as quick as possible
        NSOperation *closeOp = [[NSInvocationOperation alloc] initWithTarget:_SFTPSession
                                                                    selector:@selector(close)
                                                                      object:nil];
        
        [closeOp setQueuePriority:NSOperationQueuePriorityVeryHigh];
        [_queue addOperation:closeOp];
        
        // Clear out ivars, the actual objects will get torn down as the queue finishes its work
        [_queue release]; _queue = nil;
        [_SFTPSession release]; _SFTPSession = nil;
    }
    
    [super engineDidPublish:didPublish error:error];
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
        result = [CKTransferRecord recordWithName:[path lastPathComponent] size:[data length]];
        
        
        NSInvocation *invocation = [NSInvocation invocationWithSelector:@selector(threaded_writeData:toPath:transferRecord:)
                                                                 target:self
                                                              arguments:NSARRAY(data, path, result)];
        
        NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithInvocation:invocation];
        [_queue addOperation:op];
        [op release];
        
        
        
        [self didEnqueueUpload:result toDirectory:parent];
    }
    
    return result;
}

- (void)threaded_writeData:(NSData *)data toPath:(NSString *)path transferRecord:(CKTransferRecord *)record;
{
    NSError *error = nil;
    NSFileHandle *handle = [_SFTPSession openHandleAtPath:path
                                                    flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                     mode:[self remoteFilePermissions]];
    
    if (!handle)
    {
        error = [_SFTPSession sessionError];
        
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
                
                if (!handle) error = [_SFTPSession sessionError];
            }
        }
    }
    
    if (handle) [[record ks_proxyOnThread:nil waitUntilDone:NO] transferDidBegin:record];
    
    [handle writeData:data];
    [handle closeFile];
    
    [[record ks_proxyOnThread:nil waitUntilDone:NO] transferDidFinish:record error:error];
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
