//
//  SVSiteItemController.m
//  Sandvox
//
//  Created by Mike on 06/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItemController.h"


@implementation SVSiteItemController

- (void)dealloc;
{
    [self unbind:@"thumbnailMedia"];
    
    [_thumbnail release];
    [_pagesController release];
    
    [super dealloc];
}

#pragma mark Content

- (void)setContent:(id)content;
{
    [self unbind:@"thumbnailMedia"];
    
    [super setContent:content];
    
    // Match thumbnail up to custom image for now
    if (content)
    {
        [self bind:@"thumbnailMedia"
          toObject:content
       withKeyPath:@"customThumbnail"
           options:nil];
    }
}

@synthesize thumbnailMedia = _thumbnail;

@synthesize childPagesController = _pagesController;

@end
