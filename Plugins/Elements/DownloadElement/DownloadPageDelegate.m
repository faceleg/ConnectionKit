//
//  DownloadPageDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
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
	
	[(KTPage *)[self delegateOwner] setFileExtensionIsEditable:NO];	// Transient property, so must set it each time
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	KTMediaContainer *downloadMedia =
		[[self mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
	[[self delegateOwner] setValue:downloadMedia forKey:@"downloadMedia"];
}

#pragma mark -
#pragma mark Icons

- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
	if ([key isEqualToString:@"downloadMedia"])
	{
		// Turn on page replacement (it's off for imported pages)
		[plugin setBool:YES forKey:@"uploadMediaInPlaceOfPage"];
		
        
		
		// Page's file extension needs to match media
		NSString *fileExtension = [[[(KTMediaContainer *)value file] currentPath] pathExtension];
		[(KTPage *)plugin setCustomFileExtension:fileExtension];
		
        
        
        // Page path or filename should match media generally
		if ([(KTPage *)plugin shouldUpdateFileNameWhenTitleChanges])
        {
            NSString *filename = [[[(KTMediaContainer *)value sourceAlias] lastKnownPath] lastPathComponent];
            NSString *legalizedFileName = [[filename stringByDeletingPathExtension] legalizedWebPublishingFileName];
            [(KTPage *)plugin setFileName:legalizedFileName];
        }
        [(KTPage *)plugin setCustomPathRelativeToSite:nil];
		
		
                
		// Set our page's thumbnail to match the file's Finder icon
		[(KTPage *)plugin setThumbnail:[value imageWithScaleFactor:1.0]];
		
                
		
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
}

/*	We already handle this ourselves, so return NO.
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
	[[self delegateOwner] setValue:downloadMedia forKey:@"downloadMedia"];
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
	[[self delegateOwner] setValue:downloadMedia forKey:@"downloadMedia"];
	
	return YES;
}

/*	Our underlying media file should be uploaded either in place of the page, or to the usual location
 */
- (KTMediaFileUpload *)mediaFileUpload
{
	KTMediaFileUpload *result = nil;
	KTMediaFile *media = [[[self delegateOwner] valueForKey:@"downloadMedia"] file];
	
	if ([[self delegateOwner] boolForKey:@"uploadMediaInPlaceOfPage"])
	{
		NSURL *siteURL = [[[[self page] documentInfo] hostProperties] siteURL];
		NSString *path = [[[self page] URL] stringRelativeToURL:siteURL];
        if (path)
        {
            result = [media uploadForPath:path];
        }
	}
	
    if (!result)
	{
		result = [media defaultUpload]; 
	}
	
	return result;
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
    
    *error = nil;
    return YES;
}

@end
