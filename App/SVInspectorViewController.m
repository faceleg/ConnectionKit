//
//  SVInspectorViewController.m
//  Sandvox
//
//  Created by Mike on 23/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVInspectorViewController.h"


@implementation SVInspectorViewController

+ (void)initialize
{
    [self exposeBinding:@"inspectedDocument"];
}

@synthesize icon = _icon;

@synthesize inspectedDocument = _inspectedDocument;

#pragma mark Pages

- (NSArray *)inspectedPages
{
    return [[self inspectedPagesController] selectedObjects];
}

@synthesize inspectedPagesController = _inspectedPagesController;

@end
