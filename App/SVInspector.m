//
//  SVInspectorWindowController.m
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspector.h"
#import "SVInspectorViewController.h"


@implementation SVInspector

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    // Setup default inspectors
    SVInspectorViewController *documentInspector = [[SVInspectorViewController alloc] initWithNibName:@"DocumentInspector" bundle:nil];
    [documentInspector setTitle:NSLocalizedString(@"Document", @"Document Inspector")];
    [[self inspectorTabsController] insertViewController:documentInspector atIndex:0];
    [documentInspector release];
    
    SVInspectorViewController *pageInspector = [[SVInspectorViewController alloc] initWithNibName:@"PageInspector" bundle:nil];
    [pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    [[self inspectorTabsController] insertViewController:pageInspector atIndex:1];
    [pageInspector release];
}

@end
