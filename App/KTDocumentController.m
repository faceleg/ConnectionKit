//
//  KTDocumentController.m
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDocumentController.h"

#import "KT.h"
#import "KTDataMigrator.h"
#import "KTDataMigrationDocument.h"
#import "KTDocument.h"
#import "KTPlaceholderController.h"
#import "KTPluginInstaller.h"
#import "KTPersistentStoreCoordinator.h"

#import "NSHelpManager+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSString+Karelia.h"
#import "NSWindowController+Karelia.h"

#import "BDAlias.h"
#import "KSApplication.h"
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

- (void)noteNewRecentDocument:(NSDocument *)aDocument
{
	if ([aDocument isKindOfClass:[KTDocument class]])
	{
		// we override here to prevent sample sites from being added to list
		NSURL *documentURL = [aDocument fileURL];
		NSString *documentPath = [documentURL path];
		
		NSString *samplesPath = [[NSBundle mainBundle] bundlePath];
		if ( ![documentPath hasPrefix:samplesPath] )
		{
			[super noteNewRecentDocument:aDocument];
		}
	}
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Document";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

#pragma mark -

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
    NSString *result;
    
    if ([inAbsoluteURL isFileURL] && [[NSString UTIForFileAtPath:[inAbsoluteURL path]] conformsToUTI:kKTDocumentUTI_ORIGINAL])
    {
        result = kKTDocumentUTI_ORIGINAL;
    }
    else
    {
        result = [super typeForContentsOfURL:inAbsoluteURL error:outError];
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
	NSString *UTI = [NSString UTIForFileAtPath:requestedPath];
	
	// are we opening a KTDocument (and not a sample site)?
	if ( ([UTI conformsToUTI:kKTDocumentUTI] || [UTI conformsToUTI:kKTDocumentUTI_ORIGINAL])
		 && ![requestedPath hasPrefix:[[NSBundle mainBundle] bundlePath]] )
	{		
		// check compatibility with KTModelVersion
		NSDictionary *metadata = nil;
		@try
		{
			NSURL *datastoreURL = [KTDocument datastoreURLForDocumentURL:absoluteURL UTI:UTI];
			metadata = [KTPersistentStoreCoordinator metadataForPersistentStoreWithURL:datastoreURL error:outError];
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
			
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
											code:NSPersistentStoreInvalidTypeError 
										userInfo:userInfo];
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
			
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
											code:NSPersistentStoreInvalidTypeError 
										userInfo:userInfo];										
			return nil;
		}

		
		if (![modelVersion isEqualToString:kKTModelVersion] && NO)
		{
			
		}
	}
	
	// by now, absoluteURL should be a good file, open it
// FIXME: this annoyingly shows the window on the screen, though we resize it later.  I'd rather NOT display it and show it later... how?
	id document = [super openDocumentWithContentsOfURL:absoluteURL
											   display:displayDocument
												 error:outError];
	
	// Set documents, such as sample sites, which live inside the application, as read-only.
	if ([document isKindOfClass:[KTDocument class]])
	{		
		// restore window position, if available
		NSRect contentRect = [document documentWindowContentRect];
		if ( !NSEqualRects(contentRect, NSZeroRect) )
		{
			NSWindow *window = [[document windowController] window];
			NSRect frameRect = [window frameRectForContentRect:contentRect];

			frameRect.size.width = MAX(frameRect.size.width, 800.0);
			frameRect.size.height = MAX(frameRect.size.height, 200.0);

			NSRect screenRect = [[window screen] visibleFrame];
			
			// make sure width and height will fit on screen
			if (frameRect.size.width > screenRect.size.width) frameRect.size.width = screenRect.size.width;
			if (frameRect.size.height > screenRect.size.height) frameRect.size.height = screenRect.size.height;
			// Make sure window's upper right will fit on screen by moving to lower/left if needed
			if (NSMaxX(frameRect) > NSMaxX(screenRect) || NSMinX(frameRect) < NSMinX(screenRect)) frameRect.origin.x = screenRect.origin.x;
			if (NSMaxY(frameRect) > NSMaxY(screenRect) || NSMinY(frameRect) < NSMinY(screenRect)) frameRect.origin.y = screenRect.origin.y;
			[window setFrame:frameRect display:YES];
		}		
	}
	else if ([document isKindOfClass:[KTPluginInstaller class]])
	{
		/// once we've created this "document" we don't want it hanging around
		[document performSelector:@selector(close)
					   withObject:nil 
					   afterDelay:0.0];
	}

	
	return document;
}


#pragma mark -

- (KTDocument *)lastSavedDocument
{
	NSLog(@"!!WARNING!! -lastSavedDocument called; please re-enable -setLastSavedDocument calls elsewhere in the app.");
	return myLastSavedDocumentWeakRef;
}

- (void)setLastSavedDocument:(KTDocument *)aDocument
{
	myLastSavedDocumentWeakRef = aDocument;
}

/*	We override the default behavior to not show the document initially
 */
- (IBAction)newDocument:(id)sender
{
	// Create the document and then close it
	NSError *error = nil;
	KTDocument *document = [self openUntitledDocumentAndDisplay:NO error:&error];
	
	if (document)
	{
		NSURL *docURL = [document fileURL];
		[document close];
		
		// Open the doc again at the end of the runloop
		[[NSApp delegate] performSelector:@selector(openDocumentWithContentsOfURL:) withObject:docURL afterDelay:0.0];
	}
	else if (error)
	{
		[NSApp presentError:error];
	}
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
#pragma mark Document placeholder window

- (IBAction)showDocumentPlaceholderWindow:(id)sender
{
    if (gLicenseViolation)		// license violation dialog should open, not the new/open
    {
        [[KSRegistrationController sharedController] showWindow:nil];
    }
    else
    {
		[[KTPlaceholderController sharedController] showWindowAndBringToFront:NO];
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
    
    [document createBackup];
    [self removeDocumentAwaitingBackup:document];
}

@end
