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
#import "NSURL+Karelia.h"

#import "Registration.h"


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
		
        NSString *modelPath = [componentsBundle pathForResource:@"Sandvox" ofType:@"mom"];
        OBASSERTSTRING(modelPath, [componentsBundle description]);
        
		NSURL *modelURL = [NSURL fileURLWithPath:modelPath];
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
	BOOL result = YES;
	
	//LOGMETHOD;
	
    // NB: called whenever a document is opened *and* when a document is first saved
    // so, because of the order of operations, we have to store metadata here, too
	
	/// and we compute the sqlite URL here for both read and write
	NSURL *storeURL = [KTDocument datastoreURLForDocumentURL:url UTI:nil];
	
	// these two lines basically take the place of sending [super configurePersistentStoreCoordinatorForURL:ofType:error:]
	// NB: we're not going to use the supplied configuration or options here, though we could in a Leopard-only version
	NSPersistentStoreCoordinator *psc = [[self managedObjectContext] persistentStoreCoordinator];
	result = (nil != [psc addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType]
									   configuration:nil
												 URL:storeURL
											 options:nil
											   error:error]);
	
	// Also configure media manager's store
	if (result)
	{
		NSPersistentStoreCoordinator *mediaPSC = [[[self mediaManager] managedObjectContext] persistentStoreCoordinator];
		result = (nil != [mediaPSC addPersistentStoreWithType:NSXMLStoreType
												configuration:nil
														  URL:[KTDocument mediaStoreURLForDocumentURL:url]
													  options:nil
														error:error]);
	}
	
	
	
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
		
		/// this should be active for document open and save, but not migration
//		// store metadata if it doesn't exist yet
//		NSDictionary *metadata = [psc metadataForPersistentStore:theStore];
//		if ( nil == [metadata valueForKey:kKTMetadataModelVersionKey] )
//		{
//			result = [self setMetadataForStoreAtURL:storeURL error:error];
//		}
    }
	
	return result;
}

#pragma mark snapshot

- (void)snapshotPersistentStore
{	
	// perform file operations using Workspace
	NSArray *files = nil;
	int tag = 0;
	
	// recycle current snapshot
	NSFileManager *fm = [NSFileManager defaultManager];
	NSString *snapshotPath = [[self snapshotURL] path];
	if ( [fm fileExistsAtPath:snapshotPath] )
	{
		files = [NSArray arrayWithObject:[snapshotPath lastPathComponent]];
		BOOL didMoveOldSnapshotToTrash = [[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation 
																					  source:[[self snapshotDirectoryURL] path]
																				 destination:nil
																					   files:files 
																						 tag:&tag];
		if ( !didMoveOldSnapshotToTrash )
		{
			NSString *snapshotPathAsDisplayPath = [[snapshotPath stringByAbbreviatingWithTildeInPath] stringBySubstitutingRightArrowForPathSeparator];
			NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"Snapshot Failed", "alert: snapshot failed")
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
	
	
	NSString *destPath = [[[self snapshotDirectoryURL] URLByAppendingPathComponent:[[self fileURL] lastPathComponent] 
                                                                    isDirectory:NO] path];
	
	NSError *error;
	BOOL didSnapshot = [self saveToURL:[NSURL fileURLWithPath:destPath]
								ofType:kKTDocumentType
					  forSaveOperation:NSSaveToOperation
								 error:&error];
	
	
	if (!didSnapshot)
	{
		NSString *snapshotsDirectory = [[self snapshotDirectoryURL] path];
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

- (void)revertPersistentStoreToSnapshot
{
	if ([[NSFileManager defaultManager] fileExistsAtPath:[[self snapshotURL] path]])
	{
		// message app delegate to take it from here
		[[NSApp delegate] revertDocument:self toSnapshot:[[self snapshotURL] path]];
	}
	else
	{
		NSLog(@"error: cannot revert to snapshot %@ , file does not exist!", [[self snapshotURL] absoluteString]);
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
			
			// remove old keys that might have been in use by older versions of Sandvox
			[metadata removeObjectForKey:(NSString *)kMDItemDescription];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_AppVersion"];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_PageCount"];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_SiteAuthor"];
			[metadata removeObjectForKey:@"com_karelia_Sandvox_SiteTitle"];
			
			// set ALL of our metadata for this store
			
			//  kMDItemAuthors
			NSString *author = [[[[self documentInfo] root] master] valueForKey:@"author"];
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
			NSString *subtitle = [[[[self documentInfo] root] master] valueForKey:@"siteSubtitleHTML"];
			if ( nil == subtitle )
			{
				subtitle = @"";
			}
			subtitle = [subtitle stringByConvertingHTMLToPlainText];
			
			// add unique page titles
			NSMutableString *textContent = [NSMutableString stringWithString:subtitle];
			NSArray *pageTitles = [[self managedObjectContext] objectsForColumnName:@"titleHTML" entityName:@"Page"];
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
			NSString *siteTitle = [[[[self documentInfo] root] master] valueForKey:@"siteTitleHTML"];        
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

@end
