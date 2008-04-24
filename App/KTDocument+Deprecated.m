//
//  KTDocument+Deprecated.m
//  Marvel
//
//  Created by Mike on 08/11/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import "KTDocument.h"

#import "KTDocWindowController.h"
#import "KTMediaManager+Internal.h"


@implementation KTDocument (Deprecated)

- (void)contextDidSave:(id)aNotification
{	
	//	// NB: this is the workhorse for making sure that all contexts have fresh data
	//	KTManagedObjectContext *context = [aNotification object];
	//
	//	DEBUG_ONLY(
	//	if ( [context isEqual:[self managedObjectContext]] )
	//	{
	//		OFF((@"contextDidSave: %@ (document's context)", context));
	//	}
	//	else
	//	{
	//		OFF((@"contextDidSave: %@", context));
	//	});
	//	
	//	// we only merge changes here when kGeneratingPreview
	//	// KTTransferController has its own logic for keeping contexts in sync
	//	if ( kGeneratingPreview == [[self windowController] publishingMode] )
	//	{
	//		// if we've saved the main context, turn off timers (contextDidChange: will restart them, as appropriate)
	//		if ( [context isEqual:[self managedObjectContext]] )
	//		{
	//			if ( [NSThread isMainThread] )
	//			{
	//				[self cancelAndInvalidateAutosaveTimers];
	//				[self setLastSavedTime:[NSDate date]];
	//			}
	//			else
	//			{
	//				[self performSelectorOnMainThread:@selector(cancelAndInvalidateAutosaveTimers) 
	//									   withObject:nil
	//									waitUntilDone:NO];
	//				[self performSelectorOnMainThread:@selector(setLastSavedTime:)
	//									   withObject:[NSDate date]
	//									waitUntilDone:NO];
	//			}
	//			
	////			if ( [[[aNotification userInfo] valueForKey:NSDeletedObjectsKey] count] > 0 )
	////			{
	////				// if we have deleted objects in the main context, reset all peers
	////				[self resetAllPeerContexts];
	////				return;
	////			}
	//		}
	//		
	//		if ( ![context isEqual:[self managedObjectContext]]
	//			 || [self hasPeerContextsInFlight] )
	//		{
	//			// refresh in other contexts
	//			NSMutableSet *refreshObjects = [NSMutableSet set];
	//			
	//			//	The userInfo dictionary contains the following keys: NSInsertedObjectsKey, NSUpdatedObjectsKey, and NSDeletedObjectsKey.
	//			NSSet *insertedObjects = [[aNotification userInfo] valueForKey:NSInsertedObjectsKey];
	//			NSSet *updatedObjects = [[aNotification userInfo] valueForKey:NSUpdatedObjectsKey];
	//			NSSet *deletedObjects = [[aNotification userInfo] valueForKey:NSDeletedObjectsKey];
	//			
	//			// make a composite called changedObjects for convenience
	//			NSArray *changedObjects = [NSArray array];
	//			if ( nil != insertedObjects )
	//			{	
	//				changedObjects = [changedObjects arrayByAddingObjectsFromArray:[insertedObjects allObjects]];
	//			}
	//			if ( nil != deletedObjects )
	//			{	
	//				changedObjects = [changedObjects arrayByAddingObjectsFromArray:[deletedObjects allObjects]];
	//			}
	//			if ( nil != updatedObjects )
	//			{	
	//				changedObjects = [changedObjects arrayByAddingObjectsFromArray:[updatedObjects allObjects]];
	//			}
	//			
	//			@try
	//			{
	//				// walk changedObjects and see if we need to add/remove
	//				NSEnumerator *e = [changedObjects objectEnumerator];
	//				KTManagedObject *changedObject;
	//				while ( changedObject = [e nextObject] )
	//				{
	//					// always add changedObject
	//					[refreshObjects addObject:changedObject];
	//					
	//					//	if changedObject is CachedImage, its media object must also be refreshed
	//					if ( [changedObject isKindOfClass:[KTCachedImage class]] && ![changedObject isDeleted] )
	//					{
	//						KTMedia *media = [(KTCachedImage *)changedObject media];
	//						if ( [media isManagedObject] )
	//						{
	//							[refreshObjects addObject:media];
	//						}
	//					}
	//					
	//					//  if changedObject is MediaRef, its media object and its owner must also be refreshed
	//					if ( [changedObject isKindOfClass:[KTMediaRef class]] && ![changedObject isDeleted] )
	//					{
	//						KTMedia *media = [(KTMediaRef *)changedObject media];
	//						if ( [media isManagedObject] )
	//						{
	//							[refreshObjects addObject:media];
	//						}
	//						
	//						KTAbstractElement *owner = [(KTMediaRef *)changedObject valueForKey:@"owner"];
	//						if ( [owner isManagedObject] )
	//						{
	//							[refreshObjects addObject:owner];
	//						}
	//					}
	//					
	//					// what other things?
	//					// do we need to special case deletedObjects?
	//				}
	//				
	//				// grab the objectIDs and refresh in other contexts
	//				NSArray *objectIDs = [self objectIDsWithinArrayOrSet:refreshObjects];
	//				[self refreshObjectsWithObjectIDs:objectIDs inAllContextsExcept:context mergeChanges:YES];				
	//			}
	//			@catch (NSException *exception)
	//			{
	//				NSLog(@"error: contextDidSave caught exception: %@ %@ %@", [exception name], [exception reason], [exception userInfo]);
	//			}
	//		}		
	//	}
}

- (void)savePeerContexts
{
	// NB: since other methods only call this once, we may not be able to rely on contextDidSave:
	// to catch everything -- we may have to loop here until all changes are saved, then mergerd, then saved...
	@synchronized ( myPeerContexts )
	{
		// optimization
		if ( [myPeerContexts count] == 0 )
		{
			return; // no peers to save
		}
				
		// iterate
		NSEnumerator *e = [myPeerContexts objectEnumerator];
		NSManagedObjectContext *context;
		while ( context = [e nextObject] )
		{
			if ( [context hasChanges] )
			{
				[self saveContext:(KTManagedObjectContext *)context];
			}
		}
	}
	
	if ( ![self hasUnsavedChanges] )
	{
		[self updateChangeCount:NSChangeCleared];
	}	
}

- (void)savePeerContextsExcept:(KTManagedObjectContext *)aManagedObjectContext
{
	@synchronized ( myPeerContexts )
	{
		// optimization
		if ( [myPeerContexts count] == 0 )
		{
			return; // no peers to save
		}
				
		// iterate
		NSMutableArray *contexts = [NSMutableArray arrayWithArray:myPeerContexts];
		if ( [contexts containsObject:aManagedObjectContext] )
		{
			[contexts removeObject:aManagedObjectContext];
		}
		NSEnumerator *e = [contexts objectEnumerator];
		NSManagedObjectContext *context;
		while ( context = [e nextObject] )
		{
			if ( [context hasChanges] )
			{
				[self saveContext:(KTManagedObjectContext *)context];
			}
		}
	}
	
	if ( ![self hasUnsavedChanges] )
	{
		[self updateChangeCount:NSChangeCleared];
	}	
}

- (BOOL)hasUnsavedChanges
{
	//optimization
	@synchronized ( myPeerContexts )
	{
		if ( [myPeerContexts count] == 0 )
		{
			return [[self managedObjectContext] hasChanges];
		}
	}
		
	//optimization
	if ( [[self managedObjectContext] hasChanges] )
	{
		return YES;
	}
	
	BOOL result = NO;
	@synchronized ( myPeerContexts )
	{
		if ( [myPeerContexts count] > 0 )
		{
			NSEnumerator *e = [myPeerContexts objectEnumerator];
			NSManagedObjectContext *context;
			while ( context = [e nextObject] )
			{
				if ( [context hasChanges] )
				{
					result = YES;
					break;
				}
			}
		}
	}
	
	return result;
}

- (NSArray *)allContexts
{
	NSMutableArray *array = [NSMutableArray arrayWithObject:[self managedObjectContext]];
	
	@synchronized ( myPeerContexts )
	{
		if ( [myPeerContexts count] > 0 )
		{
			[array addObjectsFromArray:myPeerContexts];
		}
	}
	return [NSArray arrayWithArray:array];
}

- (KTManagedObjectContext *)createPeerContext
{	
	if ( ![self suspendSavesDuringPeerCreation] )
	{
//		NSEnumerator *e = [[self allContexts] objectEnumerator];
//		KTManagedObjectContext *context;
//		while ( context = [e nextObject] )
//		{
//			if ( [context hasChanges] )
//			{
//				//			if ( ![[self windowController] isAddingPagesViaDrag]
//				//				 && ![self contextChangesAreOnlyMediaOrCachedImages:context] )
//				//			{
//				[self saveContext:context];
//				//			}
//			}
//		}
		
		// what if all we save is the main context and only if it has Media MediaRef or CachedImages?
		KTManagedObjectContext *mainContext = (KTManagedObjectContext *)[self managedObjectContext];
		if ( [mainContext hasChanges] )
		{
			BOOL shouldSave = NO;
			
			NSEnumerator *e = [[mainContext changedObjects] objectEnumerator];
			KTManagedObject *object;
			while ( object = [e nextObject] )
			{
				if ( [object isKindOfClass:[KTMedia class]] 
					 || [object isKindOfClass:[KTMediaRef class]]
					 || [object isKindOfClass:[KTCachedImage class]] )
				{
					shouldSave = YES;
					break;
				}
			}
			
			if ( shouldSave )
			{
				if ( [NSThread isMainThread] )
				{
					[self saveContext:mainContext];
				}
				else
				{
					[self performSelectorOnMainThread:@selector(saveContext:) withObject: mainContext waitUntilDone:YES];
				}
				
			}
		}
	}
	
	KTManagedObjectContext *peerContext = [[KTManagedObjectContext alloc] init];
	[peerContext setPersistentStoreCoordinator:[[self managedObjectContext] persistentStoreCoordinator]];
	[peerContext setUndoManager:nil];
	[peerContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy]; // in-memory trumps on-disk
	
	// add to peer contexts array
	@synchronized ( myPeerContexts )
	{
		[myPeerContexts addObject:peerContext]; // this should retain peerContext until we releasePeerContext:
	}
	
	// add observers
	[self observeNotificationsForContext:peerContext];
	
	[peerContext release];
	
	OBASSERTSTRING((nil != peerContext), @"peerContext should still be retained by myPeerContexts");
	
	return peerContext;
}

- (BOOL)contextChangesAreOnlyCachedImages:(KTManagedObjectContext *)aContext
{
	BOOL result = YES;
	
	[aContext lockPSCAndSelf];
	
	NSEnumerator *e = [[aContext changedObjects] objectEnumerator];
	KTManagedObject *object;
	while ( object = [e nextObject] )
	{
		if ( ![[[object entity] name] isEqualToString:@"CachedImage"] )
		{
			result = NO;
			break;
		}
	}
	
	[aContext unlockPSCAndSelf];
	
	return result;
}

- (BOOL)contextChangesAreOnlyMediaOrCachedImages:(KTManagedObjectContext *)aContext
{
	BOOL result = YES;
	
	[aContext lockPSCAndSelf];
	
	NSEnumerator *e = [[aContext changedObjects] objectEnumerator];
	KTManagedObject *object;
	while ( object = [e nextObject] )
	{
		if ( ![[[object entity] name] isEqualToString:@"CachedImage"]
			 && ![[[object entity] name] isEqualToString:@"Media"] )
		{
			result = NO;
			break;
		}
	}
	
	[aContext unlockPSCAndSelf];
	
	return result;
}

- (void)releasePeerContext:(KTManagedObjectContext *)aContext
{
	OBASSERTSTRING(![aContext isEqual:[self managedObjectContext]], @"aContext should not be the document's main context");
	
	BOOL isPeer = NO;
	@synchronized ( myPeerContexts )
	{
		isPeer = [myPeerContexts containsObject:aContext];
	}
	
	if ( isPeer )
	{
		// make sure all changes are saved
		if ( [aContext hasChanges] )
		{
			(void)[self saveContext:aContext onlyIfNecessary:NO];
		}
		
		// remove observers
		[self removeObserversForContext:aContext];

		NSPersistentStoreCoordinator *coordinator = [aContext persistentStoreCoordinator];
		[coordinator lock];
		@synchronized ( myPeerContexts )
		{
			// remove context
			[myPeerContexts removeObject:aContext]; // this should release aContext
		}
		[coordinator unlock];		
	}
	else 
	{
		LOG((@"error: document asked to remove a peer context it doesn't have!"));
	}
}

- (void)releaseAllPeerContexts
{
	@synchronized ( myPeerContexts )
	{
		NSEnumerator *e = [myPeerContexts objectEnumerator];
		NSManagedObjectContext *context;
		while ( context = [e nextObject] )
		{
			[self releasePeerContext:(KTManagedObjectContext *)context];
		}
	}
}

- (void)resetAllPeerContexts
{
	@synchronized ( myPeerContexts )
	{
		NSEnumerator *e = [myPeerContexts objectEnumerator];
		NSManagedObjectContext *context;
		while ( context = [e nextObject] )
		{
			[context reset];
		}
	}
}

- (void)resetOtherPeerContexts:(KTManagedObjectContext *)currentContext
{
	OBASSERTSTRING(![currentContext isEqual:[self managedObjectContext]], @"currentContext should not be the document's main context");
	@synchronized ( myPeerContexts )
	{
		// optimization
		if ( [myPeerContexts count] == 0 )
		{
			return;
		}
		
		// build set of all contexts
		NSMutableArray *contexts = [NSMutableArray arrayWithArray:myPeerContexts];
		if ( [contexts containsObject:currentContext] )
		{
			// remove current context
			if ( nil != currentContext )
			{
				[contexts removeObject:currentContext];
			}
		}
		
		// iterate, resetting contexts
		NSEnumerator *e = [contexts objectEnumerator];
		KTManagedObjectContext *context;
		while ( context = [e nextObject] )
		{
			[context lockPSCAndSelf];
			[context reset];
			[context unlockPSCAndSelf];
		}
	}
}

- (void)refreshObjectsWithObjectIDs:(id)aSetOrArrayOfObjectIDs
				 inAllContextsExcept:(KTManagedObjectContext *)aManagedObjectContext
					   mergeChanges:(BOOL)aFlag;
{
	@synchronized ( myPeerContexts )
	{
		// optimization, if there are no peerContexts there is no other context to refresh!
		if ( [myPeerContexts count] == 0 )
		{
			return;
		}
		
		// if aSetOrArrayOfObjectIDs contains a single CachedImage, we need to update it's media and mediaRefs
		
//		if ( aFlag )
//		{
//			OFF((@"refreshing objects, merging changes: %@", aSetOrArrayOfObjectIDs));
//		}
//		else
//		{
//			OFF((@"faulting objects, discarding changes: %@", aSetOrArrayOfObjectIDs));
//		}
		
		// build set of all contexts
		NSMutableArray *contexts = [NSMutableArray arrayWithArray:[self allContexts]];
		
		// remove current context
		[contexts removeObject:aManagedObjectContext];
		
		// iterate contexts
		NSEnumerator *e = [contexts objectEnumerator];
		KTManagedObjectContext *context;
		while ( context = [e nextObject] )
		{
			[context lockPSCAndSelf];
			
			// iterate objectIDs
			NSEnumerator *idEnumerator = [aSetOrArrayOfObjectIDs objectEnumerator];
			NSManagedObjectID *objectID;
			while ( objectID = [idEnumerator nextObject] )
			{
				NSManagedObject *object = [context objectWithID:objectID];
				@try
				{
					[context refreshObject:object mergeChanges:aFlag];
				}
				@catch (NSException *exception) 
				{
					LOG((@"merge error: %@", exception)); // there shouldn't be any merge errors!
				}
			}
			
			[context unlockPSCAndSelf];
		}
	}
}

- (void)refreshObjectInAllOtherContexts:(KTManagedObject *)aManagedObject
{
	@synchronized ( myPeerContexts )
	{
		// optimization
		if ( [myPeerContexts count] == 0 )
		{
			return;
		}
	}
	
	// don't refresh until we first save ourselves
	BOOL mergeChanges = ([aManagedObject isUpdated] || [aManagedObject isInserted] || [aManagedObject isDeleted]);
	if ( mergeChanges )
	{
		(void)[self saveContext:(KTManagedObjectContext *)[aManagedObject managedObjectContext] onlyIfNecessary:NO];
	}
	
	// ok, refresh except for this context
	[self refreshObjectsWithObjectIDs:[NSArray arrayWithObject:[aManagedObject objectID]] 
				   inAllContextsExcept:(KTManagedObjectContext *)[aManagedObject managedObjectContext] 
						 mergeChanges:mergeChanges];
}	

// how about putting in a lock such that the save will not begin/lock the context until the webview has finished updating
// and vice versa so that loadinWebView doesn't begin parsing page until no saving is occuring?
- (BOOL)saveContext:(KTManagedObjectContext *)aManagedObjectContext
{
	BOOL result = NO;
		
	// do we have changes and are we on disk? (and not publishing)
	BOOL doSave = ( !myIsSuspendingAutosave
					&& [aManagedObjectContext hasChanges] 
					&& [[aManagedObjectContext persistentStoreCoordinator] hasPersistentStores]
					&& ![self isReadOnly] );
					//&& ![self connectionsAreConnected] ); // we should be ok to save changes to peer during publishing now
	if ( doSave )
	{
		[self suspendAutosave];
		
		
		
		// Do Garbage Collection etc. (but only if there is a location to move it to!)
		if ([self updateMediaStorageAtNextSave])
		{
			[[self mediaManager] resetMediaFileStorage];
		}
		
		NSManagedObjectContext *moc = [self managedObjectContext];
		[moc processPendingChanges];
		[[moc undoManager] disableUndoRegistration];
		
		[[self mediaManager] garbageCollect];
		
		[moc processPendingChanges];
		[[moc undoManager] enableUndoRegistration];
		
		
		
		//@synchronized ( myPeerContexts ) // don't create a new peer context if we're in the middle of saving (?)
		//{
				if ( kGeneratingPreview == [[self windowController] publishingMode] ) 
			{
				// NB: we can only do these backup/snapshot things if were not publishing
				// since publishing will have claimed the autosave lock on another thread
				
				// do we need to backup first?
				if (KTBackupOnOpening == mySnapshotOrBackupUponFirstSave)
				{
					(void)[self backup];
					
				}
				if (KTSnapshotOnOpening == mySnapshotOrBackupUponFirstSave)
				{
					[self snapshotPersistentStore:nil];
				}
			}
						
			NSPersistentStoreCoordinator *psc = [aManagedObjectContext persistentStoreCoordinator];
			NSMutableArray *otherContexts = [[self allContexts] mutableCopy];
			[otherContexts removeObject:aManagedObjectContext];
			@try
			{
				// don't update the webview at the same time we save
				/// commenting this out to deal with save/editing issue Dan ran into
				/// in theory, we shouldn't need this anymore -- this was 
				/// put in early on when we didn't have a good handle on the multithreading
				/// issues, but we now lock during URL loads, so saving and webview refresh
				/// should no longer conflict, in theory...
//				[[self windowController] setSuspendNextWebViewUpdate:SUSPEND];
//				[NSObject cancelPreviousPerformRequestsWithTarget:[self windowController] selector:@selector(doDelayedRefreshWebViewOnMainThread) object:nil];
				
				// lock psc - we want to avoid any simultaneous writes!
				[psc lock];

				// lock ALL moc's [not just aMonagedObjectContext] so that all other operations will finish before saving can start
				[aManagedObjectContext lock];
				
				NSEnumerator *enumerator = [otherContexts objectEnumerator];
				KTManagedObjectContext *context;
				while ((context = [enumerator nextObject]) != nil)
				{
					[context lock];
				}
				
				// ^^^^ EVERYTHING ABOVE WILL BE UNLOCKED IN THE OUTER "FINALLY" CLAUSE
				
				// are we saving the document's context?
				BOOL isMainContext = [aManagedObjectContext isEqual:[self managedObjectContext]];

				// housekeeping if this looks like we're autosaving the document's context
				/// optimization for 1.2.1: only setMetadata during file create and file close, not file save
				
				// make sure we grab anything stuck in the UI
				if ( [NSThread isMainThread] && isMainContext )
				{
					[aManagedObjectContext commitEditing];
				}
				
				// make sure main context is up to date for undo
				if ( isMainContext )
				{
					[aManagedObjectContext processPendingChanges];
				}
				
				// preliminaries out of the way, let's do it
				@try
				{
					// always start by setting saving mode
					[self setSaving:YES];
					
					// save context
					NSError *saveError = nil;
					result = [aManagedObjectContext save:&saveError];
					if ( !result )
					{
						if ( [[saveError domain] isEqualToString:NSCocoaErrorDomain] 
							 && ([saveError code] == NSManagedObjectMergeError) )
						{
							LOG((@"saveContext: detected NSManagedObjectMergeError, skipping save for now (this is not ok)"));
							LOG((@"underlying reason: %@", [saveError localizedDescription]));
						}
						else if ( [[saveError domain] isEqualToString:NSCocoaErrorDomain] 
								  && ([saveError code] >= NSManagedObjectValidationError)
								  && ([saveError code] <= NSValidationStringPatternMatchingError) )
						{
							LOG((@"saveContext: detected NSManagedObjectValidationError, skipping save for now (this might be ok)"));
							LOG((@"underlying reason: %@", [saveError localizedDescription]));
						}
						else if ( [[saveError domain] isEqualToString:NSCocoaErrorDomain]
								  && ([saveError code] == NSPersistentStoreSaveError) )
						{
							LOG((@"saveContext: detected NSPersistentStoreSaveError, skipping save for now (this is not ok)"));
							LOG((@"underlying reason: %@", [saveError localizedDescription]));
						}
						else 
						{
							// log error, even for end users, so we see it in console
							NSLog(@"unable to saveContext:, errorCode: %i", [saveError code]);
							
							if ( [NSThread isMainThread] )
							{
								// present error to the user with a more friendly description
								
								// start with the old info
								NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
								if ( nil != [saveError userInfo] )
								{
									[userInfo addEntriesFromDictionary:[saveError userInfo]];
								}
								
								// make a more informative NSLocalizedDescription
								NSString *errorDescription = nil;
								
								// NO SUCH FILE ERROR
								if ( [saveError code] == NSFileNoSuchFileError )
								{
									errorDescription = NSLocalizedString(@"Sandvox is unable to autosave this document. The underlying .svxSite file cannot be located. Was it placed in the Trash? If so, you may be able to correct the problem by moving the file from the Trash to its original location. If you are not able to correct the problem, please close this document and use Help > Send Feedback... to send Karelia a report. Be sure to include the filtered console log, so that we may diagnose the problem.", "Autosave NoSuchFileError Alert");
								}
								
								// OUT OF DISK SPACE ERROR
								else if ( [saveError code] == NSFileWriteOutOfSpaceError )
								{
									errorDescription = NSLocalizedString(@"Sandvox is unable to autosave this document. Your Macintosh does not appear to have enough space left on disk to accomodate the file.", "Autosave OutOfSpaceError Alert");
								}
								
								// UNKNOWN ERROR
								else
								{
									errorDescription = NSLocalizedString(@"Sandvox is unable to autosave this document. The exact problem is unknown. Although the problem may resolve in a future autosave, it is recommended that you close this document. Some information may be lost. Please use Help > Send Feedback... to send Karelia a report. Be sure to include the filtered console log, so that we may diagnose the problem.", "Autosave GenericError Alert");
								}
								[userInfo setValue:errorDescription forKey:NSLocalizedDescriptionKey];
								
								// make a new error out of the old one, with a better description
								NSError *betterError = [NSError errorWithDomain:[saveError domain] code:[saveError code] userInfo:userInfo];
								
								// put up the error as a sheet
								if ( [NSThread isMainThread] && isMainContext )
								{
									[self presentError:betterError
										modalForWindow:[[self windowController] window]
											  delegate:nil
									didPresentSelector:nil
										   contextInfo:nil];								
								}
								else 
								{
// FIXME: IS presentError: THREAD SAFE? HOW DO WE HANDLE INFORMING USER IF NOT MAIN THREAD?
									LOG((@"wanted to present error but not main thread: %@", 
										 [betterError valueForKey:@"errorDescription"]));
								}

							}
						}
					}
				} // end inner @try
				@catch (NSException *e)
				{
					// we shouldn't really ever get here, the NSError should have handled it
					// if not, log it to the user's console for follow up
					NSLog(@"saveContext: exception: %@ %@ %@", [e name], [e reason], [e userInfo]);
					if ( [[e reason] isEqualToString:@"Nested transactions are not supported"] ) 
					{
//						LOG((@"rolling back context %p", aManagedObjectContext));
//						[aManagedObjectContext rollback];
					}
				}
				@finally
				{
					// always finish by unsetting saving mode
					[self setSaving:NO];
				}
			} // end outer @try
			@finally
			{
				// unlock all contexts
				NSEnumerator *enumerator = [otherContexts objectEnumerator];
				KTManagedObjectContext *context;
				while ((context = [enumerator nextObject]) != nil)
				{
					[context unlock];
				}
				
				[aManagedObjectContext unlock];
				
				// unlock our psc
				[psc unlock];

				// unlock our autosave lock
				[self resumeAutosave];
				
				// restart webview updating
				/// per paried suspend above, we're no longer going to do this
				/// since we've (hopefully) made URL loading threadsafe
//				[[self windowController] setSuspendNextWebViewUpdate:DONT_SUSPEND];
			}
		//} // end @synchronized
		
			mySnapshotOrBackupUponFirstSave = KTNoBackupOnOpening;
		
	} // endif dosave

	// see if we can clear the dirty flag on the window
	/// added check for main thread to try to avoid zombie
	if ( result && [NSThread isMainThread] && ![self hasUnsavedChanges] )
	{
		[self updateChangeCount:NSChangeCleared];
	}
	
	return result;
}

- (BOOL)saveContext:(KTManagedObjectContext *)aManagedObjectContext onlyIfNecessary:(BOOL)aFlag
{
	// this can happen when first creating a document, so we just skip it
	if ( nil == [aManagedObjectContext persistentStoreCoordinator] )
	{
		return NO;
	}
	
	// optimization
	if ( ![aManagedObjectContext hasChanges] )
	{
		return NO;
	}
		
	// optimization
	if ( YES == aFlag )
	{
		if ( [self suspendSavesDuringPeerCreation] )
		{
			return YES;
		}
		// if we don't have any peer contexts, we don't need to save document until next autosave
		@synchronized ( myPeerContexts )
		{
			if ( [myPeerContexts count] == 0 )
			{
				return YES;
			}
		}
	}
	
	return [self saveContext:aManagedObjectContext];
}

- (BOOL)hasPeerContextsInFlight
{
	unsigned int peerCount = 0;
	@synchronized ( myPeerContexts )
	{
		peerCount = [myPeerContexts count];
	}
	return (peerCount > 0);
}

#pragma mark context notification method support

- (NSArray *)objectIDsWithinArrayOrSet:(id)anArrayOrSet
{
	NSMutableSet *set = [NSMutableSet set];
	
	NSEnumerator *e = [anArrayOrSet objectEnumerator];
	KTManagedObject *object;
	while ( object = [e nextObject] )
	{
		if ( [object isManagedObject] )
		{
			[set addObject:[object objectID]];
		}
	}
	
	return [set allObjects];
}

- (NSArray *)objectsWithEntityName:(NSString *)anEntityName withinSet:(NSSet *)aSet 
{
	NSMutableArray *array = [NSMutableArray array];
	
	NSEnumerator *e = [aSet objectEnumerator];
	KTManagedObject *object;
	while ( object = [e nextObject] )
	{
		if ( [object isManagedObject] && [[[object entity] name] isEqualToString:anEntityName] )
		{
			[array addObject:object];
		}
	}
	
	return [NSArray arrayWithArray:array];
}

- (NSArray *)pagesWithinSet:(NSSet *)aSet
{
	NSMutableArray *array = [NSMutableArray array];
	
	NSEnumerator *e = [aSet objectEnumerator];
	KTManagedObject *object;
	while ( object = [e nextObject] )
	{
		if ( [object isKindOfClass:[KTPage class]] )
		{
			[array addObject:object];
		}
	}
	
	return [NSArray arrayWithArray:array];
}

// TODO: THIS IS COMPLICATED! CAN THIS BE MADE ANY MORE EFFICIENT? SHARK THIS METHOD
- (BOOL)isOnlyRichTextChange:(NSSet *)changedObjects
{
	OBASSERTSTRING([NSThread isMainThread], @"should be main thread");
	
	// if the set consists of only three objects, one Page, one PluginPropertiesDictionary, and one KeyValueAsString
	// and the only change to the Page is lastModificationDate
	// and the only key in KeyValueAsString is richTextHTML
	
	BOOL result = NO;
	
	if ( 3 == [changedObjects count] )
	{
		NSArray *pages = [self pagesWithinSet:changedObjects];
		if ( 1 == [pages count] )
		{
			NSDictionary *changedValues = [[pages objectAtIndex:0] changedValues]; // does not fire faults
			if ( (1 == [changedValues count]) && (nil != [changedValues valueForKey:@"lastModificationDate"]) )
			{
				if ( 1 == [[self objectsWithEntityName:@"PluginPropertiesDictionary" 
											 withinSet:changedObjects] count] )
				{
					if ( 1 == [[self objectsWithEntityName:@"KeyValueAsString" 
												 withinSet:changedObjects] count] )
					{
						KTManagedObject *keyValue = [[self objectsWithEntityName:@"KeyValueAsString" 
																	   withinSet:changedObjects] objectAtIndex:0];
						[keyValue lockPSCAndMOC];
						if ( [[keyValue valueForKey:@"key"] isEqualToString:@"richTextHTML"] )
						{
							result = YES;
						}
						[keyValue unlockPSCAndMOC];
					}
				}
			}
		}
	}
	
	return result;
}

@end
