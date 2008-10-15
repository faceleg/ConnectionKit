//
//  NSURL+Twitter.m
//  TwitterElement
//
//  Created by Mike on 15/10/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "NSURL+Twitter.h"


@implementation NSURL (Twitter)

- (NSString *)twitterUsername
{
    NSString *result = nil;
    
    if ([[self host] isEqualToString:@"twitter.com"])
    {
        NSArray *pathComponents = [[self path] pathComponents];
        if ([pathComponents count] >= 2)
        {
            result = [pathComponents objectAtIndex:1];
        }
    }
    
    return result;
}

@end
