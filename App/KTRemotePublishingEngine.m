//
//  KTRemotePublishingEngine.m
//  Marvel
//
//  Created by Mike on 29/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTRemotePublishingEngine.h"

#import "KTDocumentInfo.h"
#import "KTHostProperties.h"
#import "KTURLCredentialStorage.h"

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
    
    
    // Create connection object
    id <CKConnection> result = [[CKConnectionRegistry sharedConnectionRegistry] connectionWithRequest:request];
    OBASSERT(result);
    [request release];
    
    [self setConnection:result];
}

/*  Use the password we have stored in the keychain corresponding to the challenge's protection space
 *  and the host properties' username.
 *  If the password cannot be retrieved, fail with an error saying why
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    if ([challenge previousFailureCount] == 0)
	{
		KTHostProperties *hostProperties = [[self site] hostProperties];
		
		NSString *user = [hostProperties valueForKey:@"userName"];
		BOOL isSFTPWithPublicKey = ([[[challenge protectionSpace] protocol] isEqualToString:@"ssh"] &&
									[[hostProperties valueForKey:@"usePublicKey"] intValue] == NSOnState);
		
		if (isSFTPWithPublicKey)
		{
			[[challenge sender] useCredential:[NSURLCredential credentialWithUser:user
                                                                         password:nil
                                                                      persistence:NSURLCredentialPersistenceNone]
                   forAuthenticationChallenge:challenge];
		}
		else
		{
			NSURLCredential *credential = [[KTURLCredentialStorage sharedCredentialStorage] credentialForUser:user
                                                                                              protectionSpace:[challenge protectionSpace]];
            
            if (credential && [credential password])
            {
                [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
            }
            else
            {
                [[challenge sender] cancelAuthenticationChallenge:challenge];
                
                NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
                                                     code:KTPublishingEngineErrorNoCredentialForAuthentication
                                     localizedDescription:NSLocalizedString(@"Username or password could not be found.", @"Publishing engine authentication error")
                              localizedRecoverySuggestion:NSLocalizedString(@"Please run the Host Setup Assistant and re-enter your host's login credentials.", @"Publishing engine authentication error")
                                          underlyingError:[challenge error]];
                
                [self failWithError:error];
            }
        }
	}
	else
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        
        NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineErrorAuthenticationFailed
							 localizedDescription:NSLocalizedString(@"Authentication failed.", @"Publishing engine authentication error")
					  localizedRecoverySuggestion:NSLocalizedString(@"Please run the Host Setup Assistant again to test your host setup.", @"Publishing engine authentication error")
								  underlyingError:[challenge error]];
        
		[self failWithError:error];
    }
}

@end
