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
#import "KTDocWindowController.h"
#import "KTSite.h"
#import "SVHTMLTemplateParser.h"
#import "KTPage.h"
#import "KTMaster+Internal.h"
#import "KTMediaManager+Internal.h"
#import "SVMutableStringHTMLContext.h"
#import "SVTitleBox.h"

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

#import "KSSilencingConfirmSheet.h"
#import "KSThreadProxy.h"

#import "Registration.h"
#import "Debug.h"


#include <sys/param.h>
#include <sys/mount.h>


NSString *KTDocumentWillSaveNotification = @"KTDocumentWillSave";


/*	These strings are used for generating Quick Look preview sticky-note text
 */
// NSLocalizedString(@"Published at", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Last updated", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Author", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Language", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Pages", "Quick Look preview sticky-note text");


@interface KTDocument (PropertiesPrivate)
- (void)copyDocumentDisplayPropertiesToModel;
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

- (BOOL)writeDatastoreToURL:(NSURL *)inURL 
                     ofType:(NSString *)inType 
           forSaveOperation:(NSSaveOperationType)inSaveOperation
        originalContentsURL:(NSURL *)inOriginalContentsURL
                      error:(NSError **)outError;

- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError;

// Metadata
- (BOOL)setMetadataForStoreAtURL:(NSURL *)aStoreURL error:(NSError **)outError;

// Quick Look
- (void)startGeneratingQuickLookThumbnail;
- (BOOL)writeQuickLookThumbnailToDocumentURLIfPossible:(NSURL *)docURL error:(NSError **)error;
- (NSImage *)_quickLookThumbnail;
- (NSString *)quickLookPreviewHTML;

@end


#pragma mark -


@implementation KTDocument (Saving)

#pragma mark -
#pragma mark Save to URL

- (BOOL)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
			error:(NSError **)outError
{
	OBPRECONDITION([absoluteURL isFileURL]);
	
	
    // Let anyone interested know
	[[NSNotificationCenter defaultCenter] postNotificationName:KTDocumentWillSaveNotification object:self];
    
    
    // Record display properties
    NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] disableUndoRegistration];
    [self copyDocumentDisplayPropertiesToModel];
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

#pragma mark -
#pragma mark Save Panel

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
    
    switch (saveOperation)
    {
        case NSSaveAsOperation:
        {
            // We'll need a path for various operations below
            NSAssert2([absoluteURL isFileURL], @"-%@ called for non-file URL: %@", NSStringFromSelector(_cmd), [absoluteURL absoluteString]);
            NSString *path = [absoluteURL path];
            
            
            // If a file already exists at the desired location move it out of the way
            NSString *backupPath = nil;
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
            {
                backupPath = [self backupExistingFileForSaveAsOperation:path error:outError];
                if (!backupPath) return NO;
            }
            
            
            // We want to catch all possible errors so that the save can be reverted. We cover exceptions & errors. Sadly crashers can't
            // be dealt with at the moment.
            @try
            {
                // Write to the new URL
                result = [self writeToURL:absoluteURL
                                   ofType:typeName
                         forSaveOperation:saveOperation
                      originalContentsURL:[self fileURL]
                                    error:outError];
                OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
            }
            @finally
            {
                if (!result && backupPath)
                {
                    // There was an error saving, recover from it
                    [self recoverBackupFile:backupPath toURL:absoluteURL];
                }
            }
            
            if (result)
            {
                // The save was successful, delete the backup file
                if (backupPath)
                {
                    [[NSFileManager defaultManager] removeFileAtPath:backupPath handler:nil];
                }
            }
            
            break;
        }
            
            
            
        // NSDocument attempts to write a copy of the document out at a temporary location.
        // Core Data cannot support this, so we override it to save directly.
        case NSSaveOperation:
            result = [self writeToURL:absoluteURL
                               ofType:typeName
                     forSaveOperation:saveOperation 
                  originalContentsURL:[self fileURL]
                                error:outError];
            
            break;
        
            
            
        // Other save types are fine to go through the regular channels
        default:
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
		
		NSString *failureReason = [NSString stringWithFormat:@"Could not remove the existing file at:\n%@", path];
		NSDictionary *userInfo = [NSDictionary dictionaryWithObjectsAndKeys:@"Unable to save document", NSLocalizedDescriptionKey,
																			failureReason, NSLocalizedFailureReasonErrorKey,
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
	OBPRECONDITION(saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation);
	
	
	BOOL result = NO;
	
	
    // Kick off thumbnail generation
    [self startGeneratingQuickLookThumbnail];
    
    
    
    // Prepare to save the context
    result = [self prepareToWriteToURL:inURL
                                ofType:inType
                      forSaveOperation:saveOperation
                                 error:outError];
    OBASSERT(result || !outError || (nil != *outError));    // make sure we didn't return NO with an empty error
	
    
	
	if (result)
	{
		// Generate Quick Look preview HTML
        NSString *quickLookPreviewHTML = [self quickLookPreviewHTML];
        
        
        // Save the context
		result = [self writeDatastoreToURL:inURL
                              ofType:inType
                    forSaveOperation:saveOperation
                 originalContentsURL:inOriginalContentsURL
                               error:outError];
		OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		
        
        // Write out Quick Look preview
        if (result && quickLookPreviewHTML)
        {
            NSURL *previewURL = [[KTDocument quickLookURLForDocumentURL:inURL] URLByAppendingPathComponent:@"Preview.html" isDirectory:NO];
            
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
    }
    
    
    if (result && _quickLookThumbnailWebView)
    {
        NSError *qlThumbnailError;
        if (![self writeQuickLookThumbnailToDocumentURLIfPossible:inURL error:&qlThumbnailError])
        {
            NSLog(@"Error saving Quick Look thumbnail: %@",
                  [[qlThumbnailError debugDescription] condenseWhiteSpace]);
        }
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
	if (saveOperation == NSSaveAsOperation)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:[inURL path] attributes:nil];
		[[NSWorkspace sharedWorkspace] setBundleBit:YES forFile:[inURL path]];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument siteURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTMediaManager mediaURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument quickLookURLForDocumentURL:inURL] path] attributes:nil];
	}
	
	
	// Make sure we have a persistent store coordinator properly set up
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	NSPersistentStoreCoordinator *storeCoordinator = [managedObjectContext persistentStoreCoordinator];
	NSURL *persistentStoreURL = [KTDocument datastoreURLForDocumentURL:inURL type:nil];
	
	if ([[storeCoordinator persistentStores] count] < 1)
	{ 
		BOOL didConfigure = [self configurePersistentStoreCoordinatorForURL:inURL // not newSaveURL as configurePSC needs to be consistent
																	 ofType:inType
                                                         modelConfiguration:nil
                                                               storeOptions:nil
																	  error:outError];
		
		OBASSERT( (YES == didConfigure) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error

		id newStore = [storeCoordinator persistentStoreForURL:persistentStoreURL];
		if ( !newStore || !didConfigure )
		{
			NSLog(@"error: unable to create document: %@", (outError ? [*outError description] : nil) );
			return NO; // bail out and display outError
		}
	} 
	
	
    // Set metadata
    if ([storeCoordinator persistentStoreForURL:persistentStoreURL])
    {
        if (![self setMetadataForStoreAtURL:persistentStoreURL error:outError])
        {
			OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
            return NO; // couldn't setMetadata, but we should have, bail...
        }
    }
    else
    {
        if (saveOperation != NSSaveAsOperation)
        {
			OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
			LOG((@"error: wants to setMetadata during save but no persistent store at %@", persistentStoreURL));
            return NO; // this case should not happen, stop
        }
    }
    
    
    // Move external media in-document if the user requests it
    KTSite *site = [self site];
    if ([site copyMediaOriginals] != [[site committedValueForKey:@"copyMediaOriginals"] intValue])
    {
        [[self mediaManager] moveApplicableExternalMediaInDocument];
    }
	
	
	return YES;
}

- (BOOL)writeDatastoreToURL:(NSURL *)inURL  // TODO: this should be the URL of the datastore, not the document
                     ofType:(NSString *)inType
           forSaveOperation:(NSSaveOperationType)inSaveOperation
        originalContentsURL:(NSURL *)inOriginalContentsURL
                      error:(NSError **)outError;

{
	OBASSERT([NSThread currentThread] == [self thread]);
    
    
    BOOL result = YES;
	NSError *error = nil;
	
	
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	
	
    
    // Handle the user choosing "Save As" for an EXISTING document
    if (inSaveOperation == NSSaveAsOperation && [self fileURL])
    {
        result = [self migrateToURL:inURL ofType:inType originalContentsURL:inOriginalContentsURL error:&error];
        if (!result)
        {
            if (outError)
            {
                *outError = error;
            }
            return NO; // bail out and display outError
        }
        else
        {
            result = [self setMetadataForStoreAtURL:[KTDocument datastoreURLForDocumentURL:inURL type:nil]
                                              error:&error];
        }
    }
    
    
    // Time to actually save the context
    if (result)
    {
        result = [managedObjectContext save:&error];
    }

    
    // Return, making sure to supply appropriate error info
    if (!result && outError) *outError = error;
    OBASSERT( (YES == result) || (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
    
    return result;
}

/*	Called when performing a "Save As" operation on an existing document
 */
- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName originalContentsURL:(NSURL *)originalContentsURL error:(NSError **)outError
{
	// Build a list of the media files that will require copying/moving to the new doc
	NSManagedObjectContext *mediaMOC = [[self mediaManager] managedObjectContext];
	NSArray *mediaFiles = [mediaMOC allObjectsWithEntityName:@"AbstractMediaFile" error:NULL];
	NSMutableSet *pathsToCopy = [NSMutableSet setWithCapacity:[mediaFiles count]];
	NSMutableSet *pathsToMove = [NSMutableSet setWithCapacity:[mediaFiles count]];
	
	NSEnumerator *mediaFilesEnumerator = [mediaFiles objectEnumerator];
	KTMediaFile *aMediaFile;
	while (aMediaFile = [mediaFilesEnumerator nextObject])
	{
		NSString *path = [aMediaFile currentPath];
		if ([aMediaFile hasTemporaryObjectID])
		{
			[pathsToMove addObjectIgnoringNil:path];
		}
		else
		{
			[pathsToCopy addObjectIgnoringNil:path];
		}
	}
	
	
	// Migrate the main document store
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:URL type:nil];
	NSPersistentStoreCoordinator *storeCoordinator = [[self managedObjectContext] persistentStoreCoordinator];
    OBASSERT(storeCoordinator);
	
	NSURL *oldDataStoreURL = [KTDocument datastoreURLForDocumentURL:originalContentsURL type:nil];
    OBASSERT(oldDataStoreURL);
    
    id oldDataStore = [storeCoordinator persistentStoreForURL:oldDataStoreURL];
    NSAssert5(oldDataStore,
              @"No persistent store found for URL: %@\nPersistent stores: %@\nDocument URL:%@\nOriginal contents URL:%@\nDestination URL:%@",
              [oldDataStoreURL absoluteString],
              [storeCoordinator persistentStores],
              [self fileURL],
              originalContentsURL,
              URL);
    
    if (![storeCoordinator migratePersistentStore:oldDataStore
										    toURL:storeURL
										  options:nil
										 withType:[self persistentStoreTypeForFileType:typeName]
										    error:outError])
	{
		OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		return NO;
	}
	
    
	// Set the new metadata
	if ( ![self setMetadataForStoreAtURL:storeURL error:outError] )
	{
		OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		return NO;
	}	
	
    
	// Migrate the media store
	storeURL = [KTMediaManager mediaStoreURLForDocumentURL:URL];
	storeCoordinator = [[[self mediaManager] managedObjectContext] persistentStoreCoordinator];
	
	NSURL *oldMediaStoreURL = [KTMediaManager mediaStoreURLForDocumentURL:originalContentsURL];
    OBASSERT(oldMediaStoreURL);
    id oldMediaStore = [storeCoordinator persistentStoreForURL:oldMediaStoreURL];
    OBASSERT(oldMediaStore);
    if (![storeCoordinator migratePersistentStore:oldMediaStore
										    toURL:storeURL
										  options:nil
										 withType:[KTMediaManager defaultMediaStoreType]
										    error:outError])
	{
		OBASSERT( (nil == outError) || (nil != *outError) ); // make sure we didn't return NO with an empty error
		return NO;
	}
	
	
	// Copy/Move media files
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *newDocMediaPath = [[KTMediaManager mediaURLForDocumentURL:URL] path];
	
	NSEnumerator *pathsEnumerator = [pathsToCopy objectEnumerator];
	NSString *aPath;	NSString *destinationPath;
	while (aPath = [pathsEnumerator nextObject])
	{
		destinationPath = [newDocMediaPath stringByAppendingPathComponent:[aPath lastPathComponent]];
		[fileManager copyPath:aPath toPath:destinationPath handler:nil];
	}
	
	pathsEnumerator = [pathsToMove objectEnumerator];
	while (aPath = [pathsEnumerator nextObject])
	{
		destinationPath = [newDocMediaPath stringByAppendingPathComponent:[aPath lastPathComponent]];
		[fileManager movePath:aPath toPath:destinationPath handler:nil];
	}
	return YES;
}

#pragma mark -
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
		if ( nil != theStore )
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
			
			//  kMDItemCreator (Sandvox is the creator of this site document)
			[metadata setObject:[NSApplication applicationName] forKey:(NSString *)kMDItemCreator];
            
			// kMDItemKind
			[metadata setObject:NSLocalizedString(@"Sandvox Site", "kind of document") forKey:(NSString *)kMDItemKind];
			
			/// we're going to fault every page, use a local pool to release them quickly
			NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
			
			//  kMDItemNumberOfPages
			NSArray *pages = [[self managedObjectContext] allObjectsWithEntityName:@"Page" error:NULL];
			unsigned int pageCount = 0;
			if ( nil != pages )
			{
				pageCount = [pages count]; // according to mmalc, this is the only way to get this kind of count
			}
			[metadata setObject:[NSNumber numberWithUnsignedInt:pageCount] forKey:(NSString *)kMDItemNumberOfPages];
			
			//  kMDItemTextContent (free-text account of content)
			//  for now, we'll make this site subtitle, plus all unique page titles, plus spotlightHTML
			NSString *subtitle = [[[[[self site] rootPage] master] siteSubtitle] textHTMLString];
			if ( nil == subtitle )
			{
				subtitle = @"";
			}
			subtitle = [subtitle stringByConvertingHTMLToPlainText];
			
			// add unique page titles
			NSMutableString *textContent = [NSMutableString stringWithString:subtitle];
			NSArray *pageTitles = [[self managedObjectContext] objectsForColumnName:@"titleHTMLString" entityName:@"Page"];
			unsigned int i;
			for ( i=0; i<[pageTitles count]; i++ )
			{
				NSString *pageTitle = [pageTitles objectAtIndex:i];
				pageTitle = [pageTitle stringByConvertingHTMLToPlainText];
				if ( nil != pageTitle )
				{
					[textContent appendFormat:@" %@", pageTitle];
				}
			}
            
			// spotlightHTML as part of textContent
			for ( i=0; i<[pages count]; i++ )
			{
				KTPage *page = [pages objectAtIndex:i];
				NSString *spotlightText = [page spotlightHTML];
				if ( (nil != spotlightText) && ![spotlightText isEqualToString:@""] )
				{
					spotlightText = [spotlightText stringByConvertingHTMLToPlainText];
					[textContent appendFormat:@" %@", spotlightText];
				}
			}
			[metadata setObject:textContent forKey:(NSString *)kMDItemTextContent];
			
			//  kMDItemKeywords (keywords of all pages)
			NSMutableSet *keySet = [NSMutableSet set];
			for (i=0; i<[pages count]; i++)
			{
				[keySet addObjectsFromArray:[[pages objectAtIndex:i] keywords]];
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

#pragma mark -
#pragma mark Quick Look Thumbnail

- (void)startGeneratingQuickLookThumbnail
{
	OBASSERT([NSThread currentThread] == [self thread]);
    
    // Put together the HTML for the thumbnail
    SVMutableStringHTMLContext *context = [[SVMutableStringHTMLContext alloc] init];
    [context setGenerationPurpose:kGeneratingPreview];
    [context setLiveDataFeeds:NO];
    [context setCurrentPage:[[self site] rootPage]];
    
    [context push];
    [[[self site] rootPage] writeHTML];
    [context pop];
	
    NSString *thumbnailHTML = [context markupString];
    [context release];
    
	
    // Load into webview
    [self performSelectorOnMainThread:@selector(_startGeneratingQuickLookThumbnailWithHTML:)
                           withObject:thumbnailHTML
                        waitUntilDone:YES];
}

- (void)_startGeneratingQuickLookThumbnailWithHTML:(NSString *)thumbnailHTML
{
    // View and WebView handling MUST be on the main thread
    OBASSERT([NSThread isMainThread]);
    
    
	// Create the webview's offscreen window
	unsigned designViewport = [[[[[self site] rootPage] master] design] viewport];	// Ensures we don't clip anything important
	NSRect frame = NSMakeRect(0.0, 0.0, designViewport+20, designViewport+20);	// The 20 keeps scrollbars out the way
	
	NSWindow *window = [[NSWindow alloc]
                        initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[window setReleasedWhenClosed:NO];	// Otherwise we crash upon quitting - I guess NSApplication closes all windows when terminatating?
	
    
    // Create the webview
    OBASSERT(!_quickLookThumbnailWebView);
	_quickLookThumbnailWebView = [[WebView alloc] initWithFrame:frame];
    
    [_quickLookThumbnailWebView setResourceLoadDelegate:self];
	[window setContentView:_quickLookThumbnailWebView];
    
    
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
        
        NSWindow *webViewWindow = [_quickLookThumbnailWebView window];
        [_quickLookThumbnailWebView release];   _quickLookThumbnailWebView = nil;
        [webViewWindow release];    // we allocate the window object when creating it but never autorelease. It stays attached to the webview until we release it here
        
        
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
		result = nil;
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

#pragma mark -
#pragma mark Quick Look preview

/*  Parses the home page to generate a Quick Look preview
 */
- (NSString *)quickLookPreviewHTML
{
    OBASSERT([NSThread currentThread] == [self thread]);
    
    SVMutableStringHTMLContext *context = [[SVMutableStringHTMLContext alloc] init];
    [context setGenerationPurpose:kGeneratingQuickLookPreview];
    [context setCurrentPage:[[self site] rootPage]];
    
    [context push];
    [[[self site] rootPage] writeHTML];
    [context pop];
    
    NSString *result = [context markupString];
    [context release];
    
    return result;
}

@end
