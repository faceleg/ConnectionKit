//
//  KTMissingMediaController.m
//  Marvel
//
//  Created by Mike on 01/11/2007.
//  Copyright 2007-2009 Karelia Software. All rights reserved.
//

#import "KTMissingMediaController.h"

#import "KTMediaFile.h"
#import "KTExternalMediaFile.h"
#import "KTMediaManager+Internal.h"

#import "NSArray+Karelia.h"
#import "NSHelpManager+Karelia.h"
#import "NSObject+Karelia.h"

#import "BDAlias.h"


@interface NSString (KTMissingMediaController)
- (void)getCommonSourcePath:(NSString **)sourceDir andDestinationPath:(NSString **)destDir
			  forMoveToPath:(NSString *)destPath;
@end

@implementation  NSString (KTMissingMediaController)

- (void)getCommonSourcePath:(NSString **)sourceDir andDestinationPath:(NSString **)destDir
			  forMoveToPath:(NSString *)destPath
{
	if (sourceDir)
	{
		*sourceDir = self;
	}
	if (destDir)
	{
		*destDir = destPath;
	}
	
	NSArray *sourceComponents = [self pathComponents];
	NSArray *destComponents = [destPath pathComponents];
	
	unsigned maxIndex = MIN([sourceComponents count], [destComponents count]);
	unsigned i;
	for (i = 0; i < maxIndex; i++)
	{
		NSString *aSourceComponent = [sourceComponents objectAtReverseIndex:i];
		NSString *aDestComponent = [destComponents objectAtReverseIndex:i];
		if ([aSourceComponent isEqualToString:aDestComponent])
		{
			if (sourceDir)
			{
				*sourceDir = [*sourceDir stringByDeletingLastPathComponent];
			}
			if (destDir)
			{
				*destDir = [*destDir stringByDeletingLastPathComponent];
			}
		}
		else
		{
			return;
		}
	}
}

@end

@interface NSArray (KTMissingMediaController)
- (BOOL)hasPrefix:(NSArray *)prefix;
@end

@implementation NSArray (KTMissingMediaController)

- (BOOL)hasPrefix:(NSArray *)prefix
{
	BOOL result = NO;
	
	if ([self count] >= [prefix count])
	{
		result = [prefix isEqualToArray:[self subarrayWithRange:NSMakeRange(0, [prefix count])]];
	}
	
	return result;
}

@end


#pragma mark -


@implementation KTMissingMediaController

#pragma mark -
#pragma mark Init & Dealloc

+ (void)initialize
{
	NSValueTransformer *transformer = [[NSClassFromString(@"KTMediaNotFoundValueTransformer") alloc] init];
	[NSValueTransformer setValueTransformer:transformer forName:@"MediaFileFoundImage"];
	[transformer release];
}

- (void)dealloc
{
	[myMissingMedia release];
	[myMediaManager release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark IB Actions

/*	Try to locate similar missing media
 */
- (void)offerToLocateSimilarMissingMedia:(KTExternalMediaFile *)originalMediaFile newPath:(NSString *)newPath;
{
	NSMutableSet *mediaToMigrate = [NSMutableSet setWithObject:originalMediaFile];
	
	NSString *oldPath = [[originalMediaFile alias] lastKnownPath];
	newPath = [newPath stringByStandardizingPath];
	
	
	// What directory are we moving the file(s) from and to?
	NSString *sourceDir;
	NSString *destDir;
	[oldPath getCommonSourcePath:&sourceDir andDestinationPath:&destDir forMoveToPath:newPath];
	
	NSArray *sourceDirComponents = [sourceDir pathComponents];
	NSArray *destDirComponents = [destDir pathComponents];
	unsigned sharedSuffixComponentCount = [[oldPath pathComponents] count] - [sourceDirComponents count];
	
	
	// Look for other missing media with the same path prefix and that exist in the possible new location
	NSMutableSet *similarMissingMedia = [NSMutableSet set];
	NSEnumerator *missingMediaEnumerator = [[self missingMedia] objectEnumerator];
	KTExternalMediaFile *aMediaFile;
	while (aMediaFile = [missingMediaEnumerator nextObject])
	{
		if ([aMediaFile isKindOfClass:[KTExternalMediaFile class]])
        {
            NSString *lastKnownPath = [[aMediaFile alias] lastKnownPath];
            NSArray *lastKnownPathComponents = [lastKnownPath pathComponents];
            
            if (aMediaFile != originalMediaFile &&
                [lastKnownPathComponents hasPrefix:sourceDirComponents] &&
                ![[aMediaFile alias] fullPath])
            {
                unsigned relPathRangeLen = MIN(sharedSuffixComponentCount, [lastKnownPathComponents count] - [sourceDirComponents count]);
                NSRange relativePathRange = NSMakeRange([sourceDirComponents count], relPathRangeLen);
                NSArray *relativePathComponents = [lastKnownPathComponents subarrayWithRange:relativePathRange];
                NSArray *destPathComponents = [destDirComponents arrayByAddingObjectsFromArray:relativePathComponents];
                NSString *possibleNewPath = [NSString pathWithComponents:destPathComponents];
                
                if ([[NSFileManager defaultManager] fileExistsAtPath:possibleNewPath]) {
                    [similarMissingMedia addObject:aMediaFile];
                }
            }
        }
	}
	
	
	// Ask the user if they want to also move those similar files
	NSString *localizedTitle = nil;
	NSString *localizedMessage = nil;
	NSString *OKButtonTitle = nil;
	if ([similarMissingMedia count] == 1)
	{
		localizedTitle = NSLocalizedString(@"Another missing media file has been found in the same location.", "Prompt when offering to locate other missing media files.");
		localizedMessage = NSLocalizedString(@"Would you like to use it as well?", "Informative text when offering to locate other missing media files");
		OKButtonTitle = NSLocalizedString(@"Accept Other File", "Button to accept other automatically found media");
	}
	else if ([similarMissingMedia count] > 1)
	{
		localizedTitle = NSLocalizedString(@"Other missing media files have been found in the same location.", "Prompt when offering to locate other missing media files.");
		localizedMessage = NSLocalizedString(@"Would you like to use them as well?", "Informative text when offering to locate other missing media files");
		OKButtonTitle = NSLocalizedString(@"Accept Other Files", "Button to accept other automatically found media");
	}
	
	if ([similarMissingMedia count] > 0)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:localizedTitle
										 defaultButton:OKButtonTitle
									   alternateButton:NSLocalizedString(@"Only This File", "Button to ignore other automatically found media")
										   otherButton:nil
							 informativeTextWithFormat:localizedMessage];
		
		if ([alert runModal] == NSAlertDefaultReturn)
		{
			[mediaToMigrate unionSet:similarMissingMedia];
		}
	}
	
	
	// Do the migration
	NSEnumerator *migrationEnumerator = [mediaToMigrate objectEnumerator];
	while (aMediaFile = [migrationEnumerator nextObject])
	{
		NSString *lastKnownPath = [[aMediaFile alias] lastKnownPath];
		NSArray *lastKnownPathComponents = [lastKnownPath pathComponents];
		unsigned relPathRangeLen = MIN(sharedSuffixComponentCount, [lastKnownPathComponents count] - [sourceDirComponents count]);
		NSRange relativePathRange = NSMakeRange([sourceDirComponents count], relPathRangeLen);
		NSArray *relativePathComponents = [lastKnownPathComponents subarrayWithRange:relativePathRange];
		NSArray *destPathComponents = [destDirComponents arrayByAddingObjectsFromArray:relativePathComponents];
		NSString *path = [NSString pathWithComponents:destPathComponents];
			
			// Create a new MediaFile and migrate MediaContainers to it
		KTMediaFile *newMediaFile = [[self mediaManager] mediaFileWithPath:path];
		[[newMediaFile mutableSetValueForKey:@"containers"] unionSet:[aMediaFile valueForKey:@"containers"]];
		
		// Replace the item in our missing media list with the new one.
		NSMutableArray *missingMedia = [self mutableArrayValueForKey:@"missingMedia"];
		unsigned index = [missingMedia indexOfObjectIdenticalTo:aMediaFile];
		[missingMedia replaceObjectAtIndex:index withObject:newMediaFile];
	}
}

- (IBAction)findSelectedMediaFile:(id)sender
{
	// The delay is to make sure the NSArrayController's selection is in sync
	[self performSelector:@selector(findSelectedMediaFile) withObject:nil afterDelay:0.0];
}

- (void)findSelectedMediaFile
{
	KTMediaFile *mediaFile = [[oMediaArrayController selectedObjects] objectAtIndex:0];
	
	// Display the open panel allowing the user to find the replacement file
	NSOpenPanel *panel = [NSOpenPanel openPanel];
	[panel setCanChooseDirectories:NO];
	[panel setTreatsFilePackagesAsDirectories:YES];

	
	NSString *fileExtension = [[mediaFile filename] pathExtension];
	int returnCode = [panel runModalForTypes:[NSArray arrayWithObject:fileExtension]];
	
	if (returnCode == NSOKButton && [mediaFile isKindOfClass:[KTExternalMediaFile class]])
	{
		[self offerToLocateSimilarMissingMedia:(KTExternalMediaFile *)mediaFile newPath:[panel filename]];
	}
}

- (IBAction)continueOpening:(id)sender
{
	[NSApp endSheet:[self window] returnCode:1];
}

- (IBAction)cancel:(id)sender
{
	[NSApp endSheet:[self window] returnCode:0];
}

- (IBAction)showHelp:(id)sender
{
	[NSHelpManager gotoHelpAnchor:@"Locating Missing Media Files"];	// HELPSTRING
}

#pragma mark -
#pragma mark Accessors

- (KTMediaManager *)mediaManager { return myMediaManager; }

- (void)setMediaManager:(KTMediaManager *)mediaManager
{
	[mediaManager retain];
	[myMediaManager release];
	myMediaManager = mediaManager;
}

- (NSArray *)missingMedia { return myMissingMedia; }

- (void)setMissingMedia:(NSArray *)media
{
	media = [media copy];
	[myMissingMedia release];
	myMissingMedia = media;
}

@end


@interface KTMediaNotFoundValueTransformer : NSValueTransformer
@end
@implementation KTMediaNotFoundValueTransformer

+ (BOOL)allowsReverseTransformation { return NO; }

+ (Class)transformedValueClass { return [NSImage class]; }

- (id)transformedValue:(id)value
{
	NSImage *result = nil;
	
	if (!value || [value isEqual:[[NSBundle mainBundle] pathForImageResource:@"qmark"]])
	{
		result = [[NSWorkspace sharedWorkspace] iconForFileType:NSFileTypeForHFSTypeCode(kAlertCautionIcon)];
	}
	else
	{
		NSString *path = [[NSBundle mainBundle] pathForResource:@"upload_complete" ofType:@"png"];
		result = [[[NSImage alloc] initWithContentsOfFile:path] autorelease];
	}
	return result;
}

@end


#pragma mark -


@interface BDAlias (MissingMedia)
- (NSString *)filename;
@end


@implementation BDAlias (MissingMedia)

- (NSString *)filename
{
    NSString *result = [[self lastKnownPath] lastPathComponent];
    return result;
}

@end