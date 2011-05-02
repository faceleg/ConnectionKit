//
//  NSImageView+IMBImageItem.m
//  Sandvox
//
//  Created by Mike on 19/08/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//

#import "NSImageView+IMBImageItem.h"

#import <iMedia/iMedia.h>


NSString *IMBImageItemBinding = @"imageItem";


@implementation NSImageView (IMBImageItem)

+ (void)load;
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    [self exposeBinding:IMBImageItemBinding];
    [pool release];
}

- (id)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code here.
    }
    return self;
}

- (id <IMBImageItem>)imageItem;
{
    return nil;
}

- (void)setImageItem:(id <IMBImageItem>)item;
{
    NSImage *image = [NSImage imageWithIMBImageItem:item];
    [self setImage:image];
}

@end
