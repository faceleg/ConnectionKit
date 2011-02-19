//
//  SVMigrationDocument.m
//  Sandvox
//
//  Created by Mike on 17/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationDocument.h"

#import "SVMigrationManager.h"
#import "KT.h"

@implementation SVMigrationDocument

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:kKTDocumentUTI_1_5])
    {
        if (![self saveToURL:absoluteURL ofType:kKTDocumentType forSaveOperation:NSSaveOperation error:outError]) return NO;

        typeName = [[NSDocumentController sharedDocumentController] typeForContentsOfURL:absoluteURL error:outError];
        if (!typeName) return NO;
    }
    
    return [super readFromURL:absoluteURL ofType:typeName error:outError];
}

- (BOOL)writeToURL:(NSURL *)inURL 
            ofType:(NSString *)inType 
  forSaveOperation:(NSSaveOperationType)saveOperation
originalContentsURL:(NSURL *)inOriginalContentsURL
             error:(NSError **)outError;
{
    // Only want special behaviour when doing a migration
    if (![[self fileType] isEqualToString:kKTDocumentUTI_1_5])
    {
        return [super writeToURL:inURL ofType:inType forSaveOperation:saveOperation originalContentsURL:inOriginalContentsURL error:outError];
    }
    
    
    // Create directory to act as new document
    NSDictionary *attributes = [self fileAttributesToWriteToURL:inURL
                                                         ofType:inType
                                               forSaveOperation:saveOperation
                                            originalContentsURL:inOriginalContentsURL
                                                          error:outError];
    if (!attributes) return NO;
    
    if (![[NSFileManager defaultManager] createDirectoryAtPath:[inURL path]
                                   withIntermediateDirectories:NO
                                                    attributes:attributes
                                                         error:outError]) return NO;
                                                                                                                         
                                                                                                                         
    // Migrate!
    NSURL *modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Sandvox 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Media 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sMediaModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    SVMigrationManager *manager = [[SVMigrationManager alloc] initWithSourceModel:sModel
                                                                       mediaModel:sMediaModel
                                                                 destinationModel:[KTDocument managedObjectModel]];
    
    
    OBASSERT(manager);
    if (![manager migrateDocumentFromURL:inOriginalContentsURL
                        toDestinationURL:inURL
                                   error:outError]) return NO;
    
    
    // Ask the doc to size its media. #108740
    KTDocument *document = [[KTDocument alloc] initWithContentsOfURL:inURL ofType:inType error:outError];
    if (!document) return NO;
    
    NSArray *mediaGraphics = [[document managedObjectContext] fetchAllObjectsForEntityForName:@"MediaGraphic" error:NULL];
    [mediaGraphics makeObjectsPerformSelector:@selector(makeOriginalSize)];
    
    if (![document saveToURL:inURL ofType:inType forSaveOperation:NSSaveOperation error:outError])
    {
        [document release];
        return NO;
    }
    
    [document release];
    
    
    return YES;
}

- (BOOL)keepBackupFile;
{
    // Only want to keep backup when migrating in case you need to get back to 1.6 land
    BOOL result = ([[self fileType] isEqualToString:kKTDocumentUTI_1_5] ? YES : [super keepBackupFile]);
    return result;
}

@end
