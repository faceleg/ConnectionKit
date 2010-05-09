//
//  KTDocument+Saving.m
//  Marvel
//
//  Created by Mike on 26/02/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "KTDocument.h"
#import "NSDocument+KTExtensions.h"

#import "KTDesign.h"
#import "KTDocumentController.h"
#import "SVDocumentFileWrapper.h"
#import "SVDocumentSavePanelAccessoryViewController.h"
#import "KTDocWindowController.h"
#import "SVDocumentUndoManager.h"
#import "KTSite.h"
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"
#import "KTMaster.h"
#import "SVMediaRecord.h"
#import "SVQuickLookPreviewHTMLContext.h"
#import "SVTextContentHTMLContext.h"
#import "SVTitleBox.h"
#import "SVWebEditorHTMLContext.h"

#import "KSSilencingConfirmSheet.h"
#import "KSThreadProxy.h"

#import "NSApplication+Karelia.h"
#import "NSDate+Karelia.h"
#import "NSError+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSInvocation+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSSet+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSView+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSURL+Karelia.h"

#import "CIImage+Karelia.h"

#import "Registration.h"
#import "Debug.h"


#include <sys/param.h>
#include <sys/mount.h>


NSString *kKTDocumentWillSaveNotification = @"KTDocumentWillSave";


/*	These strings are used for generating Quick Look preview sticky-note text
 */
// NSLocalizedString(@"Published at", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Last updated", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Author", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Language", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Pages", "Quick Look preview sticky-note text");


@interface KTDocument (PropertiesPrivate)
- (void)persistUIProperties;
@end


@interface KTDocument (SavingPrivate)

// Write Safely
- (NSString *)backupExistingFileForSaveAsOperation:(NSString *)path error:(NSError **)error;
- (void)recoverBackupFile:(NSString *)backupPath toURL:(NSURL *)saveURL;

// Write To URL
- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)inSaveOperation
					  error:(NSError **)outError;

- (BOOL)writeDatastoreToURL:(NSURL *)URL
                     ofType:(NSString *)typeName
           forSaveOperation:(NSSaveOperationType)saveOp
        originalContentsURL:(NSURL *)originalContentsURL
                      error:(NSError **)outError;

- (BOOL)writeMediaRecords:(NSArray *)media
                    toURL:(NSURL *)docURL
         forSaveOperation:(NSSaveOperationType)saveOp
                    error:(NSError **)outError;
- (BOOL)writeMediaRecord:(SVMediaRecord *)media
           toDocumentURL:(NSURL *)docURL
        forSaveOperation:(NSSaveOperationType)saveOp
                   error:(NSError **)outError;


// Metadata
- (BOOL)setMetadataForStoreAtURL:(NSURL *)aStoreURL error:(NSError **)outError;
- (NSString *)documentTextContent;


// Quick Look
- (void)startGeneratingQuickLookThumbnail;
- (BOOL)writeQuickLookThumbnailToDocumentURLIfPossible:(NSURL *)docURL error:(NSError **)error;
- (NSImage *)_quickLookThumbnail;
- (NSString *)quickLookPreviewHTML;

@end


#pragma mark -


@implementation KTDocument (Saving)

#pragma mark Save to URL

- (BOOL)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
			error:(NSError **)outError
{
	OBPRECONDITION([absoluteURL isFileURL]);
	
	
    // Let anyone interested know
	[[NSNotificationCenter defaultCenter] postNotificationName:kKTDocumentWillSaveNotification object:self];
    
    
    // Store media referencing behaviour. Primitive so as not to affect undo stack
    if (saveOperation == NSSaveAsOperation || saveOperation == NSSaveToOperation)
    {
        [[self site] setPrimitiveValue:[NSNumber numberWithBool:[_accessoryViewController copyMoviesIntoDocument]]
                                forKey:@"copyMoviesIntoDocument"];
    }
    
    
    // Record display properties
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] disableUndoRegistration];
    [self persistUIProperties];
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] enableUndoRegistration];
    
    
    // Normal save behaviour
    BOOL result = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
    OBASSERT(result || !outError || (nil != *outError)); // make sure we didn't return NO with an empty error
    
    
    return result;
}

- (BOOL)isSaving
{
    return (mySaveOperationCount > 0);
}

#pragma mark Save Panel

- (BOOL)prepareSavePanel:(NSSavePanel *)savePanel;
{
    BOOL result = [super prepareSavePanel:savePanel];
    
    if (!_accessoryViewController)
    {
        _accessoryViewController = [[SVDocumentSavePanelAccessoryViewController alloc]
                                    initWithNibName:@"DocumentSavePanelAccessoryView" bundle:nil];
    }
    
    [savePanel setAccessoryView:[_accessoryViewController view]];
    
    return result;
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation
{
	// we restrict writableTypes to our main document type so that the persistence framework does
    // not allow the user to pick a persistence store format and confuse the app.
    //
    // BUGSID:37280 If you don't specify a string the document framework recognises, hidden file extensions won't work right
	return [NSArray arrayWithObject:kKTDocumentType];
}

#pragma mark -
#pragma mark Write Safely

/*	We override the behavior to save directly ('unsafely' I suppose!) to the URL,
 *	rather than via a temporary file as is the default.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL 
				  ofType:(NSString *)typeName 
		forSaveOperation:(NSSaveOperationType)saveOperation 
				   error:(NSError **)outError
{
	BOOL result = NO;
    
    
    if (saveOperation == NSSaveOperation)
        //(saveOperation == NSAutosaveOperation && [absoluteURL isEqual:[self autosavedContentsFileURL]]))
    {
        // NSDocument attempts to write a copy of the document out at a temporary location.
        // Core Data cannot support this, so we override it to save directly.
        result = [self writeToURL:absoluteURL
                           ofType:typeName
                 forSaveOperation:saveOperation 
              originalContentsURL:[self fileURL]
                            error:outError];
        
        
        
    }
    // Other situations are basically fine to go through the regular channels
    else
    {
        result = [super writeSafelyToURL:absoluteURL 
                                  ofType:typeName 
                        forSaveOperation:saveOperation 
                                   error:outError];
    }
    
    OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
    return result;
}

/*	Support method for -writeSafelyToURL:
 *	Returns nil and an error if the file cannot be backed up.
 */
- (NSString *)backupExistingFileForSaveAsOperation:(NSString *)path error:(NSError **)error
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Move the existing file to the best available backup path
	NSString *backupDirectory = [path stringByDeletingLastPathComponent];
	NSString *preferredFilename = [NSString stringWithFormat:@"Backup of %@", [path lastPathComponent]];
	NSString *preferredPath = [backupDirectory stringByAppendingPathComponent:preferredFilename];
	NSString *backupFilename = [fileManager uniqueFilenameAtPath:preferredPath];
	NSString *result = [backupDirectory stringByAppendingPathComponent:backupFilename];
	
	BOOL success = [fileManager movePath:path toPath:result handler:nil];
	if (!success)
	{
		// The backup failed, construct an error
		result = nil;
		
		NSString *secondary = [NSString stringWithFormat:@"Could not remove the existing file at:\n%@", path];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Unable to save document", NSLocalizedDescriptionKey,
																			secondary, NSLocalizedRecoverySuggestionErrorKey,
																			path, NSFilePathErrorKey, nil];
		if (error)
		{
			*error = [NSError errorWithDomain:@"KTDocument" code:0 userInfo:userInfo];
		}
	}
	
	return result;
}

/*	In the event of a Save As operation failing, we copy the backup file back to the original location.
 */
- (void)recoverBackupFile:(NSString *)backupPath toURL:(NSURL *)saveURL
{
	OBPRECONDITION(backupPath);
    
    // Dump the failed save
	NSString *savePath = [saveURL path];
	BOOL result = [[NSFileManager defaultManager] removeFileAtPath:savePath handler:nil];
	
	// Recover the backup if there is one
	if (backupPath)
	{
		result = [[NSFileManager defaultManager] movePath:backupPath toPath:[saveURL path] handler:nil];
	}
	
	if (!result)
	{
		NSLog(@"Could not recover backup file: %@\nafter Save As operation failed for URL: %@", backupPath, [saveURL absoluteString]);
	}
}

#pragma mark -
#pragma mark Write To URL

/*	The low level NSDocument method responsible for actually getting a document onto disk
 */
 - (BOOL)writeToURL:(NSURL *)inURL 
             ofType:(NSString *)inType 
   forSaveOperation:(NSSaveOperationType)saveOperation
originalContentsURL:(NSURL *)inOriginalContentsURL
              error:(NSError **)outError
{
	OBPRECONDITION([NSThread currentThread] == [self thread]);
    
    OBPRECONDITION(inURL);
	OBPRECONDITION([inURL isFileURL]);
	
	// We don't support any of the other save ops here.
	//OBPRECONDITION(saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation);
    
    
    BOOL result = NO;
	NSManagedObjectContext *context = [self managedObjectContext];
    
	
@try
{
    if (saveOperation != NSAutosaveOperation)
    {
        // Kick off thumbnail generation
        [self startGeneratingQuickLookThumbnail];
    }
    
    
    
    // Prepare to save the context
    result = [self prepareToWriteToURL:inURL
                                ofType:inType
                      forSaveOperation:saveOperation
                                 error:outError];
    OBASSERT(result || !outError || (nil != *outError));    // make sure we didn't return NO with an empty error
	
    
	
	NSString *quickLookPreviewHTML = nil;
    if (result)
    {
        if (saveOperation == NSAutosaveOperation)
        {
            // Mark media as autosaved. #61400
            //NSArray *media = [[self documentFileWrappers] allValues];
            //[media makeObjectsPerformSelector:@selector(willAutosave)];
        }
        else
        {
            // Generate Quick Look preview HTML
            quickLookPreviewHTML = [self quickLookPreviewHTML];
            
            
            
            // Build a list of all media to copy into the document
            NSString *requestName = (saveOperation == NSSaveAsOperation) ? @"MediaToCopyIntoDocument" : @"MediaAwaitingCopyIntoDocument";
            NSFetchRequest *request = [[[self class] managedObjectModel] fetchRequestTemplateForName:requestName];
            NSArray *mediaToWriteIntoDocument = [context executeFetchRequest:request error:NULL];
            
            [self writeMediaRecords:mediaToWriteIntoDocument
                              toURL:inURL
                   forSaveOperation:saveOperation
                              error:NULL];
            
            
            
            // Tell deleted media what, if anything, to do. MUST happen after searching for new media. #72736
            NSURL *deletedMediaDirectory = [[self undoManager] deletedMediaDirectory];
            NSDictionary *wrappers = [self documentFileWrappers];
            
            for (NSString *aKey in wrappers)
            {
                id <SVDocumentFileWrapper> media = [wrappers objectForKey:aKey];
                if ([media shouldRemoveFromDocument])
                {
                    NSURL *deletionURL = [deletedMediaDirectory URLByAppendingPathComponent:aKey
                                                                                isDirectory:NO];
                    [(SVMediaRecord *)media moveToURLWhenDeleted:deletionURL];
                }
            }
        }
    }
    
    
    if (result)
    {
        // Save the context
        NSURL *originalDatastoreURL = (inOriginalContentsURL ? [KTDocument datastoreURLForDocumentURL:inOriginalContentsURL type:nil] : nil);
        
		result =  [self writeDatastoreToURL:[KTDocument datastoreURLForDocumentURL:inURL type:nil]
                                    ofType:inType
                          forSaveOperation:saveOperation
                       originalContentsURL:originalDatastoreURL
                                     error:outError];
        
		OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
    }
        
     
    if (saveOperation != NSAutosaveOperation && result)
    {
        // Make sure there's a directory to save Quick Look data into
        NSURL *quickLookDirectory = [KTDocument quickLookURLForDocumentURL:inURL];
        [[NSFileManager defaultManager] createDirectoryAtPath:[quickLookDirectory path]
                                  withIntermediateDirectories:NO
                                                   attributes:nil
                                                        error:NULL];
        
        
		// Write out Quick Look preview
        if (quickLookPreviewHTML)
        {
            NSURL *previewURL = [quickLookDirectory URLByAppendingPathComponent:@"Preview.html"
                                                                    isDirectory:NO];
            
            // We don't actually care if the preview gets written out successfully or not, since it's not critical to the consistency of the document.
            // It might be nice to warn the user one day though.
            NSError *qlPreviewError;
            if (![quickLookPreviewHTML writeToURL:previewURL
                                       atomically:NO
                                         encoding:NSUTF8StringEncoding
                                            error:&qlPreviewError])
            {
                NSLog(@"Error saving Quick Look preview: %@",
                      [[qlPreviewError debugDescription] condenseWhiteSpace]);
            }
        }
        
        
        if (_quickLookThumbnailWebView)
        {
            NSError *qlThumbnailError;
            if (![self writeQuickLookThumbnailToDocumentURLIfPossible:inURL error:&qlThumbnailError])
            {
                NSLog(@"Error saving Quick Look thumbnail: %@",
                      [[qlThumbnailError debugDescription] condenseWhiteSpace]);
            }
        }
    }
    
}
@finally
{
    // MUST make sure the thumbnail webview has been unloaded, otherwise we'll fail an assertion come the next save. This call does that. #61947
    [self _quickLookThumbnail];
}	

	
	return result;
}


/*	Support method that sets the environment ready for the MOC and other document contents to be written to disk.
 */
- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)saveOperation
					  error:(NSError **)outError
{
	OBASSERT([NSThread currentThread] == [self thread]);
    
    OBPRECONDITION(inURL);
	OBPRECONDITION([inURL isFileURL]);
	
	
	// REGISTRATION -- be annoying if it looks like the registration code was bypassed
	if ( ((0 == gRegistrationWasChecked) && random() < (LONG_MAX / 10) ) )
	{
		// NB: this is a trick to make a licensing issue look like an Unknown Store Type error
		// KTErrorReason/KTErrorDomain is a nonsense response to flag this as bad license
		NSError *registrationError = [NSError errorWithDomain:NSCocoaErrorDomain
														 code:134000 // invalid type error, for now
													 userInfo:[NSDictionary dictionaryWithObject:@"KTErrorDomain"
																						  forKey:@"KTErrorReason"]];
		if ( nil != outError )
		{
			// we'll pass registrationError back to the document for presentation
			*outError = registrationError;
		}
		
		return NO;
	}
	
	
	// For the first save of a document, create the wrapper paths on disk before we do anything else
    BOOL result = YES;
	if (saveOperation == NSSaveAsOperation || saveOperation == NSAutosaveOperation)
	{
		result = [[NSFileManager defaultManager] createDirectoryAtPath:[inURL path]
                                           withIntermediateDirectories:NO
                                                            attributes:nil
                                                                 error:outError];
        
		if (result) [[NSWorkspace sharedWorkspace] setBundleBit:YES forFile:[inURL path]];
	}
	
	
    
    if (!result)
    {
        NSURL *persistentStoreURL = [KTDocument datastoreURLForDocumentURL:inURL type:nil];
        OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
        LOG((@"error: wants to setMetadata during save but no persistent store at %@", persistentStoreURL));
    }
    
    
    return result;
}

- (BOOL)writeDatastoreToURL:(NSURL *)URL
                     ofType:(NSString *)typeName
           forSaveOperation:(NSSaveOperationType)saveOp
        originalContentsURL:(NSURL *)originalContentsURL
                      error:(NSError **)outError;

{
	OBASSERT([NSThread currentThread] == [self thread]);
    
    
    NSManagedObjectContext *context = [self managedObjectContext];
	NSPersistentStoreCoordinator *coordinator = [context persistentStoreCoordinator];
	OBASSERT(coordinator);
        
    
    BOOL result = YES;
    NSError *error = nil;
	
    
    // Setup persistent store appropriately
	NSPersistentStore *store = [self persistentStore];
    if (!store)
    {
        result = [self configurePersistentStoreCoordinatorForURL:URL
                                                          ofType:typeName
                                              modelConfiguration:nil
                                                    storeOptions:nil
                                                           error:&error];
        store = [self persistentStore];
    }
    else if (saveOp != NSSaveOperation)
    {
        // Fake a placeholder file ready for the store to save over
        result = [[NSData data] writeToURL:URL options:0 error:&error];
        if (result) [coordinator setURL:URL forPersistentStore:store];
    }
    
    
    // Now we're sure store is available, can give it some metadata.
    if (result) result = [self setMetadataForStoreAtURL:URL error:&error];
    
    
    // Do the save
    if (result) result = [context save:&error];
    
    
    // Restore persistent store URL after Save To-type operations. Even if save failed (just to be on the safe side)
    if (saveOp == NSAutosaveOperation || saveOp == NSSaveToOperation)
    {
        [coordinator setURL:originalContentsURL forPersistentStore:store];
    }
    
    
    // Return, making sure to supply appropriate error info
    if (!result && outError) *outError = error;
    OBASSERT( (result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
    
    return result;
}

#pragma mark Media

- (id <SVDocumentFileWrapper>)duplicateOfMediaRecord:(SVMediaRecord *)media;
{
    OBPRECONDITION(media);
    
    //  Look through out existing media to see if there is one with the same data
    
    id <SVDocumentFileWrapper> result = nil;
    
    
    NSDictionary *wrappers = [self documentFileWrappers];
    for (NSString *aKey in wrappers)
    {
        SVMediaRecord *aMediaRecord = [wrappers objectForKey:aKey];
        if ([media fileContentsEqualMediaRecord:aMediaRecord])
        {
            result = aMediaRecord;
            break;
        }
    }
    
    
    return result;
}

- (BOOL)writeMediaRecords:(NSArray *)media
                    toURL:(NSURL *)docURL
         forSaveOperation:(NSSaveOperationType)saveOp
                    error:(NSError **)outError;
{
    OBPRECONDITION(media);
    
    BOOL result = YES;
    
    
    // Disable undo as this belongs outside the regular stack
    NSManagedObjectContext *context = [self managedObjectContext];
    [context processPendingChanges];
    [[self undoManager] disableUndoRegistration];
    
    
    // Process each file
    for (SVMediaRecord *aMediaRecord in media)
    {
        result = [self writeMediaRecord:aMediaRecord
                          toDocumentURL:docURL
                       forSaveOperation:saveOp
                                  error:outError];
    }
    
    [context processPendingChanges];
    [[self undoManager] enableUndoRegistration];
    
    
    
    return result;
}

- (BOOL)writeMediaRecord:(SVMediaRecord *)aMediaRecord
           toDocumentURL:(NSURL *)docURL
        forSaveOperation:(NSSaveOperationType)saveOp
                   error:(NSError **)outError;
{
    BOOL result = YES;
    
    
    // Reserve filename if needed first.
    NSString *filename = [aMediaRecord committedValueForKey:@"filename"];
    if (!filename)
    {
        // Is there already a media record with the same data? If so can shortcut usual mechanism
        SVMediaRecord *dupe = (SVMediaRecord *)[self duplicateOfMediaRecord:aMediaRecord];
        if (dupe)
        {
            // Don't try to access -[dupe filename] as it may be a deleted object, and therefore unable to fulfil the fault
            NSURL *fileURL = [dupe fileURL];
            [aMediaRecord readFromURL:fileURL options:0 error:NULL];
            [aMediaRecord setFilename:[fileURL lastPathComponent]];
            
            NSString *key = [self keyForDocumentFileWrapper:dupe];
            OBASSERT(key);
            [aMediaRecord setNextObject:dupe];
            [self setDocumentFileWrapper:aMediaRecord forKey:key];
            
            return YES;
        }
        else
        {
            filename = [self addDocumentFileWrapper:aMediaRecord];
        }
    }
    
    
    // Try write
    NSURL *mediaURL = [docURL URLByAppendingPathComponent:filename isDirectory:NO];
    if ([aMediaRecord writeToURL:mediaURL updateFileURL:NO error:outError])
    {    
        [aMediaRecord setFilename:filename];
    }
    else
    {
        result = NO;
        [self unreserveFilename:filename];
    }
    
    
    return result;
}

#pragma mark Metadata

/*! setMetadataForStoreAtURL: sets all metadata for the store all at once */
- (BOOL)setMetadataForStoreAtURL:(NSURL *)aStoreURL
						   error:(NSError **)outError
{
	//LOGMETHOD;
	
	BOOL result = NO;
	NSManagedObjectContext *context = [self managedObjectContext];
	NSPersistentStoreCoordinator *coordinator = [context persistentStoreCoordinator];
    
	@try
	{
		id theStore = [coordinator persistentStoreForURL:aStoreURL];
		if (theStore)
		{
			// grab whatever data is already there (at least NSStoreTypeKey and NSStoreUUIDKey)
			NSMutableDictionary *metadata = [[[coordinator metadataForPersistentStore:theStore] mutableCopy] autorelease];
			
			// remove old keys that might have been in use by older versions of Sandvox
			[metadata removeObjectForKey:(NSString *)kMDItemDescription];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_AppVersion"];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_PageCount"];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_SiteAuthor"];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_SiteTitle"];
			
			// set ALL of our metadata for this store
			
			//  kMDItemAuthors
			NSString *author = [[[[self site] rootPage] master] valueForKey:@"author"];
			if ( (nil == author) || [author isEqualToString:@""] )
			{
				[metadata removeObjectForKey:(NSString *)kMDItemAuthors];
			}
			else
			{
				[metadata setObject:[NSArray arrayWithObject:author] forKey:(NSString *)kMDItemAuthors];
			}
			
			// kMDItemLanguages
			NSString *language = [[[[self site] rootPage] master] valueForKey:@"language"];
			if ( (nil == language) || [language isEqualToString:@""] )
			{
				[metadata removeObjectForKey:(NSString *)kMDItemLanguages];
			}
			else
			{
				[metadata setObject:[NSArray arrayWithObject:language] forKey:(NSString *)kMDItemLanguages];
			}
			
			// kMDItemHeadline  -- tagline/subtitle
			NSString *subtitle = [[[[[self site] rootPage] master] siteSubtitle] text];
			if ( (nil == subtitle) || [subtitle isEqualToString:@""] )
			{
				[metadata removeObjectForKey:(NSString *)kMDItemHeadline];
			}
			else
			{
				[metadata setObject:subtitle forKey:(NSString *)kMDItemHeadline];
			}
			
			//  kMDItemCreator (Sandvox is the creator of this site document)
			[metadata setObject:[NSApplication applicationName] forKey:(NSString *)kMDItemCreator];
            
			// kMDItemKind
			[metadata setObject:NSLocalizedString(@"Sandvox Site", "kind of document") forKey:(NSString *)kMDItemKind];
			
			/// we're going to fault every page, use a local pool to release them quickly
			NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
			
			//  kMDItemNumberOfPages
			NSArray *pages = [[self managedObjectContext] fetchAllObjectsForEntityForName:@"Page" error:NULL];
			unsigned int pageCount = 0;
			if ( nil != pages )
			{
				pageCount = [pages count]; // according to mmalc, this is the only way to get this kind of count
			}
			[metadata setObject:[NSNumber numberWithUnsignedInt:pageCount] forKey:(NSString *)kMDItemNumberOfPages];
			
            
            
			//  kMDItemTextContent (free-text account of content)
			[metadata setObject:[self documentTextContent]
                         forKey:(NSString *)kMDItemTextContent];
			
            
			//  kMDItemKeywords (keywords of all pages)
			NSMutableSet *keySet = [NSMutableSet set];
			for (id loopItem in pages)
			{
				[keySet addObjectsFromArray:[loopItem keywords]];
			}
            
			if ( (nil == keySet) || ([keySet count] == 0) )
			{
				[metadata removeObjectForKey:(NSString *)kMDItemKeywords];
			}
			else
			{
				[metadata setObject:[keySet allObjects] forKey:(NSString *)kMDItemKeywords];
			}
			[localPool release];
			
            
			//  kMDItemTitle
			NSString *siteTitle = [[[[[self site] rootPage] master] siteTitle] textHTMLString];        
			if ( (nil == siteTitle) || [siteTitle isEqualToString:@""] )
			{
				[metadata removeObjectForKey:(NSString *)kMDItemTitle];
			}
			else
			{
				siteTitle = [siteTitle stringByConvertingHTMLToPlainText];
				[metadata setObject:siteTitle forKey:(NSString *)kMDItemTitle];
			}
			
			// custom attributes
			
			//  kKTMetadataModelVersionKey
			[metadata setObject:kKTModelVersion forKey:kKTMetadataModelVersionKey];
			
			// kKTMetadataAppCreatedVersionKey should only be set once
			if ( nil == [metadata valueForKey:kKTMetadataAppCreatedVersionKey] )
			{
				[metadata setObject:[NSApplication buildVersion] forKey:kKTMetadataAppCreatedVersionKey];
			}
			
			//  kKTMetadataAppLastSavedVersionKey (CFBundleVersion of running app)
			[metadata setObject:[NSApplication buildVersion] forKey:kKTMetadataAppLastSavedVersionKey];
			
			// replace the metadata in the store with our updates
			// NB: changes to metadata through this method are not pushed to disk until the document is saved
			[coordinator setMetadata:metadata forPersistentStore:theStore];
			
			result = YES;
		}
		else
		{
			NSLog(@"error: unable to setMetadataForStoreAtURL:%@ (no persistent store)", [aStoreURL path]);
			NSString *path = [aStoreURL path];
			NSString *reason = [NSString stringWithFormat:@"(%@ is not a valid persistent store.)", path];
			if (outError)
			{
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain
												code:134070 // NSPersistentStoreOperationError
											userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
													  reason, NSLocalizedDescriptionKey,
													  nil]];
			}
			result = NO;
		}
	}
	@catch (NSException * e)
	{
		NSLog(@"error: unable to setMetadataForStoreAtURL:%@ exception: %@:%@", [aStoreURL path], [e name], [e reason]);
		if (outError)
		{
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:134070 // NSPersistentStoreOperationError
										userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												  [aStoreURL path], @"path",
												  [e name], @"name",
												  [e reason], NSLocalizedDescriptionKey,
												  nil]];
		}
		result = NO;
	}
	
	return result;
}

- (NSString *)documentTextContent;
{
    //  For now, we'll make this the tagline, plus all unique page titles, plus spotlightHTML
    
    // Start with footer
    NSMutableString *result = [NSMutableString string];
    
    
    NSString *footer = [[[[[self site] rootPage] master] footer] text];
    if (footer)
    {
        [result writeString:footer];
        [result appendUnichar:'\n'];
    }
    
    
    // Use an HTML context for reading in content
    SVTextContentHTMLContext *context = [[SVTextContentHTMLContext alloc] initWithStringWriter:result];
    [context push];
    
    
    // Sidebar pagelets
    NSManagedObjectContext *moc = [self managedObjectContext];
    NSManagedObjectModel *model = [[moc persistentStoreCoordinator] managedObjectModel];
    NSFetchRequest *request = [model fetchRequestTemplateForName:@"SidebarPagelets"];
    NSArray *sidebarPagelets = [moc executeFetchRequest:request error:NULL];
    
    [SVContentObject writeContentObjects:sidebarPagelets];
    
    
    // Page contents
    [[[self site] rootPage] writeContentRecursively:YES];
    
    
    // Tidy up
    [context pop];
    [context release];
    
    return result;
}

#pragma mark -
#pragma mark Quick Look Thumbnail

- (void)startGeneratingQuickLookThumbnail
{
	OBASSERT([NSThread currentThread] == [self thread]);
    
    // Put together the HTML for the thumbnail
    NSMutableString *thumbnailHTML = [[NSMutableString alloc] init];
    SVHTMLContext *context = [[SVWebEditorHTMLContext alloc] initWithStringWriter:thumbnailHTML];
    
    [context setLiveDataFeeds:NO];
    [context setPage:[[self site] rootPage]];
    
    [[[self site] rootPage] writeHTML:context];
	[context release];
    
	
    // Load into webview
    [self performSelectorOnMainThread:@selector(_startGeneratingQuickLookThumbnailWithHTML:)
                           withObject:thumbnailHTML
                        waitUntilDone:YES];
    
    [thumbnailHTML release];
}

- (void)_startGeneratingQuickLookThumbnailWithHTML:(NSString *)thumbnailHTML
{
    // View and WebView handling MUST be on the main thread
    OBASSERT([NSThread isMainThread]);
    
    
	// Create the webview's offscreen window
	unsigned designViewport = [[[[[self site] rootPage] master] design] viewport];	// Ensures we don't clip anything important
	NSRect frame = NSMakeRect(0.0, 0.0, designViewport+20, designViewport+20);	// The 20 keeps scrollbars out the way
	
	_quickLookThumbnailWebViewWindow = [[NSWindow alloc]
                                        initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[_quickLookThumbnailWebViewWindow setReleasedWhenClosed:NO];	// Otherwise we crash upon quitting - I guess NSApplication closes all windows when terminatating?
	
    
    // Create the webview
    OBASSERT(!_quickLookThumbnailWebView);
	_quickLookThumbnailWebView = [[WebView alloc] initWithFrame:frame];
    
    [_quickLookThumbnailWebView setResourceLoadDelegate:self];
	[_quickLookThumbnailWebViewWindow setContentView:_quickLookThumbnailWebView];
    
    
    // We want to know when it's finished loading.
    _quickLookThumbnailLock = [[NSLock alloc] init];
    [_quickLookThumbnailLock lock];
    
    OBASSERT(_quickLookThumbnailWebView);
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(webViewDidFinishLoading:)
                                                 name:WebViewProgressFinishedNotification
                                               object:_quickLookThumbnailWebView];
	
	
	// Go ahead and begin building the thumbnail
    [[_quickLookThumbnailWebView mainFrame] loadHTMLString:thumbnailHTML baseURL:nil];
}

- (BOOL)writeQuickLookThumbnailToDocumentURLIfPossible:(NSURL *)docURL error:(NSError **)error
{
    BOOL result = YES;
    
    
    
    // Wait for the thumbnail to complete. We shall allocate a maximum of 10 seconds for this
    NSDate *documentSaveLimit = [[NSDate date] addTimeInterval:10.0];
    if ([NSThread isMainThread])
    {
        while (![_quickLookThumbnailLock tryLock] &&     // Don't worry, it'll be unlocked again when tearing down the webview
               [documentSaveLimit timeIntervalSinceNow] > 0.0)
        {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:documentSaveLimit];
        }
    }
    else
    {
        OBASSERT(_quickLookThumbnailLock);
        BOOL didLock = [_quickLookThumbnailLock lockBeforeDate:documentSaveLimit];  // The lock can only be acquired once webview 
        if (didLock) [_quickLookThumbnailLock unlock];                              // loading is complete
    }
        
    
        
    // Save the thumbnail to disk
    NSImage *thumbnail = [[self proxyForThread:nil] _quickLookThumbnail];
    if (thumbnail)
    {
        NSURL *thumbnailURL = [[KTDocument quickLookURLForDocumentURL:docURL] URLByAppendingPathComponent:@"Thumbnail.png" isDirectory:NO];
        OBASSERT(thumbnailURL);	// shouldn't be nil, right?
        
        result = [[thumbnail PNGRepresentation] writeToURL:thumbnailURL options:0 error:error];
        OBASSERT(result || !error || *error != nil); // make sure we don't return NO with an empty error
    }        
        
    
    return result;
}

/*  Captures the Quick Look thumbnail from the webview if it's finished loading. MUST happen on the main thread.
 *  Has the side effect of disposing of the webview once done.
 */
- (NSImage *)_quickLookThumbnail
{
    NSImage *result = nil;
    
    
    if (_quickLookThumbnailWebView)
    {
        OBASSERT([NSThread isMainThread]);
        
        
        if (![_quickLookThumbnailWebView isLoading])
        {
            // Draw the view
            [_quickLookThumbnailWebView displayIfNeeded];	// Otherwise we'll be capturing a blank frame!
            NSImage *snapshot = [[[[_quickLookThumbnailWebView mainFrame] frameView] documentView] snapshot];
            
            result = [snapshot imageWithMaxWidth:512 height:512 
                                                      behavior:([snapshot width] > [snapshot height]) ? kFitWithinRect : kCropToRect
                                                     alignment:NSImageAlignTop];
            // Now composite "SANDVOX" at the bottom
            NSFont* font = [NSFont boldSystemFontOfSize:95];				// Emperically determine font size
            NSShadow *aShadow = [[[NSShadow alloc] init] autorelease];
            [aShadow setShadowOffset:NSMakeSize(0,0)];
            [aShadow setShadowBlurRadius:32.0];
            [aShadow setShadowColor:[NSColor colorWithCalibratedWhite:1.0 alpha:1.0]];	// white glow
            
            NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                               font, NSFontAttributeName, 
                                               aShadow, NSShadowAttributeName, 
                                               [NSColor colorWithCalibratedWhite:0.25 alpha:1.0], NSForegroundColorAttributeName,
                                               nil];
            NSString *s = @"SANDVOX";	// No need to localize of course
            
            NSSize textSize = [s sizeWithAttributes:attributes];
            float left = ([result size].width - textSize.width) / 2.0;
            float bottom = 7;		// empirically - seems to be a good offset for when shrunk to 32x32
            
            [result lockFocus];
            [s drawAtPoint:NSMakePoint(left, bottom) withAttributes:attributes];
            [result unlockFocus];
        }
        
        
        
        // Dump the webview and window
        [_quickLookThumbnailWebView setResourceLoadDelegate:nil];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:WebViewProgressFinishedNotification object:_quickLookThumbnailWebView];
        
        [_quickLookThumbnailWebView release];   _quickLookThumbnailWebView = nil;
        [_quickLookThumbnailWebViewWindow release]; _quickLookThumbnailWebViewWindow = nil;
        
        
        // Remove the lock. In the event that loading the webview timed out, it will still be locked.
        // So, we call -tryLock followed by -unlock as a neat trick to ensure it's unlocked
        [_quickLookThumbnailLock tryLock];
        [_quickLookThumbnailLock unlock];
        
        [_quickLookThumbnailLock release];
        _quickLookThumbnailLock = nil;
    }
	
    
    // Finish up
    return result;
}

- (NSURLRequest *)webView:(WebView *)sender
				 resource:(id)identifier
		  willSendRequest:(NSURLRequest *)request
		 redirectResponse:(NSURLResponse *)redirectResponse
		   fromDataSource:(WebDataSource *)dataSource
{
	NSURLRequest *result = request;
    
    NSURL *requestURL = [request URL];
	if ([requestURL hasNetworkLocation] && ![[requestURL scheme] isEqualToString:@"svxmedia"])
	{
		NSMutableURLRequest *mutableRequest = [[request mutableCopy] autorelease];
		[mutableRequest setCachePolicy:NSURLRequestReturnCacheDataDontLoad];	// don't load, but return cached value
		result = mutableRequest;
	}
    
    return result;
}

- (void)webViewDidFinishLoading:(NSNotification *)notification
{
    // Release the hounds! er, I mean the lock.
    // This allows a background thread to acquire the lock, signalling that saving can continue.
    OBASSERT(_quickLookThumbnailLock);
    [_quickLookThumbnailLock unlock];
}

#pragma mark Quick Look preview

/*  Parses the home page to generate a Quick Look preview
 */
- (NSString *)quickLookPreviewHTML
{
    OBASSERT([NSThread currentThread] == [self thread]);
    
    NSMutableString *result = [NSMutableString string];
    SVHTMLContext *context = [[SVQuickLookPreviewHTMLContext alloc] initWithStringWriter:result];
    
    [context setPage:[[self site] rootPage]];
    
    [[[self site] rootPage] writeHTML:context];
    [context release];
    
    return result;
}

@end



#pragma mark -


@implementation NSWindowController (KTDocumentAdditions)
- (void)persistUIProperties { }
@end