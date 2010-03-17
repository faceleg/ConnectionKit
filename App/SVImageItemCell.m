//
//  SVImageItemCell.m
//  Sandvox
//
//  Created by Mike on 17/03/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVImageItemCell.h"


@implementation SVImageItemCell

- (void)setObjectValue:(id <NSCopying>)obj
{
    // Generate image from the item
    id <IMBImageItem> item = (id <IMBImageItem>)obj;
    if (item)
    {
        NSImage *image = [NSImage imageWithIMBImageItem:item];
        [super setObjectValue:image];
    }
    else
    {
        [super setObjectValue:obj];
    }
}

@end
