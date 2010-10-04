//
//  SVSummaryDOMController.m
//  Sandvox
//
//  Created by Mike on 02/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSummaryDOMController.h"


@implementation SVSummaryDOMController

- (NSString *)elementIdName;
{
    // We probably shouldn't have to implement this! Instead context should generate IDs automatically of something like that
    return [NSString stringWithFormat:@"%p", self];
}

- (NSArray *)contextMenuItemsForElement:(NSDictionary *)element defaultMenuItems:(NSArray *)defaultMenuItems;
{
    return defaultMenuItems;
}

@end
