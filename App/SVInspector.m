//
//  SVInspectorWindowController.m
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspector.h"
#import "SVInspectorViewController.h"

#import "KSTabViewController.h"


@implementation SVInspector

+ (void)initialize
{
    [self exposeBinding:@"inspectedPagesController"];
}

@synthesize inspectedPagesController = _inspectedPagesController;

- (void)setInspectedWindow:(NSWindow *)window
{
    if ([self inspectedWindow])
    {
        [self unbind:@"inspectedPagesController"];
    }
    
    [super setInspectedWindow:window];
    
    if (window)
    {
        [self bind:@"inspectedPagesController"
          toObject:window
       withKeyPath:@"windowController.siteOutlineViewController.pagesController"
           options:nil];
    }
}

- (NSArray *)defaultInspectorViewControllers;
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:2];
    

    SVInspectorViewController *documentInspector = [[SVInspectorViewController alloc] initWithNibName:@"DocumentInspector" bundle:nil];
    [documentInspector setTitle:NSLocalizedString(@"Document", @"Document Inspector")];
    [documentInspector bind:@"inspectedDocument"
                   toObject:self
                withKeyPath:@"inspectedWindow.windowController.document"
                    options:nil];
    [documentInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:documentInspector atIndex:0];
    [documentInspector release];
    
    SVInspectorViewController *pageInspector = [[SVInspectorViewController alloc] initWithNibName:@"PageInspector" bundle:nil];
    [pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    [pageInspector bind:@"inspectedDocument"
               toObject:self
            withKeyPath:@"inspectedWindow.windowController.document"
                options:nil];
    [pageInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:pageInspector atIndex:1];
    [pageInspector release];
    
    
    return result;
}

@end
