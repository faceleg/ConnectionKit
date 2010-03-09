//
//  SVTabViewController.m
//  Sandvox
//
//  Created by Mike on 09/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVTabViewController.h"


@implementation SVTabViewController

+ (void)initialize
{
    [self exposeBinding:@"selectedIndex"];
}

@end
