//
//  SVPublishingHTMLContext.m
//  Sandvox
//
//  Created by Mike on 08/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVPublishingHTMLContext.h"


@implementation SVPublishingHTMLContext

- (void)dealloc
{
    [_publishingEngine release];
    
    [super dealloc];
}

@synthesize publishingEngine = _publishingEngine;

@end
