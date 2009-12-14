//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@implementation SVDOMController

- (void)dealloc
{
    [_context release];
    [super dealloc];
}

#pragma mark Updating

- (void)update;
{
    [super update]; // does nothing, but hey, might as well
    _needsUpdate = NO;
}

@synthesize needsUpdate = _needsUpdate;

- (void)setNeedsUpdate;
{
    // Try to get hold of the controller in charge of update coalescing
    id controller = (id)[[self webEditorView] delegate];
    if ([controller respondsToSelector:@selector(scheduleUpdate)])
    {
        _needsUpdate = YES;
        [controller performSelector:@selector(scheduleUpdate)];
    }
    else
    {
        [self update];
    }
}

- (void)updateIfNeeded; // recurses down the tree
{
    if ([self needsUpdate])
    {
        [self update];
    }
    
    [super updateIfNeeded];
}

@synthesize HTMLContext = _context;

@end


#pragma mark -


@implementation SVWebEditorItem (SVDOMController)

- (void)update; { }

- (void)updateIfNeeded; // recurses down the tree
{
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

@end

