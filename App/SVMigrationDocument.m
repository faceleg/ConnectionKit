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

- (BOOL)migrateURL:(NSURL *)sourceURL ofType:(NSString *)type error:(NSError **)error;
{    
    [self autosaveDocumentWithDelegate:self didAutosaveSelector:@selector(document:didAutosave:contextInfo:) contextInfo:NULL];
    
    return YES;
}

- (void)document:(SVMigrationDocument *)document didAutosave:(BOOL)didSave contextInfo:(void *)context;
{
    NSURL *modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Sandvox 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Media 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sMediaModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    SVMigrationManager *manager = [[SVMigrationManager alloc] initWithSourceModel:sModel
                                                                       mediaModel:sMediaModel
                                                                 destinationModel:[KTDocument managedObjectModel]];
    
    
    BOOL result = [manager migrateDocumentFromURL:[self fileURL]
                                 toDestinationURL:[self autosavedContentsFileURL]
                                            error:NULL];
    return result;
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:kKTDocumentUTI_1_5])
    {
        if ([self migrateURL:absoluteURL ofType:NSSQLiteStoreType error:outError])
        {
            typeName = [[NSDocumentController sharedDocumentController] typeForContentsOfURL:absoluteURL error:outError];
            if (!typeName) return NO;
            
            return YES;
        }
        else
        {
            //if (outError) NSLog(@"%@", *outError);
            return NO;
        }
    }
    else
    {
        return [super readFromURL:absoluteURL ofType:typeName error:outError];
    }
}

@end
