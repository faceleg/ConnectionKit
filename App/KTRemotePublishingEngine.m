//
//  KTRemotePublishingEngine.m
//  Marvel
//
//  Created by Mike on 29/12/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "KTRemotePublishingEngine.h"

#import "KTSite.h"
#import "KTHostProperties.h"
#import "KTURLCredentialStorage.h"

#import "CK2SSHCredential.h"

#import "NSError+Karelia.h"


@implementation KTRemotePublishingEngine

#pragma mark -
#pragma mark Connection

- (void)createConnection
{
    // Build the request object
    KTHostProperties *hostProperties = [[self site] hostProperties];
    
    NSString *hostName = [hostProperties valueForKey:@"hostName"];
    NSString *protocol = [hostProperties valueForKey:@"protocol"];
    
    NSNumber *port = [hostProperties valueForKey:@"port"];
    
    CKMutableConnectionRequest *request = [[[CKConnectionRegistry sharedConnectionRegistry] connectionRequestForName:protocol
                                                                                                                host:hostName 
                                                                                                                port:port] mutableCopy];
    
    [request setFTPDataConnectionType:[[NSUserDefaults standardUserDefaults] stringForKey:@"FTPDataConnectionType"]];   // Nil by default
    //[request setSFTPLoggingLevel:1];
    
    
    // Create connection object
    id <CKConnection> result = [[CKConnectionRegistry sharedConnectionRegistry] connectionWithRequest:request];
    OBASSERT(result);
    [request release];
    
    [self setConnection:result];
}

@end
