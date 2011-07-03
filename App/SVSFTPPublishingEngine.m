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

- (CKTransferRecord *)uploadData:(NSData *)data toPath:(NSString *)remotePath;
{
    CKTransferRecord *result = nil;
    
    CKTransferRecord *parent = [self willUploadToPath:remotePath];
    
    if (_SFTPSession)
    {
        LIBSSH2_SFTP_HANDLE *handle = [_SFTPSession openHandleAtPath:remotePath
                                                               flags:LIBSSH2_FXF_WRITE|LIBSSH2_FXF_CREAT|LIBSSH2_FXF_TRUNC
                                                                mode:LIBSSH2_SFTP_S_IRUSR|LIBSSH2_SFTP_S_IWUSR|LIBSSH2_SFTP_S_IRGRP|LIBSSH2_SFTP_S_IROTH];
        
        NSUInteger remainder = [data length];
        while (remainder)
        {
            const void *bytes = [data bytes];
            NSUInteger offset = 0;
             
            NSInteger written = [_SFTPSession write:bytes+offset maxLength:remainder handle:handle];
            offset+=written;
            remainder-=written;
        }
        
        [_SFTPSession closeHandle:handle]; handle = NULL;
        
        
        [result setName:[remotePath lastPathComponent]];
        
        if (result)
        {
            [self didEnqueueUpload:result toDirectory:parent];
        }
        else
        {
            NSLog(@"Unable to create transfer record for path:%@ data:%@", remotePath, data); // case 40520 logging
        }
    }
    
    return result;
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
