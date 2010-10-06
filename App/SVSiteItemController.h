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
    
    NSArrayController   *_pagesController;
}

@property(nonatomic, retain) id <SVMedia> thumbnailMedia;

@property(nonatomic, readonly) NSArrayController *childPagesController;

@end
