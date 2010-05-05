//
//  BadgeInspector.m
//  BadgeElement
//
//  Created by Mike on 31/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "BadgeInspector.h"


@implementation BadgeInspector

- (NSString *)nibName { return @"BadgeInspector"; }

- (IBAction)badgeClicked:(id)sender
{
	[[[self inspectedObjectsController] selection] setInteger:[[sender selectedItem] tag]
                                                       forKey:@"badgeTypeTag"];
}

@end
