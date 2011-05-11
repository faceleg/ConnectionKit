//
//  SVEntityMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 11/05/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVEntityMigrationPolicy.h"


@implementation SVEntityMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error
{
    // Flat out ignore orphaned pages
    if ([[mapping sourceEntityName] isEqualToString:@"Page"])
    {
        NSManagedObject *root = [sInstance valueForKeyPath:@"documentInfo.root"];
        if (!root) return YES;
        
        NSManagedObject *aPage = sInstance;
        while (aPage != root)
        {
            aPage = [aPage valueForKey:@"parent"];
            if (!aPage) {
                return YES;
            }
        }
    }
    
    
    return [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];
}

@end
