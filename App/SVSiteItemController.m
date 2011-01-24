//
//  SVSiteItemController.m
//  Sandvox
//
//  Created by Mike on 06/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
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
    [self unbind:@"childPagesToIndex"];
    [self unbind:@"thumbnailType"];
    
    [_thumbnail release];
    [_pagesController release];
    OBPOSTCONDITION(!_pagesToIndex);
    OBPOSTCONDITION(!_thumbnailSourceItemController);
    
    [super dealloc];
}

#pragma mark Content

- (void)prepareThumbnail;
{
    switch ([self thumbnailType])
    {
        case SVThumbnailTypeNone:
            [self setThumbnailMedia:nil];
            break;
            
        case SVThumbnailTypeCustom:
            if ([self content])
            {
                [self bind:@"thumbnailMedia"
                  toObject:[self content]
               withKeyPath:@"self"
                   options:nil];
            }
            else
            {
                [self unbind:@"thumbnailMedia"];
            }
            break;
            
        case SVThumbnailTypePickFromPage:
            if ([self content])
            {
                [self bind:@"thumbnailMedia"
                  toObject:[self content]
               withKeyPath:@"thumbnailSourceGraphic.thumbnailMedia"
                   options:nil];
            }
            else
            {
                [self unbind:@"thumbnailMedia"];
            }
            break;
            
        case SVThumbnailTypeFirstChildItem:
        case SVThumbnailTypeLastChildItem:
        {
            // This is it boys, this is war. Need a controller for the pages...
            // The controller might already be loaded, so if so just jog our memory of what to index. #104216
            if ([self childPagesToIndex]) [self setChildPagesToIndex:[self childPagesToIndex]];
            [self childPagesToIndexController]; // makes sure it's loaded/bound
            
            // ...and from there take the thumbnail media
            if (_thumbnailSourceItemController)
            {
                [self bind:@"thumbnailMedia"
                  toObject:_thumbnailSourceItemController
               withKeyPath:@"thumbnailMedia"
                   options:nil];
            }
        }
    }
}

- (void)setContent:(id)content;
{
    [self unbind:@"thumbnailMedia"];
    [self unbind:@"childPagesToIndex"];
    
    [super setContent:content];
    
    if (content)
    {
        [self bind:@"thumbnailType" toObject:content withKeyPath:@"thumbnailType" options:nil];
    }
    else
    {
        [self setThumbnailType:SVThumbnailTypeNone];
    }
    
    // Match thumbnail up to custom image for now
    [self prepareThumbnail];
}

@synthesize thumbnailMedia = _thumbnail;

@synthesize thumbnailType = _thumbnailType;
- (void)setThumbnailType:(SVThumbnailType)type;
{
    [self willChangeValueForKey:@"picksThumbnailFromPage"]; // dependent key paths don't seem to work on controllers
    
    _thumbnailType = type;
    [self prepareThumbnail];
    
    [self didChangeValueForKey:@"picksThumbnailFromPage"];
}

- (void)setNilValueForKey:(NSString *)key;  // #102342
{
    if ([key isEqualToString:@"thumbnailType"])
    {
        [self setThumbnailType:SVThumbnailTypeNone];
    }
    else
    {
        [super setNilValueForKey:key];
    }
}

- (BOOL)picksThumbnailFromPage;
{
    BOOL result = ([self thumbnailType] == SVThumbnailTypePickFromPage);
    return result;
}

#pragma mark Sub-Controllers

- (NSArrayController *)childPagesToIndexController;
{
    // Create lazily
    if (!_pagesController && [[self content] isCollection])
    {
        _pagesController = [SVPagesController controllerWithPagesToIndexInCollection:
                            [self content]];
        [_pagesController retain];
        
        [self bind:@"childPagesToIndex"
          toObject:_pagesController
       withKeyPath:@"arrangedObjects"
           options:nil];
        
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
