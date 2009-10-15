//
//  SVWebContentItem.m
//  Sandvox
//
//  Created by Mike on 02/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVWebContentItem.h"


@implementation SVWebContentItem

#pragma mark Init & Dealloc

- (void)dealloc
{
    [_representedObject release];
    
    [super dealloc];
}

#pragma mark Accessors

@synthesize representedObject = _representedObject;

@end
