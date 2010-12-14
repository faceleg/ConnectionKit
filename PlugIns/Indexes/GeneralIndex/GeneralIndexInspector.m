//
//  GeneralIndexInspector.m
//  GeneralIndex
//
//  Created by Dan Wood on 12/1/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "GeneralIndexInspector.h"
#import "GeneralIndexPlugIn.h"


@implementation GeneralIndexInspector


- (void)loadView;
{
	[super loadView];
    // Bind banner type
    [oTruncationController bind:@"truncateCount" toObject:self withKeyPath:@"inspectedObjectsController.selection.truncateCount" options:nil];
    [oTruncationController bind:@"truncationType" toObject:self withKeyPath:@"inspectedObjectsController.selection.truncationType" options:nil];
}

@end
