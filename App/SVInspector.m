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

- (NSArrayController *)inspectedPagesController
{
    if (!_inspectedPagesController)
    {
        _inspectedPagesController = [[NSArrayController alloc] init];
        [_inspectedPagesController setAvoidsEmptySelection:NO];
        [_inspectedPagesController setPreservesSelection:NO];
    }
    
    return _inspectedPagesController;
}

- (void)setInspectedPages:(NSArray *)pages;
{
    NSArrayController *controller = [self inspectedPagesController];
    [controller setContent:pages];
    [controller setSelectionIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [pages count])]];
}

- (void)setInspectedWindow:(NSWindow *)window
{
    [super setInspectedWindow:window];
    
    NSArray *pages = [[[[window windowController] siteOutlineViewController] pagesController] selectedObjects];
    [self setInspectedPages:pages];
}

- (NSArray *)defaultInspectorViewControllers;
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:2];
    

    SVInspectorViewController *documentInspector = [[SVInspectorViewController alloc] initWithNibName:@"DocumentInspector" bundle:nil];
    [documentInspector setTitle:NSLocalizedString(@"Document", @"Document Inspector")];
    [documentInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:documentInspector atIndex:0];
    [documentInspector release];
    
    SVInspectorViewController *pageInspector = [[SVInspectorViewController alloc] initWithNibName:@"PageInspector" bundle:nil];
    [pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    [pageInspector setInspectedPagesController:[self inspectedPagesController]];
    [result insertObject:pageInspector atIndex:1];
    [pageInspector release];
    
    
    return result;
}

@end
