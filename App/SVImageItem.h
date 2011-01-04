//
//  SVImageItem.h
//  Sandvox
//
//  Created by Mike on 04/11/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//
//  A simple implementation of IMBImageItem that can be passed off to a background thread for processing, since we shouldn't do so with managed objects directly


#import <iMedia/iMedia.h>


@interface SVImageItem : NSObject <IMBImageItem>
{
  @private
    id          _rep;
    NSString    *_repType;
    
    id <IMBImageItem>   _sourceItem;
}

- (id)initWithImageRepresentation:(id)rep type:(NSString *)repType;
- (id)initWithIMBImageItem:(id <IMBImageItem>)item;

@property(nonatomic, readonly) id <IMBImageItem> originalItem;

- (BOOL)isEqualToIMBImageItem:(id <IMBImageItem>)anItem;


@end