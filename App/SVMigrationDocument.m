//
//  SVMigrationDocument.m
//  Sandvox
//
//  Created by Mike on 17/02/2011.
//  Copyright 2011 Karelia Software. All rights reserved.
//

#import "SVMigrationDocument.h"

#import "SVMediaGraphic.h"
#import "SVMigrationManager.h"
#import "KT.h"

#import "KSThreadProxy.h"


@implementation SVMigrationDocument

#pragma mark Init & Dealloc

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
{
    if (self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError])
    {
        // Kick off migration in background
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        
        NSOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                      selector:@selector(threaded_migrate)
                                                                        object:nil];
        
        [queue addOperation:operation];
        [operation release];
    }
    return self;
}

- (void)close;
{
    // Make sure migration is cancelled
    [self cancelMigration:self];
    
    [super close];
}

- (void)dealloc;
{
    [_migrationManager removeObserver:self forKeyPath:@"migrationProgress"];
    [_migrationManager release];
    
    [super dealloc];
}

#pragma mark Migration

- (void)documentDidMigrate:(BOOL)didMigrateSuccessfully error:(NSError *)error;
{
    if (didMigrateSuccessfully)
    {
        didMigrateSuccessfully = [self readFromURL:[self fileURL] ofType:[self fileType] error:&error];
        if (didMigrateSuccessfully)
        {
            // Close the migration UI
            NSArray *migrationWindowControllers = [self windowControllers];
            for (NSWindowController *aController in migrationWindowControllers)
            {
                [self removeWindowController:aController];
            }
            
            // Show regular UI
            [self makeWindowControllers];
            [self showWindows];
        }
    }
    
    if (!didMigrateSuccessfully)
    {
        [self close];
        [[NSDocumentController sharedDocumentController] presentError:error];   // ignores cancel errors
    }
}

- (void)threaded_migrate;
{
    NSError *error;
    BOOL result = [self saveToURL:[self fileURL]
                           ofType:kSVDocumentTypeName
                 forSaveOperation:NSSaveOperation
                            error:&error];
    
    [[self ks_proxyOnThread:nil waitUntilDone:NO] documentDidMigrate:result error:error];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    if ([typeName isEqualToString:kSVDocumentTypeName_1_5])
    {
        return YES;
    }
    else
    {
        return [super readFromURL:absoluteURL ofType:typeName error:outError];
    }
}

- (BOOL)writeToURL:(NSURL *)inURL 
            ofType:(NSString *)inType 
  forSaveOperation:(NSSaveOperationType)saveOperation
originalContentsURL:(NSURL *)inOriginalContentsURL
             error:(NSError **)outError;
{
    // Only want special behaviour when doing a migration
    if (![[self fileType] isEqualToString:kSVDocumentTypeName_1_5])
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
    
    NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];    // likely to run on worker thread
    if (![fileManager createDirectoryAtPath:[inURL path]
                withIntermediateDirectories:NO
                                 attributes:attributes
                                      error:outError]) return NO;
                                                                                                                         
                                                                                                                         
    // Migrate!
    NSURL *modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Sandvox 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Media 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sMediaModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    _migrationManager = [[SVMigrationManager alloc] initWithSourceModel:sModel
                                                             mediaModel:sMediaModel
                                                       destinationModel:[KTDocument managedObjectModel]];
    
    [_migrationManager addObserver:self forKeyPath:@"migrationProgress" options:0 context:NULL];
    
    OBASSERT(_migrationManager);
    if (![(SVMigrationManager *)_migrationManager migrateDocumentFromURL:inOriginalContentsURL
                                                        toDestinationURL:inURL
                                                                   error:outError]) return NO;
    
    
    
    return YES;
}

- (BOOL)keepBackupFile;
{
    // Only want to keep backup when migrating in case you need to get back to 1.6 land
    BOOL result = ([[self fileType] isEqualToString:kSVDocumentTypeName_1_5] ? YES : [super keepBackupFile]);
    return result;
}

#pragma mark Autosave

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    // During migration, ignore any attempts to autosave, pretending they worked
    if (saveOperation == NSAutosaveOperation && [[self fileType] isEqualToString:kSVDocumentTypeName_1_5])
    {
        return YES;
    }
    else
    {
        return [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    }
}

#pragma mark UI

- (NSString *)windowNibName { return @"DocumentMigration"; }

/*  Start up the progress indicator and set text fields right
 */
- (void)awakeFromNib
{
    NSString *filename = [[NSFileManager defaultManager] displayNameAtPath:[[self fileURL] path]];
    NSString *message = [NSString stringWithFormat:
                         NSLocalizedString(@"Upgrading document “%@.”","document upgrade message text"), filename];
    [messageTextField setStringValue:message];
    
    
    NSString *path = [[self fileURL] path];
    //path = [KTDataMigrator renamedFileName:path modelVersion:kKTModelVersion_ORIGINAL];
    filename = [[NSFileManager defaultManager] displayNameAtPath:path];
    
    message = [NSString stringWithFormat:
               NSLocalizedString(@"Before it can be opened, this document must be upgraded to the latest Sandvox data format. A backup of the original document will be kept in the same folder in case you need to refer back to it","document upgrade informative text"),
               filename];
    [informativeTextField setStringValue:message];
    
	[cancelButton setTitle:NSLocalizedString(@"Cancel","Button title")];
    
	
    //[dataMigratorController setContent:[self dataMigrator]];
    [progressIndicator startAnimation:self];
    
}

- (IBAction)cancelMigration:(id)sender
{
    // Ask the migrator to cancel. It may take a few moments to actually stop
    [_migrationManager cancelMigrationWithError:[NSError errorWithDomain:NSCocoaErrorDomain
                                                                    code:NSUserCancelledError
                                                                userInfo:nil]];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    float progress = [_migrationManager migrationProgress];
    [[progressIndicator ks_proxyOnThread:nil waitUntilDone:NO] setDoubleValue:progress];
    [[progressIndicator ks_proxyOnThread:nil waitUntilDone:NO] setIndeterminate:NO];
}

@end
