//
//  SVInspectorViewController.m
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009-2011 Karelia Software. All rights reserved.
//

#import "SVInspectorViewController.h"


@interface SVInspectorViewController ()
@property(nonatomic, copy) NSArray *inspectedPages;
@end



@implementation SVInspectorViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    
    _inspectedObjectsController = [[NSArrayController alloc] init];
    [_inspectedObjectsController setAvoidsEmptySelection:NO];
    [_inspectedObjectsController setClearsFilterPredicateOnInsertion:NO];
    [_inspectedObjectsController setSelectsInsertedObjects:NO];
    
    return self;
}

#pragma mark Presentation

- (void)setView:(NSView *)view;
{
    [super setView:view];
    
    // Want to store the tab height before anyone else has a chance to distort it
    if (![self contentHeightForViewInInspector])
    {
        [self setContentHeightForViewInInspector:[[self view] frame].size.height];
    }
}

@synthesize contentHeightForViewInInspector = _tabHeight;

#pragma mark -

- (NSArray *)inspectedObjects; { return [[self inspectedObjectsController] selectedObjects]; }

- (NSArrayController *)inspectedObjectsController;
{
    return _inspectedObjectsController;
}

@synthesize inspectedPages = _inspectedPages;

@end
