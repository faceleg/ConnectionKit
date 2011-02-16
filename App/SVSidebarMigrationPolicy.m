//
//  SVSidebarMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 16/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVSidebarMigrationPolicy.h"


@implementation SVSidebarMigrationPolicy

- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dSidebar entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error;
{
    NSArray *sPages = [manager sourceInstancesForEntityMappingNamed:[mapping name] destinationInstances:[NSArray arrayWithObject:dSidebar]];
    for (NSManagedObject *sPage in sPages)
    {
        // Import pagelets connected directly to the page
        NSSet *sPagelets = [sPage valueForKey:@"pagelets"];
        sPagelets = [sPagelets filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"location == 1"]];
        
        NSArray *dPagelets = [manager destinationInstancesForEntityMappingNamed:nil sourceInstances:[sPagelets allObjects]];
        [dSidebar setValue:[NSSet setWithArray:dPagelets] forKey:@"pagelets"];
    }
    
    return YES;
}

@end
