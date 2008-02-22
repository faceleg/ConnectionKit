//
//  KTDocument+CoreData.m
//  Marvel
//
//  Created by Terrence Talbot on 4/22/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDocument.h"

#import "Debug.h"

#import "KT.h"
#import "KTAppDelegate.h"
#import "KTBundleManager.h"

#import "KTDocSiteOutlineController.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTDocumentController.h"
#import "KTMediaManager+Internal.h"
#import "KTDocumentInfo.h"
#import "KTPersistentStoreCoordinator.h"
#import "KTHTMLParser.h"
#import "KTManagedObjectContext.h"
#import "KTAbstractElement.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "KTPage.h"
#import "NSBundle+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSWorkspace+Karelia.h"
#import "NSMutableSet+Karelia.h"
#import "NSString+Karelia.h"
#import "NSApplication+Karelia.h"
#import "KTAbstractPluginDelegate.h"

#import "Registration.h"

#import <iMediaBrowser/RBSplitView.h>


// TODO: change these into defaults
#define FIRST_AUTOSAVE_DELAY 3
#define SECOND_AUTOSAVE_DELAY 60


@interface KTDocument ( CoreDataPrivate )
- (void)logManagedObjectsInSet:(NSSet *)managedObjects;

- (BOOL)backup;
- (BOOL)migrateToURL:(NSURL *)URL ofType:(NSString *)typeName error:(NSError **)outError;

- (void)rememberDocumentDisplayProperties;
@end


@implementation KTDocument ( CoreData )

#pragma mark context

- (NSManagedObjectContext *)managedObjectContext
{
	if ( nil == myManagedObjectContext )
	{
		//LOGMETHOD;
		
		// set up KTManagedObjectContext as our context
		myManagedObjectContext = [[KTManagedObjectContext alloc] init];
		
		// ALWAYS set merge policy of context to "on-disk trumps in-memory"
		// TODO: is setting this policy necessary or proper if we have only one context?
		//[myManagedObjectContext setMergePolicy:NSMergeByPropertyStoreTrumpMergePolicy];
		
		NSManagedObjectModel *model = [self managedObjectModel];
		KTPersistentStoreCoordinator *psc = [[KTPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
		[myManagedObjectContext setPersistentStoreCoordinator:psc];
		[psc release];
	}
	
	NSAssert((nil != myManagedObjectContext), @"myManagedObjectContext should not be nil");
	
	return (NSManagedObjectContext *)myManagedObjectContext;
}

#pragma mark model

- (NSManagedObjectModel *)managedObjectModel
{
	if ( nil == myManagedObjectModel )
	{
		//LOGMETHOD;
		
		// TODO: move to using Sandvox.mom before shipping 1.5
		// grab only Sandvox.mom (ignoring "previous moms" in KTComponents/Resources)
		NSBundle *componentsBundle = [NSBundle bundleForClass:[KTAbstractElement class]];
        if ( nil != componentsBundle )
        {
            NSURL *modelURL = [NSURL fileURLWithPath:[componentsBundle pathForResource:@"Sandvox" ofType:@"mom"]];
            if ( nil != modelURL )
            {
                myManagedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
            }
        }
	}
	
	NSAssert((nil != myManagedObjectModel), @"myManagedObjectModel should not be nil");
	
	return myManagedObjectModel;
}

#pragma mark store coordinator

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url 
										   ofType:(NSString *)fileType 
							   modelConfiguration:(NSString *)configuration 
									 storeOptions:(NSDictionary *)storeOptions 
											error:(NSError **)error
{
	//LOGMETHOD;
	
    // NB: called whenever a document is opened *and* when a document is first saved
    // so, because of the order of operations, we have to store metadata here, too
	
	/// and we compute the sqlite URL here for both read and write
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:url];
	
	// these two lines basically take the place of sending [super configurePersistentStoreCoordinatorForURL:ofType:error:]
	// NB: we're not going to use the supplied configuration or options here, though we could in a Leopard-only version
	NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
	id theStore = [psc addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType] 
									configuration:nil 
											  URL:storeURL
										  options:nil 
										 error:error];
	
	// Also configure media manager's store
	NSPersistentStoreCoordinator *mediaPSC = [[[self mediaManager] managedObjectContext] persistentStoreCoordinator];
	[mediaPSC addPersistentStoreWithType:NSXMLStoreType
					       configuration:nil
									 URL:[KTDocument mediaStoreURLForDocumentURL:url]
								 options:nil
								   error:error];
	
	
	
	BOOL result = (nil != theStore);
	if ( result )
    {
        // handle datastore open, grab documentInfo and root
        if ( nil == [self documentInfo] )
        {
			// fetch and set documentInfo
            KTDocumentInfo *documentInfo = [[self managedObjectContext] documentInfo];
            if ( (nil != documentInfo) && [documentInfo isKindOfClass:[KTDocumentInfo class]] )
            {
                [self setDocumentInfo:documentInfo];
                result = YES;
            }
            else
            {
                result = NO;
            }
            
			// if we're good, fetch and set root and root's document
			if ( result )
			{
				KTPage *root = [[self managedObjectContext] root];
				if ( (nil != root) && [root isKindOfClass:[KTPage class]] )
				{
					[self setRoot:root];
					[root setDocument:self];
					result = YES;
				}
				else
				{
					result = NO;
				}
			}
            
            // if we're good, make sure all our required bundles have been loaded
            if ( result )
            {
                NSEnumerator *e = [[self requiredBundlesIdentifiers] objectEnumerator];
                NSString *bundleIdentifier;
                while ( bundleIdentifier  = [e nextObject] )
                {
                    NSBundle *bundle = [[[[KTAppDelegate sharedInstance] bundleManager] pluginWithIdentifier:bundleIdentifier] bundle];
                    if ( nil != bundle )
                    {
                        // NB: bundles without delegates may not have a principal class
                        if ( Nil != [NSBundle principalClassForBundle:bundle] )
                        {
                            [bundle load];
                        }
                    }
                    else
                    {
                        NSLog(@"unable to locate required plugin: %@", bundleIdentifier);
                    }
                }
            }
        }
        // document is being saved for the first time
        else
        {
            // set and save metadata (writeToURL: *will* grab these changes)
//            (void)[self setMetadataForStoreAtURL:storeURL];
        }
    }
	
	return result;
}

#pragma mark -
#pragma mark Saves

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

- (IBAction)saveDocument:(id)sender
{
	//LOGMETHOD;
	// because context changes will be processed before writeToURL:::::, set flag here, too
	[self setSaving:YES];
	[super saveDocument:sender]; // ultimately calls writeToURL:::::, below
	[self setSaving:NO];
}

// called when creating a new document and when performing saveDocumentAs:
- (BOOL)writeToURL:(NSURL *)inURL ofType:(NSString *)inType forSaveOperation:(NSSaveOperationType)inSaveOperation originalContentsURL:(NSURL *)inOriginalContentsURL error:(NSError **)outError 
{
	//LOGMETHOD;
	//LOG((@"-writeToURL: %@ ofType: %@ forSaveOperation: %d originalContentsURL: %@", inURL, inType, inSaveOperation, inOriginalContentsURL));
	NSAssert([NSThread isMainThread], @"should be called only from the main thread");

	BOOL result = NO;
	
	// REGISTRATION -- be annoying if it looks like the registration code was bypassed
	if ( ((0 == gRegistrationWasChecked) && random() < (LONG_MAX / 10) ) )
	{
		result = NO; // explicitly fail to save document
		
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
	}
	else
	{
		// TODO: add in code to do a backup or snapshot, see KTDocument+Deprecated.m
		
		@synchronized ( self ) // right now, we don't want to do anything but write out this file
		{
			// CRITICAL: set flag to turn off model property inheritance (among other things) while saving
			[self setSaving:YES];
			
			NSManagedObjectContext *managedObjectContext = [self managedObjectContext];
			NSPersistentStoreCoordinator *storeCoordinator = [managedObjectContext persistentStoreCoordinator];
			
			// if we haven't been saved before, create document wrapper paths on disk before we do anything else
			if ( NSSaveAsOperation == inSaveOperation )
			{
				[[NSFileManager defaultManager] createDirectoryAtPath:[inURL path] attributes:nil];
				[[NSWorkspace sharedWorkspace] setBundleBit:YES forFile:[inURL path]];
				
				[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument siteURLForDocumentURL:inURL] path] attributes:nil];
				[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument mediaURLForDocumentURL:inURL] path] attributes:nil];
				[[NSFileManager defaultManager] createDirectoryAtPath:[[KTDocument quickLookURLForDocumentURL:inURL] path] attributes:nil];
			}
			
			// we really want to write to a URL inside the wrapper, so compute the real URL
			NSURL *newSaveURL = [KTDocument datastoreURLForDocumentURL:inURL];
			@try 
			{
				
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
				
				if ( result )
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
		}
	}
	
	return result;
}

/*	We override the "Save As" behavior to save directly ('unsafely' I suppose!) to the URL,
 *	rather than via a temporary file as is the default.
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError
{
	if (saveOperation != NSSaveAsOperation)
	{
		return [super writeSafelyToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
	}
	
	
	// Write to the new URL
	BOOL result = [self writeToURL:absoluteURL
							ofType:typeName
				  forSaveOperation:saveOperation
			   originalContentsURL:[self fileURL]
							 error:outError];
	
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
#pragma mark context notifications

- (void)contextDidChange:(NSNotification *)aNotification
{
	//LOGMETHOD;
	
	// if the context changes, we want to kick off the autosave timer
	// if it keeps changing, we want to reset the timer
	// except that we can't let it go too long
	// what do we do about that?
	// right now, this is the only place where we are starting the timers
	
	if ( (nil != [self fileURL]) && ![self isSaving] )
	{
		// if we have a place to save, then we can autosave
		[self restartAutosaveTimersIfNecessary];
	}
	
	// NB: calling saveContext: from this method results in infinite loop, by design, so DON'T DO IT
	KTManagedObjectContext *context = [aNotification object];
	
	// if we remove a page, we need to remove our observing and retaining of it
	
	
//	NSSet *changedObjects = [context changedObjects];
//	
//	// special case a change only to richTextHTML
//	if ( [context isEqual:[self managedObjectContext]] )
//	{
//		if ( [NSThread isMainThread] && [self isOnlyRichTextChange:changedObjects] )
//		{
//			[self restartAutosaveTimersIfNecessary];
//			return;
//		}
//	}
		
	// log changes if set in Debug menu
	if ( [[KTAppDelegate sharedInstance] logAllContextChanges] )
	{		
		NSLog(@"================== contextDidChange: ==================");		
		if ( [NSThread isMainThread] )
		{
			if ( [context isEqual:[self managedObjectContext]] )
			{
				NSLog(@"============== main thread, main context ==============");
			}
			else
			{
				NSLog(@"============== main thread, context %p ", context);
			}
		}
		else
		{
			if ( [context isEqual:[self managedObjectContext]] )
			{
				NSLog(@"============== thread %p, main context =========", [NSThread currentThread]);
			}
			else
			{
				NSLog(@"============== thread %p, context %p ", [NSThread currentThread], context);
			}
		}

		NSDictionary *userInfo = [aNotification userInfo];
		if ( nil != [userInfo valueForKey:NSInsertedObjectsKey] )
		{
			NSSet *insertedObjects = [userInfo valueForKey:NSInsertedObjectsKey];
			NSLog(@"** inserted objects:");
			[self logManagedObjectsInSet:insertedObjects];
		}
		if ( nil != [userInfo valueForKey:NSUpdatedObjectsKey] )
		{
			NSSet *updatedObjects = [userInfo valueForKey:NSUpdatedObjectsKey];
			NSLog(@"** updated objects:");
			[self logManagedObjectsInSet:updatedObjects];
		}
		if ( nil != [userInfo valueForKey:NSDeletedObjectsKey] )
		{
			NSSet *deletedObjects = [userInfo valueForKey:NSDeletedObjectsKey];
			NSLog(@"** deleted objects:");
			[self logManagedObjectsInSet:deletedObjects];
		}
		NSLog(@"=======================================================");
	}
}

- (void)contextDidSave:(id)aNotification
{
	// this method used to sync all peer contexts with fresh data after a save
}

#pragma mark autosave


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

- (void)processPendingChangesAndClearChangeCount
{
	//LOGMETHOD;

	[[self managedObjectContext] processPendingChanges];
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
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

#pragma mark backup

- (BOOL)backup
{
	BOOL result = NO;
	
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *originalPath = [[self fileURL] path];
	NSString *backupPath = [self backupPathForOriginalPath:originalPath];
	
	if ( (nil != originalPath) && [fm fileExistsAtPath:originalPath] )
	{
		result = [self backupPath:originalPath toPath:backupPath];
	}
	
	return result;
}

- (NSString *)backupPathForOriginalPath:(NSString *)aPath
{
	NSString *result = nil;
	
	if ( nil != aPath )
	{
		NSString *originalPath = [[aPath copy] autorelease];
		NSString *originalPathWithoutFileName = [originalPath stringByDeletingLastPathComponent];
		
		NSString *fileName = [[originalPath lastPathComponent] stringByDeletingPathExtension];
		NSString *fileExtension = [originalPath pathExtension];
		
		NSString *backupFileName = NSLocalizedString(@"Backup of ", "Prefix for backup copy of document");
		backupFileName = [backupFileName stringByAppendingString:fileName];
		backupFileName = [backupFileName stringByAppendingPathExtension:fileExtension];
		
		// commenting this out for another day 20061213 -- currently can cause crash after hitting OK
//		NSString *testPath = [originalPathWithoutFileName stringByAppendingPathComponent:backupFileName];
//		testPath = [testPath stringByAppendingPathExtension:fileExtension];
//		
//		unsigned int maxNumberOfBackups = [[NSUserDefaults standardUserDefaults] integerForKey:@"KeepAtMostNBackups"];
//		
//		NSFileManager *fm = [NSFileManager defaultManager];
//		if ( [fm fileExistsAtPath:testPath] )
//		{
//			// append a monotonically increasing digit until we find an available path ;-)
//			// e.g., <fileName>-1.<fileExtension> <fileName>-2.<fileExtension> <fileName>-3.<fileExtension> ...
//			unsigned int i = 1;
//			BOOL foundAvailablePath = NO;
//			while ( !foundAvailablePath )
//			{
//				// bail if we can't find a path after a number of tries
//				if ( i > maxNumberOfBackups )
//				{
//					foundAvailablePath = YES;
//					testPath = nil;
//					
//					NSDictionary *infoDictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//						NSLocalizedString(@"Maximum number of backups exceeded.", "alert title: max number of backups exceeded"), @"messageText", 
//						NSLocalizedString(@"Consider removing backups no longer needed, or send feedback to Karelia suggesting an increase in the maximum number of backups allowed.", "alert text: advice when maximum number of backups exceeded"), @"informativeText", 
//						nil];
//					[self performSelector:@selector(delayedAlertSheetWithInfo:)
//							   withObject:infoDictionary
//							   afterDelay:1.0];					
//					break;
//				}
//				
//				NSString *backupFileNameWithSuffix = [NSString stringWithFormat:@"%@-%u", backupFileName, i];
//				testPath = [originalPathWithoutFileName stringByAppendingPathComponent:backupFileNameWithSuffix];
//				testPath = [testPath stringByAppendingPathExtension:fileExtension];
//				
//				if ( ![fm fileExistsAtPath:testPath] )
//				{
//					foundAvailablePath = YES;
//				}
//				
//				i++;
//			}
//		}
		
//		result = [[testPath copy] autorelease];
		result = [originalPathWithoutFileName stringByAppendingPathComponent:backupFileName];
	}
	
	return result;
}

- (BOOL)backupPath:(NSString *)aPath toPath:(NSString *)anotherPath
{
	BOOL result = NO;
	
	@try
	{
		NSFileManager *fm = [NSFileManager defaultManager];
		NSString *originalPath = [[aPath copy] autorelease];
		
		if ( [fm fileExistsAtPath:originalPath] )
		{			
			NSString *backupPath = [[anotherPath copy] autorelease];
			if ( nil != backupPath )
			{
				BOOL okToProceed = YES;

				// delete old backup first
				if ( [fm fileExistsAtPath:backupPath] )
				{
					okToProceed = [fm removeFileAtPath:backupPath handler:self];
				}
				
				if ( okToProceed )
				{
					// grab the date
					NSDate *now = [NSDate date];
					
					// make the backup
					result = [fm copyPath:originalPath toPath:backupPath handler:self];
					
					// update the creation/lastModification times to now
					//  what key is "Last opened" that we see in Finder?
					//  until we know that, only update mod time
					NSDictionary *dateInfo = [NSDictionary dictionaryWithObjectsAndKeys:
						//now, NSFileCreationDate,
						now, NSFileModificationDate,
						nil];
					(void)[fm changeFileAttributes:dateInfo atPath:backupPath];
				}
			}
		}
	}
    @catch (NSException *exception)
    {
        NSLog(@"error: document backup caught exception! name:%@ reason:%@", [exception name], [exception reason]);
    }
	
	return result;
}

#pragma mark snapshot

- (void)snapshotPersistentStore:(id)notUsedButRequiredParameter
{	
	// perform file operations using Workspace
	NSArray *files = nil;
	int tag = 0;
	
	// recycle current snapshot
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *snapshotPath = [self snapshotPath];
	if ( [fm fileExistsAtPath:snapshotPath] )
	{
		files = [NSArray arrayWithObject:[snapshotPath lastPathComponent]];
		BOOL didMoveOldSnapshotToTrash = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation 
																					  source:[self snapshotDirectory]
																				 destination:nil
																					   files:files 
																						 tag:&tag];
		if ( !didMoveOldSnapshotToTrash )
		{
			NSString *snapshotPathAsDisplayPath = [[snapshotPath stringByAbbreviatingWithTildeInPath] stringBySubstitutingRightArrowForPathSeparator];
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Snaphot Failed", "alert: snapshot failed")
											 defaultButton:NSLocalizedString(@"OK", "OK Button")
										   alternateButton:nil 
											   otherButton:nil 
								 informativeTextWithFormat:NSLocalizedString(@"Sandvox was unable to move this document's previous snapshot to the Trash. Please remove the document at %@.",
																			 "alert: could not remove prior snap"), snapshotPathAsDisplayPath];
			
			[alert beginSheetModalForWindow:[[self windowController] window] 
							  modalDelegate:self 
							 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) 
								contextInfo:[[NSDictionary dictionaryWithObject:@"!didMoveOldSnapshotToTrash"
																		 forKey:@"context"] retain]];
			
			return;
		}
	}
	else
	{
		// create snapshot directory, if necessary
		[self createSnapshotDirectoryIfNecessary];
	}
	
	// save all contexts
	//if ( [self hasUnsavedChanges] )
	if ( [[self managedObjectContext] hasChanges] )
	{
		[self autosaveDocument:nil];
	}
	
	// suspend saving
	[self suspendAutosave];	
	
	// copy file to snapshotPath
	NSString *filePath = [[self fileURL] path];
	NSString *destPath = [[self snapshotDirectory] stringByAppendingPathComponent:[filePath lastPathComponent]];
	BOOL didSnapshot = [[NSFileManager defaultManager] copyPath:filePath toPath:destPath handler:self];

	
	// OLD WAY -- PROBLEMATIC
//	files = [NSArray arrayWithObject:[filePath lastPathComponent]];
//	BOOL didSnapshot = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceCopyOperation 
//																	source:[filePath stringByDeletingLastPathComponent]
//															   destination:[self snapshotDirectory]
//																	 files:files 
//																	   tag:&tag];
	// resume saving
	[self resumeAutosave];

	if ( !didSnapshot )
	{
		NSString *snapshotsDirectory = [[self snapshotDirectory] stringByDeletingLastPathComponent];
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Snaphot Failed", "alert: snapshot failed")
										 defaultButton:NSLocalizedString(@"OK", "OK Button")
									   alternateButton:nil 
										   otherButton:nil 
							 informativeTextWithFormat:NSLocalizedString(@"Sandvox was unable to create a snapshot of this document. Please check that the folder %@ exists and is writeable.",
																		 "alert: could not remove prior snap"), [snapshotsDirectory stringByAbbreviatingWithTildeInPath]];
		
		[alert beginSheetModalForWindow:[[self windowController] window] 
						  modalDelegate:self 
						 didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) 
							contextInfo:[[NSDictionary dictionaryWithObject:@"!didSnapshot"
																	 forKey:@"context"] retain]];
		
		return;
	}
}

- (void)revertPersistentStoreToSnapshot:(id)notUsedButRequiredParameter
{
	if ( [[NSFileManager defaultManager] fileExistsAtPath:[self snapshotPath]] )
	{
		// save document so no changes need to be dealt with...
		[self autosaveDocument:nil];
		
		// message app delegate to take it from here
		[[NSApp delegate] revertDocument:self toSnapshot:[self snapshotPath]];
	}
	else
	{
		NSLog(@"error: cannot revert to snapshot %@ , file does not exist!", [self snapshotPath]);
	}
}


- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo
{
	LOG((@"File manager error - really an error? %@", [[errorInfo description] condenseWhiteSpace]));
	return YES;	// always proceed
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path
{
}

#pragma mark metadata

/*! setMetadataForStoreAtURL: sets all metadata for the store all at once */
- (BOOL)setMetadataForStoreAtURL:(NSURL *)aStoreURL
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
			
			// set ALL of our metadata for this store
			//  kKTMetadataSiteTitleKey
			NSString *siteTitle = [[[self root] master] valueForKey:@"siteTitleHTML"];        
			if ( (nil == siteTitle) || [siteTitle isEqualToString:@""] )
			{
				[metadata removeObjectForKey:kKTMetadataSiteTitleKey];
			}
			else
			{
				[metadata setObject:[siteTitle flattenHTML] forKey:kKTMetadataSiteTitleKey];
			}
			
			//  kKTMetadataModelVersionKey
			[metadata setObject:kKTModelVersion forKey:kKTMetadataModelVersionKey];
				
			//  kKTMetadataSiteAuthorKey and kMDItemAuthors
			NSString *author = [[[self root] master] valueForKey:@"author"];
			if ( (nil == author) || [author isEqualToString:@""] )
			{
				[metadata removeObjectForKey:kKTMetadataSiteAuthorKey];
				[metadata removeObjectForKey:(NSString *)kMDItemAuthors];
			}
			else
			{
				[metadata setObject:author forKey:kKTMetadataSiteAuthorKey];
				[metadata setObject:author forKey:(NSString *)kMDItemAuthors];
			}
			
			//  kKTMetadataAppVersionKey (internal build number)
			NSBundle *bundle = [NSBundle mainBundle];
			[metadata setObject:[[bundle infoDictionary] valueForKey:@"CFBundleVersion"] forKey:kKTMetadataAppVersionKey];
							
			//  kMDItemCreator (Sandvox is the creator of this site document)
			[metadata setObject:[NSApplication applicationName] forKey:(NSString *)kMDItemCreator];
			
			/// we're going to fault every page, use a local pool to release them quickly
			NSAutoreleasePool *localPool = [[NSAutoreleasePool alloc] init];
			
			//  kKTMetadataPageCountKey and kMDItemNumberOfPages
			NSArray *pages = [[self managedObjectContext] allObjectsWithEntityName:@"Page" error:NULL];
			unsigned int pageCount = 0;
			if ( nil != pages )
			{
				pageCount = [pages count]; // according to mmalc, this is the only way to get this kind of count
			}
			[metadata setObject:[NSNumber numberWithUnsignedInt:pageCount] forKey:kKTMetadataPageCountKey];
			[metadata setObject:[NSNumber numberWithUnsignedInt:pageCount] forKey:(NSString *)kMDItemNumberOfPages];
			
			//  kMDItemDescription (free-text account of content)
			//  for now, we'll make this site subtitle, plus all unique page titles, plus spotlightHTML
			NSString *subtitle = [[[self root] master] valueForKey:@"siteSubtitleHTML"];
			if ( nil == subtitle )
			{
				subtitle = @"";
			}
			subtitle = [subtitle flattenHTML];
			
			// add unique page titles
			NSMutableString *itemDescription = [NSMutableString stringWithString:subtitle];
			NSArray *pageTitles = [[self managedObjectContext] objectsForColumnName:@"titleHTML" entityName:@"Page"];
			unsigned int i;
			for ( i=0; i<[pageTitles count]; i++ )
			{
				NSString *pageTitle = [pageTitles objectAtIndex:i];
				pageTitle = [pageTitle flattenHTML];
				if ( nil != pageTitle )
				{
					[itemDescription appendFormat:@" %@", pageTitle];
				}
			}
						
			// spotlightHTML as part of itemDescription
			for ( i=0; i<[pages count]; i++ )
			{
				KTPage *page = [pages objectAtIndex:i];
				NSString *spotlightText = [page spotlightHTML];
				if ( (nil != spotlightText) && ![spotlightText isEqualToString:@""] )
				{
					spotlightText = [spotlightText flattenHTML];
					[itemDescription appendFormat:@" %@", spotlightText];
				}
			}
			[metadata setObject:itemDescription forKey:(NSString *)kMDItemDescription];
			
			
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
			
			// replace the metadata in the store with our updates
			// NB: changes to metadata through this method are not pushed to disk until the document is saved
			[coordinator setMetadata:metadata forPersistentStore:theStore];
			
			result = YES;
		}
	}
	@catch (NSException * e)
	{
		NSLog(@"error: unable to setMetadataForStoreAtURL:%@ exception: %@:%@", [aStoreURL path], [e name], [e reason]);
	}
	
	return result; // currently no caller relies on the return value of this method
}

#pragma mark document support

- (NSString *)defaultStoreType
{
	// options are NSSQLiteStoreType, NSXMLStoreType, NSBinaryStoreType, or NSInMemoryStoreType
	// also, be sure to set (and match) Store Type in application target properties
	return NSSQLiteStoreType;
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
	// we want to limit the store type to only the default
	// otherwise Cocoa will put up an accessory view in the save panel
	return [self defaultStoreType];
}

- (NSArray *)writableTypesForSaveOperation:(NSSaveOperationType)saveOperation
{
	// we restrict writableTypes to our main document type
	// so that the persistence framework does not allow the user to pick
	// a persistence store format and confuse the app
	return [NSArray arrayWithObject:@"KTDocument"];
}

- (BOOL)keepBackupFile
{
	// we tie this standard NSDocument method to a user default
	return [[NSUserDefaults standardUserDefaults] boolForKey:@"CreateBackupFileWhenSaving"];
}

- (BOOL)isSaving
{
    return myIsSaving;
}

- (void)setSaving:(BOOL)flag
{
    myIsSaving = flag;
}

#pragma mark managed object support

// exception handling
- (void)resetUndoManager
{
	// something got screwed up in undo and we're being messaged to fix it
	[[self undoManager] removeAllActions];
}

#pragma mark debug

- (void)logManagedObjectsInSet:(NSSet *)managedObjects
{
	NSEnumerator *e = [[managedObjects allObjects] objectEnumerator];
	NSManagedObject *managedObject = nil;
	while ( managedObject = [e nextObject] )
	{
		NSLog(@"%@", [managedObject managedObjectDescription]);
		//NSLog(@"DESCRIPTION: %@", [managedObject managedObjectDescription]);
		//NSLog(@"CHANGED VALUES: %@", [[managedObject changedValues] allKeys]);
	}
}

- (void)observeNotificationsForContext:(KTManagedObjectContext *)aManagedObjectContext
{
	//LOG((@"document registering for context change, MOC = %@ thread = %p", aManagedObjectContext, [NSThread currentThread]));
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(contextDidChange:)
												 name:NSManagedObjectContextObjectsDidChangeNotification
											   object:aManagedObjectContext];
	
//	[[NSNotificationCenter defaultCenter] addObserver:self
//											 selector:@selector(contextDidSave:)
//												 name:NSManagedObjectContextDidSaveNotification
//											   object:aManagedObjectContext];			
}

- (void)removeObserversForContext:(KTManagedObjectContext *)aManagedObjectContext
{
	//LOG((@"document UN-reg for context change, MOC = %@ thread = %p", aManagedObjectContext, [NSThread currentThread]));
	[[NSNotificationCenter defaultCenter] removeObserver:self
													name:NSManagedObjectContextObjectsDidChangeNotification
												  object:aManagedObjectContext];
//	[[NSNotificationCenter defaultCenter] removeObserver:self
//													name:NSManagedObjectContextDidSaveNotification
//												  object:aManagedObjectContext];
}

#pragma mark -
#pragma mark Publishing/export pagelet cache

/*	We maintain a cache of the inherited sidebar pagelets for each page when exporting a site
 *	since these methods will be called many times upon collection pages.
 *	The cache is in the document, not the individual pages, so we can easily clear it after
 *	publishing.
 */

- (NSArray *)cachedAllInheritableTopSidebarsForPage:(KTPage *)page
{
	NSString *pageID = [page uniqueID];
	
	// Cache the value if we haven't already done so
	NSArray *result = [myTopSidebarsCache objectForKey:pageID];
	if (!result) {
		result = [page _allInheritableTopSidebars];
		[myTopSidebarsCache setValue:result forKey:pageID];
	}
	
	return result;
}

- (NSArray *)cachedAllInheritableBottomSidebarsForPage:(KTPage *)page
{
	NSString *pageID = [page uniqueID];
	
	// Cache the value if we haven't already done so
	NSArray *result = [myBottomSidebarsCache objectForKey:pageID];
	if (!result) {
		result = [page _allInheritableBottomSidebars];
		[myBottomSidebarsCache setValue:result forKey:pageID];
	}
	
	return result;
}

- (void)clearInheritedSidebarsCaches
{
	[myTopSidebarsCache removeAllObjects];
	[myBottomSidebarsCache removeAllObjects];
}

@end
