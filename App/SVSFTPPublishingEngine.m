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

- (id)initWithURL:(NSURL *)URL path:(NSString *)path publishingEngine:(SVSFTPPublishingEngine *)engine transferRecord:(CKTransferRecord *)record;

@end


#pragma mark -


@implementation SVSFTPPublishingEngine

#pragma mark Lifecycle

- (id)init;
{
    if (self = [super init])
    {
        _queue = [[NSOperationQueue alloc] init];
        [_queue setMaxConcurrentOperationCount:1];
        [_queue setSuspended:YES];  // we'll resume once authenticated
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
    if (port && ![port unsignedIntegerValue]) port = nil;   // somehow some sites have 0 stored as port
    
    CKConnectionRequest *request = [[CKConnectionRegistry sharedConnectionRegistry] connectionRequestForName:protocol
                                                                                                        host:hostName 
                                                                                                        port:port];
    
    _session = [[CK2SFTPSession alloc] initWithURL:[request URL] delegate:self startImmediately:NO];
}

- (void)finishGeneratingContent;
{
    [super finishGeneratingContent];
    
    
    // Disconnect once all else is done
    NSOperation *closeOp = [[NSInvocationOperation alloc] initWithTarget:self
                                                                selector:@selector(threaded_finish)
                                                                  object:nil];
    
    NSArray *operations = [_queue operations];
    for (NSOperation *anOp in operations)
    {
        [closeOp addDependency:anOp];
    }
    
    [_queue addOperation:closeOp];
    [closeOp release];
    
}

- (void)threaded_finish;
{
    [_session cancel];
    [_session release]; _session = nil;
    
    [[self ks_proxyOnThread:nil waitUntilDone:NO] finishPublishing:YES error:nil];
}

- (void)finishPublishing:(BOOL)didPublish error:(NSError *)error
{
    if (!didPublish || [self isCancelled])
    {
        // Stop any pending ops
        [_queue cancelAllOperations];
        
        // Close the connection as quick as possible
        NSOperation *closeOp = [[NSInvocationOperation alloc] initWithTarget:[self SFTPSession]
                                                                    selector:@selector(cancel)
                                                                      object:nil];
        
        [closeOp setQueuePriority:NSOperationQueuePriorityVeryHigh];
        [_queue addOperation:closeOp];
        [closeOp release];
        
        // Clear out ivars, the actual objects will get torn down as the queue finishes its work
        [_queue release]; _queue = nil;
        [_session release]; _session = nil;
    }
    
    [super finishPublishing:didPublish error:error];
}

- (void)dealloc;
{
    OBASSERT(!_session);    // should have already been handled
    [_queue release];
    
    [super dealloc];
}

#pragma mark Upload

- (CKTransferRecord *)willUploadToPath:(NSString *)path;
{
    if (!_sessionStarted)
    {
        NSInvocationOperation *op = [[NSInvocationOperation alloc] initWithTarget:[self SFTPSession]
                                                                         selector:@selector(start)
                                                                           object:nil];
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        [queue addOperation:op];
        [op release];
        [queue release];
        
        _sessionStarted = YES;
    }
    
    return [super willUploadToPath:path];
}

- (void)didEnqueueUpload:(CKTransferRecord *)record toDirectory:(CKTransferRecord *)parent;
{
    [parent addContent:record];
}

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)path;
{
    CKTransferRecord *result = nil;
    
    CKTransferRecord *parent = [self willUploadToPath:path];
    
    if ([self SFTPSession])
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
    
    if ([self SFTPSession])
    {
        NSNumber *size = [[NSFileManager defaultManager] sizeOfFileAtPath:[localURL path]];
        
        if (size)   // if size can't be determined, no chance of being able to upload
        {
            result = [CKTransferRecord recordWithName:[path lastPathComponent] size:[size unsignedLongLongValue]];
            [self didEnqueueUpload:result toDirectory:parent];  // so record has correct path
            
            
            NSOperation *op = [[SVWriteContentsOfURLToSFTPHandleOperation alloc] initWithURL:localURL
                                                                                        path:path
                                                                            publishingEngine:self
                                                                              transferRecord:result];
            [_queue addOperation:op];
            [op release];
            
            
            
        }
    }
    
    return result;
}

- (BOOL)threaded_createDirectoryAtPath:(NSString *)path error:(NSError **)outError;
{
    CK2SFTPSession *sftpSession = [self SFTPSession];
    OBPRECONDITION(sftpSession);
    
    NSError *error;
    BOOL result = [sftpSession createDirectoryAtPath:path
                         withIntermediateDirectories:YES
                                                mode:[self remoteDirectoryPermissions]
                                               error:&error];
    
    
    if (!result)
    {
        if (outError) *outError = error;
        
        // It's possible directory creation failed because there's already a FILE by the same name…
        if ([[error domain] isEqualToString:CK2LibSSH2SFTPErrorDomain] &&
            [error code] == LIBSSH2_FX_FAILURE)
        {
            NSString *failedPath = [[error userInfo] objectForKey:NSFilePathErrorKey];  // might be a parent dir
            if (failedPath)
            {
                // …so try to destroy that file…
                if ([sftpSession removeFileAtPath:failedPath error:outError])
                {
                    // …then create the directory
                    if ([sftpSession createDirectoryAtPath:failedPath
                               withIntermediateDirectories:YES
                                                      mode:[self remoteDirectoryPermissions]
                                                     error:outError])
                    {
                        // And finally, might still need to make some child dirs
                        if ([failedPath isEqualToString:path])
                        {
                            result = YES;
                        }
                        else
                        {
                            result = [self threaded_createDirectoryAtPath:path error:outError];
                        }
                    }
                }
            }
        }
    }
    
    return result;
}

- (CK2SFTPFileHandle *)threaded_openHandleAtPath:(NSString *)path error:(NSError **)outError;
{
    CK2SFTPSession *sftpSession = [self SFTPSession];
    OBPRECONDITION(sftpSession);
    
    NSError *error;
    CK2SFTPFileHandle *result = [sftpSession openHandleAtPath:path
                                                        flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                         mode:[self remoteFilePermissions]
                                                        error:&error];
    
    if (!result)
    {
        if (outError) *outError = error;
        
        if ([[error domain] isEqualToString:CK2LibSSH2SFTPErrorDomain] &&
            [error code] == LIBSSH2_FX_NO_SUCH_FILE)
        {
            // Parent directory probably doesn't exist, so create it
            BOOL madeDir = [self threaded_createDirectoryAtPath:[path stringByDeletingLastPathComponent]
                                                          error:outError];
            
            if (madeDir)
            {
                result = [sftpSession openHandleAtPath:path
                                                 flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                  mode:[self remoteFilePermissions]
                                                 error:outError];
            }
        }
    }
    
    return result;
}

- (void)threaded_writeData:(NSData *)data toPath:(NSString *)path transferRecord:(CKTransferRecord *)record;
{
    CK2SFTPSession *sftpSession = [self SFTPSession];
    OBPRECONDITION(sftpSession);
    
    NSError *error;
    CK2SFTPFileHandle *handle = [self threaded_openHandleAtPath:path error:&error];
    
    if (handle)
    {
        [[self ks_proxyOnThread:nil waitUntilDone:NO] transferDidBegin:record];
        
        BOOL result = [handle writeData:data error:&error];
        [handle closeFile];         // don't really care if this fails
        if (!result) handle = nil;  // so error gets sent
    }
    
    [[record ks_proxyOnThread:nil waitUntilDone:NO] transferDidFinish:record
                                                                error:(handle ? nil : error)];
}

- (void)transferDidBegin:(CKTransferRecord *)record;
{
    [record transferDidBegin:record];
    [[self delegate] publishingEngine:self didBeginUploadToPath:[record path]];
}

#pragma mark SFTP session

@synthesize SFTPSession = _session;

- (void)SFTPSessionDidInitialize:(CK2SFTPSession *)session;
{
    [_queue setSuspended:NO];
}

- (void)SFTPSession:(CK2SFTPSession *)session didFailWithError:(NSError *)error;
{
    [self finishPublishing:NO error:error];
}

- (void)SFTPSession:(CK2SFTPSession *)session didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    [[self ks_proxyOnThread:nil waitUntilDone:NO] connection:nil
                           didReceiveAuthenticationChallenge:challenge];
}

- (void)SFTPSession:(CK2SFTPSession *)session appendStringToTranscript:(NSString *)string;
{
    [[self ks_proxyOnThread:nil waitUntilDone:NO]
     connection:[self connection] appendString:string toTranscript:CKTranscriptSent];
}

@end


#pragma mark -


@implementation SVWriteContentsOfURLToSFTPHandleOperation

- (id)initWithURL:(NSURL *)URL path:(NSString *)path publishingEngine:(SVSFTPPublishingEngine *)engine transferRecord:(CKTransferRecord *)record;
{
    if (self = [self init])
    {
        _URL = [URL copy];
        _path = [path copy];   // copy now since it's not threadsafe
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
        CK2SFTPFileHandle *sftpHandle = [_engine threaded_openHandleAtPath:_path error:&error];
        
        if (sftpHandle)
        {
            [[_engine ks_proxyOnThread:nil waitUntilDone:NO] transferDidBegin:_record];
            
            while (YES)
            {
                NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
                @try
                {
                    if ([self isCancelled]) break;
                    
                    NSData *data = [handle readDataOfLength:CK2SFTPPreferredChunkSize];
                    if (![data length]) break;
                    if ([self isCancelled]) break;
                    
                    if (![sftpHandle writeData:data error:&error])
                    {
                        [sftpHandle closeFile]; // don't care if it fails
                        sftpHandle = nil;   // so error gets sent
                        break;
                    }
                    
                    [[_record ks_proxyOnThread:nil waitUntilDone:NO]
                     transfer:_record transferredDataOfLength:[data length]];
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
