//
//  KTImageView.m
//  KTComponents
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
//


#import "KTImageView.h"

#import "Debug.h"
//#import "ImageCropperController.h"
#import "KT.h"
#import "KTDataSourceProtocol.h"

#import "NSBitmapImageRep+Karelia.h"
#import "NSFileManager+Karelia.h"
#import "NSImage+Karelia.h"
//#import "NSImagePicker.h"		// OLD
#import "NSString+Karelia.h"
#import <WebKit/WebKit.h>


@interface KTImageView ()
//- (void)setFileName:(NSString *)aPath;
//- (void)pickSomeoneWithNewCropper:(id)sender;
- (id)delegateForSelector:(SEL)aSelector;
- (void)tellDelegate;
@end


@implementation KTImageView

#pragma mark awake

- (void)awakeFromNib
{
	[self setAllowsCutCopyPaste:NO];
}

#pragma mark accessors

- (NSDictionary *)dataSourceDictionary
{
    return myDataSourceDictionary; 
}

- (void)setDataSourceDictionary:(NSDictionary *)aDataSourceDictionary
{
    [aDataSourceDictionary retain];
    [myDataSourceDictionary release];
    myDataSourceDictionary = aDataSourceDictionary;
}

- (id)delegate
{
    return delegate;
}

- (void)setDelegate:(id)anObject
{
    delegate = anObject; // weak reference
}

- (NSString *)windowTitle
{
    return myWindowTitle; 
}

- (void)setWindowTitle:(NSString *)aWindowTitle
{
    [aWindowTitle retain];
    [myWindowTitle release];
    myWindowTitle = aWindowTitle;
}

#pragma mark actions

- (IBAction)removeImage:(id)sender
{
    // what if we want the underlying object just to display something else rather than No Image?
	NSDictionary *dataSourceDictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"Remove Image", kKTDataSourceNil, nil];
	[self setDataSourceDictionary:dataSourceDictionary];
		
	[self tellDelegate];
	
	NSImage *image = nil;
	
	SEL imageSelector = @selector(imageForImageView:);
	id imageDelegate = [self delegateForSelector:imageSelector];
	image = [imageDelegate imageForImageView:self];
	
	if ( nil != image )
	{
		// let delegate set image
		[self setImage:image];
	}
	else
	{
		// clear image to placeholder
		NSSize viewSize = [self bounds].size;
		if ( viewSize.width > 32.0 )
		{
			[self setImage:nil]; // [NSImage noImageImage]];
		}
		else
		{
			[self setImage:nil]; // [NSImage noneImage]];
		}
	}
}

// for binding to X button
- (BOOL)isNoImage
{
    NSImage *image = [self image];
    BOOL result = ( (nil == image) ); // || [image isEqual:[NSImage noImageImage]] || [image isEqual:[NSImage noneImage]]);
    return result;
}

/*	Rather sneaky hack to ensure DPIs are NOT respected.
 */
- (void)drawRect:(NSRect)aRect
{
	[[self image] normalizeSize];
	[super drawRect:aRect];
}

#pragma mark delegate utilities

/*! searches delegate, then controller's content, then controller's content's delegate */
- (id)delegateForSelector:(SEL)aSelector
{
	id actualDelegate = nil;
	
	// check IB delegate
	if ( (nil != delegate) && [delegate respondsToSelector:aSelector] )
	{
		actualDelegate = delegate;
	}
	else if ( (nil != oDelegateController) && [[oDelegateController content] respondsToSelector:aSelector] )
	{
		actualDelegate = [oDelegateController content];
	}
	else if ( [[oDelegateController content] respondsToSelector:@selector(delegate)] 
			  && [[[oDelegateController content] delegate] respondsToSelector:aSelector] )
	{
		actualDelegate = [[oDelegateController content] delegate];
	}
	
	return actualDelegate;
}

- (void)tellDelegate
{
	SEL dataSourceSelector = @selector(imageView:setWithDataSourceDictionary:);
	id dataSourceDelegate = [self delegateForSelector:dataSourceSelector];
	[dataSourceDelegate imageView:self setWithDataSourceDictionary:myDataSourceDictionary];	
}

#pragma mark Dragging

- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)draggingInfo
{
	NSDragOperation result = NSDragOperationNone;
	
	if ([self isEnabled])	// If we are enabled, have a look to see if the drag source is suitable
	{
		NSArray *acceptedTypes = [NSArray arrayWithObjects:
			WebArchivePboardType,	// drags from safari, includes links and such
			NSFilenamesPboardType,
			NSTIFFPboardType,
			NSPICTPboardType,
			NSPDFPboardType,
			//		@"Apple PNG pasteboard type",		// not defined in headers, but it's on screenshots!
			nil];
		
		NSPasteboard *pboard = [draggingInfo draggingPasteboard];
		if ([pboard availableTypeFromArray:acceptedTypes]) {
			result = NSDragOperationCopy;
		}
	}
	
	return result;
}

- (void)concludeDragOperation:(id <NSDraggingInfo>)draggingInfo
{
    NSPasteboard *pboard = [draggingInfo draggingPasteboard];
    (void)[pboard types]; // we always have to call types

	NSArray *acceptedTypes = [NSArray arrayWithObjects:
		WebArchivePboardType,	// drags from safari, includes links and such
		NSFilenamesPboardType,
		NSTIFFPboardType,
		NSPICTPboardType,
		NSPDFPboardType,
		//		@"Apple PNG pasteboard type",		// not defined in headers, but it's on screenshots!
		nil];
	
	NSMutableDictionary *dataSourceDictionary = [NSMutableDictionary dictionary];
	
	BOOL result = [NSImage populateDictionary:dataSourceDictionary
						orderedImageTypesAccepted:acceptedTypes
                                    fromPasteboard:[draggingInfo draggingPasteboard]
											index:0];	// get info for first item, if multiple
	[self setDataSourceDictionary:dataSourceDictionary];
	/*!	General method to populate dictionary of useful information about a dragged image.  Accepts
		images dragged from finder, safari, iphoto, etc.
		
		This will populate dictionary with:
		kKTDataSourceUTI
		kKTDataSourceCreationDate (if jpeg data)
		kKTDataSourceData
		
		If from safari:
		
		kKTDataSourceFileName  (just useful for file name)
		kKTDataSourceTitle  (alt text)
		kKTDataSourceURLString -- URL it links to
		kKTDataSourceImageURLString -- source it comes from
		kKTDataSourcePreferExternalImageFlag (set to NO)
		
		If from a file:
		kKTDataSourceFilePath
		kKTDataSourceFileName
		
		If from iPhoto (which also includes file information above)
		kKTDataSourceTitle
		kKTDataSourceCaption
		kKTDataSourceCreationDate  (NOT YET -- only after bugfix)
		*/
	if (result)
	{
		[self tellDelegate];
	}
	
    //[super concludeDragOperation:draggingInfo];
}

@end


#pragma mark -


@implementation NSImage (KTDataSource)

static NSDictionary *sCachedIPhotoInfoDict = nil;

+ (void)setCachedIPhotoInfoDict:(NSDictionary *)aCachedIPhotoInfoDict
{
    [aCachedIPhotoInfoDict retain];
    [sCachedIPhotoInfoDict release];
    sCachedIPhotoInfoDict = aCachedIPhotoInfoDict;
}

+ (void)clearCachedIPhotoInfoDict
{
	[self setCachedIPhotoInfoDict:nil];
}

/*!	Convert the dictionary passed in with a drag from iPhoto into something we can use.
Tricky thing is that we are given a dictionary, keyed by arbitrary numbers which are not really
related to anything useful.  We need to search for the entry with the ImagePath equal to
the indexed value into NSFilenamesPboardType.

*/

+ (void)buildCachedIPhotoInfoDictFromImageDataList:(NSDictionary *)aDict
{
	NSMutableDictionary *buildDict = [NSMutableDictionary dictionary];
	NSEnumerator *theEnum = [aDict objectEnumerator];
	NSDictionary *value;
	
	while (nil != (value = [theEnum nextObject]) )
	{
		NSString *newKey = [value objectForKey:@"ImagePath"];
		if (nil != newKey)
		{
			[buildDict setObject:value forKey:newKey];
		}
	}
	[self setCachedIPhotoInfoDict:[NSDictionary dictionaryWithDictionary:buildDict]];
}

/*!	General method to populate dictionary of useful information about a dragged image.  Accepts
	images dragged from finder, safari, iphoto, etc.

	This will populate dictionary with:
		kKTDataSourceUTI
		kKTDataSourceCreationDate (if jpeg data)
		kKTDataSourceData

	If from safari:

		kKTDataSourceFileName  (just useful for file name)
		kKTDataSourceTitle  (alt text)
		kKTDataSourceURLString -- URL it links to
		kKTDataSourceImageURLString -- source it comes from
		kKTDataSourcePreferExternalImageFlag (set to NO)


	If from a file:
		kKTDataSourceFileName

	If from iPhoto (which also includes file information above)
		kKTDataSourceTitle
		kKTDataSourceCaption
		kKTDataSourceCreationDate  (NOT YET -- only after bugfix)

	Note that we do NOT populate kKTDataSourceImage -- we could easily get that from others.
*/

+ (BOOL)populateDictionary:(NSMutableDictionary *)aDictionary
 orderedImageTypesAccepted:(NSArray *)orderedTypes
            fromPasteboard:(NSPasteboard *)pasteboard
					 index:(unsigned int)anIndex;
{
    BOOL result = NO;
	NSString *UTI = nil;		// set this so we can check later
	NSData *imageData = nil;
		
    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
	
	BOOL hasiPhotoData = NO;
	// Check for additional information that iPhoto supplies; build our own cache
	if (nil == sCachedIPhotoInfoDict
		&& nil != [pasteboard availableTypeFromArray:[NSArray arrayWithObject:@"ImageDataListPboardType"]]
		&& (nil != [pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]]) )
	{
		[self buildCachedIPhotoInfoDictFromImageDataList:
			[pasteboard propertyListForType:@"ImageDataListPboardType"]];
		hasiPhotoData = YES;
	}
	
	// Get an image, alt text, and linked URL from a drag from Safari/WebKit
	if ( [bestType isEqualToString:WebArchivePboardType] )
	{
		NSData *webArchiveData = [pasteboard dataForType:WebArchivePboardType];
		WebArchive *webArchive = [[[WebArchive alloc] initWithData:webArchiveData] autorelease];
		WebResource *resource = [webArchive mainResource];
		UTI = [NSString UTIForMIMEType:[resource MIMEType]];
		if ( ![NSString UTI:UTI conformsToUTI:(NSString *)kUTTypeImage])
		{
			NSArray *subresources = [webArchive subresources];
			if ([subresources count])
			{
				resource = [subresources objectAtIndex:0];
				UTI = [NSString UTIForMIMEType:[resource MIMEType]];
			}
			else
			{
				resource = nil;
			}
		}
		if (resource)
		{
			imageData = [resource data];
			NSURL *imageURL = [resource URL];
			[aDictionary setValue:[[imageURL path] lastPathComponent] forKey:kKTDataSourceFileName];	// just name			
			// Now get the alt text and the linked URL
			NSArray *arrayFromData = [pasteboard propertyListForType:@"WebURLsWithTitlesPboardType"];
			NSArray *urlStringArray = [arrayFromData objectAtIndex:0];
			NSArray *urlTitleArray = [arrayFromData objectAtIndex:1];
			NSString *urlString = [urlStringArray objectAtIndex:anIndex];
			NSString *altText = [urlTitleArray objectAtIndex:anIndex];
			
			if ( ![altText isEqualToString:@""] && ![altText isEqualToString:[urlString lastPathComponent]] )
			{
				// only set alt text if it's actually meaningful ... not empty, and not just the same as the file name
				[aDictionary setValue:altText forKey:kKTDataSourceTitle];
			}
			if (![urlString isEqualToString:[imageURL absoluteString]])
			{
				// Only set a URL if the URL found in the archive (which is always the URL of the image)
				// is *different* from the URL found in the other URL places (which is either the URL it links to,
				// or the URL of the image itself if it doesn't link.
				[aDictionary setValue:urlString forKey:kKTDataSourceURLString];
			}
			// Set the source of the image.  But since we are also setting the actual image, that will take precedence.
			[aDictionary setValue:[imageURL absoluteString] forKey:kKTDataSourceImageURLString];
			[aDictionary setValue:[NSNumber numberWithBool:NO] forKey:kKTDataSourcePreferExternalImageFlag];
			
			// Since the drag came from the web, let's let it TRY to link to the original page, not the original image
			[aDictionary setValue:[NSNumber numberWithBool:YES] forKey:kKTDataSourceShouldIncludeLinkFlag];
			[aDictionary setValue:[NSNumber numberWithBool:NO] forKey:kKTDataSourceLinkToOriginalFlag];		// probably don't have an original to link to from a web source; too small
			result = YES;
		}
	}
	else if ( [bestType isEqualToString:NSFilenamesPboardType] )
    {
		NSArray *filePaths = [pasteboard propertyListForType:NSFilenamesPboardType];
		if (anIndex < [filePaths count])
		{
			NSString *filePath = [filePaths objectAtIndex:anIndex];
			if ( nil != filePath )
			{
				[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];

				filePath = [[NSFileManager defaultManager] resolvedAliasPath:filePath];
				UTI = [NSString UTIForFileAtPath:filePath];
				[aDictionary setValue:filePath forKey:kKTDataSourceFilePath];
				if (!hasiPhotoData)
				{
					imageData = [NSData dataWithContentsOfFile:filePath];		// for metadata below
				}
				result = YES;
			}
		}
    }
	else
	{
		// some other kind of image
		imageData = [pasteboard dataForType:bestType];
		UTI = [NSString UTIForPboardType:bestType];
	}
	
	// ONLY set the data if we don't have a file.  Otherwise, it's not worth the time/memory.
	if (nil != imageData && nil == [aDictionary valueForKey:kKTDataSourceFilePath])
	{
		[aDictionary setValue:imageData forKey:kKTDataSourceData];
	}
	
	if (nil != UTI)
	{
		[aDictionary setValue:UTI forKey:kKTDataSourceUTI];
	}
	
	// If we have an info dictionary from ImageDataListPboardType, populate the info
	if (nil != sCachedIPhotoInfoDict)
	{
		NSArray *fileNames = [pasteboard propertyListForType:NSFilenamesPboardType];
		if (anIndex < [fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:anIndex];

			NSDictionary *entry = [sCachedIPhotoInfoDict objectForKey:fileName];
			if (nil != entry)
			{
				NSString *caption = [entry objectForKey:@"Caption"];		// Really, title.
																			// Process if not empty, and if it's not just echoing the file name.
				if (nil != caption && ![caption isEqualToString:@""] && ![caption isEqualToString:[fileName lastPathComponent]])
				{
					[aDictionary setValue:caption forKey:kKTDataSourceTitle];
				}
				NSString *comment = [entry objectForKey:@"Comment"];		// Make this be our caption
				if (nil != comment && ![comment isEqualToString:@""])
				{
					[aDictionary setValue:comment forKey:kKTDataSourceCaption];
				}
				
				// Get date
				// old problem with "Date": Reported as radar 4262615  ... Sept 18 2005.

				NSNumber *dateNumber = [entry objectForKey:@"DateAsTimeInterval"];
				if (nil != dateNumber)
				{
					NSTimeInterval timeInterval = [dateNumber doubleValue];
					NSDate *date = [NSDate dateWithTimeIntervalSinceReferenceDate:timeInterval];
					// Set date.  Overrides date from metadata; if we set it in iphoto, we are overriding metadata.
					[aDictionary setValue:date forKey:kKTDataSourceCreationDate];
				}
				
				// Possibly try another method, though this is slower, if no date there
				if (nil == dateNumber
					&& [[NSUserDefaults standardUserDefaults] boolForKey:@"SetDateFromSourceMaterial"]
					&& [[NSUserDefaults standardUserDefaults] boolForKey:@"SetDateFromEXIF"])
				{
					// Get image data if we don't already have it from the file, but only if it's JPEG
					NSString *dataFilePath = nil;
					if (nil == imageData
						&& nil != (dataFilePath = [aDictionary valueForKey:kKTDataSourceFilePath])
						&& ([[NSString UTIForFileAtPath:dataFilePath] isEqualToString:(NSString *)kUTTypeJPEG])
						)
					{
						CGImageSourceRef source = nil;
						NSURL *url = [NSURL fileURLWithPath:dataFilePath];
						source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
						//source = CGImageSourceCreateWithData((CFDataRef)[self data], NULL);
						if (source)
						{
							CFDictionaryRef props = CGImageSourceCopyPropertiesAtIndex(source,  0,  NULL );
							CFDictionaryRef exif = CFDictionaryGetValue(props, kCGImagePropertyExifDictionary);
							if ( nil != exif )
							{
								id dateTime = (id) CFDictionaryGetValue(exif, kCGImagePropertyExifDateTimeOriginal);
								if (nil != dateTime)
								{
									NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease];
									[formatter setDateFormat:@"yyyy':'MM':'dd kk':'mm':'ss"];
									NSDate *dateFromString = [formatter dateFromString:dateTime];
									if ( nil != dateFromString )
									{
										[aDictionary setValue:dateFromString forKey:kKTDataSourceCreationDate];	// get from EXIF
									}
								}
							}
							CFRelease(props);
							CFRelease(source);
						}
					}
				}
				
				// Get keywords.  If we have "iMediaKeywords", we have already gotten the keyword numbers
				// converted to strings for us -- the drag came from iMedia browser.
				// If we just have "Keywords" then they are numbers (dragged from iPhoto), 
				// we will have to look them up from AlbumData.xml ourselves.
				
				NSArray *keywords = [entry objectForKey:@"iMediaKeywords"];

	// TODO: Look up Keywords from Numbers for direct iPhoto drags

				if ([keywords count])
				{
					NSMutableArray *newArray = [NSMutableArray arrayWithArray:keywords];
					[newArray removeObject:@"_Favorite_"];	// we don't want this iphoto keyword
					if ([newArray count])
					{
						[aDictionary setValue:[NSArray arrayWithArray:newArray] forKey:kKTDataSourceKeywords];
					}
				}
			}
		}
	}
	
    return result;
}

@end

