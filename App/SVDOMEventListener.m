//
//  SVDOMEventListener.m
//  Sandvox
//
//  Created by Mike on 12/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMEventListener.h"


@implementation SVDOMEventListener

@synthesize eventsTarget = _target;

- (void)handleEvent:(DOMEvent *)event;
{
    [[self eventsTarget] handleEvent:event];
}

@end
