//
//  KTDocumentController.m
//  Marvel
//
//  Created by Terrence Talbot on 9/20/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTDocumentController.h"
#import "KTPluginInstaller.h"
#import "SandvoxPrivate.h"
#import "Registration.h"
#import "KTDocument.h"

@implementation KTDocumentController

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	// LOG((@"asking document controller to validate menu item: %@", [menuItem title]));
	//return (!gLicenseViolation);
	
	if ( gLicenseViolation )
	{
		return NO;
	}
	else
	{
		return [super validateMenuItem:menuItem];
	}
}

- (id)init
{
	if ( ![super init] )
	{
		return nil;
	}
	
	//NSLog(@"substituting KTDocumentController for NSDocumentController");
	
	return self;
}

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
	if ( [NSString UTI:UTI conformsToUTI:kKTDocumentUTI] 
		 && ![requestedPath hasPrefix:[[NSBundle mainBundle] bundlePath]] )
	{		
		// check compatibility with KTModelVersion
		NSDictionary *metadata = nil;
		@try
		{
			NSURL *datastoreURL = [KTDocument datastoreURLForDocumentURL:absoluteURL];
			metadata = [KTPersistentStoreCoordinator metadataForPersistentStoreWithURL:datastoreURL error:outError];
		}
		@catch (NSException *exception)
		{
			// TJT got an NSInternalInconsistencyException, saying that the metadata XML was malformed
			// so we'll just catch that and treat it as if metadata was unreadable
			metadata = nil;
		}
		
		if ( nil == metadata )
		{
			LOG((@"***Can't open %@ : unable to read metadata!", requestedPath));
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
        if ( nil == modelVersion )
        {
            // backward compatibility with old key
            modelVersion = [metadata valueForKey:@"KTModelVersion"];
        }
		if ( (nil == modelVersion) || [modelVersion isEqualToString:@""] )
		{
			LOG((@"***Can't open %@ : no model version!", requestedPath));
			
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

		
		NSString *mainBundleVersion = [metadata valueForKey:kKTMetadataAppVersionKey];
        if ( nil == mainBundleVersion )
        {
            // backward compatibility with old key
            mainBundleVersion = [metadata valueForKey:@"KTMainBundleVersion"];
        }
		if ( ![modelVersion isEqualToString:kKTModelVersion] )
		{
			NSLog(@"error: only document with model %@ are supported in 1.5 until KTDataMigrator is re-examined.", kKTModelVersion);
			
			NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
			
			NSString *description = NSLocalizedString(@"This document is not compatible with this version of Sandvox.",
													  "error description: document is not compatible");
			[userInfo setObject:description forKey:NSLocalizedDescriptionKey];
			
			NSString *reason = NSLocalizedString(@"\n\nSandvox was not able to read the document. Its datamodel is not compatible. \n\nPlease contact Karelia Software by sending feedback from the 'Help' menu.",
												 "error reason: document model is not compatible");
			[userInfo setObject:reason forKey:NSLocalizedFailureReasonErrorKey];
			
			[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
			
			*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
											code:NSPersistentStoreInvalidTypeError 
										userInfo:userInfo];
			
			return nil;
//			NSString *fileNameWithExtension = [requestedPath lastPathComponent];
//			if ( ([modelVersion intValue] >= [kKTModelMinimumVersion intValue])
//				 && ([modelVersion intValue] <= [kKTModelMaximumVersion intValue]) )
//			{
//				NSString *renamedFileName = [KTDataMigrator renamedFileName:fileNameWithExtension modelVersion:modelVersion];
//				NSAlert *fileAlert = [NSAlert alertWithMessageText:NSLocalizedString(@"Outdated Document",
//																					 "Title of Warning Alert Panel") 
//													 defaultButton:NSLocalizedString(@"Upgrade Document",
//																					 "Upgrade Document button") 
//												   alternateButton:NSLocalizedString(@"Don\\U2019t Open",
//																					 "Don't Open button") 
//													   otherButton:nil 
//										 informativeTextWithFormat:NSLocalizedString(@"The document \\U201C%@\\U201D was saved with an older version of Sandvox. To open it, Sandvox must upgrade your document. Your original file will be renamed to %@. Are you sure you want to upgrade this document?",
//																					 "alert: The document was saved with an older version of Sandvox."), fileNameWithExtension, renamedFileName];
//				
//				[fileAlert setShowsHelp:YES];
//				[fileAlert setDelegate:self];
//				
//				int alertResult = [fileAlert runModal];
//				if ( NSOKButton == alertResult )
//				{
//					if ( ![KTDataMigrator upgradeDocumentWithURL:absoluteURL modelVersion:modelVersion error:outError] )
//					{
//						// move the renamedFileName back to the original path
//						NSFileManager *fm = [NSFileManager defaultManager];
//						NSString *originalPath = [absoluteURL path];
//						NSString *renamedPath = [KTDataMigrator renamedFileName:originalPath modelVersion:modelVersion];
//						if ( [fm fileExistsAtPath:originalPath] && [fm fileExistsAtPath:renamedPath] )
//						{
//							[fm removeFileAtPath:originalPath handler:nil];
//							[fm movePath:renamedPath toPath:originalPath handler:nil];
//						}
//						
//						// return an error to the user
//						NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
//						
//						NSString *description = NSLocalizedString(@"Unable to upgrade document.",
//																  "error description: Unable to upgrade document model.");
//						[userInfo setObject:description forKey:NSLocalizedDescriptionKey];
//						
//						NSString *reason = NSLocalizedString(@"\n\nSandvox (build %@) was unable to upgrade this document. Please contact Karelia Software by sending feedback from the 'Help' menu.",
//															 "error reason: Sandvox failed to updgrade document");
//						[userInfo setObject:[NSString stringWithFormat:reason, mainBundleVersion] 
//									 forKey:NSLocalizedFailureReasonErrorKey];
//						
//						[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
//						
//						*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
//														code:NSPersistentStoreInvalidTypeError 
//													userInfo:userInfo];										
//						return nil;
//					}
//				}
//				else
//				{
//					// the user cancelled, we don't really want to display an error
//					// but the document framework appears to crash if we don't :-(
//					// perhaps in the future Apple will correctly not present a panel
//					// for NSUserCancelledErrors (see FoundationErrors.h)
//					*outError = [NSError errorWithDomain:NSCocoaErrorDomain
//													code:NSUserCancelledError
//												userInfo:nil];
//					return nil;
//				}
//			}
//			else if ( [modelVersion intValue] < [kKTModelMinimumVersion intValue] )
//			{
//				// we can't support this version (too old)
//				NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
//				
//				NSString *description = NSLocalizedString(@"Unable to read document data model.",
//														  "error description: Unable to read document data model");
//				[userInfo setObject:description forKey:NSLocalizedDescriptionKey];
//				
//				NSString *reason = NSLocalizedString(@"\n\nThis document was saved with an older version of Sandvox (build %@). Unfortunately, it cannot be upgraded with this version of Sandvox.\n\nPlease contact Karelia Software by sending feedback from the 'Help' menu.",
//													 "error reason: The document cannot be upgraded.");
//				[userInfo setObject:[NSString stringWithFormat:reason, mainBundleVersion] 
//							 forKey:NSLocalizedFailureReasonErrorKey];
//				
//				[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
//				
//				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
//												code:NSPersistentStoreInvalidTypeError 
//											userInfo:userInfo];										
//				return nil;
//			}
//			else if ( [modelVersion intValue] > [kKTModelMaximumVersion intValue] )
//			{
//				// we can't support this version either (too new)
//				NSMutableDictionary *userInfo = [NSMutableDictionary dictionary];
//				
//				NSString *description = NSLocalizedString(@"Unable to read document data model.",
//														  "error description: Unable to read document data model");
//				[userInfo setObject:description forKey:NSLocalizedDescriptionKey];
//				
//				NSString *reason = NSLocalizedString(@"\n\nThis document was saved with a more recent version of Sandvox (build %@). Please upgrade Sandvox to the latest version.",
//													 "error reason: Sandvox needs to be upgraded.");
//				[userInfo setObject:[NSString stringWithFormat:reason, mainBundleVersion] 
//							 forKey:NSLocalizedFailureReasonErrorKey];
//				[userInfo setObject:[absoluteURL path] forKey:NSFilePathErrorKey];
//
//				*outError = [NSError errorWithDomain:NSCocoaErrorDomain 
//												code:NSPersistentStoreInvalidTypeError 
//											userInfo:userInfo];										
//				return nil;
//			}
		}
	}
	
	// by now, absoluteURL should be a good file, open it
// FIXME: this annoyingly shows the window on the screen, though we resize it later.  I'd rather NOT display it and show it later... how?
	id document = [super openDocumentWithContentsOfURL:absoluteURL
											   display:displayDocument
												 error:outError];
	
	// Set documents, such as sample sites, which live inside the application, as read-only.
	if ( [document isKindOfClass:[KTDocument class]] )
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
	else if ( [document isKindOfClass:[KTPluginInstaller class]] )
	{
		/// once we've created this "document" we don't want it hanging around
		[document performSelector:@selector(close)
					   withObject:nil 
					   afterDelay:0.0];
	}

	
	return document;
}

- (KTDocument *)lastSavedDocument
{
	return myLastSavedDocumentWeakRef;
}

- (void)setLastSavedDocument:(KTDocument *)aDocument
{
	myLastSavedDocumentWeakRef = aDocument;
}


@end
