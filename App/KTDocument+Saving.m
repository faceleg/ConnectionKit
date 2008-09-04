//
//  KTDocument+Saving.m
//  Marvel
//
//  Created by Mike on 26/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "KTDesign.h"
#import "KTDocumentController.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"
#import "KTDocumentInfo.h"
#import "KTHTMLParser.h"
#import "KTPage.h"
#import "KTMaster.h"
#import "KTMediaManager+Internal.h"

#import "CIImage+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSView+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSURL+Karelia.h"

#import "KTWebKitCompatibility.h"

#import "Registration.h"
#import "Debug.h"


NSString *KTDocumentWillSaveNotification = @"KTDocumentWillSave";


/*	These strings are used for generating Quick Look preview sticky-note text
 */
// NSLocalizedString(@"Published at", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Last updated", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Author", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Language", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Pages", "Quick Look preview sticky-note text");


// TODO: change these into defaults
//#define FIRST_AUTOSAVE_DELAY 3
//#define SECOND_AUTOSAVE_DELAY 60


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
            includeMetadata:(BOOL)includeMetadata
					  error:(NSError **)outError;

- (BOOL)writeMOCToURL:(NSURL *)inURL 
			   ofType:(NSString *)inType 
	 forSaveOperation:(NSSaveOperationType)inSaveOperation 
				error:(NSError **)outError;

- (BOOL)migrateToURL:(NSURL *)URL 
			  ofType:(NSString *)typeName 
			   error:(NSError **)outError;

- (WebView *)newQuickLookThumbnailWebView;
@end


#pragma mark -


@implementation KTDocument (Saving)

#pragma mark -
#pragma mark Save to URL

/*	-writeToURL: only supports the Save and SaveAs operations. Instead, we fake SaveTo operations by doing a standard
 *  Save operation and then copying the resultant file to the destination.
 */
- (BOOL)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
			error:(NSError **)outError
{
	[[NSNotificationCenter defaultCenter] postNotificationName:KTDocumentWillSaveNotification object:self];
    
    
    BOOL result = NO;
    
    
    // Mark -isSaving as YES;
    mySaveOperationCount++;
	
    
    // Do the save op
	if (saveOperation == NSSaveToOperation)
	{
		result = [self saveToURL:[self fileURL] ofType:[self fileType] forSaveOperation:NSSaveOperation error:outError];
		if (result)
		{
			result = [[NSFileManager defaultManager] copyPath:[[self fileURL] path] toPath:[absoluteURL path] handler:nil];
		}
	}
	else
	{
		result = [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
	}
	
    
    // Unmark -isSaving as YES if applicable
    mySaveOperationCount--;
    
    
	return result;
}

- (BOOL)isSaving
{
    return (mySaveOperationCount > 0);
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
	// We're only interested in special behaviour for Save As operations
	if (saveOperation != NSSaveAsOperation)
	{
		return [super writeSafelyToURL:absoluteURL 
								ofType:typeName 
					  forSaveOperation:saveOperation 
								 error:outError];
	}
	
	
	// We'll need a path for various operations below
	NSAssert2([absoluteURL isFileURL], @"%@ called for non-file URL: %@", NSStringFromSelector(_cmd), [absoluteURL absoluteString]);
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
	BOOL result = NO;
	
	@try
	{
		// Write to the new URL
		result = [self writeToURL:absoluteURL
						   ofType:typeName
				 forSaveOperation:saveOperation
			  originalContentsURL:[self fileURL]
							error:outError];
	}
	@catch (NSException *exception) 
	{
		// Recover from an exception as best as possible and then rethrow the exception so it goes the exception reporter mechanism
		[self recoverBackupFile:backupPath toURL:absoluteURL];
		@throw;
	}
	
	
	if (result)
	{
		// The save was successful, delete the backup file
		if (backupPath)
		{
			[[NSFileManager defaultManager] removeFileAtPath:backupPath handler:nil];
		}
	}
	else
	{
		// There was an error saving, recover from it
		[self recoverBackupFile:backupPath toURL:absoluteURL];
	}
	
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
		*error = [NSError errorWithDomain:@"KTDocument" code:0 userInfo:userInfo];
	}
	
	return result;
}

/*	In the event of a Save As operation failing, we copy the backup file back to the original location.
 */
- (void)recoverBackupFile:(NSString *)backupPath toURL:(NSURL *)saveURL
{
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
		NSLog(@"Could not recover backup file:\n%@\nafter Save As operation failed for URL:\n%@", backupPath, [saveURL path]);
	}
}

#pragma mark -
#pragma mark Write To URL

/*  We're overriding NSDocument's default behaviour to give the option of writing metadata
 */
- (BOOL)writeToURL:(NSURL *)inURL 
			ofType:(NSString *)inType 
  forSaveOperation:(NSSaveOperationType)inSaveOperation originalContentsURL:(NSURL *)inOriginalContentsURL
			 error:(NSError **)outError 
{
    return [self writeToURL:inURL
                     ofType:inType
           forSaveOperation:inSaveOperation
        originalContentsURL:inOriginalContentsURL
            includeMetadata:YES
                      error:outError];
}

/*	Called when creating a new document and when performing saveDocumentAs:
 */
- (BOOL)writeToURL:(NSURL *)inURL ofType:(NSString *)inType forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL includeMetadata:(BOOL)includeMetadata error:(NSError **)outError;
{
	// We don't support any of the other save ops here.
	OBPRECONDITION(saveOperation == NSSaveOperation || saveOperation == NSSaveAsOperation);
	
	
	BOOL result = NO;
	
	
    // Begin loading the thumbnail if on the main thread
	NSDate *documentSaveLimit = [[NSDate date] addTimeInterval:10.0];
	
    WebView *quickLookThumbnailWebView = nil;
    if ([NSThread isMainThread])
    {
        quickLookThumbnailWebView = [self newQuickLookThumbnailWebView];
	}
    
    
    // Prepare to save the context
	result = [self prepareToWriteToURL:inURL
                                ofType:inType
                      forSaveOperation:saveOperation
                       includeMetadata:includeMetadata
                                 error:outError];
	
	
	if (result)
	{
		// Save the context
		result = [self writeMOCToURL:inURL ofType:inType forSaveOperation:saveOperation error:outError];
		
		
		if (result && quickLookThumbnailWebView)
		{
			// Wait a second before putting up a progress sheet
			while ([quickLookThumbnailWebView isLoading] && [documentSaveLimit timeIntervalSinceNow] > 8.0)
			{
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:documentSaveLimit];
			}
			BOOL beganSheet = NO;
			if ([quickLookThumbnailWebView isLoading])
			{
				[[self windowController] beginSheetWithStatus:NSLocalizedString(@"Saving\\U2026","Message title when performing a lengthy save")
														image:nil];
				beganSheet = YES;
			}
			
			
			
			// Wait for the thumbnail to complete. We shall allocate a maximum of 10 seconds for this
			while ([quickLookThumbnailWebView isLoading] && [documentSaveLimit timeIntervalSinceNow] > 0.0)
			{
				[[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:documentSaveLimit];
			}
			
			if (![quickLookThumbnailWebView isLoading])
			{
				// Write the thumbnail to disk
				[quickLookThumbnailWebView displayIfNeeded];	// Otherwise we'll be capturing a blank frame!
				NSImage *snapshot = [[[[quickLookThumbnailWebView mainFrame] frameView] documentView] snapshot];
				
				NSImage *snapshot512 = [snapshot imageWithMaxWidth:512 height:512 
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
				float left = ([snapshot512 size].width - textSize.width) / 2.0;
				float bottom = 7;		// empirically - seems to be a good offset for when shrunk to 32x32
				
				[snapshot512 lockFocus];
				[s drawAtPoint:NSMakePoint(left, bottom) withAttributes:attributes];
				[snapshot512 unlockFocus];
				
				
				
				NSURL *thumbnailURL = [NSURL URLWithString:@"thumbnail.png" relativeToURL:[KTDocument quickLookURLForDocumentURL:inURL]];
				OBASSERT(thumbnailURL);	// shouldn't be nil, right?
				result = [[snapshot512 PNGRepresentation] writeToURL:thumbnailURL options:NSAtomicWrite error:outError];
			}
			
			
			// Close the progress sheet
			if (beganSheet)
			{
				[[self windowController] endSheet];
			}
		}
	}
	
	
	// Tidy up
	NSWindow *webViewWindow = [quickLookThumbnailWebView window];
	[quickLookThumbnailWebView release];
	[webViewWindow release];
	
	return result;
}


/*	Support method that sets the environment ready for the MOC and other document contents to be written to disk.
 */
- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)saveOperation 
            includeMetadata:(BOOL)includeMetadata
					  error:(NSError **)outError
{
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
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument mediaURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument quickLookURLForDocumentURL:inURL] path] attributes:nil];
	}
	
	
	// Make sure we have a persistent store coordinator properly set up
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	NSPersistentStoreCoordinator *storeCoordinator = [managedObjectContext persistentStoreCoordinator];
	NSURL *persistentStoreURL = [KTDocument datastoreURLForDocumentURL:inURL UTI:nil];
	
	if ((saveOperation == NSSaveOperation) && ![storeCoordinator persistentStoreForURL:persistentStoreURL]) 
	{
		// NSDocument does atomic saves so the first time the user saves it's in a temporary
		// directory and the file is then moved to the actual save path, so we need to tell the 
		// persistentStoreCoordinator to remove the old persistentStore, otherwise if we attempt
		// to migrate it, the coordinator complains because it knows they are the same store
		// despite having two different URLs
		(void)[storeCoordinator removePersistentStore:[[storeCoordinator persistentStores] objectAtIndex:0]
												error:outError];
	}
	
	if ([[storeCoordinator persistentStores] count] < 1)
	{ 
		// this is our first save so we just set the persistentStore and save normally
//		BOOL didConfigure = [self configurePersistentStoreCoordinatorForURL:inURL // not newSaveURL as configurePSC needs to be consistent
//																	 ofType:[KTDocument defaultStoreType]
//														 modelConfiguration:nil
//															   storeOptions:nil
//																	  error:outError];
		// the above method isn't available in Tiger, so we use the old, deprecated method
		
		BOOL didConfigure = [self configurePersistentStoreCoordinatorForURL:inURL // not newSaveURL as configurePSC needs to be consistent
																	 ofType:[KTDocument defaultStoreType]
																	  error:outError];
		
		id newStore = [storeCoordinator persistentStoreForURL:persistentStoreURL];
		if ( !newStore || !didConfigure )
		{
			NSLog(@"error: unable to create document: %@", [*outError description]);
			return NO; // bail out and display outError
		}
	} 
	
	
    // Set metadata
    if (includeMetadata)
    {
        if ( nil != [storeCoordinator persistentStoreForURL:persistentStoreURL] )
        {
            if ( ![self setMetadataForStoreAtURL:persistentStoreURL error:outError] )
            {
                return NO; // couldn't setMetadata, but we should have, bail...
            }
        }
        else
        {
            if ( saveOperation != NSSaveAsOperation )
            {
                LOG((@"error: wants to setMetadata during save but no persistent store at %@", persistentStoreURL));
                return NO; // this case should not happen, stop
            }
        }
    }
    
    
    // Record display properties
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] disableUndoRegistration];
    [self copyDocumentDisplayPropertiesToModel];
    [managedObjectContext processPendingChanges];
    [[managedObjectContext undoManager] enableUndoRegistration];
    
    
    // Move external media in-document if the user requests it
    KTDocumentInfo *docInfo = [self documentInfo];
    if ([docInfo copyMediaOriginals] != [[docInfo committedValueForKey:@"copyMediaOriginals"] intValue])
    {
        [[self mediaManager] moveApplicableExternalMediaInDocument];
    }
	
	
	return YES;
}

- (BOOL)writeMOCToURL:(NSURL *)inURL 
			   ofType:(NSString *)inType 
	 forSaveOperation:(NSSaveOperationType)inSaveOperation 
				error:(NSError **)outError
{
	BOOL result = NO;
	NSError *error = nil;
	
	
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	
	
	// Handle the user choosing "Save As" for an EXISTING document
	if (inSaveOperation == NSSaveAsOperation && [self fileURL])
	{
		result = [self migrateToURL:inURL ofType:inType error:&error];
		if (!result)
		{
			*outError = error;
			return NO; // bail out and display outError
		}
		else
		{
			result = [self setMetadataForStoreAtURL:[KTDocument datastoreURLForDocumentURL:inURL UTI:nil]
											  error:&error];
		}
	}
	
	
	// Store QuickLook preview
	if ([NSThread isMainThread])
	{
		KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[[self documentInfo] root]];
		[parser setHTMLGenerationPurpose:kGeneratingQuickLookPreview];
		NSString *previewHTML = [parser parseTemplate];
		[parser release];
		
		NSString *previewPath = [[[KTDocument quickLookURLForDocumentURL:inURL] path] stringByAppendingPathComponent:@"preview.html"];
		[previewHTML writeToFile:previewPath atomically:NO encoding:NSUTF8StringEncoding error:NULL];
	}
	
	
	result = [managedObjectContext save:&error];
	if (result) result = [[[self mediaManager] managedObjectContext] save:&error];
	
	if (result)
	{
		// if we've saved, we don't need to autosave until after the next context change
		[self cancelAndInvalidateAutosaveTimers];
	}
	else
	{
        // Return, making sure to supply appropriate error info
        if (!result) *outError = error;
    }
    
	return result;
}

/*	Called when performaing a "Save As" operation on an existing document
 */
- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName error:(NSError **)outError
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
		if ([aMediaFile isTemporaryObject])
		{
			[pathsToMove addObjectIgnoringNil:path];
		}
		else
		{
			[pathsToCopy addObjectIgnoringNil:path];
		}
	}
	
	
	// Migrate the main document store
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:URL UTI:nil];
	NSPersistentStoreCoordinator *storeCoordinator = [[self managedObjectContext] persistentStoreCoordinator];
	
	if (![storeCoordinator migratePersistentStore:[[storeCoordinator persistentStores] objectAtIndex:0]
										    toURL:storeURL
										  options:nil
										 withType:[KTDocument defaultStoreType]
										    error:outError])
	{
		return NO;
	}
	
	// Set the new metadata
	if ( ![self setMetadataForStoreAtURL:storeURL error:outError] )
	{
		return NO;
	}	
	
	// Migrate the media store
	storeURL = [KTDocument mediaStoreURLForDocumentURL:URL];
	storeCoordinator = [[[self mediaManager] managedObjectContext] persistentStoreCoordinator];
	
	if (![storeCoordinator migratePersistentStore:[[storeCoordinator persistentStores] objectAtIndex:0]
										    toURL:storeURL
										  options:nil
										 withType:[KTDocument defaultMediaStoreType]
										    error:outError])
	{
		return NO;
	}
	
	
	// Copy/Move media files
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *newDocMediaPath = [[KTDocument mediaURLForDocumentURL:URL] path];
	
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
#pragma mark Quick Look Thumbnail

/*	Please note the "new" in the title. The result is NOT autoreleased. And neither is its window.
 */
- (WebView *)newQuickLookThumbnailWebView
{
	// Put together the HTML for the thumbnail
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[[self documentInfo] root]];
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	[parser setLiveDataFeeds:NO];
	NSString *thumbnailHTML = [parser parseTemplate];
	[parser release];
	
	
	// Create the webview. It must be in an offscreen window to do this properly.
	unsigned designViewport = [[[[[self documentInfo] root] master] design] viewport];	// Ensures we don't clip anything important
	NSRect frame = NSMakeRect(0.0, 0.0, designViewport+20, designViewport+20);	// The 20 keeps scrollbars out the way
	
	NSWindow *window = [[NSWindow alloc]
		initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[window setReleasedWhenClosed:NO];	// Otherwise we crash upon quitting - I guess NSApplication closes all windows when terminatating?
	
	WebView *result = [[WebView alloc] initWithFrame:frame];	// Both window and webview will be released later
    [result setResourceLoadDelegate:self];
	[window setContentView:result];
	
	
	// Go ahead and begin building the thumbnail. This MUST be done on the main thread
    [[result mainFrame] performSelectorOnMainThreadAndReturnResult:@selector(loadHTMLString:baseURL:)
                                                        withObject:thumbnailHTML
                                                        withObject:nil];
    
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

#pragma mark -
#pragma mark Autosave

- (void)processPendingChangesAndClearChangeCount
{
	LOGMETHOD;
	[[self managedObjectContext] processPendingChanges];
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
}

- (void)updateChangeCount:(NSDocumentChangeType)changeType
{
	//LOGMETHOD;
	[super updateChangeCount:changeType];
	
	switch ( changeType )
	{
		case NSChangeDone:
		case NSChangeUndone:
			[self restartAutosaveTimerIfNecessary];
			break;
		default:
			break;
	}
}

// main entry point for saving the document programmatically
- (IBAction)autosaveDocument:(id)sender
{
	@try	 // Because it's on a timer, we have to catch any exceptions ourself.
	{
        // the timer will fire whether there are changes to save or not
		// but we only want to save if isDocumentEdited
		if ( [self isDocumentEdited] && (nil != [self fileURL]) )
		{
			LOGMETHOD;
			OBASSERT([NSThread isMainThread]);
			
			// remember the current status. PURPOSELY LEAKED AS WE RELEASE IT IN THE CALLBACK
			NSString *status = [[[self windowController] status] copy];
			[[self windowController] setStatusField:NSLocalizedString(@"Autosaving...", @"Status: Autosaving...")];
			
			// turn off timers before doing save
			[self cancelAndInvalidateAutosaveTimers];
			
			// Save the document through normal channels (ultimately calls writeToURL:::).
		    [self saveDocumentWithDelegate:self
                           didSaveSelector:@selector(document:didAutosave:contextInfo:)
                               contextInfo:status];
        }
	}
	@catch (NSException *exception)
	{
		[NSApp reportException:exception];
	}
}

- (void)document:(NSDocument *)doc didAutosave:(BOOL)didSave contextInfo:(void  *)contextInfo
{
	NSAssert1(doc == self, @"%@ called for unknown document", _cmd);
	
	if ([(id)contextInfo isKindOfClass:[NSString class]])
	{
		// restore status
		NSString *contextInfoString = contextInfo;
		[[self windowController] setStatusField:contextInfoString];
		
		[contextInfoString release]; // balances copy in autosaveDocument:
	}
}

//- (void)fireAutosave:(id)notUsedButRequiredParameter
//{
//	LOGMETHOD;
//	
//	OBASSERTSTRING([NSThread isMainThread], @"should be main thread");
//	
//	[self cancelAndInvalidateAutosaveTimers];
//	[self performSelector:@selector(autosaveDocument:)
//			   withObject:nil
//			   afterDelay:0.0];
//}

- (void)fireAutosaveViaTimer:(NSTimer *)aTimer
{
	//LOGMETHOD;
	OBASSERTSTRING([NSThread isMainThread], @"should be main thread");
	
//    if ( [myLastSavedTime timeIntervalSinceNow] >= SECOND_AUTOSAVE_DELAY )
//    {
		[self autosaveDocument:nil];
//    }
}

- (oneway void)release;
{
	[super release];
}

- (void)restartAutosaveTimerIfNecessary
{
	//LOGMETHOD;
	if ( !myIsSuspendingAutosave && ![self isClosing] )
	{
		OBASSERTSTRING([NSThread isMainThread], @"should be main thread");
		
		// timer A, save in 3 seconds, cancelled by change to context
		//LOG((@"cancelling previous and starting new 3 second timer"));
//		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fireAutosave:) object:nil];
//		[self performSelector:@selector(fireAutosave:) withObject:nil afterDelay:FIRST_AUTOSAVE_DELAY];
		
		// timer B, save in N seconds, if not saved within last N seconds
		if ( nil == myAutosaveTimer )
		{
			// start a timer
			
			NSTimeInterval interval = [[[NSUserDefaults standardUserDefaults] valueForKey:@"AutosaveFrequency"] doubleValue];
			// if the number is wildly out of range, go back to our default of 30
			if ( interval < 5 ) interval = 30.0;
			if ( interval > 5*60 ) interval = 30.0;
			
			LOG((@"starting new autosave timer to fire %g seconds from now", interval));
			NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:interval
															  target:self
															selector:@selector(fireAutosaveViaTimer:)
															userInfo:nil
															 repeats:NO];
			[self setAutosaveTimer:timer];
		}
	}
}

- (void)cancelAndInvalidateAutosaveTimers
{
	//LOGMETHOD;
	//OBASSERTSTRING([NSThread isMainThread], @"should be main thread");

	//LOG((@"cancelling autosave timers"));
//	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fireAutosave:) object:nil];
	@synchronized ( myAutosaveTimer )
	{
		[self setAutosaveTimer:nil];
	}
	
	// also clear run loop of any previous requests that made it through
/// NOT USING	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autosaveDocument:) object:nil];
}

- (void)suspendAutosave
{
	//LOGMETHOD;
	//LOG((@"---------------------------------------------- deactivating autosave"));
	if ( !myIsSuspendingAutosave || !(kGeneratingPreview == [[self windowController] publishingMode]) )
	{
		myIsSuspendingAutosave = YES;
	}
	if ( [NSThread isMainThread] )
	{
		[self cancelAndInvalidateAutosaveTimers];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(cancelAndInvalidateAutosaveTimers) withObject:nil waitUntilDone:NO];
	}
}

- (void)resumeAutosave
{
	//LOGMETHOD;
	//LOG((@"---------------------------------------------- (re)activating autosave"));
	if ( myIsSuspendingAutosave || !(kGeneratingPreview == [[self windowController] publishingMode]) )
	{
		myIsSuspendingAutosave = NO;
	}
	if ( [NSThread isMainThread] )
	{
		[self restartAutosaveTimerIfNecessary];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(restartAutosaveTimerIfNecessary) withObject:nil waitUntilDone:NO];
	}
}

@end
