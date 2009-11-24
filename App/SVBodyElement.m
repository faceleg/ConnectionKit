// 
//  SVBodyElement.m
//  Sandvox
//
//  Created by Mike on 18/11/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVBodyElement.h"

#import "SVPageletBody.h"


@implementation SVBodyElement 

@dynamic body;
@dynamic sortKey;

#pragma mark HTML

- (NSString *)HTMLString;
{
    SUBCLASSMUSTIMPLEMENT;
    return nil;
}

- (NSString *)editingElementID;
{
    //  The default is just to generate a string based on object address, keeping us nicely unique
    NSString *result = [NSString stringWithFormat:@"%p", self];
    return result;
}

@end
