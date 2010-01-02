//
//  SVInspectorViewController.m
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspectorViewController.h"


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

- (NSArray *)inspectedObjects; { return [[self inspectedObjectsController] selectedObjects]; }

- (NSArrayController *)inspectedObjectsController;
{
    return _inspectedObjectsController;
}

@end
