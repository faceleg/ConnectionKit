//
//  KTDocumentController.m
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005-2009 Karelia Software. All rights reserved.
//

#import "KTDocumentController.h"

#import "KT.h"
#import "KTAbstractIndex.h"
#import "KTAbstractPage+Internal.h"
#import "KTAppDelegate.h"
#import "KTDataMigrator.h"
#import "KTDataMigrationDocument.h"
#import "KTDocument.h"
#import "KTDocumentInfo.h"
#import "KTElementPlugin.h"
#import "KTIndexPlugin.h"
#import "KTMediaManager.h"
#import "KTMaster.h"
#import "KTPage+Internal.h"
#import "KTPagelet+Internal.h"
#import "KTPlaceholderController.h"
#import "KTPluginInstaller.h"
#import "KTPersistentStoreCoordinator.h"

#import "NSArray+Karelia.h"
#import "NSError+Karelia.h"
#import "NSHelpManager+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWindowController+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSURL+Karelia.h"

#import "BDAlias.h"
#import "KSApplication.h"
#import "KSProgressPanel.h"
#import "KSRegistrationController.h"

#import "Debug.h"

#import "Registration.h"


@interface KTDocumentController (Private)
- (NSArray *)documentsAwaitingBackup;
- (void)addDocumentAwaitingBackup:(KTDocument *)document;
- (void)removeDocumentAwaitingBackup:(KTDocument *)document;
@end


#pragma mark -


@implementation KTDocumentController

#pragma mark -
#pragma mark Init & Dealloc

- (id)init
{
	if ( ![super init] )
	{
		return nil;
	}
	
	myDocumentsAwaitingBackup = [[NSMutableArray alloc] initWithCapacity:1];
    
	return self;
}

- (void)dealloc
{
    NSEnumerator *documents = [[self documentsAwaitingBackup] objectEnumerator];
    KTDocument *aDocument;
    while (aDocument = [documents nextObject])
    {
        [self removeDocumentAwaitingBackup:aDocument];
    }
    
    OBASSERT([myDocumentsAwaitingBackup count] == 0);
    [myDocumentsAwaitingBackup release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Document placeholder window

- (IBAction)showDocumentPlaceholderWindow:(id)sender
{
    if (gLicenseViolation)		// license violation dialog should open, not the new/open
    {
        [[KSRegistrationController sharedController] showWindow:@"license"];		// string is just a tag for the source of this
    }
    else
    {
		[[KTPlaceholderController sharedController] showWindowAndBringToFront:NO];
    }
}

#pragma mark -
#pragma mark Creating New Documents

- (IBAction)newDocument:(id)sender
{
    NSError *error = nil;
    if (![self openUntitledDocumentAndDisplay:YES error:&error])
    {
        if (![[error domain] isEqualToString:NSCocoaErrorDomain] || [error code] != NSUserCancelledError)
        {
            [self presentError:error];
        }
    }
}

- (id)makeUntitledDocumentOfType:(NSString *)typeName error:(NSError **)outError
{
    // Do nothing if the license is invalid
	if (gLicenseViolation) {
		NSBeep();
		if (outError)
		{
			*outError = nil;	// Otherwise we crash	// TODO: Perhaps actually return an error
		}
		return nil;
	}
	
    
	
	Class docClass = [self documentClassForType:typeName];
    if (![docClass isSubclassOfClass:[KTDocument class]])
    {
        return [super makeUntitledDocumentOfType:typeName error:outError];
    }
        
        
        
    // Ask the user for the location and home page type of the document
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setTitle:NSLocalizedString(@"New Site", @"Save Panel Title")];
	[savePanel setPrompt:NSLocalizedString(@"Create", @"Create Button")];
	[savePanel setCanSelectHiddenExtension:YES];
	[savePanel setRequiredFileType:kKTDocumentExtension];
	[savePanel setCanCreateDirectories:YES];
	
	[[NSBundle mainBundle] loadNibNamed:@"NewDocumentAccessoryView" owner:self];
	
	NSButton *helpButton = [[[NSButton alloc] initWithFrame:NSMakeRect(20, 20, 21, 23)] autorelease];
	[helpButton setBezelStyle:NSHelpButtonBezelStyle];
	[helpButton setTitle:@""];
	[helpButton setTarget:self];
	[helpButton setAction:@selector(newDocShowHelp:)];

	[savePanel setAccessoryView:oNewDocAccessoryView];

	NSView *view = [oNewDocAccessoryView superview];		// we want this to be ABOVE the accessory view.
	[view addSubview:helpButton];
	
    
    // Offer all available page types except External Link and File Download. BUGSID:38542
	NSMutableSet *pagePlugins = [[KTElementPlugin pagePlugins] mutableCopy];
    [pagePlugins removeObject:[KSPlugin pluginWithIdentifier:@"sandvox.DownloadElement"]];
    [pagePlugins removeObject:[KSPlugin pluginWithIdentifier:@"sandvox.LinkElement"]];
    
	[KTElementPlugin addPlugins:pagePlugins
						 toMenu:[oNewDocHomePageTypePopup menu]
						 target:nil
						 action:nil
					  pullsDown:NO
					  showIcons:YES smallIcons:YES smallText:NO];
	[pagePlugins release];
    
    
	int saveResult = [savePanel runModalForDirectory:nil file:nil];
	if (saveResult == NSFileHandlingPanelCancelButton)
    {
		if (outError) *outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil];
		return nil;
	}
    
	
	//  Put up a progress bar
	NSImage *newDocumentImage = [NSImage imageNamed:@"document.icns"];
	NSString *progressMessage = NSLocalizedString(@"Creating Site...",@"Creating Site...");
	
    KSProgressPanel *progressPanel = [[KSProgressPanel alloc] init];
    [progressPanel setMessageText:progressMessage];
    [progressPanel setInformativeText:nil];
    [progressPanel setIcon:newDocumentImage];
    [progressPanel makeKeyAndOrderFront:self];
        
	
    KTDocument *result = nil;
    @try    // To remove the progress bar if something goes wrong
	{
        // Do we already have a file there? Remove it.
		NSURL *saveURL = [savePanel URL];
		if ([[NSFileManager defaultManager] fileExistsAtPath:[saveURL path]])
		{
			// is saveURL path writeable?
			if (![[NSFileManager defaultManager] isWritableFileAtPath:[saveURL path]])
			{
				NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
				[errorInfo setObject:[NSString stringWithFormat:
                                      NSLocalizedString(@"Unable to create new document.",@"Alert: Unable to create new document.")]
							  forKey:NSLocalizedDescriptionKey]; // message text
				[errorInfo setObject:[NSString stringWithFormat:
                                      NSLocalizedString(@"The path %@ is not writeable.",@"Alert: The path %@ is not writeable."), [saveURL path]]
							  forKey:NSLocalizedFailureReasonErrorKey]; // informative text
				if (outError)
				{
					*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:errorInfo];
				}
				
				return nil;
			}
			
			if (![[NSFileManager defaultManager] removeFileAtPath:[saveURL path] handler:nil])
			{
				
				//  put up an error that the previous file could not be overwritten
				NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
				[errorInfo setObject:[NSString stringWithFormat:
                                      NSLocalizedString(@"Unable to create new document.",@"Alert: Unable to create new document.")]
							  forKey:NSLocalizedDescriptionKey]; // message text
				[errorInfo setObject:[NSString stringWithFormat:
                                      NSLocalizedString(@"Could not remove pre-existing file at path %@.",@"Alert: Could not remove pre-existing file at path %@."), [saveURL path]]
							  forKey:NSLocalizedFailureReasonErrorKey]; // informative text
				
				if (outError)
				{
					*outError = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:errorInfo];
				}
				
				return nil;
			}
		}
		
		
        
        // Create the doc
        result = [[docClass alloc] initWithType:typeName
                                     rootPlugin:[[oNewDocHomePageTypePopup selectedItem] representedObject]
                                          error:outError];
        [result autorelease];
        
        KTPage *root = [[result documentInfo] root];
        KTMaster *master = [root master];
        
        
        // Give the site a subtitle too
        NSString *subtitle = [[NSBundle mainBundle] localizedStringForString:@"siteSubtitleHTML"
                                                                    language:[master valueForKey:@"language"]
                                                                    fallback:NSLocalizedStringWithDefaultValue(@"siteSubtitleHTML", nil, [NSBundle mainBundle],
                                                                                                               @"This is the subtitle for your site.",
                                                                                                               @"Default introduction statement for a page")];
        [master setValue:subtitle forKey:@"siteSubtitleHTML"];
        
        
        // FIXME: we should load up the properties from a KTPreset
        [root setBool:NO forKey:@"includeTimestamp"];
        [root setInteger:KTCollectionUnsorted forKey:@"collectionSortOrder"];
        [root setCollectionSyndicate:NO];
        [root setInteger:0 forKey:@"collectionMaxIndexItems"];
        [root setBool:NO forKey:@"collectionShowPermanentLink"];
        [root setBool:YES forKey:@"collectionHyperlinkPageTitles"];		
        
        
        NSString *defaultRootIndexIdentifier = [[NSUserDefaults standardUserDefaults] stringForKey:@"DefaultRootIndexBundleIdentifier"];
        if (nil != defaultRootIndexIdentifier && ![defaultRootIndexIdentifier isEqualToString:@""])
        {
            KTAbstractHTMLPlugin *plugin = [KTIndexPlugin pluginWithIdentifier:defaultRootIndexIdentifier];
            if (nil != plugin)
            {
                NSBundle *bundle = [plugin bundle];
                [root setValue:defaultRootIndexIdentifier forKey:@"collectionIndexBundleIdentifier"];
                
                Class indexToAllocate = [bundle principalClassIncludingOtherLoadedBundles:YES];
                KTAbstractIndex *theIndex = [[((KTAbstractIndex *)[indexToAllocate alloc]) initWithPage:root plugin:plugin] autorelease];
                [root setIndex:theIndex];
            }
        }
        
        // Give it a Site Title based on the location
        NSString *siteName = [[NSFileManager defaultManager] displayNameAtPath:[[saveURL path] stringByDeletingPathExtension]];
        [master setSiteTitleHTML:siteName];
        
        
        // Set the Favicon
        NSString *faviconPath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
        KTMediaContainer *faviconMedia = [[root mediaManager] mediaContainerWithPath:faviconPath];
        [master setValue:[faviconMedia identifier] forKey:@"faviconMediaIdentifier"];
        
        
        // Make the initial Sandvox badge
        NSString *initialBadgeBundleID = [[NSUserDefaults standardUserDefaults] objectForKey:@"DefaultBadgeBundleIdentifier"];
        if (nil != initialBadgeBundleID && ![initialBadgeBundleID isEqualToString:@""])
        {
            KTElementPlugin *badgePlugin = [KTElementPlugin pluginWithIdentifier:initialBadgeBundleID];
            if (badgePlugin)
            {
                KTPagelet *pagelet = [KTPagelet pageletWithPage:root plugin:badgePlugin];
                [pagelet setPrefersBottom:YES];
            }
        }
        
        
        
        // Is this path a currently open document? if yes, close it!
		NSDocument *openDocument = [[NSDocumentController sharedDocumentController] documentForURL:saveURL];
		[openDocument close];   // Has no effect if openDocument is nil
        
        
        // We want the doc to have a presence on-disk before the user works with it
        if (![result saveToURL:saveURL ofType:[result fileType] forSaveOperation:NSSaveAsOperation error:outError])
        {
            result = nil;
        }
    }
    @finally
	{
		// Hide the progress window
		[progressPanel performClose:self];
        [progressPanel release];
	}
    
        
    
    return result;
}
    
- (IBAction)newDocShowHelp:(id)sender
{
	[[NSApp delegate] showHelpPage:@"Replacing_the_Home_Page_with_an_alternative_page_type"];		// HELPSTRING
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Document";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

#pragma mark -
#pragma mark Document Closing

/*  Normally, if there are 2 or more edited docs open, NSDocumentController asks the user what they want to do.
 *  We override this method to jump straight to asking each individual doc to close.
 */
- (void)reviewUnsavedDocumentsWithAlertTitle:(NSString *)title
                                 cancellable:(BOOL)cancellable
                                    delegate:(id)delegate
                        didReviewAllSelector:(SEL)didReviewAllSelector
                                 contextInfo:(void *)contextInfo
{
    // Act as if the user had chosen "Review..."
    if (delegate)
    {
        BOOL result = NO;
        
        NSInvocation *callback = [NSInvocation invocationWithMethodSignature:[delegate methodSignatureForSelector:didReviewAllSelector]];
        [callback setTarget:delegate];
        [callback setSelector:didReviewAllSelector];
        [callback setArgument:&self atIndex:2];                         // documentController:
        [callback setArgument:&result atIndex:3];                       // didReviewAll:
        if (contextInfo) [callback setArgument:&contextInfo atIndex:4]; // contextInfo:
        
        [callback invoke];
    }
    
    [self closeAllDocumentsWithDelegate:self didCloseAllSelector:@selector(documentController:didCloseAll:contextInfo:) contextInfo:NULL];
}

/*  The user tried to quit, and in response, all documents tried to close themselves. If that was successful and there are now no edited
 *  documents open, we can quit.
 */
- (void)documentController:(NSDocumentController *)docController didCloseAll:(BOOL)didCloseAll contextInfo:(void *)contextInfo
{
    if (didCloseAll && ![self hasEditedDocuments])
    {
        [NSApp terminate:self];
    }
}

#pragma mark -
#pragma mark Other

- (Class)documentClassForType:(NSString *)documentTypeName
{
    if ([kKTDocumentUTI_ORIGINAL isEqualToString:documentTypeName])
    {
        return [KTDataMigrationDocument class];
    }
    else
    {
        return [super documentClassForType:documentTypeName];
    }
}

/*  We're overriding this method so that 1.2.x documents are differentiated from the newer ones
 */
- (NSString *)typeForContentsOfURL:(NSURL *)inAbsoluteURL error:(NSError **)outError
{
    NSString *result = [super typeForContentsOfURL:inAbsoluteURL error:outError];
    
    if ([inAbsoluteURL isFileURL])
    {
        BOOL fileIsDirectory = YES;
        BOOL fileExists = [[NSFileManager defaultManager] fileExistsAtPath:[inAbsoluteURL path] isDirectory:&fileIsDirectory];
                           
        if (fileExists &&
            [[NSString UTIForFileAtPath:[inAbsoluteURL path]] conformsToUTI:kKTDocumentUTI_ORIGINAL] &&
            !fileIsDirectory)
        {
            result = kKTDocumentUTI_ORIGINAL;
        }
    }
    
    return result;
}

- (id)openDocumentWithContentsOfURL:(NSURL *)absoluteURL display:(BOOL)displayDocument error:(NSError **)outError
{
	LOG((@"opening document %@", [absoluteURL path]));
	// first, close any modal windows
	if ( nil != [NSApp modalWindow] )
	{
		[NSApp stopModalWithCode:NSAlertSecondButtonReturn]; // cancel
	}	
	
	NSString *requestedPath = [absoluteURL path];
    NSString *fileType = [self typeForContentsOfURL:absoluteURL error:outError];
	
	// are we opening a KTDocument?
	if (fileType && ([fileType isEqualToString:kKTDocumentType] || [fileType isEqualToString:kKTDocumentUTI_ORIGINAL]))
	{		
		// check compatibility with KTModelVersion
		NSDictionary *metadata = nil;
		@try
		{
			NSURL *datastoreURL = [KTDocument datastoreURLForDocumentURL:absoluteURL
                                                                    type:([fileType isEqualToString:kKTDocumentUTI_ORIGINAL] ? kKTDocumentUTI_ORIGINAL : kKTDocumentUTI)];
            
			metadata = [KTPersistentStoreCoordinator metadataForPersistentStoreWithURL:datastoreURL
                                                                                 error:outError];
		}
		@catch (NSException *exception)
		{
			// TJT got an NSInternalInconsistencyException, saying that the metadata XML was malformed
			// so we'll just catch that and treat it as if metadata was unreadable
			metadata = nil;
		}
		
		if (!metadata)
		{
			NSLog(@"error: ***Can't open %@ : unable to read metadata!", requestedPath);
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			
			NSString *description = NSLocalizedString(@"Unable to read document metadata.",
													  "error description: document metadata is unreadable");
			[userInfo setObject:description forKey:NSLocalizedDescriptionKey];
			
			NSString *reason = NSLocalizedString(@"\n\nSandvox was not able to read the document metadata.\n\nPlease contact Karelia Software by sending feedback from the 'Help' menu.",
												 "error reason: document metadata is unreadable");
			[userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
			
			[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
			
			if (outError)
			{
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
												code:NSPersistentStoreInvalidTypeError 
											userInfo:userInfo];
			}
			return nil;
		}
		
		NSString *modelVersion = [metadata valueForKey:kKTMetadataModelVersionKey];
		if (!modelVersion || [modelVersion isEqualToString:@""])
		{
			NSLog(@"error: ***Can't open %@ : no model version!", requestedPath);
			
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			
			NSString *description = NSLocalizedString(@"Unable to read document model information.",
													  "error description: document model version is unknown");
			[userInfo setObject:description forKey:NSLocalizedDescriptionKey];
			
			NSString *reason = NSLocalizedString(@"\n\nThis document appears to have an unknown document model.\n\nPlease contact Karelia Software by sending feedback from the 'Help' menu.",
												 "error reason: document model version is unknown");
			[userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
			
			[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
			
			if (outError)
			{
				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
												code:NSPersistentStoreInvalidTypeError 
											userInfo:userInfo];	
			}
			return nil;
		}

		
		if (![modelVersion isEqualToString:kKTModelVersion] && NO)
		{
			
		}
	}
	
	// by now, absoluteURL should be a good file, open it
	id document = [super openDocumentWithContentsOfURL:absoluteURL
											   display:displayDocument
												 error:outError];
	
	if ([document isKindOfClass:[KTPluginInstaller class]])
	{
		/// once we've created this "document" we don't want it hanging around
		[document performSelector:@selector(close)
					   withObject:nil 
					   afterDelay:0.0];
	}

	
	return document;
}

/*  Disallow the user from opening a Sandvox document that is in the Snapshots directory
 */
- (id)makeDocumentWithContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    Class docClass = [self documentClassForType:typeName];
    
    if ([docClass isSubclassOfClass:[KTDocument class]] &&
        [absoluteURL isSubpathOfURL:[docClass snapshotsDirectoryURL]])
    {
        if (outError)
        {
            *outError = [NSError errorWithDomain:kKareliaErrorDomain code:KareliaError
                            localizedDescription:NSLocalizedString(@"Documents cannot be opened while in the Snapshots folder.", "alert message")
                     localizedRecoverySuggestion:NSLocalizedString(@"Please move the document out of the Snapshots folder first.", "alert info")
                                 underlyingError:nil];
        }
        
        return nil;
    }
    
    return [super makeDocumentWithContentsOfURL:absoluteURL ofType:typeName error:outError];
}

#pragma mark -
#pragma mark Document List

- (void)synchronizeOpenDocumentsUserDefault
{
    NSMutableArray *aliases = [NSMutableArray array];
    NSEnumerator *enumerator = [[[NSDocumentController sharedDocumentController] documents] objectEnumerator];
    KTDocument *document;
    while ( ( document = [enumerator nextObject] ) )
    {
		if ([document isKindOfClass:[KTDocument class]])	// make sure it's a KTDocument
		{
			if ( [[[document fileName] pathExtension] isEqualToString:kKTDocumentExtension] 
				&& ![[document fileName] hasPrefix:[[NSBundle mainBundle] bundlePath]]  )
			{
				BDAlias *alias = [BDAlias aliasWithSubPath:[document fileName] relativeToPath:[NSHomeDirectory() stringByResolvingSymlinksInPath]];
				if (nil == alias)
				{
					// couldn't find relative to home directory, so just do absolute
					alias = [BDAlias aliasWithPath:[document fileName]];
				}
				if ( nil != alias )
				{
					NSData *aliasData = [[[alias aliasData] copy] autorelease];
					[aliases addObject:aliasData];
				}
			}
		}
    }
    [[NSUserDefaults standardUserDefaults] setObject:[NSArray arrayWithArray:aliases]
                                              forKey:@"KSOpenDocuments"];
	BOOL synchronized = [[NSUserDefaults standardUserDefaults] synchronize];
	if (!synchronized)
	{
		NSLog(@"Unable to synchronize defaults");
	}
}

/*	Remember any docs we open
 */
- (void)addDocument:(NSDocument *)document
{
	[super addDocument:document];
    
    [[KTPlaceholderController sharedController] hideWindow:self];
	[self synchronizeOpenDocumentsUserDefault];
    
    
    // Backup the doc as needed if the user requested it
    if ([document isKindOfClass:[KTDocument class]] &&
        [[NSUserDefaults standardUserDefaults] boolForKey:@"BackupOnOpening"])
    {
        [self addDocumentAwaitingBackup:(KTDocument *)document];
    }
}

/*	When a document is removed we don't want to reopen on launch, unless the close was part of the app quitting
 */
- (void)removeDocument:(NSDocument *)document
{
	[super removeDocument:document];
    
    // Stop backup monitoring if appropriate
    if ([document isKindOfClass:[KTDocument class]])
    {
        [self removeDocumentAwaitingBackup:(KTDocument *)document];
    }
    
    
    if (![NSApp isTerminating])
	{
		// Show the placeholder window when there are no docs open
        if ([[self documents] count] == 0)
        {
            [self showDocumentPlaceholderWindow:self];
        }
        
        // Record open doc list
        [self synchronizeOpenDocumentsUserDefault];
	}
}

#pragma mark -
#pragma mark Recent Documents

- (void)noteNewRecentDocument:(NSDocument *)aDocument
{
	// By default, NSDocument tries to register itself even if it's not in the documents list.
	if ([[self documents] containsObjectIdenticalTo:aDocument])
	{
		BOOL noteDocument = ![aDocument isKindOfClass:[KTPluginInstaller class]];
		
		if ([aDocument isKindOfClass:[KTDocument class]])
		{
			// we override here to prevent sample sites from being added to list
			NSURL *documentURL = [aDocument fileURL];
			NSString *documentPath = [documentURL path];
			
			NSString *samplesPath = [[NSBundle mainBundle] bundlePath];
			if ([documentPath hasPrefix:samplesPath])
			{
				noteDocument = NO;
			}
		}
		
		if (noteDocument)
		{
			[super noteNewRecentDocument:aDocument];
		}
	}
}

#pragma mark -
#pragma mark Backups

/*  We monitor documents in order to make a backup the first time a change will be saved
 */

- (NSArray *)documentsAwaitingBackup
{
    return [[myDocumentsAwaitingBackup copy] autorelease];
}

- (void)addDocumentAwaitingBackup:(KTDocument *)document
{
    [myDocumentsAwaitingBackup addObject:document];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(documentAwaitingBackupWillSave:)
                                                 name:KTDocumentWillSaveNotification
                                               object:document];
}

- (void)removeDocumentAwaitingBackup:(KTDocument *)document
{
    unsigned index = [myDocumentsAwaitingBackup indexOfObjectIdenticalTo:document];
    if (index != NSNotFound)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:KTDocumentWillSaveNotification
                                                      object:document];
        
        [myDocumentsAwaitingBackup removeObjectAtIndex:index];
    }
}

/*  The document's about to save. Make up the backup and then let the save continue
 */
- (void)documentAwaitingBackupWillSave:(NSNotification *)notification
{
    KTDocument *document = [notification object];
    OBASSERT(document);
    
    int backupOrSnapshotOnOpening = [[NSUserDefaults standardUserDefaults] integerForKey:@"BackupOnOpening"];
    switch (backupOrSnapshotOnOpening)
    {
        case KTSnapshotOnOpening:
        {
            if (![document backupToURL:[document snapshotURL] error:NULL])
            {
                NSLog(@"warning: unable to create snapshot of document %@", [[document fileURL] path]);
            }
            break;
        }
        case KTBackupOnOpening:
        {
            if (![document backupToURL:[document backupURL] error:NULL])
            {
                NSLog(@"warning: unable to create backup of document %@", [[document fileURL] path]);
            }			
            break;
        }
        default:
            break;
    }
    
    [self removeDocumentAwaitingBackup:document];
}

@end
