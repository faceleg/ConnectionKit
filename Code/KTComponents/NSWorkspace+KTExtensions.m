//
//  NSWorkspace+KTExtensions.m
//  KTComponents
//
//  Copyright (c) 2004 Biophony LLC. All rights reserved.
//

#import "NSWorkspace+KTExtensions.h"

#import "KT.h"
#import "KTAbstractPlugin.h"		// for the benefit of L'izedStringInKTComponents macro
#import "NSImage+KTExtensions.h"
#import "NSString+KTExtensions.h"


@implementation NSWorkspace ( KTExtensions )

/*!	Wrapper around 'FindFolder' carbon call
*/
- (NSString *)folderWithType:(OSType)aFolderType
{
	UInt8	s[1024];
	FSRef	ref;
	
	if ( FSFindFolder( kOnAppropriateDisk, aFolderType, true,	// create if needed
                     &ref ) == noErr )
	{
		FSRefMakePath(&ref, (UInt8 *)s, (UInt32)sizeof(s));
		return [NSString stringWithUTF8String:(const char *)s];
		// not sure if s is in UTF8 encoding:
	}
	return nil;
}

- (NSString *)userSitesDirectory
{
	return [self folderWithType:kInternetSitesFolderType];
}


// let's make one for the ~/Documents directory, too
- (NSString *)userDocumentsDirectory
{
	return [self folderWithType:kDocumentsFolderType];
}

// and one for ~/.Trash, too
- (NSString *)userTrashDirectory
{
	return [self folderWithType:kTrashFolderType];
}



/*"	Attempt to open the given (web) URL, and complain if it couldn't be 
"*/

- (void)attemptToOpenWebURL:(NSURL *)inURL
{
	BOOL retry = YES;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	while (retry)
	{
		BOOL success = NO;
		if (nil != inURL)
		{
			if ([defaults boolForKey:@"urls in background"] && (NSAppKitVersionNumber > NSAppKitVersionNumber10_1))
			{
				NSArray *urlsArray;
				LSLaunchURLSpec urlSpec;
				
				urlsArray = [NSArray arrayWithObject: [inURL absoluteURL]];
				
				urlSpec.appURL = nil;
				urlSpec.itemURLs = (CFArrayRef) urlsArray;
				urlSpec.passThruParams = nil;
				
				// This makes it stay in the background.  Nil for regular behavior.
				urlSpec.launchFlags = kLSLaunchDontSwitch;
				//	urlSpec.launchFlags = nil;
				
				urlSpec.asyncRefCon = nil;
				
				OSStatus status = LSOpenFromURLSpec (&urlSpec, nil);
				success = (noErr == status);
			}
			else
			{
				success = [[NSWorkspace sharedWorkspace] openURL:[inURL absoluteURL]];
			}
        }
		
		if (success)
		{
			retry = NO;
		}
		else
		{
			int button = NSRunCriticalAlertPanel(
                                                 NSLocalizedString(@"Unable to Open Web URL",@"Title of alert"),
                                                 NSLocalizedString(@"The following URL could not be opened:\n\n%@\n\nThis may be an invalid Web URL, or perhaps your Mac may not be configured properly to open Web URLs. You can select and copy the URL above and paste it into your Web browser.",@"Message in alert"),
                                                 NSLocalizedString(@"Cancel",@""),
                                                 NSLocalizedString(@"Try Again",@""),
                                                 nil,
                                                 [inURL absoluteString]);
			
			retry = (0 == button);
		}
	}
}

- (NSImage *)iconImageForUTI:(NSString *)aUTI
{
	NSString *extension = [NSString filenameExtensionForUTI:aUTI];
	NSImage *result = [self iconForFileType:extension];
    [result normalizeSize];
	return result;
}

#pragma mark -
#pragma mark Launch Applications

- (NSString *)applicationForURL:(NSURL *)url
{
	NSURL *appURL = nil;
	LSGetApplicationForURL((CFURLRef)url, kLSRolesAll, NULL, (CFURLRef *)&appURL);
	
	NSString *result = [appURL path];
	
	[appURL release];	// For no particualrly good reason LSGetApplicationForURL retains the URL.
	return result;
}

- (BOOL)applicationWithBundleIdentifierIsLaunched:(NSString *)identifier
{
	NSArray *launchedApps = [[NSWorkspace sharedWorkspace] launchedApplications];
	NSArray *launchedAppIdentifiers = [launchedApps valueForKey:@"NSApplicationBundleIdentifier"];
	BOOL result = [launchedAppIdentifiers containsObject:identifier];
	return result;
}

- (void)setBundleBit:(BOOL)flag forFile:(NSString *)path
{
	FSRef fileRef;
	OSErr error = FSPathMakeRef((UInt8 *)[path fileSystemRepresentation], &fileRef, NULL);
	
	// Get the file's current info
	FSCatalogInfo fileInfo;
	if (!error)
	{
		error = FSGetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &fileInfo, NULL, NULL, NULL);
	}
	
	if (!error)
	{
		// Adjust the bundle bit
		FolderInfo *finderInfo = (FolderInfo *)fileInfo.finderInfo;
		if (flag) {
			finderInfo->finderFlags |= kHasBundle;
		}
		else {
			finderInfo->finderFlags &= ~kHasBundle;
		}
		
		// Set the altered flags of the file
		error = FSSetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &fileInfo);
	}
	
	if (error) {
		NSLog(@"OSError %i in -[NSWorkspace setBundleBit:forFile:]", error);
	}
}

@end
