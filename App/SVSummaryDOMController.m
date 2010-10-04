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
    // Tack on control over custom summary
    NSMutableArray *result = [[defaultMenuItems mutableCopy] autorelease];
    
    [result addObject:[NSMenuItem separatorItem]];
    
    NSMenuItem *command = [[NSMenuItem alloc] initWithTitle:@"Remove Custom Summary"
                                                     action:@selector(toggleCustomSummary:)
                                              keyEquivalent:@""];
    [command setTarget:self];
    
    [result addObject:command];
    [command release];
    
    return result;
}

- (void)toggleCustomSummary:(NSMenuItem *)sender;
{
    
}

@end
