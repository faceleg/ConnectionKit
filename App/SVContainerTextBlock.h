//
//  SVContainerTextBlock.h
//  Sandvox
//
//  Created by Mike on 01/09/2009.
//  Copyright 2009 Karelia Software. All rights reserved.
//

//  Takes a regular text block and adds the ability to embed pagelets in it.


#import "SVBindableTextBlock.h"


@class SVWebContentItem;


@interface SVContainerTextBlock : SVBindableTextBlock
{
    NSMutableSet    *_webContentItems;
}

- (NSSet *)webContentItems;
- (void)addWebContentItem:(SVWebContentItem *)item;
- (void)removeWebContentItem:(SVWebContentItem *)item;

@end
