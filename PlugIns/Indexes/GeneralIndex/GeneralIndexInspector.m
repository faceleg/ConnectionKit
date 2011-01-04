//
//  GeneralIndexInspector.m
//  GeneralIndex
//
//  Created by Dan Wood on 12/1/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "GeneralIndexInspector.h"
#import "GeneralIndexPlugIn.h"


@implementation GeneralIndexInspector


- (void)loadView;
{
	[super loadView];
    [oTruncationController bind:@"maxItemLength" toObject:self withKeyPath:@"inspectedObjectsController.selection.maxItemLength" options:nil];
	
}

- (void)dealloc
{
    [self unbind:@"maxItemLength"];

    [super dealloc];
}


@end
