//
//  SVLayoutView.m
//  Sandvox
//
//  Created by Mike on 04/10/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVLayoutView.h"

#import "NSView+Karelia.h"


@implementation SVLayoutView

/*  Super-duper simple for now. Just ensure our interior view is centered at all times
 */

- (void)setFrame:(NSRect)frameRect
{
    [super setFrame:frameRect];
    [centeredView centerInRect:[self bounds]];
}

@end
