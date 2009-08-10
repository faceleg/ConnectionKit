//
//  KTMobileMePublishingEngine.m
//  Marvel
//
//  Created by Mike on 23/12/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTMobileMePublishingEngine.h"

#import "NSError+Karelia.h"


@implementation KTMobileMePublishingEngine

- (void)createConnection
{
	id <CKConnection> connection = [[CKDotMacConnection alloc] initWithUser:nil];
    if (connection)
    {
        [self setConnection:connection];
        [connection release];
    }
    else
    {
        NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineErrorNoCredentialForAuthentication
							 localizedDescription:NSLocalizedString(@"MobileMe username could not be found.", @"Publishing engine authentication error")
					  localizedRecoverySuggestion:NSLocalizedString(@"Please run the Host Setup Assistant and re-enter your host's login credentials.", @"Publishing engine authentication error")
								  underlyingError:nil];
        
        [self engineDidPublish:NO error:error];
    }
}

/*  Use the password we have stored in the keychain corresponding to the challenge's protection space
 *  and the host properties' username.
 *  If the password cannot be retrieved, fail with an error saying why
 */
- (void)connection:(id <CKConnection>)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    if ([challenge previousFailureCount] > 0)
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        
        NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineErrorAuthenticationFailed
							 localizedDescription:NSLocalizedString(@"Authentication failed.", @"Publishing engine authentication error")
					  localizedRecoverySuggestion:NSLocalizedString(@"Please check your account settings in the MobileMe System Preferences pane.", @"Publishing engine authentication error")
								  underlyingError:[challenge error]];
        
		[self engineDidPublish:NO error:error];
        return;
    }
    
    
    NSURLCredential *credential = [challenge proposedCredential];
	if (credential && [credential hasPassword] && [credential password])    // Fetching it from the keychain might fail
    {
        [[challenge sender] useCredential:credential forAuthenticationChallenge:challenge];
    }
    else
    {
        [[challenge sender] cancelAuthenticationChallenge:challenge];
        
		NSError *error = [NSError errorWithDomain:KTPublishingEngineErrorDomain
											 code:KTPublishingEngineErrorNoCredentialForAuthentication
							 localizedDescription:NSLocalizedString(@"MobileMe password could not be found.", @"Publishing engine authentication error")
					  localizedRecoverySuggestion:NSLocalizedString(@"Please run the Host Setup Assistant and re-enter your host's login credentials.", @"Publishing engine authentication error")
								  underlyingError:[challenge error]];
        
		[self engineDidPublish:NO error:error];
    }
}

@end
