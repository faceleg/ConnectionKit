//
//  SVDOMController.m
//  Sandvox
//
//  Created by Mike on 13/12/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

#import "SVDOMController.h"


@interface SVDOMController ()
- (void)descendantNeedsUpdate:(SVWebEditorItem *)controller;
@end


#pragma mark -


@implementation SVDOMController

#pragma mark Updating

- (void)update;
{
    [super update]; // does nothing, but hey, might as well
    _needsUpdate = NO;
}

@synthesize needsUpdate = _needsUpdate;

- (void)setNeedsUpdate;
{
    _needsUpdate = YES;
    [self descendantNeedsUpdate:self];
}

- (void)updateIfNeeded; // recurses down the tree
{
    if ([self needsUpdate])
    {
        [self update];
    }
    
    // The update may well have meant no children need updating any more. If so, no biggie as this recursion should do nothing
    [[self childWebEditorItems] makeObjectsPerformSelector:_cmd];
}

- (void)descendantNeedsUpdate:(SVWebEditorItem *)controller;
{
    // If possible ask our parent to take care of it. But if not must just update the controller immediately
    SVWebEditorItem *parent = [self parentWebEditorItem];
    if (parent)
    {
        [parent descendantNeedsUpdate:controller];
    }
    else
    {
        [controller update];
    }
}

@end


#pragma mark -


@implementation SVWebEditorItem (SVDOMController)

- (void)update; { }

@end

