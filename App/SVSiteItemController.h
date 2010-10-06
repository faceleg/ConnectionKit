//
//  SVSiteItemController.h
//  Sandvox
//
//  Created by Mike on 06/10/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "SVSiteItem.h"

#import "SVPagesController.h"
#import "SVMediaProtocol.h"


@interface SVSiteItemController : NSObjectController
{
  @private
    id <SVMedia>    _thumbnail;
    
    NSArrayController       *_pagesController;
    NSArray                 *_pagesToIndex;
    SVSiteItemController    *_thumbnailSourceItemController;
}

@property(nonatomic, retain, readonly) id <SVMedia> thumbnailMedia;

@property(nonatomic, readonly) NSArrayController *childPagesToIndexController;

@end
