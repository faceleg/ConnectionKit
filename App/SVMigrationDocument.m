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

#import "KSAppDelegate.h"
#import "KSDocumentController.h"

#import "KSThreadProxy.h"
#import "KSURLUtilities.h"


@implementation SVMigrationDocument

#pragma mark Lifecycle

- (id)initWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
{
    if (self = [super initWithContentsOfURL:absoluteURL ofType:typeName error:outError])
    {
        
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

- (void)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation delegate:(id)delegate didSaveSelector:(SEL)didSaveSelector contextInfo:(void *)contextInfo;
{
    // Is this a migration, so should run on background thread?
    if ([typeName isEqualToString:kSVDocumentTypeName] && ![[self fileType] isEqualToString:kSVDocumentTypeName])
    {
        OBASSERT(!delegate);
        
        // Time for UI
        [self makeWindowControllers];
        [self showWindows];
        
        // Deregister recent doc
        [[NSDocumentController sharedDocumentController] clearRecentDocumentURL:[self fileURL]];
        
        
        NSOperationQueue *queue = [[NSOperationQueue alloc] init];
        
        NSOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
                                                                      selector:@selector(threaded_migrateToURL:)
                                                                        object:absoluteURL];
        
        [queue addOperation:operation];
        [operation release];
    }
    else
    {
        [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation delegate:delegate didSaveSelector:didSaveSelector contextInfo:contextInfo];
    }
}

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

- (void)threaded_migrateToURL:(NSURL *)newURL;
{    
    NSError *error;
    BOOL result = [self saveToURL:newURL
                           ofType:kSVDocumentTypeName
                 forSaveOperation:NSSaveAsOperation
                            error:&error];
    
    [[self ks_proxyOnThread:nil waitUntilDone:NO]
     documentDidMigrate:result
     error:(result ? nil : error)]; // if successful, error might be random pointer, so can't pass to main thread. #113018
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
                                                                                                                         
                                                                                                                         
    // Migrate!
    NSURL *modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Sandvox 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    modelURL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"Media 1.5" ofType:@"mom"]];
    NSManagedObjectModel *sMediaModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    
    _migrationManager = [[SVMigrationManager alloc] initWithSourceModel:sModel
                                                             mediaModel:sMediaModel
                                                       destinationModel:[KTDocument managedObjectModel]];
    
    [sModel release];
    [sMediaModel release];
    
    [_migrationManager addObserver:self forKeyPath:@"migrationProgress" options:0 context:NULL];
    
    OBASSERT(_migrationManager);
    if (![(SVMigrationManager *)_migrationManager migrateDocumentFromURL:inOriginalContentsURL
                                                        toDestinationURL:inURL
                                                              attributes:attributes
                                                                   error:outError])
    {
        // Was the failure because this is actually a 1.5 doc?
        if ([[self fileURL] isFileURL] && [inURL isFileURL])
        {
            NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:[self fileURL] type:kSVDocumentTypeName];
            
            NSDictionary *metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil
                                                                                                URL:storeURL
                                                                                              error:NULL];
            
            if (metadata)
            {
                return [fileManager copyItemAtPath:[[self fileURL] path]
                                            toPath:[inURL path]
                                             error:outError];
            }
        }
        
        
        return NO;
    }
    
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
                         NSLocalizedString(@"Upgrading document “%@”","document upgrade message text"), filename];
    [messageTextField setStringValue:message];
    
    message = NSLocalizedString(@"Your original document will be left alone, in case you need to refer back to it.","document upgrade informative text");
    [informativeTextField setStringValue:message];
    
	[cancelButton setTitle:NSLocalizedString(@"Cancel","Button title")];
    
	
    //[dataMigratorController setContent:[self dataMigrator]];
    [progressIndicator startAnimation:self];
    
}

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel;
{
    BOOL result = [super prepareSavePanel:savePanel];
    if (result && ![[self fileType] isEqualToString:kSVDocumentTypeName])
    {
        NSString *title = NSLocalizedString(@"Upgrade Document", "upgrade panel title");
        [savePanel setTitle:title];
        
        NSString *message = NSLocalizedString(@"This document must be upgraded to the latest Sandvox data format.","document upgrade informative text - TRY TO KEEP THIS SHORT, OTHERWISE IT WILL BE TRUNCATED");
        
        [savePanel setMessage:message];
        
        [savePanel setPrompt:NSLocalizedString(@"Upgrade", "button title")];
    }
    
    return result;
}

- (IBAction)cancelMigration:(id)sender
{
    // Ask the migrator to cancel. It may take a few moments to actually stop
    [_migrationManager cancelMigrationWithError:[NSError errorWithDomain:NSCocoaErrorDomain
                                                                    code:NSUserCancelledError
                                                                userInfo:nil]];
}

- (IBAction)windowHelp:(id)sender
{
    [[NSApp delegate] showHelpPage:@"Upgrading_Previous_Documents"];    // HELPSTRING ..... TO DO
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;
{
    float progress = [_migrationManager migrationProgress];
    [[progressIndicator ks_proxyOnThread:nil waitUntilDone:NO] setDoubleValue:progress];
    [[progressIndicator ks_proxyOnThread:nil waitUntilDone:NO] setIndeterminate:NO];
}

+ (BOOL)isNativeType:(NSString *)aType
{
    // Standard implementation seems to ignore class inheritance, and look purely at the plist. So also ask KTDocument
    BOOL result = [super isNativeType:aType] || [[self superclass] isNativeType:aType];
    return result;
}

+ (NSArray *)writableTypes
{
    // Standard implementation seems to ignore class inheritance, and look purely at the plist. So I override here
    NSArray *result = [KTDocument writableTypes];
    return result;
}

- (BOOL) validateUserInterfaceItem:(id <NSValidatedUserInterfaceItem>)anItem;
{
	VALIDATION((@"%s %@",__FUNCTION__, anItem));
    // Disable all controls while migrating
    BOOL result = ([[self fileType] isEqualToString:kSVDocumentTypeName_1_5] ?
                   NO :
                   [super validateUserInterfaceItem:anItem]);
    
    return result;
}


@end
