//
//  SandvoxBadgeInspector.m
//  BadgeElement
//
//  Created by Mike on 31/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SandvoxBadgeInspector.h"


@implementation SandvoxBadgeInspector

- (NSString *)nibName { return @"BadgePagelet"; }

- (IBAction)badgeClicked:(id)sender
{
	[self setBadgeTypeTag:[sender tag]];
}

@end
