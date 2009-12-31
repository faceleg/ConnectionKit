//
//  SVPlugInInspector.m
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVPlugInInspector.h"


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
        id controllerClass = nil;
        
        @try
        {
            controllerClass = [[[self inspectedObjectsController] selection] valueForKeyPath:@"plugIn.class.inspectorViewControllerClass"];
        }
        @catch (NSException *exception)
        {
            if (![[exception name] isEqualToString:NSUndefinedKeyException]) @throw exception;
        }
        
        SVInspectorViewController *inspector = nil;
        if (!NSIsControllerMarker(controllerClass))
        {
            inspector = [[[controllerClass alloc] init] autorelease];
        }
        
        [self setSelectedInspector:inspector];
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
    [[inspector view] removeFromSuperview];
    [inspector setInspectedObjectsController:nil];
    
    // Store new
    [inspector retain];
    [_selectedInspector release]; _selectedInspector = inspector;
    
    // Setup new
    [inspector setInspectedObjectsController:[self inspectedObjectsController]];
    
    [[inspector view] setFrame:[[self view] frame]];
    [[self view] addSubview:[inspector view]];
}

- (CGFloat)viewHeight
{
    CGFloat result = ([self selectedInspector] ? [[self selectedInspector] viewHeight] : [super viewHeight]);
    return result;
}

- (void)setInspectedObjectsController:(id <KSCollectionController>)controller
{
    [super setInspectedObjectsController:controller];
    
    [[self selectedInspector] setInspectedObjectsController:controller];
}

@end
