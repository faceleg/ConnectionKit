//
//  SVLoginWindowController.h
//  Sandvox
//
//  Created by Mike on 23/09/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface SVLoginWindowController : NSWindowController
{
    IBOutlet NSTextField        *oUserField;
    IBOutlet NSSecureTextField  *oPasswordField;
    IBOutlet NSButton           *oKeychainCheckbox;
    
  @private
    NSURLAuthenticationChallenge *_challenge;
}

@property(nonatomic, retain) NSURLAuthenticationChallenge *authenticationChallenge;

// nil, if user cancelled. Encapsulates whether they want password stored too.
- (NSURLCredential *)credential;

- (IBAction)login:(id)sender;
- (IBAction)cancel:(id)sender;

@end
