//
//  SVInspectorWindowController.m
//  Sandvox
//
//  Created by Mike on 22/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVInspector.h"
#import "SVInspectorViewController.h"
#import "SVLinkInspector.h"
#import "SVMetricsInspector.h"
#import "SVPageInspector.h"
#import "SVPlugInInspector.h"
#import "SVDocumentInspector.h"
#import "SVWrapInspector.h"

#import "KTDocWindowController.h"

#import "NSImage+Karelia.h"

#import <BWToolkitFramework/BWToolkitFramework.h>


@implementation SVInspector

#pragma mark Init

+ (void)initialize
{
    [self exposeBinding:@"inspectedPagesController"];
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
    if (!window)
    {
        [self unbind:@"inspectedPagesController"];
        [self setInspectedPagesController:[[[NSTreeController alloc] init] autorelease]];
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
    //[_graphicInspector setInspectedObjectsController:controller];
    [_metricsInspector setInspectedObjectsController:controller];
    [_linkInspector setInspectedObjectsController:controller];
    [_plugInInspector setInspectedObjectsController:controller];
}

- (NSArray *)defaultInspectorViewControllers;
{
    //  Document
    _documentInspector = [[SVDocumentInspector alloc] initWithNibName:@"DocumentInspector" bundle:nil];
    [_documentInspector setIdentifier:@"com.karelia.Sandvox.DocumentInspector"];
    [_documentInspector setTitle:NSLocalizedString(@"Document", @"Document Inspector")];
    [_documentInspector setIcon:[NSImage imageNamed:@"document_inspector"] ];
    
    
    // Page
    _pageInspector = [[SVPageInspector alloc] initWithNibName:@"PageInspector" bundle:nil];
    [_pageInspector setIdentifier:@"com.karelia.Sandvox.PageInspector"];
    [_pageInspector setTitle:NSLocalizedString(@"Page", @"Page Inspector")];
    [_pageInspector setIcon:[NSImage imageNamed:@"page_inspector"]];
    
    
    // Wrap
    _wrapInspector = [[SVWrapInspector alloc] initWithNibName:@"WrapInspector" bundle:nil];
    [_wrapInspector setIdentifier:@"com.karelia.Sandvox.WrapInspector"];
    [_wrapInspector setTitle:NSLocalizedString(@"Wrap", @"Wrap Inspector")];
    [_wrapInspector setIcon:[NSImage imageNamed:@"wrap_inspector"]];
    
    
    // Graphic
    //_graphicInspector = [[KSInspectorViewController alloc] initWithNibName:@"GraphicInspector" bundle:nil];
    //[_graphicInspector setIdentifier:@"com.karelia.Sandvox.GraphicInspector"];
    //[_graphicInspector setTitle:NSLocalizedString(@"Graphic", @"Graphic Inspector")];
    //[_graphicInspector setIcon:[NSImage imageNamed:@"graphic_inspector"]];
    
    
    // Metrics
    _metricsInspector = [[SVMetricsInspector alloc] initWithNibName:@"MetricsInspector" bundle:nil];
    [_metricsInspector setIdentifier:@"com.karelia.Sandvox.MetricsInspector"];
    [_metricsInspector setTitle:NSLocalizedString(@"Metrics", @"Metrics Inspector")];
    [_metricsInspector setIcon:[NSImage imageNamed:@"metrics_inspector"]];
    
    
    // Links
    _linkInspector = [[SVLinkInspector alloc] initWithNibName:@"LinkInspector" bundle:nil];
    [_linkInspector setIdentifier:@"com.karelia.Sandvox.LinkInspector"];
    [_linkInspector setTitle:NSLocalizedString(@"Link", @"Link Inspector")];
    [_linkInspector setIcon:[NSImage imageNamed:@"link_inspector"]];
    
    // Plug-in, will set its own title
    _plugInInspector = [[SVPlugInInspector alloc] initWithNibName:@"PlugInInspector" bundle:nil];
    [_plugInInspector setIdentifier:@"com.karelia.Sandvox.PlugInInspector"];
    [_plugInInspector setIcon:[NSImage imageNamed:@"plugin_inspector"]];
    
    
    //  Finish up
    NSArray *result = [NSArray arrayWithObjects:
                       _documentInspector,
                       _pageInspector,
                       // _collectionInspector,		NOT USING THIS ... THOUGH MIKE MAY CHANGE HIS MIND :-)
                       _wrapInspector,
                       //_graphicInspector,         NOR THIS
                       _metricsInspector,
                       _linkInspector,
                       _plugInInspector,
                       nil];
    
    return result;
}

@end
