//
//  SVInspectorWindowController.m
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspector.h"
#import "SVInspectorViewController.h"
#import "SVLinkInspector.h"
#import "SVPageInspector.h"
#import "SVPlugInInspector.h"
#import "SVDocumentInspector.h"

#import "KTDocWindowController.h"

#import "KSTabViewController.h"


@implementation SVInspector

#pragma mark Init

+ (void)initialize
{
    [self exposeBinding:@"inspectedPagesController"];
}

- (id)initWithWindow:(NSWindow *)window
{
    if (self = [super initWithWindow:window])
    {
        [self setInspectorFrameTopLeftPointAutosaveName:gInfoWindowAutoSaveName];
    }
    return self;
}

#pragma mark Inspected Pages

@synthesize inspectedPagesController = _inspectedPagesController;
- (void)setInspectedPagesController:(id <KSCollectionController>)controller
{
    [_documentInspector setInspectedObjectsController:controller];
    [_pageInspector setInspectedObjectsController:controller];
    [_collectionInspector setInspectedObjectsController:controller];
}

@synthesize linkInspector = _linkInspector;

- (void)setInspectedWindow:(NSWindow *)window
{
    if ([self inspectedWindow])
    {
        [self unbind:@"inspectedPagesController"];
        [self setInspectedPagesController:[[self class] noSelectionController]];
    }
    
    
    [super setInspectedWindow:window];
    
    
    if (window)
    {
        [self bind:@"inspectedPagesController"
          toObject:window
       withKeyPath:@"windowController.siteOutlineViewController.pagesController"
           options:nil];
    }
    
    
    // Document
    KTDocument *document = [[window windowController] document];
    [[[self inspectorTabsController] viewControllers] setValue:document forKey:@"representedObject"];
    
    // Objects
    id <KSCollectionController> controller = [[window windowController] objectsController];
    if (!controller) controller = [[self class] noSelectionController];
    
    [_wrapInspector setInspectedObjectsController:controller];
    [_metricsInspector setInspectedObjectsController:controller];
    [_linkInspector setInspectedObjectsController:controller];
    [_plugInInspector setInspectedObjectsController:controller];
}

- (NSArray *)defaultInspectorViewControllers;
{
    //  Document
    _documentInspector = [[SVDocumentInspector alloc] initWithNibName:@"DocumentInspector" bundle:nil];
    [_documentInspector setTitle:NSLocalizedString(@"Document", @"Document Inspector")];
    [_documentInspector setIcon:[NSImage imageNamed:@"emptyDoc"]];
    
    
    // Page
    _pageInspector = [[SVPageInspector alloc] initWithNibName:@"PageInspector" bundle:nil];
    [_pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    [_pageInspector setIcon:[NSImage imageNamed:@"toolbar_new_page"]];
    
    
    // Collection
    _collectionInspector = [[KSInspectorViewController alloc] initWithNibName:@"CollectionInspector" bundle:nil];
    [_collectionInspector setTitle:NSLocalizedString(@"Collection", @"Collection Inspector")];
    [_collectionInspector setIcon:[NSImage imageNamed:@"toolbar_collection"]];
    
    
    // Wrap
    _wrapInspector = [[KSInspectorViewController alloc] initWithNibName:@"WrapInspector" bundle:nil];
    [_wrapInspector setTitle:NSLocalizedString(@"Wrap", @"Wrap Inspector")];
    [_wrapInspector setIcon:[NSImage imageNamed:@"WrapInspector"]];
    
    
    // Metrics
    _metricsInspector = [[KSInspectorViewController alloc] initWithNibName:@"MetricsInspector" bundle:nil];
    [_metricsInspector setTitle:NSLocalizedString(@"Metrics", @"Metrics Inspector")];
    [_metricsInspector setIcon:[NSImage imageNamed:NSImageNameActionTemplate]];
    
    
    // Links
    _linkInspector = [[SVLinkInspector alloc] initWithNibName:@"LinkInspector" bundle:nil];
    [_linkInspector setTitle:NSLocalizedString(@"Link", @"Link Inspector")];
    [_linkInspector setIcon:[NSImage imageNamed:@"follow"]];
    
    // Plug-in
    _plugInInspector = [[SVPlugInInspector alloc] initWithNibName:@"PlugInInspector" bundle:nil];
    [_plugInInspector setTitle:NSLocalizedString(@"Plug-in", @"Plug-in Inspector")];
    [_plugInInspector setIcon:[NSImage imageNamed:@"pageplugin"]];
    
    
    //  Finish up
    NSArray *result = [NSArray arrayWithObjects:
                       _documentInspector,
                       _pageInspector,
                       _collectionInspector,
                       _wrapInspector,
                       _metricsInspector,
                       _linkInspector,
                       _plugInInspector,
                       nil];
    
    return result;
}

@end
