//
//  SVPageMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 14/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVPageMigrationPolicy.h"

#import "KTPage.h"


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
    
    // Make sure collectionMaxFeedItemLength is appropriate
    if (![sInstance valueForKey:@"collectionTruncateCharacters"])
    {
        NSEntityDescription *dEntity = [manager destinationEntityForEntityMapping:mapping];
        NSAttributeDescription *dAttribute = [[dEntity attributesByName] objectForKey:@"collectionMaxFeedItemLength"];
        [sInstance setValue:[dAttribute defaultValue] forKey:@"collectionTruncateCharacters"];
    }
    
    // collectionMaxSyndicatedPagesCount can no longer be zero. Instead make it rather large
    if ([[sInstance valueForKey:@"collectionMaxIndexItems"] intValue] < 1)
    {
        [sInstance setValue:[NSNumber numberWithInt:20] forKey:@"collectionMaxIndexItems"];
    }
    
    
    BOOL result = [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];

    return result;
}

- (NSNumber *)sourceCollectionSortOrderIsAscending:(NSNumber *)sOrder;
{
    return NSBOOL([sOrder intValue] < KTCollectionSortLatestAtTop);
}

- (NSNumber *)collectionSortOrderFromSource:(NSManagedObject *)sInstance;
{
    NSNumber *sOrder = [sInstance valueForKey:@"collectionSortOrder"];
    switch ([sOrder intValue])
    {
        case KTCollectionSortAlpha:
        case KTCollectionSortReverseAlpha:
            return [NSNumber numberWithInt:SVCollectionSortAlphabetically];
            
        case KTCollectionSortLatestAtBottom:
        case KTCollectionSortLatestAtTop:
        {
            NSNumber *timestampType = [sInstance valueForKeyPath:@"master.timestampType"];
            return [NSNumber numberWithInt:([timestampType intValue] == KTTimestampCreationDate ?
                                            SVCollectionSortByDateCreated :
                                            SVCollectionSortByDateModified)];
        }
            
        default:
            return [NSNumber numberWithInt:SVCollectionSortManually];
    }
}

@end
