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

#import "NSFileManager+Karelia.h"

#import "KSThreadProxy.h"


@interface SVWriteContentsOfURLToSFTPHandleOperation : NSOperation
{
  @private
    NSURL                   *_URL;
    NSString                *_path;
    SVSFTPPublishingEngine  *_engine;
    CKTransferRecord        *_record;
}

- (id)initWithURL:(NSURL *)URL publishingEngine:(SVSFTPPublishingEngine *)engine transferRecord:(CKTransferRecord *)record;

@end


#pragma mark -


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
    
    _session = [[CK2SFTPSession alloc] initWithURL:[request URL] delegate:self];
}

- (void)engineDidPublish:(BOOL)didPublish error:(NSError *)error
{
    if (!didPublish)
    {
        // Stop any pending ops
        [_queue cancelAllOperations];
        
        // Close the connection as quick as possible
        NSOperation *closeOp = [[NSInvocationOperation alloc] initWithTarget:_session
                                                                    selector:@selector(close)
                                                                      object:nil];
        
        [closeOp setQueuePriority:NSOperationQueuePriorityVeryHigh];
        [_queue addOperation:closeOp];
        
        // Clear out ivars, the actual objects will get torn down as the queue finishes its work
        [_queue release]; _queue = nil;
        [_session release]; _session = nil;
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
    
    if (_session)
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

- (CKTransferRecord *)uploadContentsOfURL:(NSURL *)localURL toPath:(NSString *)path
{
    // Cheat and send non-file URLs direct
    if (![localURL isFileURL]) return [self uploadData:[NSData dataWithContentsOfURL:localURL] toPath:path];
    
    
    CKTransferRecord *result = nil;
    
    CKTransferRecord *parent = [self willUploadToPath:path];
    
    if (_session)
    {
        NSNumber *size = [[NSFileManager defaultManager] sizeOfFileAtPath:[localURL path]];
        
        if (size)   // if size can't be determined, no chance of being able to upload
        {
            result = [CKTransferRecord recordWithName:[path lastPathComponent] size:[size unsignedLongLongValue]];
            
            
            NSOperation *op = [[SVWriteContentsOfURLToSFTPHandleOperation alloc] initWithURL:localURL
                                                                            publishingEngine:self
                                                                              transferRecord:result];
            [_queue addOperation:op];
            [op release];
            
            
            
            [self didEnqueueUpload:result toDirectory:parent];
        }
    }
    
    return result;
}

- (void)threaded_writeData:(NSData *)data toPath:(NSString *)path transferRecord:(CKTransferRecord *)record;
{
    NSError *error;
    NSFileHandle *handle = [_session openHandleAtPath:path
                                                flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                 mode:[self remoteFilePermissions]
                                                error:&error];
    
    if (!handle)
    {
        if ([[error domain] isEqualToString:CK2LibSSH2SFTPErrorDomain] &&
            [error code] == LIBSSH2_FX_NO_SUCH_FILE)
        {
            // Parent directory probably doesn't exist, so create it
            BOOL madeDir = [_session createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                                   withIntermediateDirectories:YES
                                                          mode:[self remoteDirectoryPermissions]];
            
            if (madeDir)
            {
                handle = [_session openHandleAtPath:path
                                              flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                               mode:[self remoteFilePermissions]
                                              error:&error];
            }
        }
    }
    
    if (handle) [[record ks_proxyOnThread:nil waitUntilDone:NO] transferDidBegin:record];
    
    [handle writeData:data];
    [handle closeFile];
    
    [[record ks_proxyOnThread:nil waitUntilDone:NO] transferDidFinish:record
                                                                error:(handle ? nil : error)];
}

#pragma mark SFTP session

@synthesize SFTPSession = _session;

- (void)SFTPSessionDidInitialize:(CK2SFTPSession *)session;
{
    
}

- (void)SFTPSession:(CK2SFTPSession *)session didFailWithError:(NSError *)error;
{
    [self engineDidPublish:NO error:error];
}

- (void)SFTPSession:(CK2SFTPSession *)session didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    [self connection:nil didReceiveAuthenticationChallenge:challenge];
}

@end


#pragma mark -


@implementation SVWriteContentsOfURLToSFTPHandleOperation

- (id)initWithURL:(NSURL *)URL publishingEngine:(SVSFTPPublishingEngine *)engine transferRecord:(CKTransferRecord *)record;
{
    if (self = [self init])
    {
        _URL = [URL copy];
        _path = [[record path] copy];   // copy now since it's not threadsafe
        _engine = [engine retain];
        _record = [record retain];
    }
    
    return self;
}

- (void)dealloc;
{
    [_URL release];
    [_path release];
    [_engine release];
    [_record release];
    
    [super dealloc];
}

- (void)main
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:[_URL path]];
    
    if (handle)
    {
        NSError *error;
        NSFileHandle *sftpHandle = [[_engine SFTPSession] openHandleAtPath:_path
                                                                     flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                                      mode:[_engine remoteFilePermissions]
                                                                     error:&error];
        
        if (!sftpHandle)
        {
            if ([[error domain] isEqualToString:CK2LibSSH2SFTPErrorDomain] &&
                [error code] == LIBSSH2_FX_NO_SUCH_FILE)
            {
                // Parent directory probably doesn't exist, so create it
                BOOL madeDir = [[_engine SFTPSession] createDirectoryAtPath:[_path stringByDeletingLastPathComponent]
                                       withIntermediateDirectories:YES
                                                              mode:[_engine remoteDirectoryPermissions]];
                
                if (madeDir)
                {
                    sftpHandle = [[_engine SFTPSession] openHandleAtPath:_path
                                                                   flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                                    mode:[_engine remoteFilePermissions]
                                                                   error:&error];
                }
            }
        }
        
        if (sftpHandle)
        {
            [[_record ks_proxyOnThread:nil waitUntilDone:NO] transferDidBegin:_record];
            
            while (YES)
            {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                @try
                {
                    if ([self isCancelled]) break;

                    NSData *data = [handle readDataOfLength:CK2SFTPPreferredChunkSize];
                    if (![data length]) break;
                    if ([self isCancelled]) break;
                    
                    [sftpHandle writeData:data];
                }
                @finally
                {
                    [pool release];
                }
            }
        }
        
        [handle closeFile];
        [sftpHandle closeFile];
        
        [[_record ks_proxyOnThread:nil waitUntilDone:NO] transferDidFinish:_record error:(sftpHandle ? nil : error)];
    }
    else
    {
        [[_record ks_proxyOnThread:nil waitUntilDone:NO] transferDidFinish:_record error:nil];
    }
}

@end
