//
//  KTPluginInstaller.m
//  Marvel
//
//  Created by Dan Wood on 3/9/06.
//  Copyright 2006 Biophony LLC. All rights reserved.
//

#import "KTPluginInstaller.h"


@implementation KTPluginInstaller

- (NSString *)windowNibName
{
    return nil;
}

- (BOOL)alertShowHelp:(NSAlert *)alert
{
	NSString *helpString = @"Installing_Sandvox_Plugins_and_Designs";		// HELPSTRING
	return [NSHelpManager gotoHelpAnchor:helpString];
}

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
	NSString *sourcePath = [absoluteURL path];

	NSArray *libraryPaths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
	NSString *destPath = [libraryPaths objectAtIndex:0];
	
	NSFileManager *fm = [NSFileManager defaultManager];
	(void) [fm createDirectoryAtPath:destPath attributes:nil];
	
	destPath = [destPath stringByAppendingPathComponent:[NSApplication applicationName]];
	(void) [fm createDirectoryAtPath:destPath attributes:nil];
	
	destPath = [destPath stringByAppendingPathComponent:[sourcePath lastPathComponent]];	
		
	if ([fm fileExistsAtPath:destPath] && ![sourcePath isEqualToString:destPath])
	{
		BOOL success = [fm removeFileAtPath:destPath handler:nil];
		LOG((@"success of removing:%d", success));
	}
	BOOL copied = [fm copyPath:sourcePath toPath:destPath handler:nil];
	if (copied)
	{
		NSString *message = NSLocalizedString(@"Plugin Installed",@"Alert Message Title");
		NSString *information = [NSString stringWithFormat:NSLocalizedString(@"The '%@' plugin '%@' was installed.\n\nYou may need to re-launch Sandvox to use it.",@"result of installation"), typeName, [sourcePath lastPathComponent]];

		NSAlert *alert = [NSAlert alertWithMessageText:message defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:information];
		
		[alert setShowsHelp:YES];
		[alert setDelegate:self];

		[alert setIcon:[[NSWorkspace sharedWorkspace] iconForFile:sourcePath]];
		[alert setAlertStyle:NSInformationalAlertStyle];
		[alert runModal];
	}
	else
	{
		if (nil != outError)
		{
			*outError = [NSError errorWithLocalizedDescription:
				[NSString stringWithFormat:NSLocalizedString(@"Unable to copy file to this directory: %@",@"error message"),
					[destPath stringByDeletingLastPathComponent]]];
		}
	}
	return (copied);
}

/// adding this here just in case this "document" ends up in the shared document list
- (NSManagedObjectContext *)managedObjectContext
{
	return nil;
}


@end
