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
#import "SVApplicationController.h"

#import "Debug.h"

#import "Registration.h"


@implementation KTDocumentController

#pragma mark -
#pragma mark Document placeholder window

- (void)showDocumentPlaceholderWindowInitial:(BOOL)firstTimeSoReopenSavedDocuments;
{
    if (gLicenseViolation)		// license violation dialog should open, not the new/open
    {
        [[KSRegistrationController sharedController] showWindow:@"license"];		// string is just a tag for the source of this
    }
    else
    {
		[[SVWelcomeController sharedController] showWindowAndBringToFront:NO initial:firstTimeSoReopenSavedDocuments];
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
    
- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Document";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (NSError *)willPresentError:(NSError *)error
{
	NSError *result = [super willPresentError:error];
	return result;
}

#pragma mark -
#pragma mark Other

- (Class)documentClassForType:(NSString *)documentTypeName
{
    if ([kKTDocumentUTI_ORIGINAL isEqualToString:documentTypeName])
    {
        return nil;//[KTDataMigrationDocument class];
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
	// General error description to use if there are problems
	NSError *subError = nil;
	
    NSString *type = [self typeForContentsOfURL:absoluteURL error:outError];	// Should we ignore this error?
	
	// are we opening a KTDocument?
	if (type && ([type isEqualToString:kKTDocumentType] || [type isEqualToString:kKTDocumentUTI_ORIGINAL]))
	{		
		// check compatibility with KTModelVersion
		NSDictionary *metadata = nil;
		@try
		{
			NSURL *datastoreURL = [KTDocument datastoreURLForDocumentURL:absoluteURL
                                                                    type:([type isEqualToString:kKTDocumentUTI_ORIGINAL] ? kKTDocumentUTI_ORIGINAL : kKTDocumentUTI)];
            
			metadata = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:nil
                                                                                  URL:datastoreURL
                                                                                error:&subError];
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
			
			// Description is shown after an "unable to open..." sentence thanks to documentController.
			[userInfo setObject:NSLocalizedString(@"Metadata error.", @"brief description of error") forKey:NSLocalizedDescriptionKey];
			[userInfo setObject:requestedPath forKey:NSFilePathErrorKey];
			
			NSString *secondary = NSLocalizedString(@"Sandvox was not able to read the document metadata.\n\nPlease contact Karelia Software by sending feedback from the “Sandvox” menu.",
												 "error reason: document metadata is unreadable");
			[userInfo setObject:secondary forKey:NSLocalizedRecoverySuggestionErrorKey];
			[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
			[userInfo setObject:subError forKey:NSUnderlyingErrorKey];
			
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
						
			NSString *secondary = NSLocalizedString(@"This document appears to have an unknown document model.\n\nPlease contact Karelia Software by sending feedback from the 'Sandvox' menu.",
												 "error reason: document model version is unknown");
			[userInfo setObject:NSLocalizedString("Document model error.", @"brief description of error") forKey:NSLocalizedDescriptionKey];
			[userInfo setObject:secondary forKey:NSLocalizedRecoverySuggestionErrorKey];
			[userInfo setObject:requestedPath forKey:NSFilePathErrorKey];
			
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
				// TODO: What is this for?
		}
	}
	
	// by now, absoluteURL should be a good file, open it
	id document = [super openDocumentWithContentsOfURL:absoluteURL
											   display:displayDocument
												 error:&subError];
	if (subError && outError)
	{
		NSString *reasonOfSubError = [subError localizedFailureReason];
		if (!reasonOfSubError)	// Note:  above returns nil!
		{
			reasonOfSubError = [[subError userInfo] objectForKey:@"reason"];
		}
		if (!reasonOfSubError)
		{
			reasonOfSubError = [NSString stringWithFormat:NSLocalizedString(@"Error type: %@, code %d", @"information for an error"), [subError domain], [subError code]];
		}

		NSMutableDictionary *errorInfo = [NSMutableDictionary dictionary];
		[errorInfo setValue:NSLocalizedString(@"There is a problem with the document.", @"brief description of error.") forKey:NSLocalizedDescriptionKey];
		[errorInfo setValue:reasonOfSubError forKey:NSLocalizedRecoverySuggestionErrorKey];
		[errorInfo setValue:subError forKey:NSUnderlyingErrorKey];
		[errorInfo setObject:requestedPath forKey:NSFilePathErrorKey];

		if (outError)
		{
			*outError = [NSError errorWithDomain:[subError domain] 
											code:[subError code] 
										userInfo:errorInfo];
		}
	}
	
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
            [self showDocumentPlaceholderWindowInitial:NO];
        }
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
            
            if (![NSApp isTerminating])
            {
                [self synchronizeOpenDocumentsUserDefault];
            }
		}
	}
}

#pragma mark Inspectors

- (Class)inspectorClass;
{
    return [SVInspector class];
}

#pragma mark validation


- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	OBPRECONDITION(menuItem);
	OFF((@"KTDocumentController validateMenuItem:%@ %@", [menuItem title], NSStringFromSelector([menuItem action])));
	
	if (gLicenseViolation || [[NSApp delegate] appIsExpired])
	{
		return NO;	// No, don't let stuff be done if expired.
	}
	
	return [super validateMenuItem:menuItem];
}

@end
