//
//  SVSiteItemController.h
//  Sandvox
//
//  Created by Mike on 06/10/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

//  Used by the Page Inspector for handling all KVO etc. required to figure out the thumbnail image of a page. May have wider uses in the future.


#import <Cocoa/Cocoa.h>
#import "SVSiteItem.h"

#import "SVPagesController.h"
#import "SVMediaProtocol.h"


@interface SVSiteItemController : NSObjectController
{
  @private
    id <SVMedia>    _thumbnail;
    SVThumbnailType _thumbnailType;
    
    NSArrayController       *_pagesController;
    NSArray                 *_pagesToIndex;
    SVSiteItemController    *_thumbnailSourceItemController;
}

@property(nonatomic, retain, readonly) id <SVMedia> thumbnailMedia;
@property(nonatomic) SVThumbnailType thumbnailType;
- (BOOL)picksThumbnailFromPage;
- (BOOL)usesCustomThumbnail;

@property(nonatomic, readonly) NSArrayController *childPagesToIndexController;

@end
