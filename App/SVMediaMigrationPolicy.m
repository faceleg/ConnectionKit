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

- (NSManagedObject *)createDestinationInstanceForSourceInstance:(NSManagedObject *)sInstance mediaContainerIdentifier:(NSString *)mediaID entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    // Find Media File
    NSManagedObject *mediaFile = [[self class] sourceMediaFileForContainerIdentifier:mediaID
                                                                             manager:manager
                                                                               error:error];
    if (!mediaFile) return NO; 
    
    
    
    // Locate file on disk
    NSString *filename = [mediaFile valueForKey:@"filename"];
    NSURL *url = [manager sourceURLOfMediaWithFilename:filename];
    NSURL *dURL = [manager destinationURLOfMediaWithFilename:filename];
    
    // Copy media. Might well fail, but if so:
    // A) There's nothing user can really do to fix it
    // B) Failure might be because file is already copied
    [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:[dURL path] error:NULL];
    
    
    
    // Create new media record to match
    SVMedia *media = [[SVMedia alloc] initByReferencingURL:dURL];
    
    NSManagedObject *result = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                            inManagedObjectContext:[manager destinationContext]];
    
    [result setValue:filename forKey:@"filename"];
    
    NSString *preferredFilename = [mediaFile valueForKey:@"sourceFilename"];
    if (!preferredFilename)
    {
        preferredFilename = filename;
    }
    [result setValue:preferredFilename forKey:@"preferredFilename"];
    
    
    // Also record old ID in case anything else needs it
    [result setValue:[KSExtensibleManagedObject archiveExtensibleProperties:
                      [NSMutableDictionary dictionaryWithObject:mediaID
                                                         forKey:@"mediaContainerIdentifier"]]
              forKey:@"extensiblePropertiesData"];
    
    
    // Finish up
    [manager associateSourceInstance:sInstance withDestinationInstance:result forEntityMapping:mapping];
    [media release];
    
    return result;
}

+ (NSManagedObject *)sourceMediaFileForContainerIdentifier:(NSString *)containerID manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    // Find Media Container & File
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", containerID];
    
    NSArray *containers = [[manager sourceMediaContext] fetchAllObjectsForEntityForName:@"MediaContainer"
                                                                              predicate:predicate
                                                                                  error:error];
    if (!containers) return nil;
    
    
    
    // The container might be referencing another, so follow that up
    NSManagedObject *mediaContainer = [containers lastObject];
    
    while ([[[mediaContainer entity] relationshipsByName] objectForKey:@"sourceMedia"] &&
           [mediaContainer valueForKey:@"sourceMedia"])
    {
        mediaContainer = [mediaContainer valueForKey:@"sourceMedia"];
    }
    
    NSManagedObject *result = [mediaContainer valueForKey:@"file"];
    return result;  // FIXME: return an error if nil
}

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
    return ([self createDestinationInstanceForSourceInstance:sInstance mediaContainerIdentifier:mediaID entityMapping:mapping manager:manager error:error] != nil);
}

@end
