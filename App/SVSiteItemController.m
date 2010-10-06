//
//  SVSiteItemController.m
//  Sandvox
//
//  Created by Mike on 06/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVSiteItemController.h"

#import "NSArray+Karelia.h"


@interface SVSiteItemController ()

@property(nonatomic, retain, readwrite) id <SVMedia> thumbnailMedia;

@property(nonatomic, copy) NSArray *childPagesToIndex;

@end



@implementation SVSiteItemController

- (void)dealloc;
{
    [self setContent:nil];  // make sure bindings etc. are torn down
    
    [_thumbnail release];
    [_pagesController release];
    
    [super dealloc];
}

#pragma mark Content

- (void)setContent:(id)content;
{
    [self unbind:@"thumbnailMedia"];
    [self unbind:@"childPagesToIndex"];
    
    [super setContent:content];
    
    // Match thumbnail up to custom image for now
    if (content)
    {
        switch ([[content thumbnailType] intValue])
        {
            case SVThumbnailTypeNone:
                [self setThumbnailMedia:nil];
                break;
                
            case SVThumbnailTypeCustom:
                [self bind:@"thumbnailMedia"
                  toObject:content
               withKeyPath:@"customThumbnail"
                   options:nil];
                break;
                
            case SVThumbnailTypePickFromPage:
                [self bind:@"thumbnailMedia"
                  toObject:content
               withKeyPath:@"thumbnailSourceGraphic.thumbnailMedia"
                   options:nil];
                break;
                
            case SVThumbnailTypeFirstChildItem:
            case SVThumbnailTypeLastChildItem:
            {
                // This is it boys, this is war. Need a controller for the pages...
                NSArrayController *pagesController = [self childPagesToIndexController];
                [self bind:@"childPagesToIndex"
                  toObject:pagesController
               withKeyPath:@"arrangedObjects"
                   options:nil];
                
                // ...and from there take the thumbnail media
                [self bind:@"thumbnailMedia"
                  toObject:_thumbnailSourceItemController
               withKeyPath:@"thumbnailMedia"
                   options:nil];
            }
        }
    }
}

@synthesize thumbnailMedia = _thumbnail;

@synthesize childPagesToIndexController = _pagesController;
- (NSArrayController *)childPagesToIndexController;
{
    // Create lazily
    if (!_pagesController && [[self content] isCollection])
    {
        _pagesController = [SVPagesController controllerWithPagesToIndexInCollection:
                            [self content]];
        [_pagesController retain];
    }
    
    return _pagesController;
}

@synthesize childPagesToIndex = _pagesToIndex;
- (void)setChildPagesToIndex:(NSArray *)pages;
{
    pages = [pages copy];
    [_pagesToIndex release]; _pagesToIndex = pages;
    
    
    // Sart monitoring correct page for its thumbnail
    SVThumbnailType thumbnailType = [[[self content] thumbnailType] intValue];
    SVSiteItem *targetItem;
    
    switch (thumbnailType)
    {
        case SVThumbnailTypeFirstChildItem:
            targetItem = [pages firstObjectKS];
            break;
        case SVThumbnailTypeLastChildItem:
            targetItem = [pages lastObject];
            break;
        default:
            targetItem = nil;
            break;
    }
    
    if (targetItem && !_thumbnailSourceItemController)
    {
        // To do so will need a controller (potentially there's a whole chain of them, eek!
        _thumbnailSourceItemController = [[SVSiteItemController alloc] init];
    }
    [_thumbnailSourceItemController setContent:targetItem];
}

@end
