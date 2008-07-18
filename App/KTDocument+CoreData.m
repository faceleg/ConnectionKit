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
#import "KTAbstractElement.h"
#import "KTAbstractPluginDelegate.h"
#import "KTAppDelegate.h"
#import "KSPlugin.h"
#import "KTDocumentController.h"
#import "KTDocumentInfo.h"
#import "KTDocWebViewController.h"
#import "KTDocWindowController.h"
#import "KTHTMLParser.h"
#import "KTManagedObjectContext.h"
#import "KTPage.h"
#import "KTPersistentStoreCoordinator.h"

#import "NSApplication+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSSortDescriptor+Karelia.h"
#import "NSString+Karelia.h"
#import "NSThread+Karelia.h"
#import "NSWorkspace+Karelia.h"

#ifdef APP_RELEASE
#import "Registration.h"
#endif


@interface KTDocument (CoreDataPrivate)
- (void)logManagedObjectsInSet:(NSSet *)managedObjects;

- (BOOL)backup;

@end


@implementation KTDocument (CoreData)

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
		KTPersistentStoreCoordinator *PSC = [[KTPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
		[PSC setDocument:self];
		[myManagedObjectContext setPersistentStoreCoordinator:PSC];
		[PSC release];
	}
	
	OBASSERTSTRING((nil != myManagedObjectContext), @"myManagedObjectContext should not be nil");
	
	return (NSManagedObjectContext *)myManagedObjectContext;
}

#pragma mark model

/*	The first time the model is loaded, we need to give Fetched Properties sort descriptors.
 */
+ (NSManagedObjectModel *)managedObjectModel
{
	static NSManagedObjectModel *result;
	
	if (!result)
	{
		// grab only Sandvox.mom (ignoring "previous moms" in KTComponents/Resources)
		NSBundle *componentsBundle = [NSBundle bundleForClass:[KTAbstractElement class]];
        OBASSERT(componentsBundle);
		
		NSURL *modelURL = [NSURL fileURLWithPath:[componentsBundle pathForResource:@"Sandvox" ofType:@"mom"]];
		OBASSERT(modelURL);
		
		result = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
	}
	
	OBPOSTCONDITION(result);
	return result;
}

/*	We override NSPersistentDocument to use a global model.
 */
- (NSManagedObjectModel *)managedObjectModel { return [[self class] managedObjectModel]; }

#pragma mark store coordinator

//- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url 
//										   ofType:(NSString *)fileType 
//							   modelConfiguration:(NSString *)configuration 
//									 storeOptions:(NSDictionary *)storeOptions 
//											error:(NSError **)error

// this method is deprecated in Leopard, but we must continue to use its signature for Tiger
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url 
										   ofType:(NSString *)fileType 
											error:(NSError **)error
{
	//LOGMETHOD;
	
    // NB: called whenever a document is opened *and* when a document is first saved
    // so, because of the order of operations, we have to store metadata here, too
	
	/// and we compute the sqlite URL here for both read and write
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:url UTI:nil];
	
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
					//[root setDocument:self];
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
                    NSBundle *bundle = [[KSPlugin pluginWithIdentifier:bundleIdentifier] bundle];
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
#pragma mark context notifications

- (void)contextDidChange:(NSNotification *)aNotification
{
	//LOGMETHOD;
	
	// if the context changes, we want to kick off the autosave timer
	// if it keeps changing, we want to reset the timer
	// except that we can't let it go too long
	// what do we do about that?
	// right now, this is the only place where we are starting the timers
	
	if ([self fileURL])
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
	if ( [[NSApp delegate] logAllContextChanges] )
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

- (void)processPendingChangesAndClearChangeCount
{
	//LOGMETHOD;

	[[self managedObjectContext] processPendingChanges];
	[[self undoManager] removeAllActions];
	[self updateChangeCount:NSChangeCleared];
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
		OBASSERT(fileName);
		backupFileName = [backupFileName stringByAppendingString:fileName];
		OBASSERT(fileExtension);
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
			
			// set ALL of our metadata for this store
			//  kKTMetadataSiteTitleKey
			NSString *siteTitle = [[[self root] master] valueForKey:@"siteTitleHTML"];        
			if ( (nil == siteTitle) || [siteTitle isEqualToString:@""] )
			{
				[metadata removeObjectForKey:kKTMetadataSiteTitleKey];
			}
			else
			{
				[metadata setObject:[siteTitle stringByConvertingHTMLToPlainText] forKey:kKTMetadataSiteTitleKey];
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
			
			// kKTMetadataAppCreatedVersionKey should only be set once
			if ( nil == [metadata valueForKey:kKTMetadataAppCreatedVersionKey] )
			{
				[metadata setObject:[NSApplication buildVersion] forKey:kKTMetadataAppCreatedVersionKey];
			}
			
			//  kKTMetadataAppLastSavedVersionKey (CFBundleVersion of running app)
			[metadata setObject:[NSApplication buildVersion] forKey:kKTMetadataAppLastSavedVersionKey];
							
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
			subtitle = [subtitle stringByConvertingHTMLToPlainText];
			
			// add unique page titles
			NSMutableString *itemDescription = [NSMutableString stringWithString:subtitle];
			NSArray *pageTitles = [[self managedObjectContext] objectsForColumnName:@"titleHTML" entityName:@"Page"];
			unsigned int i;
			for ( i=0; i<[pageTitles count]; i++ )
			{
				NSString *pageTitle = [pageTitles objectAtIndex:i];
				pageTitle = [pageTitle stringByConvertingHTMLToPlainText];
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
					spotlightText = [spotlightText stringByConvertingHTMLToPlainText];
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
		else
		{
			NSLog(@"error: unable to setMetadataForStoreAtURL:%@ (no persistent store)", [aStoreURL path]);
			NSString *path = [aStoreURL path];
			NSString *reason = [NSString stringWithFormat:@"(%@ is not a valid persistent store.)", path];
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain
											code:134070 // NSPersistentStoreOperationError
										userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
												  reason, NSLocalizedDescriptionKey,
												  nil]]; 
			result = NO;
		}
	}
	@catch (NSException * e)
	{
		NSLog(@"error: unable to setMetadataForStoreAtURL:%@ exception: %@:%@", [aStoreURL path], [e name], [e reason]);
		*outError = [NSError errorWithDomain:NSCocoaErrorDomain
										code:134070 // NSPersistentStoreOperationError
									userInfo:[NSDictionary dictionaryWithObjectsAndKeys:
											  [aStoreURL path], @"path",
											  [e name], @"name",
											  [e reason], NSLocalizedDescriptionKey,
											  nil]]; 
		result = NO;
	}
	
	return result;
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

@end
