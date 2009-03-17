//
//  DownloadPageDelegate.m
//  Sandvox SDK
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//



// LocalizedStringInThisBundle(@"This display is a placeholder for this file:", "Informational text in the webview")
// LocalizedStringInThisBundle(@"Clicking on a link to this file will cause it to be downloaded in your browser.", "Informational text in the webview")
// LocalizedStringInThisBundle(@"No file specified", "Informational text in the webview")
// LocalizedStringInThisBundle(@"Use the Inspector to set the file and title of this page.", "Informational text in the webview")



#import "DownloadPageDelegate.h"

#import "SandvoxPlugin.h"
#import "BDAlias.h"


@implementation DownloadPageDelegate

#pragma mark -
#pragma mark Init & Dealloc

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (isNewObject)
	{
		[[self delegateOwner] setPluginHTMLIsFullPage:YES];
	}
	else	// Old download pages tend to have includeSidebar on. This disables it to properly sort the inspector.
	{
		[[self delegateOwner] setBool:NO forKey:@"includeSidebar"];
	}
	
    KTPage *page = [self delegateOwner];        // Somehow, some users have download pagelets
    if ([page isKindOfClass:[KTPage class]])    // (case 38904)
    {
        [page setFileExtensionIsEditable:NO];	// Transient property, so must set it each time
    }
    else if (page && [page isKindOfClass:[KTPagelet class]])
    {
        NSLog(@"Deleting unwanted Download PAGELET");
        [[(KTPagelet *)page page] removePagelet:(KTPagelet *)page];
        [[page managedObjectContext] deleteObject:page];
    }
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	KTMediaContainer *downloadMedia =
		[[self mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
	[self setDownloadMedia:downloadMedia];
}

#pragma mark -
#pragma mark Icons

- (void)plugin:(KTPage *)page didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
	if (![key isEqualToString:@"downloadMedia"]) return;
	
	
    
    // Page's file extension needs to match media
    NSString *mediaPath = [[(KTMediaContainer *)value file] currentPath];
    NSString *fileExtension = [mediaPath pathExtension];
    if (!fileExtension || [fileExtension isEqualToString:@""])
    {
        NSString *UTI = [NSString UTIForFileAtPath:mediaPath];
        if (UTI) fileExtension = [NSString filenameExtensionForUTI:UTI];
    }
    
    if ([fileExtension isEqualToString:@""]) fileExtension = nil;
    [page setCustomFileExtension:fileExtension];
    
    
    
    // Page path or filename should match media generally
    if ([page shouldUpdateFileNameWhenTitleChanges])
    {
        NSString *filename = [[[(KTMediaContainer *)value sourceAlias] lastKnownPath] lastPathComponent];
        NSString *legalizedFileName = [[filename stringByDeletingPathExtension] legalizedWebPublishingFileName];
        [page setFileName:legalizedFileName];
    }
    [page setCustomPathRelativeToSite:nil];
    
    
    
    // Set our page's thumbnail to match the file's Finder icon
	NSImage *finderIcon = [[NSWorkspace sharedWorkspace] iconForFile:[[value file] currentPath]];
	KTMediaContainer *iconMedia = [[self mediaManager] mediaContainerWithImage:finderIcon];
    [page setThumbnail:iconMedia];
    
    
    
    // Composite the download arrow onto the file's Finder icon
    NSString *UTI = [NSString UTIForFileAtPath:[[value file] currentPath]];
    NSImage *fileIcon = [[NSWorkspace sharedWorkspace] iconImageForUTI:UTI];
    
    NSString *overlayImagePath = [[self bundle] pathForImageResource:@"download-overlay"];
    NSImage *overlayImage = [[NSImage alloc] initWithContentsOfFile:overlayImagePath];
    
    NSImage *thumbnail = [[NSImage alloc] initWithSize:NSMakeSize(128.0, 128.0)];
    [thumbnail lockFocus];
    
    [fileIcon drawInRect:NSMakeRect(0.0, 0.0, 128.0, 128.0)
                fromRect:NSMakeRect(0.0, 0.0, [fileIcon size].width, [fileIcon size].height)
               operation:NSCompositeCopy
                fraction:1.0];
    
    [overlayImage drawInRect:NSMakeRect(0.0, 0.0, 128.0, 128.0)
                    fromRect:NSMakeRect(0.0, 0.0, [overlayImage size].width, [overlayImage size].height)
                   operation:NSCompositeSourceOver
                    fraction:1.0];
    
    [thumbnail unlockFocus];
    
    // Create the media container
    KTMediaContainer *thumbnailMedia = [[self mediaManager] mediaContainerWithImage:thumbnail];
    [[self delegateOwner] setCustomSiteOutlineIcon:thumbnailMedia];
    
    // Tidy up
    [overlayImage release];
    [thumbnail release];
}

/*	We already handled this ourselves, so return NO.
 */
- (BOOL)shouldMaskCustomSiteOutlinePageIcon:(KTPage *)page
{
	return NO;
}

#pragma mark -
#pragma mark Media Storage

- (NSSet *)requiredMediaIdentifiers
{
	NSSet *result = nil;
	
	KTMediaContainer *downloadMedia = [[self delegateOwner] valueForKey:@"downloadMedia"];
	if (downloadMedia)
	{
		result = [NSSet setWithObject:[downloadMedia identifier]];
	}
	
	return result;
}

- (IBAction)chooseFile:(id)sender
{
	NSOpenPanel *fileChooser = [NSOpenPanel openPanel];
	[fileChooser setCanChooseDirectories:NO];
	[fileChooser setAllowsMultipleSelection:NO];
	[fileChooser setPrompt:LocalizedStringInThisBundle(@"Choose", "choose button - open panel")];
	
// TODO: Open the panel at a reasonable location
	[fileChooser runModalForDirectory:nil
								 file:nil
								types:nil];
	
	NSArray *selectedPaths = [fileChooser filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
	KTMediaContainer *downloadMedia = [[self mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
	[self setDownloadMedia:downloadMedia];
}

- (BOOL)pathInfoField:(KSPathInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp
{
	BOOL fileShouldBeExternal = NO;
	if (dragOp & NSDragOperationLink)
	{
		fileShouldBeExternal = YES;
	}
	
	KTMediaContainer *downloadMedia =
		[[self mediaManager] mediaContainerWithDraggingInfo:sender preferExternalFile:fileShouldBeExternal];
	[self setDownloadMedia:downloadMedia];
	
	return YES;
}

/*	Our underlying media file should be uploaded either in place of the page, or to the usual location
 */
- (KTMediaFileUpload *)mediaFileUpload
{
	KTMediaFileUpload *result = nil;
	KTMediaFile *media = [[[self delegateOwner] valueForKey:@"downloadMedia"] file];
	
    NSURL *siteURL = [[[[self page] documentInfo] hostProperties] siteURL];
    NSString *path = [[[self page] URL] stringRelativeToURL:siteURL];
    if (path)
    {
        result = [media uploadForPath:path];
    }
	
    if (!result)
	{
		result = [media defaultUpload]; 
	}
	
	return result;
}

/*  Prompts the user if there's an issue with the media. Otherwise, stores it
 */
- (BOOL)setDownloadMedia:(KTMediaContainer *)media
{
    // We need a valid filename to upload from
    NSString *mediaPath = [[media file] currentPath];
    NSString *fileExtension = [mediaPath pathExtension];
    if (!fileExtension || [fileExtension isEqualToString:@""])
    {
        NSString *UTI = [NSString UTIForFileAtPath:mediaPath];
        if (UTI) fileExtension = [NSString filenameExtensionForUTI:UTI];
    }
    
    if (!fileExtension || [fileExtension isEqualToString:@""])
    {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:LocalizedStringInThisBundle(@"This file cannot be used for downloading as it has no filename extension.", "alert title")];
        [alert setInformativeText:LocalizedStringInThisBundle(@"Please select a different file or use the Finder to give the file an extension.", "alert info")];
        [alert addButtonWithTitle:@"OK"];
        [alert runModal];
		[alert release];
        
        return NO;
    }
    
    
    // Store the media
    [[self delegateOwner] setValue:media forKey:@"downloadMedia"];
    return YES;
}

#pragma mark -
#pragma mark WebView

- (NSString *)iconURL
{
	NSString *iconPath = [[self bundle] pathForImageResource:@"download"];
	NSString *result = [[NSURL fileURLWithPath:iconPath] absoluteString];
	return result;
}

- (NSString *)fileName
{
	NSString *result = [[NSFileManager defaultManager] displayNameAtPath:
		[[self delegateOwner] valueForKeyPath:@"downloadMedia.file.currentPath"]];
		
	return result;
}

/*	Users don't want to actually publish a Download page, they want its media instead.
 */
- (BOOL)pageShouldPublishHTMLTemplate:(KTPage *)page
{
	if ([page delegate] == self)
	{
		return NO;
	}
	else
	{
		return YES;
	}
}

#pragma mark -
#pragma mark Data Migrator

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    KTMediaContainer *downloadMedia = [[self mediaManager] mediaContainerWithMediaRefNamed:@"DownloadPage" element:oldPlugin];
    [[self delegateOwner] setValue:downloadMedia forKey:@"downloadMedia"];
    
    [[self delegateOwner] setValuesForKeysWithDictionary:oldPluginProperties];
    
    if (error) *error = nil;
    return YES;
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            NSFilenamesPboardType,
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)pasteboard
{
	if (nil != [pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pasteboard propertyListForType:NSFilenamesPboardType];
		return [fileNames count];
	}
	else
	{
		return 1;
	}
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    [pboard types];
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:dragIndex];
			if ( nil != fileName )
			{
				NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible
				
				if ( [NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeAppleProtectedMPEG4Audio] )
				{
					return KTSourcePriorityNone;	// disallow protected audio; don't try to play as audio
				}
			}
		}
		else
		{
			return KTSourcePriorityNone;	// no actual files
		}
	}
	return KTSourcePriorityMinimum;		// For a truly generic file.
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    NSArray *orderedTypes = [self supportedPasteboardTypesForCreatingPagelet:isCreatingPagelet];
    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
    
    if ( [bestType isEqualToString:NSFilenamesPboardType] )
    {
        NSArray *arrayFromData = [pasteboard propertyListForType:NSFilenamesPboardType];
        if (dragIndex < [arrayFromData count])
        {
            NSString *filePath = [arrayFromData objectAtIndex:dragIndex];
            
            [aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
            [aDictionary setValue:[[NSFileManager defaultManager] resolvedAliasPath:filePath]
                           forKey:kKTDataSourceFilePath];
            result = YES;
        }
    }
	return result;
}

@end
