//
//  SVElementInfoGatheringHTMLContext.m
//  Sandvox
//
//  Created by Mike on 07/07/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVElementInfoGatheringHTMLContext.h"


@implementation SVElementInfoGatheringHTMLContext

@end


#pragma mark -


@implementation SVElementInfo

- (id)init
{
    if (self = [super init])
    {
        _subelements = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)dealloc;
{
    [_subelements release];
    [super dealloc];
}

- (NSArray *)subelements; { return [[_subelements copy] autorelease]; }

- (void)addSubelement:(KSElementInfo *)element;
{
    [_subelements addObject:element];
}

@end
