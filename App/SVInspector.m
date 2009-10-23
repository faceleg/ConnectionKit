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
    
    SVInspectorViewController *pageInspector = [[SVInspectorViewController alloc] initWithNibName:@"PageInspector" bundle:nil];
    [pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    
    NSArray *inspectors = [[NSArray alloc] initWithObjects:documentInspector, pageInspector, nil];
    [documentInspector release];
    [pageInspector release];
    
    [[self inspectorTabsController] setViewControllers:inspectors selectedIndex:0];
    [inspectors release];
}

@end
