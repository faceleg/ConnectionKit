//
//  KTDocumentMigrationController.m
//  Marvel
//
//  Created by Mike on 27/03/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDataMigrationDocument.h"
#import "KTDataMigrator.h"

#import "NSObject+Karelia.h"
#import "KT.h"


@implementation KTDataMigrationDocument

#pragma mark -
#pragma mark Init

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    OBASSERT(![self dataMigrator]);
        
    myDataMigrator = [[KTDataMigrator alloc] initWithDocumentURL:absoluteURL];
    
    [myDataMigrator migrateWithDelegate:self
                     didMigrateSelector:@selector(dataMigrator:didMigrate:error:contextInfo:)
                            contextInfo:NULL];
    
    return YES;
}

- (void)dealloc
{
    // It shouldn't happen, but migration MUST be stopped by this point
    OBASSERT(!myCanCloseDocumentCallbacks);
    
    [myDataMigrator release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Accessors

- (KTDataMigrator *)dataMigrator
{
    return myDataMigrator;
}

#pragma mark -
#pragma mark Nib loading

- (NSString *)windowNibName { return @"DocumentMigration"; }

/*  Start up the progress indicator and set text fields right
 */
- (void)awakeFromNib
{
    NSString *filename = [[NSFileManager defaultManager] displayNameAtPath:[[self fileURL] path]];
    NSString *message = [NSString stringWithFormat:
                         NSLocalizedString(@"Upgrading document “%@.”","document upgrade message text"), filename];
    [messageTextField setStringValue:message];
    
    
    NSString *path = [[[self dataMigrator] oldStoreURL] path];
    path = [KTDataMigrator renamedFileName:path modelVersion:kKTModelVersion_ORIGINAL];
    filename = [[NSFileManager defaultManager] displayNameAtPath:path];
    
    message = [NSString stringWithFormat:
               NSLocalizedString(@"Before it can be opened, this document must be upgraded to the latest Sandvox data format. A backup of the original document will be saved as “%@.”","document upgrade informative text"),
               filename];
    [informativeTextField setStringValue:message];
    
	[cancelButton setTitle:NSLocalizedString(@"Cancel","Button title")];

	
    [dataMigratorController setContent:[self dataMigrator]];
    [progressIndicator startAnimation:self];
    
}

#pragma mark -
#pragma mark Doc Closing

- (void)addCanCloseDocumentCallback:(NSInvocation *)callback
{
    if (!myCanCloseDocumentCallbacks)
    {
        myCanCloseDocumentCallbacks = [[NSMutableArray alloc] init];
    }
    
    [myCanCloseDocumentCallbacks addObject:callback];
}

- (void)sendCanCloseDocumentCallbacks
{
    [myCanCloseDocumentCallbacks makeObjectsPerformSelector:@selector(invoke)];
    [myCanCloseDocumentCallbacks release];  myCanCloseDocumentCallbacks = nil;
}

#pragma mark -
#pragma mark Migration

- (IBAction)cancelMigration:(id)sender
{
    // Ask the migrator to cancel. It may take a few moments to actually stop
    [[self dataMigrator] cancel];
}

/*  We treat a close request the same as clicking cancel. i.e. Wait until the migration is finished before actually closing.
 */
- (void)canCloseDocumentWithDelegate:(id)delegate shouldCloseSelector:(SEL)shouldCloseSelector contextInfo:(void *)contextInfo
{
    [self cancelMigration:self];
    BOOL result = YES;
    
    NSInvocation *callback = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:shouldCloseSelector]];
    [callback setTarget:delegate];
    [callback setSelector:shouldCloseSelector];
    [callback setArgument:&self atIndex:2];
    [callback setArgument:&result atIndex:3];
    [callback setArgument:&contextInfo atIndex:4];
    [self addCanCloseDocumentCallback:callback];
}

- (BOOL)isDocumentEdited
{
	return YES;
}

/*  After migration we either open the new document or alert the user to the error
 */
- (void)dataMigrator:(KTDataMigrator *)dataMigrator
          didMigrate:(BOOL)didMigrateSuccessfully error:(NSError *)error
         contextInfo:(void *)contextInfo
{
    // Ignore invalid data migrators
    if (dataMigrator != [self dataMigrator]) return;
    
    
    if (didMigrateSuccessfully)
    {
        [self close];
        [[NSDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[dataMigrator migratedDocumentURL] display:YES error:NULL];
    }
    else
    {
        // Was this an actual failure, or because the user canceled?
        if ([dataMigrator isCancelled])
        {
            // Send any close doc callbacks
            [self sendCanCloseDocumentCallbacks];
            [self close];
        }
        else
        {
            // Alert the user
            [self close];
            [[NSDocumentController sharedDocumentController] presentError:error];
        }
    }
}

@end
