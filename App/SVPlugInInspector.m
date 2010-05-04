//
//  SVPlugInInspector.m
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInInspector.h"

#import "KSCollectionController.h"
#import "SVInspectorViewController.h"

#import "NSArrayController+Karelia.h"


static NSString *sPlugInInspectorInspectedObjectsObservation = @"PlugInInspectorInspectedObjectsObservation";


@implementation SVPlugInInspector

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    [self addObserver:self forKeyPath:@"inspectedObjectsController.selectedObjects" options:0 context:sPlugInInspectorInspectedObjectsObservation];
    
    return self;
}
     
- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"inspectedObjects"];
    
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)
change context:(void *)context
{
    if (context == sPlugInInspectorInspectedObjectsObservation)
    {
        NSString *identifier = nil;
        @try
        {
            identifier = [[[self inspectedObjectsController] selection] valueForKeyPath:@"plugInIdentifier"];
        }
        @catch (NSException *exception)
        {
            if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        }
        
        
        SVInspectorViewController *inspector = nil;
        if (identifier && !NSIsControllerMarker(identifier))
        {
            // If re-selecting something of the same type, keep the Inspector we aready have
            Class controllerClass = [[[self inspectedObjectsController] selection] valueForKeyPath:@"plugIn.class.inspectorViewControllerClass"];
            
            if ([[self selectedInspector] isKindOfClass:controllerClass]) return;
            
            
            // Make an Inspector.
            NSBundle *bundle = [NSBundle bundleForClass:controllerClass];
            inspector = [[controllerClass alloc] initWithNibName:nil    // subclass will override -nibName
                                                          bundle:bundle];
            
            // Give it the right content/selection
            NSArrayController *controller = [inspector inspectedObjectsController];
            NSArray *plugIns = [[self inspectedObjects] valueForKey:@"plugIn"];
            [controller setContent:plugIns];
            [controller selectAll];
        }
        
        [self setSelectedInspector:inspector];
        [inspector release];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -

@synthesize selectedInspector = _selectedInspector;
- (void)setSelectedInspector:(SVInspectorViewController *)inspector
{
    // Remove old inspector
    [[_selectedInspector view] removeFromSuperview];
    [[_selectedInspector inspectedObjectsController] setContent:nil];
    
    // Store new
    [inspector retain];
    [_selectedInspector release]; _selectedInspector = inspector;
    
    // Setup new
    @try
    {
        [[inspector view] setFrame:[[self view] frame]];
        [[self view] addSubview:[inspector view]];
    }
    @catch (NSException *exception)
    {
        // TODO: Log error
    }
}

- (CGFloat)viewHeight
{
    CGFloat result = ([self selectedInspector] ? [[[self selectedInspector] view] frame].size.height : [super viewHeight]);
    return result;
}

@end
