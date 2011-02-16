//
//  SVMediaMigrationPolicy.m
//  Sandvox
//
//  Created by Mike on 15/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMediaMigrationPolicy.h"

#import "SVMedia.h"
#import "SVMediaRecord.h"
#import "SVMigrationManager.h"

#import "KSExtensibleManagedObject.h"


@implementation SVMediaMigrationPolicy

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    // Figure media ID
    NSString *keyPath = [[mapping userInfo] objectForKey:@"mediaContainerIdentifierKeyPath"];
    NSString *mediaID;
    
    if ([[[sInstance entity] attributesByName] objectForKey:keyPath])
    {
        mediaID = [sInstance valueForKey:keyPath];
    }
    else
    {
        NSDictionary *properties = [KSExtensibleManagedObject unarchiveExtensibleProperties:[sInstance valueForKey:@"extensiblePropertiesData"]];
        mediaID = [properties valueForKeyPath:keyPath];
    }
    
    if (!mediaID) return YES;   // there was no media to import
    
    
    // Find Media
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", mediaID];
    
    NSArray *containers = [[manager sourceMediaContext] fetchAllObjectsForEntityForName:@"MediaContainer"
                                                                              predicate:predicate
                                                                                  error:error];
    if (![containers count]) return NO; // FIXME: return an error
    
    NSManagedObject *mediaContainer = [containers objectAtIndex:0];
    NSManagedObject *mediaFile = [mediaContainer valueForKey:@"file"];
    NSString *filename = [mediaFile valueForKey:@"filename"];
    NSURL *url = [manager sourceURLOfMediaWithFilename:filename];
    
    
    // Create new media record to match
    SVMedia *media = [[SVMedia alloc] initByReferencingURL:url];
    
    NSManagedObject *record = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                            inManagedObjectContext:[manager destinationContext]];
    
    [record setValue:filename forKey:@"filename"];
    
    NSString *preferredFilename = [mediaFile valueForKey:@"sourceFilename"];
    if (!preferredFilename)
    {
        preferredFilename = filename;
    }
    [record setValue:preferredFilename forKey:@"preferredFilename"];
    
    [manager associateSourceInstance:sInstance withDestinationInstance:record forEntityMapping:mapping];
    
    
    // Tidy up
    [media release];
    
    return YES;
}

@end
