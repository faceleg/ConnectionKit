//
//  ImageElementDelegate.m
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

#import "ImageElementDelegate.h"

#import <Sandvox.h>
#import <KTDesign.h>
#import <KTMaster.h>
#import <KTMediaContainer.h>
#import <KTAbstractMediaFile.h>
#import <KTPathInfoField.h>

#import <NSMutableSet+KTExtensions.h>

#import <QuartzCore/QuartzCore.h>


// LocalizedStringInThisBundle(@"Please use the Inspector to enter the URL of an image", "Prompt when no URL has been entered")
// LocalizedStringInThisBundle(@"Order prints of this image from dotphoto.com", "Title of dot photo link");
// LocalizedStringInThisBundle(@"dotphoto", "alt text of dot photo link");
// LocalizedStringInThisBundle(@"View this image full-size", "Title of mag link");
// LocalizedStringInThisBundle(@"magnify", "alt text of mag link");


@interface ImageElementDelegate (Private)
- (void)updateDependentThumbnailsFrom:(KTAbstractMediaFile *)oldFile to:(KTAbstractMediaFile *)newFile;

- (NSSize)boundingImageBox;
- (NSString *)placeholderImagePath;
@end


#pragma mark -


@implementation ImageElementDelegate

#pragma mark -
#pragma mark Initialization

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
    
	if ( isNewObject )
	{
		// set default properties
		[[self delegateOwner] setValue:[NSNumber numberWithInt:AutomaticSize] forKey:@"imageSize"];
		
		BOOL shouldIncludeLinkInitially = [[NSUserDefaults standardUserDefaults] boolForKey:@"shouldIncludeLink"];
		[[self delegateOwner] setValue:[NSNumber numberWithBool:shouldIncludeLinkInitially] forKey:@"shouldIncludeLink"];
        
		BOOL shouldLinktoOriginalInitially = [[NSUserDefaults standardUserDefaults] boolForKey:@"linkImageToOriginal"];
		[[self delegateOwner] setValue:[NSNumber numberWithBool:shouldLinktoOriginalInitially] forKey:@"linkImageToOriginal"];
        
		BOOL shouldUseExternalImage = [[NSUserDefaults standardUserDefaults] boolForKey:@"preferExternalImage"];
		[[self delegateOwner] setValue:[NSNumber numberWithBool:shouldUseExternalImage] forKey:@"preferExternalImage"];
	}
}

- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
    
    // Add the dragged image into the DB
	KTMediaContainer *image =
		[[[self delegateOwner] mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
	
	[[self delegateOwner] setValue:image forKey:@"image"];
	
	
	// grab any other properties from aDragSourceDictionary
	NSString *title = [aDataSourceDictionary valueForKey:kKTDataSourceTitle];
	if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		title = [[aDataSourceDictionary valueForKey:kKTDataSourceFileName] stringByDeletingPathExtension];
	}
	if (nil != title)
	{
		[[self delegateOwner] setObject:title forKey:@"altText"];
	}
    
	if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceImageURLString])
	{
		[[self delegateOwner] setObject:[aDataSourceDictionary objectForKey:kKTDataSourceImageURLString] forKey:@"externalImageURL"];
	}
    
	if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceURLString])
	{
		[[self delegateOwner] setObject:[aDataSourceDictionary objectForKey:kKTDataSourceURLString] forKey:@"externalURL"];
	}
    
	if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceCaption])
	{
		[[self delegateOwner] setObject:[[aDataSourceDictionary objectForKey:kKTDataSourceCaption] escapedEntities] forKey:@"captionHTML"];
	}
	
	// override defaults if set in aDragSourceDictionary
	if (nil != [aDataSourceDictionary objectForKey:@"kKTDataSourcePreferExternalImageFlag"])
	{
		[[self delegateOwner] setValue:[aDataSourceDictionary objectForKey:@"kKTDataSourcePreferExternalImageFlag"] forKey:@"preferExternalImage"];
	}
    
	if (nil != [aDataSourceDictionary objectForKey:@"kKTDataSourceShouldIncludeLinkFlag"])
	{
		[[self delegateOwner] setValue:[aDataSourceDictionary objectForKey:@"kKTDataSourceShouldIncludeLinkFlag"] forKey:@"shouldIncludeLink"];
	}
    
	if (nil != [aDataSourceDictionary objectForKey:@"kKTDataSourceLinkToOriginalFlag"])
	{
		[[self delegateOwner] setValue:[aDataSourceDictionary objectForKey:@"kKTDataSourceLinkToOriginalFlag"] forKey:@"linkImageToOriginal"];
	}
}

- (void)dealloc
{
	[myImage release];
	[myImagePath release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Plugin

/*	When a user updates one of these settings, update the defaults accordingly
 */
- (void)setDelegateOwner:(id)plugin
{
	NSSet *keyPaths = [NSSet setWithObjects:@"shouldIncludeLink", @"linkImageToOriginal", @"preferExternalImage", nil];
	
	[[self delegateOwner] removeObserver:self forKeyPaths:keyPaths];
	[super setDelegateOwner:plugin];
	[plugin addObserver:self forKeyPaths:keyPaths options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [self delegateOwner])
	{
		id newValue = [change objectForKey:NSKeyValueChangeNewKey];
		if (newValue && newValue != [NSNull null])
		{
			if ([keyPath isEqualToString:@"preferExternalImage"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"preferExternalImage"];
			}
			
			if ([keyPath isEqualToString:@"shouldIncludeLink"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"shouldIncludeLink"];
			}
			
			if ([keyPath isEqualToString:@"linkImageToOriginal"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"linkImageToOriginal"];
			}
		}
	}
}

#pragma mark -
#pragma mark Media Storage

- (void)plugin:(KTAbstractPlugin *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
	if ([key isEqualToString:@"image"])
	{
		// If being used in a Page plugin, update the page's thumbnail (if appropriate) and Site Outline icon
		id container = [[self delegateOwner] container];
		if ([container isKindOfClass:[KTPage class]])
		{
			if ([container thumbnail] == oldValue) {
				[container setThumbnail:value];
			}
			
			[container setCustomSiteOutlineIcon:value];
		}
	}
}

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet setWithCapacity:2];
	
	KTMediaContainer *image = [[self delegateOwner] valueForKey:@"image"];
	[result addObjectIgnoringNil:[image identifier]];
	
	// Scaled image
	KTMediaContainer *scaledImage = [image imageToFitSize:[self boundingImageBox]];
	[result addObjectIgnoringNil:[scaledImage identifier]];
	
	return result;
}

- (IBAction)chooseImage:(id)sender
{
	NSOpenPanel *imageChooser = [NSOpenPanel openPanel];
	[imageChooser setCanChooseDirectories:NO];
	[imageChooser setAllowsMultipleSelection:NO];
	[imageChooser setPrompt:LocalizedStringInThisBundle(@"Choose", "choose button - open panel")];
	
// TODO: Open the panel at a reasonable location
	[imageChooser runModalForDirectory:nil
								  file:nil
								 types:[NSImage imageFileTypes]];
	
	NSArray *selectedPaths = [imageChooser filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
	KTMediaContainer *image =
		[[[self delegateOwner] mediaManager] mediaContainerWithPath:[selectedPaths firstObject]];
	
	[[self delegateOwner] setValue:image forKey:@"image"];
}

- (BOOL)pathInfoField:(KTPathInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp
{
	BOOL fileShouldBeExternal = NO;
	if (dragOp & NSDragOperationLink)
	{
		fileShouldBeExternal = YES;
	}
	
	KTMediaContainer *image = [[[self delegateOwner] mediaManager] mediaContainerWithDraggingInfo:sender
																				  preferExternalFile:fileShouldBeExternal];
																				  
	[[self delegateOwner] setValue:image forKey:@"image"];
	
	return YES;
}

/*	We want to support all image types
 */
- (NSArray *)supportedDragTypesForPathInfoField:(KTPathInfoField *)pathInfoField
{
	return [NSImage imagePasteboardTypes];
}

- (BOOL)pathInfoField:(KTPathInfoField *)filed shouldAllowFileDrop:(NSString *)path
{
	BOOL result = NO;
	
	if ([NSString UTI:[NSString UTIForFileAtPath:path] conformsToUTI:(NSString *)kUTTypeImage])
	{
		result = YES;
	} 
	
	return result;
}

#pragma mark -
#pragma mark HTML Generation

/*	This depends on the chosen image and other factors.
 *	Returns nil if linking is disabled.
 */
- (NSString *)linkURL
{
	NSString *result = nil;
	
	if ([[[self delegateOwner] valueForKey:@"shouldIncludeLink"] boolValue])
	{
		if ([[[self delegateOwner] valueForKey:@"linkImageToOriginal"] boolValue])
		{
			if ([[self delegateOwner] boolForKey:@"preferExternalImage"])
			{
				// Just link straight back to the image's source
				result = [[self delegateOwner] valueForKey:@"externalImageURL"];
			}
			else
			{
				NSString *path = [[self delegateOwner] valueForKeyPath:@"image.file.currentPath"];
				if (path)
				{
					result = [[NSURL fileURLWithPath:path] absoluteString];
				}
			}
		}
		else
		{
			// Link to the user-specified URL
			result = [[self delegateOwner] valueForKey:@"externalURL"];
		}
	}
	
	return result;
}

/*	Depending on how we're being used, the image must fit within a certain bounding box.
 *	e.g. A Photo pagelet has a much smaller box to fit in.
 */
- (NSSize)boundingImageBox
{
	NSSize result = NSZeroSize;
	
	id container = [[self delegateOwner] container];
	if ([container isKindOfClass:[KTPagelet class]])
	{
		// we're in a pagelet
		result = [[[(KTPage *)[container page] master] design] maximumMediaSizeForUse:@"KTPageletMedia"];
	}
	else if ([container isKindOfClass:[KTPage class]])
	{
		if ([container includeSidebar])
		{
			result = [[[container master] design] maximumMediaSizeForUse:@"KTSidebarPageMedia"];
		}
		else
		{
			result = [[[container master] design] maximumMediaSizeForUse:@"KTPageMedia"];
		}
	}
	
	return result;
}

#pragma mark Placeholder

- (float)placeholderScaling
{
	NSURL *placeholderURL = [NSURL fileURLWithPath:[self placeholderImagePath]];
	CIImage *placeholderImage = [[CIImage alloc] initWithContentsOfURL:placeholderURL];
	CGSize placeholderCGSize = [placeholderImage extent].size;
	NSSize placeholderSize = (*(NSSize *)&(placeholderCGSize));
	
	float result = [KTAbstractMediaFile scaleFactorOfSize:placeholderSize toFitSize:[self boundingImageBox]];
	
	[placeholderImage release];
	return result;
}

/*	For use when there is no photo selected; generate the approrpriate svximage:// URL to get the placeholder image
 */
- (NSString *)placeholderImagePath
{
	NSString *result = [[[[self page] master] design] placeholderImagePath];
	if (!result || [result isEqualToString:@""])
	{
		result = [[self bundle] pathForImageResource:@"placeholder"];
	}
	
	return result;
}

- (NSString *)placeholderImage
{
	NSString *placeholderPath = [self placeholderImagePath];
	NSURL *basicPlaceholderURL = [NSURL fileURLWithPath:placeholderPath];
	
	NSURL *uneditedURL = [[[NSURL alloc] initWithScheme:@"svximage"
												   host:[basicPlaceholderURL host]
												   path:[basicPlaceholderURL path]] autorelease];
	
	NSString *resultString = [[uneditedURL absoluteString] stringByAppendingFormat:@"?scale=%f&placeholder=yes",
																				   [self placeholderScaling]];
	
	return [NSURL URLWithString:resultString];
}

#pragma mark -
#pragma mark Resources

- (NSString *)dotphotoResource
{
	return [[self bundle] pathForImageResource:@"dotphoto"];
}


- (NSString *)magResource
{
	return [[self bundle] pathForImageResource:@"mag"];
}

@end
