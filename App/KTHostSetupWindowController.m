//
//  KTHostSetupWindowController.m
//  Marvel
//
//  Created by Mike on 19/01/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "KTHostSetupWindowController.h"

#import "KTConnectionTest.h"


@implementation KTHostSetupWindowController

- (IBAction)testConnection:(NSButton *)sender
{
    NSURL *connectionURL = [[NSURL alloc] initWithString:@"http://mikeabdullah:d3712d@idisk.mac.com/mikeabdullah/Sites/foo/bar/baz"];
    
    [[KTConnectionTest alloc] initWithSiteURL:[NSURL URLWithString:@"http://homepage.mac.com/mikeabdullah/"]
                                connectionURL:connectionURL
                                     delegate:nil];
    [connectionURL release];
}

- (IBAction)close:(NSButton *)sender
{
    [NSApp endSheet:[self window]];
    [[self window] orderOut:self];
}

@end
