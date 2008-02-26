//
//  KTDocument+Saving.m
//  Marvel
//
//  Created by Mike on 26/02/2008.
//  Copyright 2008 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "KTDocumentController.h"
#import "KTDocWindowController.h"
#import "KTDocSiteOutlineController.h"
#import "KTHTMLParser.h"
#import "KTMediaManager+Internal.h"

#import "NSManagedObjectContext+KTExtensions.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSMutableSet+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSWorkspace+Karelia.h"

#import <iMediaBrowser/RBSplitView.h>

#import "Debug.h"


// TODO: change these into defaults
#define FIRST_AUTOSAVE_DELAY 3
#define SECOND_AUTOSAVE_DELAY 60


@interface KTDocument (SavingPrivate)
- (void)threadedSaveToURL:(NSURL *)absoluteURL
				   ofType:(NSString *)typeName
		 forSaveOperation:(NSSaveOperationType)saveOperation;
		 
- (BOOL)writeMOCToURL:(NSURL *)inURL ofType:(NSString *)inType forSaveOperation:(NSSaveOperationType)inSaveOperation error:(NSError **)outError;

- (void)rememberDocumentDisplayProperties;
- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName error:(NSError **)outError;
@end


#pragma mark -


@implementation KTDocument (Saving)

- (IBAction)saveDocument:(id)sender
{
	// because context changes will be processed before writeToURL:::::, set flag here, too
	[self setSaving:YES];
	[super saveDocument:sender]; // ultimately calls writeToURL:::::, below
	[self setSaving:NO];
}

/*	Override of default NSDocument behaviour. We split off a new thread to perform the save.
 */
- (void)saveToURL:(NSURL *)absoluteURL
		   ofType:(NSString *)typeName
 forSaveOperation:(NSSaveOperationType)saveOperation
		 delegate:(id)delegate
  didSaveSelector:(SEL)didSaveSelector
	  contextInfo:(void *)contextInfo
{
	// CRITICAL: set flag to turn off model property inheritance (among other things) while saving
	[self setSaving:YES];
	
	[[NSThread detachNewThreadInvocationToTarget:self]
		threadedSaveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation];
}

- (void)threadedSaveToURL:(NSURL *)absoluteURL
				   ofType:(NSString *)typeName
		 forSaveOperation:(NSSaveOperationType)saveOperation
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:NULL];
	
	[pool release];
}

// called when creating a new document and when performing saveDocumentAs:
- (BOOL)writeToURL:(NSURL *)inURL ofType:(NSString *)inType forSaveOperation:(NSSaveOperationType)inSaveOperation originalContentsURL:(NSURL *)inOriginalContentsURL error:(NSError **)outError 
{
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
		
		[self setSaving:NO];
		return NO;
	}
	
	
	
	// TODO: add in code to do a backup or snapshot, see KTDocument+Deprecated.m
	
	
	
	
	
	// if we haven't been saved before, create document wrapper paths on disk before we do anything else
	if ( NSSaveAsOperation == inSaveOperation )
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:[inURL path] attributes:nil];
		[[NSWorkspace sharedWorkspace] setBundleBit:YES forFile:[inURL path]];
		
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument siteURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument mediaURLForDocumentURL:inURL] path] attributes:nil];
		[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument quickLookURLForDocumentURL:inURL] path] attributes:nil];
	}
	
	
	
	// A bunch of trickery to save the context on the main thread
	NSMethodSignature *methodSig = [self methodSignatureForSelector:@selector(writeMOCToURL:ofType:forSaveOperation:error:)];
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:methodSig];
	
	[invocation setSelector:@selector(writeMOCToURL:ofType:forSaveOperation:error:)];
	[invocation setArgument:&inURL atIndex:2];
	[invocation setArgument:&inType atIndex:3];
	[invocation setArgument:&inSaveOperation atIndex:4];
	[invocation setArgument:&outError atIndex:5];
	
	[invocation performSelectorOnMainThread:@selector(invokeWithTarget:) withObject:self waitUntilDone:YES];
	[invocation getReturnValue:&result];
	
	
	
	return result;
}

- (BOOL)writeMOCToURL:(NSURL *)inURL ofType:(NSString *)inType forSaveOperation:(NSSaveOperationType)inSaveOperation error:(NSError **)outError
{
	NSAssert([NSThread isMainThread], @"should be called only from the main thread");
	
	BOOL result = NO;
	
	// we really want to write to a URL inside the wrapper, so compute the real URL
	NSURL *newSaveURL = [KTDocument datastoreURLForDocumentURL:inURL];
	
	@try 
	{
		NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
		NSPersistentStoreCoordinator *storeCoordinator = [managedObjectContext persistentStoreCoordinator];
		if ( (NSSaveOperation == inSaveOperation) && ![storeCoordinator persistentStoreForURL:newSaveURL] ) 
		{
			// NSDocument does atomic saves so the first time the user saves it's in a temporary
			// directory and the file is then moved to the actual save path, so we need to tell the 
			// persistentStoreCoordinator to remove the old persistentStore, otherwise if we attempt
			// to migrate it, the coordinator complains because it knows they are the same store
			// despite having two different URLs
			(void)[storeCoordinator removePersistentStore:[[storeCoordinator persistentStores] objectAtIndex:0]
													error:outError];
			
		}
		
		if ( [[storeCoordinator persistentStores] count] < 1 ) 
		{ 
			// this is our first save so we just set the persistentStore and save normally
			BOOL didConfigure = [self configurePersistentStoreCoordinatorForURL:inURL // not newSaveURL as configurePSC needs to be consistent
																		 ofType:[KTDocument defaultStoreType]
															 modelConfiguration:nil
																   storeOptions:nil
																		  error:outError];
			
			NSPersistentStoreCoordinator *coord = [[self managedObjectContext] persistentStoreCoordinator];
			id newStore = [coord persistentStoreForURL:newSaveURL];
			if ( !newStore || !didConfigure )
			{
				NSLog(@"error: unable to create document: %@", [*outError description]);
			}
			else
			{
				(void)[self setMetadataForStoreAtURL:newSaveURL];
			}
		} 
		else if (inSaveOperation == NSSaveAsOperation)
		{
			result = [self migrateToURL:inURL ofType:inType error:outError];
			if (!result) {
				return result;
			}
		}
		
		if ( [self isClosing] )
		{
			// grab any last edits
			[[[self windowController] webViewController] commitEditing];
			[managedObjectContext processPendingChanges];
			
			// remembering and collecting should not be undoable
			[[managedObjectContext undoManager] disableUndoRegistration];

								
			// remember important things that we don't usually update
			[self rememberDocumentDisplayProperties];
			
			// collect garbage
			if ([self upateMediaStorageAtNextSave])
			{
				[[self mediaManager] resetMediaFileStorage];
			}
			[[self mediaManager] garbageCollect];
			
			// force context to record all changes before saving
			[managedObjectContext processPendingChanges];
			[[managedObjectContext undoManager] enableUndoRegistration];
		}
		
		
		// Write out the last QuickLook thumbnail
		if (myQuickLookthumbnailPNGData)
		{
			[myQuickLookthumbnailPNGData writeToFile:
			 [[[KTDocument quickLookURLForDocumentURL:inURL] path] stringByAppendingPathComponent:@"Thumbnail.png"]
										  atomically:NO];
		}
		
		
		// Store QuickLook preview
		KTHTMLParser *parser = [[KTHTMLParser alloc] initWithPage:[self root]];
		[parser setHTMLGenerationPurpose:kGeneratingQuickLookPreview];
		NSString *previewHTML = [parser parseTemplate];
		[parser release];
		
		NSString *previewPath =
			[[[KTDocument quickLookURLForDocumentURL:inURL] path] stringByAppendingPathComponent:@"preview.html"];
		[previewHTML writeToFile:previewPath atomically:NO encoding:NSUTF8StringEncoding error:NULL];
		
		
		// we very temporarily keep a weak pointer to ourselves as lastSavedDocument
		// so that saveDocumentAs: can find us again until the new context is fully ready
		// FIXME: is keeping this weak ref still necessary for save as?
		[[KTDocumentController sharedDocumentController] setLastSavedDocument:self];
		result = [managedObjectContext save:outError];
		if (result) result = [[[self mediaManager] managedObjectContext] save:outError];
		[[KTDocumentController sharedDocumentController] setLastSavedDocument:nil];
		
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
	@finally
	{
		if ( ![self isClosing] )
		{
			// CRITICAL: now, set flag to turn on model property inheritance during normal operation
			[self setSaving:NO]; // Make SURE this is reset (so that inherited properties work again)
		}
		else
		{
			[mySaveLock unlock]; // don't resume autosave, but we do have to break the lock
		}
	}
	
	
	return result;
}

/*	We override the behavior to save directly ('unsafely' I suppose!) to the URL,
 *	rather than via a temporary file as is the default.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	// Write to the new URL
	BOOL result = [self writeToURL:absoluteURL
							ofType:typeName
				  forSaveOperation:saveOperation
			   originalContentsURL:[self fileURL]
							 error:outError];
	
	return result;
}

- (void)rememberDocumentDisplayProperties
{
	// Selected pages
	NSIndexSet *outlineSelectedRowIndexSet = [[[(KTDocWindowController *)[self windowController] siteOutlineController] siteOutline] selectedRowIndexes];
	NSIndexSet *storedIndexSet = [self lastSelectedRows];
	
	if ( ![storedIndexSet isEqualToIndexSet:outlineSelectedRowIndexSet] )
	{
		[self setLastSelectedRows:outlineSelectedRowIndexSet];	
	}	
	
	
	// Source Outline width
	float width = [[[[self windowController] siteOutlineSplitView] subviewAtPosition:0] dimension];
	[[self documentInfo] setInteger:width forKey:@"sourceOutlineSize"];
	
	
	// Icon size
	[[self documentInfo] setPrimitiveValue:[NSNumber numberWithBool:[self displaySmallPageIcons]]
									forKey:@"displaySmallPageIcons"];
	
	
	// Window size
	BOOL saveContentRect = NO;
	NSRect currentContentRect = NSZeroRect;
	NSRect storedContentRect = [self documentWindowContentRect];
	NSWindow *window = [[self windowController] window];
	if ( nil != window )
	{
		NSRect frame = [window frame];
		currentContentRect = [window contentRectForFrameRect:frame];
		if ( !NSEqualRects(currentContentRect, NSZeroRect) )
		{
			if ( !NSEqualRects(currentContentRect, storedContentRect) )
			{
				saveContentRect = YES;
			}
		}
	}
	
	if (saveContentRect)	// store content rect, if needed
	{
		[[self documentInfo] setValue:NSStringFromRect(currentContentRect) forKey:@"documentWindowContentRect"];
	}
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
	
	[self setMetadataForStoreAtURL:storeURL];
	
	
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
		[mySaveLock lock];
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
		[mySaveLock unlock];
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
