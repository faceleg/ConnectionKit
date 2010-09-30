//
//  SVCollectionPagesController.m
//  Sandvox
//
//  Created by Mike on 30/09/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVCollectionPagesController.h"


@implementation SVCollectionPagesController

+ (SVCollectionPagesController *)pagesControllerWithCollection:(KTPage *)collection;
{
    SVCollectionPagesController *result = [[self alloc] init];
    
    [result setSortDescriptors:
     [collection
      sortDescriptorsForCollectionSortType:[[collection collectionSortOrder] intValue]
      ascending:[[collection collectionSortAscending] boolValue]]];
    
    [result setAutomaticallyRearrangesObjects:YES];
    
    [result bind:NSContentSetBinding toObject:collection withKeyPath:@"childItems" options:nil];
    
    return [result autorelease];
}

@end
