//
//  SVPlugInInspector.m
//  Sandvox
//
//  Created by Mike on 30/12/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVPlugInInspector.h"

#import "KSCollectionController.h"
#import "SVInspectorViewController.h"
#import "Sandvox.h"

#import "NSArrayController+Karelia.h"
#import "NSObject+Karelia.h"


static NSString *sPlugInInspectorInspectedObjectsObservation = @"PlugInInspectorInspectedObjectsObservation";


@interface SVPlugInInspector ()
@end


#pragma mark -


@implementation SVPlugInInspector

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    _plugInInspectors = [[NSMutableDictionary alloc] init];
    
    [self setTitle:nil];    // uses default title
    
    [self addObserver:self
           forKeyPath:@"inspectedObjectsController.selectedObjects.plugIn"
              options:NSKeyValueObservingOptionOld
              context:sPlugInInspectorInspectedObjectsObservation];
    
    return self;
}
     
- (void)dealloc
{
    [self removeObserver:self forKeyPath:@"inspectedObjectsController.selectedObjects.plugIn"];
    [self unbind:@"title"];
    [self unbind:@"inspectedPages"];
    
    [_plugInInspectors release];
    
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)
change context:(void *)context
{
    if (context == sPlugInInspectorInspectedObjectsObservation)
    {
        NSString *identifier = [[self inspectedObjectsController] ks_valueForKeyPath:@"selection.plugInIdentifier"
                                                          raisesForNotApplicableKeys:NO];
        
        SVInspectorViewController *inspector = nil;
        if (NSIsControllerMarker(identifier))
        {
            identifier = nil;
        }
        else if (identifier)
        {
            inspector = [_plugInInspectors objectForKey:identifier];
            
            if (!inspector)
            {
                Class class = [[self inspectedObjectsController] valueForKeyPath:@"selection.inspectorFactoryClass"];
                inspector = [class makeInspectorViewController];
                
                if (inspector) [_plugInInspectors setObject:inspector forKey:identifier];
            }
            
            // Give it the right content/selection
            NSArrayController *controller = [inspector inspectedObjectsController];
            NSArray *plugIns = [[self inspectedObjects] valueForKey:@"objectToInspect"];
            [controller setContent:plugIns];
            [controller selectAll];
        }
        
        [self setSelectedInspector:inspector];
    }
    else
    {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark -

@synthesize inspectedPages = _inspectedPages;
- (void)setInspectedPages:(NSArray *)pages;
{
    pages = [pages copy];
    [_inspectedPages release]; _inspectedPages = pages;
    
    // Pass on to plug-in
    [(id)[self selectedInspector] setInspectedPages:pages];
}

@synthesize selectedInspector = _selectedInspector;
- (void)setSelectedInspector:(SVInspectorViewController *)inspector;
{
    if (inspector == [self selectedInspector]) return;
    
    
    // Remove old inspector
    @try
    {
        [[_selectedInspector view] removeFromSuperview];
        [[_selectedInspector inspectedObjectsController] setContent:nil];
    }
    @catch (NSException *exception)
    {
        NSLog(@"%@", [exception description]);
    }
    
    
    // Store new
    [_selectedInspector release]; _selectedInspector = [inspector retain];
    
    
    // Match title to selection
    if (!inspector)
    {
        [self unbind:@"title"];
        [self setTitle:nil];
        return;
    }
    
    
    // Setup new
    @try
    {
        // Match title to selection
        [self bind:@"title" toObject:inspector withKeyPath:@"title" options:nil];
    
        
        NSView *view = [inspector view];    // make sure it's loaded before going further
        
        if (inspector)
        {
            CGFloat height = [inspector contentHeightForViewInInspector];
            if (height > [self contentHeightForViewInInspector])
            {
                [self setContentHeightForViewInInspector:height];
            }
        }
        
        [view setFrame:[[self view] frame]];
        [[self view] addSubview:view];
		
		[_selectedInspector setRepresentedObject:[self representedObject]];
        [(id)_selectedInspector setInspectedPages:[self inspectedPages]];
    }
    @catch (NSException *exception)
    {
        NSLog(@"%@", [exception description]);
    }
}

- (void)setTitle:(NSString *)title;
{
    // Fallback to standard title
    if (!title) title = NSLocalizedString(@"Object", @"Object Inspector");
    [super setTitle:title];
}

@end
