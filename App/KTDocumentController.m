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
#import "KTSite.h"
#import "KTElementPlugin.h"
#import "KTIndexPlugin.h"
#import "SVInspector.h"
#import "KTMediaManager.h"
#import "KTMaster.h"
#import "KTPage+Internal.h"
#import "KTPagelet+Internal.h"
#import "SVWelcomeController.h"
#import "KTPluginInstaller.h"

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


@implementation KTDocumentController

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
		[[SVWelcomeController sharedController] showWindowAndBringToFront:NO];
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
	
    return [super makeUntitledDocumentOfType:typeName error:outError];
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
            
			metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil
                                                                                  URL:datastoreURL
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
    
    [[SVWelcomeController sharedController] hideWindow:self];
	[self synchronizeOpenDocumentsUserDefault];
}

/*	When a document is removed we don't want to reopen on launch, unless the close was part of the app quitting
 */
- (void)removeDocument:(NSDocument *)document
{
	[super removeDocument:document];
    
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

#pragma mark Inspectors

- (Class)inspectorClass;
{
    return [SVInspector class];
}

@end
