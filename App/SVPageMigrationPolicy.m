//
//  SVPageMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 14/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPageMigrationPolicy.h"


typedef enum {
    KTCollectionSortUnspecified = -1,		// used internally
	KTCollectionUnsorted = 0, 
    KTCollectionSortAlpha,
    KTCollectionSortLatestAtBottom,
	KTCollectionSortLatestAtTop,		// = 3 ... default
	KTCollectionSortReverseAlpha,
} KTCollectionSortType;


@implementation SVPageMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    // Home page of old docs tends to have @"" as filename. We want to change to nil
    if (![sInstance valueForKey:@"parent"])
    {
        [sInstance setValue:nil forKey:@"fileName"];
    }
    
    BOOL result = [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];

    return result;
}

- (NSNumber *)sourceCollectionSortOrderIsAscending:(NSNumber *)sOrder;
{
    return NSBOOL([sOrder intValue] < KTCollectionSortLatestAtTop);
}

@end
