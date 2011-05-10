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

#import "NSManagedObjectContext+KTExtensions.h"

#import "NSError+Karelia.h"

#import "BDAlias.h"
#import "KSExtensibleManagedObject.h"
#import "KSSHA1Stream.h"


@implementation SVMediaMigrationPolicy 

+ (NSManagedObject *)createDestinationInstanceForSourceInstance:(NSManagedObject *)sInstance mediaContainerIdentifier:(NSString *)mediaID entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    // Find Media File
    NSManagedObject *mediaFile = [[self class] sourceMediaFileForContainerIdentifier:mediaID
                                                                             manager:manager
                                                                               error:error];
    if (!mediaFile) return nil; 
    
    
    // Create new media record to match
    NSManagedObject *result = [NSEntityDescription insertNewObjectForEntityForName:[mapping destinationEntityName]
                                                            inManagedObjectContext:[manager destinationContext]];
    
    
    // Locate file on disk
    if ([[[mediaFile entity] name] isEqualToString:@"InDocumentMediaFile"])
    {
        NSString *filename = [mediaFile valueForKey:@"filename"];
        OBASSERT(filename);
        NSURL *url = [manager sourceURLOfMediaWithFilename:filename];
        NSURL *dURL = [manager destinationURLOfMediaWithFilename:filename];
        
        // Copy media. Might well fail, but if so:
        // A) There's nothing user can really do to fix it
        // B) Failure might be because file is already copied
        [[NSFileManager defaultManager] copyItemAtPath:[url path] toPath:[dURL path] error:NULL];
        
        
        
        // Create new media record to match
        [result setValue:filename forKey:@"filename"];
        
        NSString *preferredFilename = [mediaFile valueForKey:@"sourceFilename"];
        if (!preferredFilename)
        {
            preferredFilename = filename;
        }
        OBASSERT(preferredFilename);
        [result setValue:preferredFilename forKey:@"preferredFilename"];
    }
    else if ([[[mediaFile entity] name] isEqualToString:@"ExternalMediaFile"])
    {
        NSData *aliasData = [mediaFile valueForKey:@"aliasData"];
        if (!aliasData)
        {
            if (error) *error = [KSError errorWithDomain:NSCocoaErrorDomain
                                                    code:NSValidationMissingMandatoryPropertyError
                                    localizedDescription:@"External media has no alias data"];
            return nil;
        }
        
        [result setValue:aliasData forKey:@"aliasData"];
        
        NSString *preferredFilename = [[[BDAlias aliasWithData:aliasData] lastKnownPath] lastPathComponent];
        OBASSERT(preferredFilename);
        [result setValue:preferredFilename forKey:@"preferredFilename"];
        
        [result setValue:NSBOOL(NO) forKey:@"shouldCopyFileIntoDocument"];
    }
    else
    {
        OBASSERT_NOT_REACHED("WTF? How is there a third type of media?");
    }
    
    
    // Also record old ID in case anything else needs it
    [result setValue:[KSExtensibleManagedObject archiveExtensibleProperties:
                      [NSMutableDictionary dictionaryWithObject:mediaID
                                                         forKey:@"mediaContainerIdentifier"]]
              forKey:@"extensiblePropertiesData"];
    
    
    // Finish up
    if (sInstance) [manager associateSourceInstance:sInstance withDestinationInstance:result forEntityMapping:mapping];
    
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
    if (!result && error) *error = nil; // report nil error since the media just doesn't exist
    
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
    
    
    // Find Media. Can be given nil result with a nil error to signify media not existing. #110320
    NSManagedObject *dInstance = [[self class] createDestinationInstanceForSourceInstance:sInstance
                                                                 mediaContainerIdentifier:mediaID
                                                                            entityMapping:mapping
                                                                                  manager:manager
                                                                                    error:error];
    if (!dInstance && error && !*error) return YES;
    return (dInstance != nil);
}

@end


#pragma mark -


@implementation SVFileMediaMigrationPolicy

+ (NSManagedObject *)createDestinationInstanceForSourceInstance:(NSManagedObject *)sInstance mediaContainerIdentifier:(NSString *)mediaID entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    NSManagedObject *result = [super createDestinationInstanceForSourceInstance:sInstance mediaContainerIdentifier:mediaID entityMapping:mapping manager:manager error:error];
    
    // Set preferredFilename from page fileName
    NSString *extension = [sInstance valueForKey:@"customFileExtension"];
    if (!extension) extension = @"html";    // shouldn't happen
    
    [result setValue:[[sInstance valueForKey:@"fileName"] stringByAppendingPathExtension:extension]
              forKey:@"preferredFilename"];
    
    return result;
}

- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(SVMigrationManager *)manager error:(NSError **)error;
{
    BOOL result = [super createDestinationInstancesForSourceInstance:sInstance entityMapping:mapping manager:manager error:error];
    
    // Failed to locate file? #119893
    if (result &&
        ![[manager destinationInstancesForEntityMappingNamed:[mapping name]
                                             sourceInstances:[NSArray arrayWithObject:sInstance]] count])
    {
        // Treat like raw HTML
        SVFullPageRawHTMLMediaMigrationPolicy *policy = [[SVFullPageRawHTMLMediaMigrationPolicy alloc] init];
        NSEntityMapping *mapping = [[[manager mappingModel] entityMappingsByName] objectForKey:@"HTMLPageToFileMedia"];
        
        result = [policy createDestinationInstancesForSourceInstance:sInstance
                                                       entityMapping:mapping
                                                             manager:manager
                                                               error:error];
        
        [policy release];
    }
    
    
    return result;
}

@end



#pragma mark -


@implementation SVFullPageRawHTMLMediaMigrationPolicy

- (NSData *)extensiblePropertiesFromHTMLString:(NSString *)html;
{
    if (!html) html = @"";
    NSData *data = [html dataUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:
                                       @"x-sandvox-fake-url:///%@.%@",
                                       [data sha1DigestString],
                                       @"html"]];
    
    SVMedia *media = [[SVMedia alloc] initWithData:data URL:url];
    NSDictionary *properties = [NSDictionary dictionaryWithObject:media forKey:@"media"];
    [media release];
    
    return [KSExtensibleManagedObject archiveExtensibleProperties:properties];
}

- (NSString *)filenameFromName:(NSString *)name customExtension:(NSString *)extension;
{
    if (!extension) extension = @"html";
    NSString *result = [name stringByAppendingPathExtension:extension];
    return result;
}

@end
