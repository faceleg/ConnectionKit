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
#import "KTHTMLParser.h"
#import "KTPage.h"
#import "KTMaster.h"
#import "KTMediaManager+Internal.h"

#import "CIImage+Karelia.h"
#import "KTWebKitCompatibility.h"
#import "NSImage+Karelia.h"
#import "NSImage+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSView+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import "Debug.h"


/*	These strings are used for generating Quick Look preview sticky-note text
 */
// NSLocalizedString(@"Published at", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Last updated", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Author", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Language", "Quick Look preview sticky-note text");
// NSLocalizedString(@"Pages", "Quick Look preview sticky-note text");


// TODO: change these into defaults
#define FIRST_AUTOSAVE_DELAY 3
#define SECOND_AUTOSAVE_DELAY 60


@interface KTDocument (PropertiesPrivate)
- (void)copyDocumentDisplayPropertiesToModel;
@end


@interface KTDocument (SavingPrivate)

- (void)threadedSaveToURL:(NSURL *)absoluteURL
				   ofType:(NSString *)typeName
		 forSaveOperation:(NSSaveOperationType)saveOperation;

- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)inSaveOperation 
					  error:(NSError **)outError;

- (BOOL)writeMOCToURL:(NSURL *)inURL 
			   ofType:(NSString *)inType 
	 forSaveOperation:(NSSaveOperationType)inSaveOperation 
				error:(NSError **)outError;

- (BOOL)migrateToURL:(NSURL *)URL 
			  ofType:(NSString *)typeName 
			   error:(NSError **)outError;

- (WebView *)quickLookThumbnailWebView;
- (void)beginLoadingQuickLookThumbnailWebView;
- (void)quickLookThumbnailWebViewIsFinishedWith;
@end


#pragma mark -


@implementation KTDocument (Saving)

/*	Override of default NSDocument behaviour. Thumbnail generation begins asynchronously, and once complete, the doc is saved.
 */
- (void)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
		 delegate:(id)delegate
  didSaveSelector:(SEL)didSaveSelector
	  contextInfo:(void *)contextInfo
{
	NSAssert(![self quickLookThumbnailWebView], @"A save is already in progress");
	
	// Store the information until it's needed later
	mySavingURL = [absoluteURL copy];
	mySavingType = [mySavingType copy];
	mySavingOperationType = saveOperation;
	mySavingDelegate = delegate;	// weak ref
	mySavingFinishedSelector = didSaveSelector;
	mySavingContextInfo = contextInfo;
	
	// Start generating thumbnail
	[self beginLoadingQuickLookThumbnailWebView];
}

// TODO: add in code to do a backup or snapshot, see KTDocument+Deprecated.m. Should be in one of the -saveToURL methods.


/*	Called when creating a new document and when performing saveDocumentAs:
 */
- (BOOL)writeToURL:(NSURL *)inURL 
			ofType:(NSString *)inType 
  forSaveOperation:(NSSaveOperationType)inSaveOperation originalContentsURL:(NSURL *)inOriginalContentsURL error:(NSError **)outError 
{
	NSAssert([NSThread isMainThread], @"should be called only from the main thread");
	
	BOOL result = NO;
	
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
	
	
	// Prepare to save the context
	result = [self prepareToWriteToURL:inURL ofType:inType forSaveOperation:inSaveOperation error:outError];
	
	
	if (result)
	{
		// Save the context
		result = [self writeMOCToURL:inURL ofType:inType forSaveOperation:inSaveOperation error:outError];
		
		if (result)
		{
			// Write out Quick Look thumbnail if available
			WebView *thumbnailWebView = [self quickLookThumbnailWebView];
			if (thumbnailWebView && ![thumbnailWebView isLoading])
			{
				// Write out the thumbnail
				[thumbnailWebView displayIfNeeded];	// Otherwise we'll be capturing a blank frame!
				NSImage *snapshot = [[[[thumbnailWebView mainFrame] frameView] documentView] snapshot];
				
				NSImage *snapshot512 = [snapshot imageWithMaxWidth:512 height:512 
														  behavior:([snapshot width] > [snapshot height]) ? kFitWithinRect : kCropToRect
														 alignment:NSImageAlignTop];
				
				NSURL *thumbnailURL = [NSURL URLWithString:@"thumbnail.png" relativeToURL:[KTDocument quickLookURLForDocumentURL:[self fileURL]]];
				[[snapshot512 PNGRepresentation] writeToURL:thumbnailURL atomically:NO];
				
				
				[self quickLookThumbnailWebViewIsFinishedWith];
			}
		}
	}
	
	return result;
}


/*	Support method that sets the environment ready for the MOC and other document contents to be written to disk.
 */
- (BOOL)prepareToWriteToURL:(NSURL *)inURL 
					 ofType:(NSString *)inType 
		   forSaveOperation:(NSSaveOperationType)inSaveOperation 
					  error:(NSError **)outError
{
	BOOL result = NO;
	NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
	
	
	// For the first save of a document, create the wrapper paths on disk before we do anything else
	if ( NSSaveAsOperation == inSaveOperation )
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:[inURL path] attributes:nil];
		[[NSWorkspace sharedWorkspace] setBundleBit:YES forFile:[inURL path]];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument siteURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument mediaURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument quickLookURLForDocumentURL:inURL] path] attributes:nil];
	}
	
	
	// Make sure we have a persistent store coordinator properly set up
	NSPersistentStoreCoordinator *storeCoordinator = [[self managedObjectContext] persistentStoreCoordinator];
	NSURL *persistentStoreURL = [KTDocument datastoreURLForDocumentURL:inURL];
	if ((inSaveOperation == NSSaveOperation) && ![storeCoordinator persistentStoreForURL:persistentStoreURL]) 
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
		BOOL didConfigure = [self configurePersistentStoreCoordinatorForURL:inURL // not newSaveURL as configurePSC needs to be consistent
																	 ofType:[KTDocument defaultStoreType]
														 modelConfiguration:nil
															   storeOptions:nil
																	  error:outError];
		
		NSPersistentStoreCoordinator *coord = [[self managedObjectContext] persistentStoreCoordinator];
		id newStore = [coord persistentStoreForURL:persistentStoreURL];
		if ( !newStore || !didConfigure )
		{
			NSLog(@"error: unable to create document: %@", [*outError description]);
			return NO; // bail out and display outError
		}
	} 
	
	
	// set metadata
	result = [self setMetadataForStoreAtURL:persistentStoreURL error:outError];
	if ( result )
	{
		// Record display properties
		[managedObjectContext processPendingChanges];
		[[managedObjectContext undoManager] disableUndoRegistration];
		[self copyDocumentDisplayPropertiesToModel];
		[managedObjectContext processPendingChanges];
		[[managedObjectContext undoManager] enableUndoRegistration];
		
		
		if ([self isClosing])
		{
			// grab any last edits
			[[[self windowController] webViewController] commitEditing];
			[managedObjectContext processPendingChanges];
			
			// remembering and collecting should not be undoable
			[[managedObjectContext undoManager] disableUndoRegistration];
			
			// collect garbage
			if ([self updateMediaStorageAtNextSave])
			{
				[[self mediaManager] resetMediaFileStorage];
			}
			[[self mediaManager] garbageCollect];
			
			// force context to record all changes before saving
			[managedObjectContext processPendingChanges];
			[[managedObjectContext undoManager] enableUndoRegistration];
		}
	}
	
	return result;
}

- (BOOL)writeMOCToURL:(NSURL *)inURL 
			   ofType:(NSString *)inType 
	 forSaveOperation:(NSSaveOperationType)inSaveOperation 
				error:(NSError **)outError
{
	NSAssert([NSThread isMainThread], @"should be called only from the main thread");
	
	BOOL result = NO;
	
	// we really want to write to a URL inside the wrapper, so compute the real URL
	NSURL *newSaveURL = [KTDocument datastoreURLForDocumentURL:inURL];
	
	@try 
	{
		NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
		NSPersistentStoreCoordinator *storeCoordinator = [managedObjectContext persistentStoreCoordinator];
		
		
		if (inSaveOperation == NSSaveAsOperation)
		{
			result = [self migrateToURL:inURL ofType:inType error:outError];
			if (!result)
			{
				return NO; // bail out and display outError
			}
			else
			{
				result = [self setMetadataForStoreAtURL:inURL
												  error:outError];
			}
		}
		
		
		// Store QuickLook preview
		KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[self root]];
		[parser setHTMLGenerationPurpose:kGeneratingQuickLookPreview];
		NSString *previewHTML = [parser parseTemplate];
		[parser release];
		
		NSString *previewPath = [[[KTDocument quickLookURLForDocumentURL:inURL] path] stringByAppendingPathComponent:@"preview.html"];
		[previewHTML writeToFile:previewPath atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		
		
		// we very temporarily keep a weak pointer to ourselves as lastSavedDocument
		// so that saveDocumentAs: can find us again until the new context is fully ready
		/// These are disabled since in theory they're not needed any more, but we want to be sure. MA & TT.
		//[[KTDocumentController sharedDocumentController] setLastSavedDocument:self];
		result = [managedObjectContext save:outError];
		if (result) result = [[[self mediaManager] managedObjectContext] save:outError];
		//[[KTDocumentController sharedDocumentController] setLastSavedDocument:nil];
		
		if (result)
		{
			// if we've saved, we don't need to autosave until after the next context change
			[self cancelAndInvalidateAutosaveTimers];
		}
	}
	@catch (NSException * e) 
	{
		NSLog(@"writeToURL: %@", [e description]);
	}
	
	return result;
}

/*	We override the behavior to save directly ('unsafely' I suppose!) to the URL,
 *	rather than via a temporary file as is the default.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL 
				  ofType:(NSString *)typeName 
		forSaveOperation:(NSSaveOperationType)saveOperation 
				   error:(NSError **)outError
{
	BOOL result;
	
	if (saveOperation == NSSaveAsOperation)
	{
		// Write to the new URL
		result = [self writeToURL:absoluteURL
						   ofType:typeName
				 forSaveOperation:saveOperation
			  originalContentsURL:[self fileURL]
							error:outError];
	}
	else
	{
		result = [super writeSafelyToURL:absoluteURL 
								  ofType:typeName 
						forSaveOperation:saveOperation 
								   error:outError];
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
	NSMutableSet *pathsToCopy = [[NSMutableSet alloc] initWithCapacity:[mediaFiles count]];
	NSMutableSet *pathsToMove = [[NSMutableSet alloc] initWithCapacity:[mediaFiles count]];
	
	NSEnumerator *mediaFilesEnumerator = [mediaFiles objectEnumerator];
	KTAbstractMediaFile *aMediaFile;
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
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:URL];
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
	
	
	// Tidy up
	[pathsToCopy release];
	[pathsToMove release];
	
	return YES;
}

#pragma mark -
#pragma mark Quick Look Thumbnail

/*	Each document has a private WebView dedicated to generating Quick Look thumbnails.
 */
- (WebView *)quickLookThumbnailWebView { return myQuickLookThumbnailWebView; }

/*	Once saving is complete, the WebView and its window can be disposed of to save memory.
 */
- (void)quickLookThumbnailWebViewIsFinishedWith
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:WebViewProgressFinishedNotification object:myQuickLookThumbnailWebView];
	
	// Get rid of the webview and its window
	NSWindow *window = [myQuickLookThumbnailWebView window];
	[myQuickLookThumbnailWebView release];	myQuickLookThumbnailWebView = nil;
	[window release];
	
	// This information was temporary while we waited. Clear it out.
	[mySavingURL release];	mySavingURL = nil;
	[mySavingType release];	mySavingType = nil;
	mySavingOperationType = 0;
	mySavingDelegate = nil;		// weak ref
	mySavingFinishedSelector = nil;
	mySavingContextInfo = NULL;
}

- (void)beginLoadingQuickLookThumbnailWebView
{
	NSAssert([NSThread isMainThread], @"should be called only from the main thread");
	NSAssert(!myQuickLookThumbnailWebView, @"A Quick Look thumbnail is already being generated");
	
	
	// Put together the HTML for the thumbnail
	KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[self root]];
	[parser setHTMLGenerationPurpose:kGeneratingPreview];
	[parser setLiveDataFeeds:NO];
	NSString *thumbnailHTML = [parser parseTemplate];
	[parser release];
	
	
	// Create the webview. It must be in an offscreen window to do this properly.
	unsigned designViewport = [[[[self root] master] design] viewport];	// Ensures we don't clip anything important
	NSRect frame = NSMakeRect(0.0, 0.0, designViewport+20, designViewport+20);	// The 20 keeps scrollbars out the way
	
	NSWindow *window = [[NSWindow alloc]
		initWithContentRect:frame styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
	[window setReleasedWhenClosed:NO];	// Otherwise we crash upon quitting - I guess NSApplication closes all windows when termintating?
	
	myQuickLookThumbnailWebView = [[WebView alloc] initWithFrame:frame];	// Both window and webview will be released later
	[window setContentView:myQuickLookThumbnailWebView];
	
	
	// We want to know when the webview's done loading
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(quickLookThumbnailWebviewDidFinishLoading:)
												 name:WebViewProgressFinishedNotification
											   object:myQuickLookThumbnailWebView];
	
	
	// Actually go ahead and begin building the thumbnail
	[[myQuickLookThumbnailWebView mainFrame] loadHTMLString:thumbnailHTML baseURL:nil];
}

/*	Once the thumbnail webview has loaded we can go ahead and do normal document saving
 */
- (void)quickLookThumbnailWebviewDidFinishLoading:(NSNotification *)notification
{
	if ([notification object] != [self quickLookThumbnailWebView]) return;
	if (![[notification name] isEqualToString:WebViewProgressFinishedNotification]) return;
	
	
	[super saveToURL:mySavingURL
			  ofType:mySavingType
	forSaveOperation:mySavingOperationType
			delegate:mySavingDelegate
	 didSaveSelector:mySavingFinishedSelector
		 contextInfo:mySavingContextInfo];
}

#pragma mark -
#pragma mark Autosave

// main entry point for saving the document programmatically
- (IBAction)autosaveDocument:(id)sender
{
	// the timer will fire whether there are changes to save or not
	// but we only want to save if hasChanges
	if ( [[self managedObjectContext] hasChanges] )
	{
		LOGMETHOD;
		NSAssert([NSThread isMainThread], @"should be called only from the main thread");
		
		// remember the current status
		NSString *status = [[self windowController] status];
		
		// update status 
		[[self windowController] setStatusField:NSLocalizedString(@"Autosaving...", "Status: Autosaving...")];
		
		// save the document through normal channels (ultimately calls writeToURL:::)
		[self saveDocument:nil];
		
		// restore status
		[[self windowController] setStatusField:status];
	}
}


- (void)fireAutosave:(id)notUsedButRequiredParameter
{
	//LOGMETHOD;
	
	NSAssert([NSThread isMainThread], @"should be main thread");
	
	[self cancelAndInvalidateAutosaveTimers];
	[self performSelector:@selector(autosaveDocument:)
			   withObject:nil
			   afterDelay:0.0];
}

- (void)fireAutosaveViaTimer:(NSTimer *)aTimer
{
	//LOGMETHOD;
	
	NSAssert([NSThread isMainThread], @"should be main thread");
	
    if ( [myLastSavedTime timeIntervalSinceNow] >= SECOND_AUTOSAVE_DELAY )
    {
		[self cancelAndInvalidateAutosaveTimers];
		[self performSelector:@selector(autosaveDocument:)
				   withObject:nil
				   afterDelay:0.0];
    }
}

- (void)restartAutosaveTimersIfNecessary
{
	//LOGMETHOD;
	
	NSAssert([NSThread isMainThread], @"should be main thread");
	
	if ( !myIsSuspendingAutosave )
	{
		// timer A, save in 3 seconds, cancelled by change to context
		//LOG((@"cancelling previous and starting new 3 second timer"));
		[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fireAutosave:) object:nil];
		[self performSelector:@selector(fireAutosave:) withObject:nil afterDelay:FIRST_AUTOSAVE_DELAY];
		
		// timer B, save in 60 seconds, if not saved within last 60 seconds
		if ( nil == myAutosaveTimer )
		{
			// start a timer
			//LOG((@"starting new 60 second timer"));
			NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:SECOND_AUTOSAVE_DELAY
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
	
	NSAssert([NSThread isMainThread], @"should be main thread");

	//LOG((@"cancelling autosave timers"));
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fireAutosave:) object:nil];
	@synchronized ( myAutosaveTimer )
	{
		[self setAutosaveTimer:nil];
	}
	
	// also clear run loop of any previous requests that made it through
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(autosaveDocument:) object:nil];
}

- (void)suspendAutosave
{
	LOGMETHOD;
	
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
	LOGMETHOD;
	
	//LOG((@"---------------------------------------------- (re)activating autosave"));
	if ( myIsSuspendingAutosave || !(kGeneratingPreview == [[self windowController] publishingMode]) )
	{
		myIsSuspendingAutosave = NO;
	}
	if ( [NSThread isMainThread] )
	{
		[self restartAutosaveTimersIfNecessary];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(restartAutosaveTimersIfNecessary) withObject:nil waitUntilDone:NO];
	}
}

@end
