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
@dynamic previousElement;
@dynamic nextElement;


- (NSString *)HTMLString;
{
    SUBCLASSMUSTIMPLEMENT;
}

@end
