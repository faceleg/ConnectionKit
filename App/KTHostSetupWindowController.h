//
//  KTHostSetupWindowController.h
//  Marvel
//
//  Created by Mike on 19/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface KTHostSetupWindowController : NSWindowController
{
    IBOutlet NSTextField    *siteURLField;
    IBOutlet NSTextField    *hostNameField;
    IBOutlet NSTextField    *userField;
    IBOutlet NSTextField    *passwordField;
}

- (IBAction)testConnection:(NSButton *)sender;
- (IBAction)close:(NSButton *)sender;

@end
