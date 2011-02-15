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
    // Find Media
    NSDictionary *properties = [KSExtensibleManagedObject unarchiveExtensibleProperties:[sInstance valueForKey:@"extensiblePropertiesData"]];
    NSString *mediaID = [properties valueForKeyPath:@"downloadMedia.myObjectIdentifier"];
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", mediaID];
    
    NSArray *containers = [[manager sourceMediaContext] fetchAllObjectsForEntityForName:@"MediaContainer"
                                                                              predicate:predicate
                                                                                  error:error];
    if (![containers count]) return NO;
    
    NSManagedObject *mediaContainer = [containers objectAtIndex:0];
    NSManagedObject *mediaFile = [mediaContainer valueForKey:@"file"];
    NSString *filename = [mediaFile valueForKey:@"filename"];
    NSURL *url = [manager sourceURLOfMediaWithFilename:filename];
    
    
    // Create new media record to match
    SVMedia *media = [[SVMedia alloc] initByReferencingURL:url];
    
    NSManagedObject *record = [NSEntityDescription insertNewObjectForEntityForName:@"FileMedia"
                                                            inManagedObjectContext:[manager destinationContext]];
    
    [record setValue:filename forKey:@"filename"];
    [record setValue:[mediaFile valueForKey:@"sourceFilename"] forKey:@"preferredFilename"];
    
    [manager associateSourceInstance:sInstance withDestinationInstance:record forEntityMapping:mapping];
    
    
    // Tidy up
    [media release];
    
    return YES;
}

@end
