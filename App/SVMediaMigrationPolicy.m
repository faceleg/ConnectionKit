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
    // Find Media Container & File
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"identifier == %@", mediaID];
    
    NSArray *containers = [[manager sourceMediaContext] fetchAllObjectsForEntityForName:@"MediaContainer"
                                                                              predicate:predicate
                                                                                  error:error];
    if (!containers) return NO;
    
    
    NSManagedObject *mediaContainer = [containers lastObject];
    NSManagedObject *mediaFile = [mediaContainer valueForKey:@"file"];
    
    // The container might be referencing another, so follow that up
    while (mediaContainer && !mediaFile)
    {
        mediaContainer = [mediaContainer valueForKey:@"sourceMedia"];
        mediaFile = [mediaContainer valueForKey:@"file"];
    }
    
    if (!mediaContainer) return NO; // FIXME: return an error
    
    
    
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
    
    [manager associateSourceInstance:sInstance withDestinationInstance:result forEntityMapping:mapping];
    
    
    // Tidy up
    [media release];
    
    return result;
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
