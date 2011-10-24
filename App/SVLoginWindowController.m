//
//  SVLoginWindowController.m
//  Sandvox
//
//  Created by Mike on 23/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVLoginWindowController.h"


@implementation SVLoginWindowController

- (id)init;
{
    return [self initWithWindowNibName:@"Login"];
}

- (void)dealloc
{
    [_challenge release];
    [super dealloc];
}

@synthesize authenticationChallenge = _challenge;
- (void)setAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge;
{
    [challenge retain];
    [_challenge release]; _challenge = challenge;
    
    [self window];  // make sure it's loaded
    NSURLCredential *credential = [challenge proposedCredential];
    
    NSString *user = [credential user];
    if (!user) user = @"";
    [oUserField setStringValue:user];
    
    [oKeychainCheckbox setState:([credential persistence] == NSURLCredentialPersistencePermanent ?
                                 NSOnState :
                                 NSOffState)];
}

- (NSURLCredential *)credential;
{
    [self window];  // make sure it's loaded
    
    NSURLCredential *result = [NSURLCredential credentialWithUser:[oUserField stringValue]
                                                          password:[oPasswordField stringValue]
                                                       persistence:([oKeychainCheckbox state] ?
                                                                    NSURLCredentialPersistencePermanent :
                                                                    NSURLCredentialPersistenceForSession)];
    
    return result;
}

- (IBAction)login:(id)sender;
{
    [NSApp endSheet:[self window] returnCode:NSOKButton];
    [[self window] orderOut:self];
}

- (IBAction)cancel:(id)sender;
{
    [NSApp endSheet:[self window] returnCode:NSCancelButton];
    [[self window] orderOut:self];
}

@end
