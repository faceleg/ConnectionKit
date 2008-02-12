//
//  KTCachedImage.m
//  KTComponents
//
//  Created by Terrence Talbot on 8/3/05.
//  Copyright 2005 Biophony LLC. All rights reserved.
//

#import "KTCachedImage.h"

#import "Debug.h"
#import "KT.h"
#import "KTDocument.h"
#import "KTMedia.h"
#import "NSManagedObject+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "assertions.h"


@interface KTCachedImage ( Private )
+ (NSImage *)scaledImageWithImageName:(NSString *)aName media:(KTMedia *)aMediaObject;
+ (BOOL)substituteOriginalForImageName:(NSString *)aName
                                 media:(KTMedia *)aMediaObject
                           scaledWidth:(unsigned int *)aWidth
                          scaledHeight:(unsigned int *)aHeight;
+ (KTCachedImage *)cachedFaviconWithMedia:(KTMedia *)aMediaObject;
- (void)cacheImageInPreferredFormat:(NSImage *)anImage;
- (void)cacheFaviconData:(NSData *)faviconData;
- (NSData *)faviconData;
@end


@implementation KTCachedImage

#pragma mark supporting class methods

/*! returns autoreleased NSImage of aMediaObject's data according to aName properties */
+ (NSImage *)scaledImageWithImageName:(NSString *)aName
                              media:(KTMedia *)aMediaObject
{
    NSImage *result = nil; // returning nil means substituteOriginal
	
	[aMediaObject lockPSCAndMOC];
	
	// we scale the image based on properties in KTCachedImageTypes.plist
	NSDictionary *typeInfo = [[aMediaObject class] typeInfoForImageName:aName];
	int maxWidth = 0;
	int maxHeight = 0;
	
	// do we have a key for maxPixels? if so, that sets both maxWidth and maxHeight
	if ( nil != [typeInfo valueForKey:@"maxPixels"] )
	{
		// some range checking here might be nice
		maxWidth = maxHeight = [[typeInfo valueForKey:@"maxPixels"] intValue];
	}
	else
	{
		// both of these keys better exist, maybe some error checking here, too
		maxWidth = [[typeInfo valueForKey:@"maxWidth"] intValue];
		maxHeight = [[typeInfo valueForKey:@"maxHeight"] intValue];
	}
	NSAssert((maxWidth > 0), @"maxWidth should be > 0");
	NSAssert((maxHeight > 0), @"maxHeight should be > 0");
	
	// if we're looking for a thumbnailImage and we have specific data for that, use that
	if ( [aName isEqualToString:@"thumbnailImage"] && (nil != [aMediaObject thumbnailData]) )
	{
		NSData *data = [aMediaObject valueForKeyPath:@"thumbnailData.contents"];
		result = [[[NSImage alloc] initWithData:data] autorelease];
	}	
	
	[aMediaObject unlockPSCAndMOC];

	int aMaxSize = MAX(maxWidth,maxHeight);
	if ( nil == result && aMaxSize <= 128)
	{
		NSString *path = [aMediaObject dataFilePath]; // or use originalPath?
		if ( (nil != path) && [[NSFileManager defaultManager] fileExistsAtPath:path] )
		{
			NSURL *url = [NSURL fileURLWithPath:path];
			CGImageSourceRef source = CGImageSourceCreateWithURL((CFURLRef)url, NULL);
			if (source)
			{
				// image thumbnail options
				NSDictionary* thumbOpts = [NSDictionary dictionaryWithObjectsAndKeys:
					(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailWithTransform,
					(id)kCFBooleanFalse, (id)kCGImageSourceCreateThumbnailFromImageIfAbsent,
					(id)kCFBooleanTrue, (id)kCGImageSourceCreateThumbnailFromImageAlways,	// bug in rotation so let's use the full size always
					[NSNumber numberWithInt:aMaxSize], (id)kCGImageSourceThumbnailMaxPixelSize, 
					nil];
				
				// make image -- a thumbnail if 128 pixels or smaller.
				CGImageRef theCGImage = CGImageSourceCreateThumbnailAtIndex(source, 0, (CFDictionaryRef)thumbOpts);
				
				if (theCGImage)
				{
					// Now draw into an NSImage
					NSRect imageRect = NSMakeRect(0.0, 0.0, 0.0, 0.0);
					CGContextRef imageContext = nil;
					
					// Get the image dimensions.
					imageRect.size.height = CGImageGetHeight(theCGImage);
					imageRect.size.width = CGImageGetWidth(theCGImage);
					
					// Create a new image to receive the Quartz image data.
					NSImage *img = [[[NSImage alloc] initWithSize:imageRect.size] autorelease];
					[img setFlipped:NO];
					[img lockFocus];
					
					// Get the Quartz context and draw.
					OBASSERT([NSGraphicsContext currentContext]);
					imageContext = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
					CGContextDrawImage(imageContext, *(CGRect*)&imageRect, theCGImage);
					[img unlockFocus];
					result = img;
					
					CFRelease(theCGImage);
				}
				CFRelease(source);
			}
		}
	}
	
	// catch-all, pull data from datastore
	if ( nil == result)
	{
		result = [aMediaObject imageConvertedFromData]; // should lock context on its own
	}
	
// FIXME: CASE 14405: IF THE UNDERLYING MEDIA IS USING ALIAS STORAGE AND THE FILE IS MOVED RESULT WILL BE NIL
	//NSAssert((nil != result), @"Image (before scaling) should not be nil. Has the original file been moved?");
	if ( nil == result )
	{
// TODO: put up an NSError panel or ask user to locate underlying media
		NSLog(@"error: %@ imageConvertedFromData should not be nil. Has the original file been moved?", [aMediaObject name]);
		result = [NSImage qmarkImage];
	}
	
	// normalizeSize before checking size
	[result normalizeSize];

	// do we need to scale? let's check ...
	NSSize resultSize = [result size];
	NSAssert(!NSEqualSizes(NSZeroSize,resultSize), @"result should not be NSZeroSize");
	if ( (resultSize.width > maxWidth) || (resultSize.height > maxHeight) )
	{
		// pull out behaviour and alignment; if not set, defaults are returned
		CIScalingBehavior behavior = [aMediaObject scalingBehaviorForKey:[typeInfo valueForKey:@"behavior"]];	
		NSImageAlignment alignment = [aMediaObject imageAlignmentForKey:[typeInfo valueForKey:@"alignment"]];
		
		result = [result imageWithMaxWidth:maxWidth
									height:maxHeight
								  behavior:behavior
								 alignment:alignment];
		NSAssert(!NSEqualSizes(NSZeroSize,[result size]), @"scaledImage should not be NSZeroSize");
	}
	    
	// square it up once more
	[result normalizeSize];
	
    return result;    
}

/*! returns whether we should just use the original image instead,
    passing putative width and height back to the caller */ 
+ (BOOL)substituteOriginalForImageName:(NSString *)aName
                                 media:(KTMedia *)aMediaObject
                           scaledWidth:(unsigned int *)aWidth
                          scaledHeight:(unsigned int *)aHeight
{
    // how does scaled size for aName compare to originalSize?	
    NSSize originalSize = [aMediaObject imageSize];
    
    // if orignal has no size, it's likely not an image and we can't substitute
    if ( (originalSize.width == 0) || (originalSize.height == 0) )
    {
        *aWidth = originalSize.width;
        *aHeight = originalSize.height;
        return NO;
    }
    
    float originalWidth = originalSize.width;
    float originalHeight = originalSize.height;
    NSDictionary *typeInfo = [[aMediaObject class] typeInfoForImageName:aName];
    
    float maxWidth = 0;
    float maxHeight = 0;
    
    // do we have a key for maxPixels? if so, that sets both maxWidth and maxHeight
    if ( nil != [typeInfo valueForKey:@"maxPixels"] )
    {
        // some range checking here might be nice
        maxWidth = maxHeight = [[typeInfo valueForKey:@"maxPixels"] floatValue];
    }
    else
    {
        // both of these keys better exist, maybe some error checking here, too
        maxWidth = [[typeInfo valueForKey:@"maxWidth"] floatValue];
        maxHeight = [[typeInfo valueForKey:@"maxHeight"] floatValue];
    }
    	
    // if either ratioW or ratioH > 1 we need to scale
    float ratioW = originalWidth / maxWidth;
    float ratioH = originalHeight / maxHeight;
    
    if ( (ratioW <= 1) && (ratioH <= 1) )
    {
        *aWidth = originalWidth;
        *aHeight = originalHeight;
        return YES; // no need to scale either dimension, just substitute
    }
    
    if ( ratioW > ratioH )
    {
        // scale the width to maxWidth and bring height down proportionally
        *aWidth = maxWidth;
        *aHeight = (maxWidth/originalWidth) * originalHeight;
    }
    else
    {
        // scale the height to maxHeight and bring width in proportionally
        *aHeight = maxHeight;
        *aWidth = (maxHeight/originalHeight) * originalWidth;
    }
    
    return NO; // we need to scale
}

#pragma mark private constructors

/*! returns a CachedImage with image in .ico format, for internal use */
+ (KTCachedImage *)cachedFaviconWithMedia:(KTMedia *)aMediaObject
{
    // because favicons may contain more than one bitmap,
    // we want to work exclusively with it as a chunk of data
	
	// grab the context
    KTManagedObjectContext *context = (KTManagedObjectContext *)[aMediaObject managedObjectContext];
	        
    // make a new entity to store the info
    KTCachedImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"CachedImage"
														  inManagedObjectContext:context];
    if ( nil != result )
    {
        // set its media relationship (should also set the inverse)
        [result setValue:aMediaObject forKey:@"media"];
        
        // set imageName
        [result setValue:@"faviconImage" forKey:@"imageName"];
        
        // set substituteOriginal
        [result setValue:[NSNumber numberWithBool:NO] forKey:@"substituteOriginal"];
        
        // set cacheName
        [result setValue:[NSString shortGUIDString] forKey:@"cacheName"];
        
		// set UTI
        [result setValue:(NSString *)kUTTypeICO forKey:@"imageFormatUTI"];
		
		// set default size of 32, it will be set more accurately when cached
        [result setValue:[NSNumber numberWithUnsignedInt:32] forKey:@"imageWidth"];
        [result setValue:[NSNumber numberWithUnsignedInt:32] forKey:@"imageHeight"];
		
		/// mark underlying media as not published
		[aMediaObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPublished"];
		
		// save and update context(s)
		KTDocument *document = [aMediaObject document];
		[document saveContext:context onlyIfNecessary:YES];
    }
	
	return result; // was created by NSEntityDescription as an autoreleased object
}

/*! returns a CachedImage with substituteOriginal true */
+ (KTCachedImage *)cachedImageSubstitutingOriginalForImageName:(NSString *)aName
                                                         media:(KTMedia *)aMediaObject
                                                         width:(unsigned int)aWidth
                                                        height:(unsigned int)aHeight
{
    // grab the context
    KTManagedObjectContext *context = (KTManagedObjectContext *)[aMediaObject managedObjectContext];
	[context lockPSCAndSelf];
    	
    // make a new entity to store the info
    KTCachedImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"CachedImage"
														  inManagedObjectContext:context];
    if ( nil != result )
    {		
        // set its media relationship (should also set the inverse)
        [result setValue:aMediaObject forKey:@"media"];
        
        // set imageName
        [result setValue:aName forKey:@"imageName"];
        
        // set substituteOriginal
        [result setWrappedValue:[NSNumber numberWithBool:YES] forKey:@"substituteOriginal"];
        
        // set image size
        unsigned int width = 0;
        unsigned int height = 0;
        
        // do we need to calculate them?
        if ( (0 == aWidth) || (0 == aHeight) )
        {
			NSSize originalSize = [aMediaObject imageSize];
            width = originalSize.width;
            height = originalSize.height;
        }
        else
        {
            width = aWidth;
            height = aHeight;
        }        
        [result setValue:[NSNumber numberWithUnsignedInt:width] forKey:@"imageWidth"];
        [result setValue:[NSNumber numberWithUnsignedInt:height] forKey:@"imageHeight"];
        
        // set UTI (originals shouldn't change, so setting this here should be fine)
        NSString *UTI = [aMediaObject mediaUTI];
        if ( nil != UTI )
        {
            [result setValue:UTI forKey:@"imageFormatUTI"];
        }
        else
        {
            NSLog(@"error: substitutingOriginalForImageName:%@ but underlying media has no UTI!", aName);
        }
		
		/// mark underlying media as not published
		[aMediaObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPublished"];

		KTDocument *document = [aMediaObject document];
		
		// saving will cause other contexts to refresh
		// we want to make sure that context is always the document's main context
		[document saveContext:context onlyIfNecessary:YES];
    }
	
	[context unlockPSCAndSelf];
	
	return result; // was created by NSEntityDescription as an autoreleased object
}

+ (KTCachedImage *)cachedImageWithImageName:(NSString *)aName
                                      media:(KTMedia *)aMediaObject
                                      width:(unsigned int)aWidth
                                     height:(unsigned int)aHeight;
{
    // grab the context
    KTManagedObjectContext *context = (KTManagedObjectContext *)[aMediaObject managedObjectContext];
	[context lockPSCAndSelf];

    // make a new entity to store the info
    KTCachedImage *result = [NSEntityDescription insertNewObjectForEntityForName:@"CachedImage"
														  inManagedObjectContext:context];
    if ( nil != result )
    {
        // set its media relationship (should also set the inverse)
        [result setValue:aMediaObject forKey:@"media"];
        
        // set imageName
        [result setValue:aName forKey:@"imageName"];
        
        // set substituteOriginal
        [result setValue:[NSNumber numberWithBool:NO] forKey:@"substituteOriginal"];
        
        // set cacheName
        [result setValue:[NSString shortGUIDString] forKey:@"cacheName"];
        
        // set size (don't defer)
        [result setValue:[NSNumber numberWithUnsignedInt:aWidth] forKey:@"imageWidth"];
        [result setValue:[NSNumber numberWithUnsignedInt:aHeight] forKey:@"imageHeight"];
		
		// set UTI (if original is jpeg, we can just use default)
		NSString *UTI = nil;
		NSString *path = [aMediaObject dataFilePath];
		if ( (nil != path) && [[NSFileManager defaultManager] fileExistsAtPath:path] )
		{
			NSString *originalUTI = [NSString UTIForFileAtPath:path];
			if ( [originalUTI isEqualToString:(NSString *)kUTTypeJPEG] )
			{
				if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"KTPrefersPNGFormat"] )
				{
					UTI = (NSString *)kUTTypePNG;
				}
				else
				{
					UTI = (NSString *)kUTTypeJPEG;
				}
			}
		}
		if ( nil != UTI )
		{
			[result setValue:UTI forKey:@"imageFormatUTI"];
		}
		
		/// mark underlying media as not published
		[aMediaObject setValue:[NSNumber numberWithBool:NO] forKey:@"isPublished"];

		KTDocument *document = [aMediaObject document];
		
		// saving will cause other contexts to refresh
		// we want to make sure that context is always the document's main context
		[document saveContext:context onlyIfNecessary:YES];
		
        // cache image (defer)
        // NB: we no longer cache the image on disk at creation time, but rather wait
        // until the image is first requested. We could try to detach a thread
        // to create the cache file in the background on the assumption that
        // the cache file will be needed fairly soon -- someday...
    }
	
	[context unlockPSCAndSelf];
		
	return result; // was created by NSEntityDescription as an autoreleased object
}

#pragma mark public constructors

+ (KTCachedImage *)cachedImageWithImageName:(NSString *)aName media:(KTMedia *)aMediaObject
{
	KTCachedImage *result = nil;
	
	if ( [aName isEqualToString:@"faviconImage"] )
	{
		result = [KTCachedImage cachedFaviconWithMedia:aMediaObject];
	}
	else
	{
		unsigned int width = 0;
		unsigned int height = 0;
		BOOL shouldSubstitute = [KTCachedImage substituteOriginalForImageName:aName
																		media:aMediaObject
																  scaledWidth:&width
																 scaledHeight:&height];
		
		if ( shouldSubstitute )
		{
			result = [KTCachedImage cachedImageSubstitutingOriginalForImageName:aName
																		  media:aMediaObject
																		  width:width
																		 height:height];
		}
		else
		{
			result = [KTCachedImage cachedImageWithImageName:aName
													   media:aMediaObject
													   width:width
													  height:height];
		}
	}
	
	return result;
}

+ (KTCachedImage *)cachedImageSubstitutingOriginalForImageName:(NSString *)aName media:(KTMedia *)aMediaObject
{
	KTCachedImage *result = [KTCachedImage cachedImageSubstitutingOriginalForImageName:aName
																				 media:aMediaObject
																				 width:0
																				height:0];
	
	return result;
}

#pragma mark operations

- (void)cacheFaviconData:(NSData *)faviconData
{
    NSAssert((nil != faviconData), @"faviconData should not be nil");
    NSAssert([[self name] isEqualToString:@"faviconImage"], @"method should only be used with faviconImages");
    
	// set digest
	[self setWrappedValue:[faviconData partiallyDigestString] forKey:@"imageDigest"];        

    // cache faviconData on disk
    NSString *cachePath = [self cacheAbsolutePath];
	
	// do we have a place to cache it?
    NSFileManager *fm = [NSFileManager defaultManager];
    if ( ![fm fileExistsAtPath:[cachePath stringByDeletingLastPathComponent] isDirectory:NULL] )
    {
        // something happened to the cache directory, recreate it
        (void)[[[self media] document] createImagesCacheIfNecessary];
    }
    
    // is cache directory writable?
    if ( [fm isWritableFileAtPath:[cachePath stringByDeletingLastPathComponent]] )
    {
		// cache it
        if ( [faviconData writeToFile:cachePath atomically:NO] )
		{
			NSNumber *cacheSize = [[NSFileManager defaultManager] sizeOfFileAtPath:[self cacheAbsolutePath]];
			if ( nil != cacheSize )
			{
				[self setWrappedValue:cacheSize forKey:@"cacheSize"];
			}
			else
			{
				NSLog(@"error: unable to get size for cache %@", [self cacheAbsolutePath]);
			}
			TJT((@"cached %@_%@.%@ at %@ size %@",[[self media] name], [self name], [NSString filenameExtensionForUTI:[self formatUTI]], [cachePath lastPathComponent], cacheSize));
		}
    }
    else
    {
        // we can't write this cache file, put up an alert
        KTDocument *document = [[self media] document];
        NSWindow *documentWindow = [[document windowController] window];
        
        NSString *description = NSLocalizedString(@"The path ~/Library/Caches/Sandvox is not writeable.", "Alert: path not writeable");
        NSString *suggestion = NSLocalizedString(@"Please make sure that the above folder exists and is writeable. Without this, Sandvox may experience performance and/or publishing problems.", "Alert: path not writeable suggestion");
        NSArray *buttons = [NSArray arrayWithObject:NSLocalizedString(@"OK", "OK Button")];
        
        NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
            cachePath, NSFilePathErrorKey,
            description, NSLocalizedDescriptionKey,
            suggestion, NSLocalizedRecoverySuggestionErrorKey,
            buttons, NSLocalizedRecoveryOptionsErrorKey,
            nil];
        
        NSError *writeError = [NSError errorWithDomain:NSCocoaErrorDomain
                                                  code:NSFileWriteUnknownError
                                              userInfo:errorInfo];
        NSAlert *writeAlert = [NSAlert alertWithError:writeError];
        [writeAlert beginSheetModalForWindow:documentWindow modalDelegate:nil didEndSelector:nil contextInfo:NULL];
    }
}

// assumes anImage has already been scaled appropriately
- (void)cacheImageInPreferredFormat:(NSImage *)anImage
{
	OFF((@"cacheImageInPreferredFormat:"));
    NSAssert((nil != anImage), @"anImage should not be nil");
	
    // normalize size before examining values
    [anImage normalizeSize];
    
    // determine our preferred format
    NSString *UTI = nil;
	
	/// Case 19530: hasAlphaComponent is returning true for some scaled JPEGs
	/// which has us outputting PNGs for scaled JPEGs when the user preference if for JPEGs
	/// so, until we figure out how to use Core Image to scale a JPEG and not get back
	/// an image with alpha, we're just going to cheat and make sure that the 
	/// combo of mediaUTI and imageFormatUTI are plausible in the Sandvox universe
	
	// is the original media a JPEG?
	NSString *mediaUTI = [[self media] mediaUTI];
	if ( [NSString UTI:mediaUTI isEqualToUTI:(NSString *)kUTTypeJPEG] )
	{
		// if we're JPEG, we can use either JPEG or PNG scaled images
		// so just base choice on user preference
		if ( [[NSUserDefaults standardUserDefaults] boolForKey:@"KTPrefersPNGFormat"] )
		{
			UTI = (NSString *)kUTTypePNG;
		}
		else
		{
			UTI = (NSString *)kUTTypeJPEG;
		}
	}
	else
	{
		// not a JPEG, extract image data in preferred format
		UTI = [anImage preferredFormatUTI];
	}
	
	OBASSERT(nil != UTI);

	// get our image data
    NSData *imageData = [anImage representationForUTI:UTI];
	
	/// added lockPSCAndMOC to avoid deadlock of 3/20 where another 
	/// thread wants to save but is waiting to @sync(self)
	[self lockPSCAndMOC];
	    
	@synchronized ( self )
	{
		// set image size
		unsigned int width = [anImage size].width;
		unsigned int height = [anImage size].height;
		[self setWrappedValue:[NSNumber numberWithUnsignedInt:width] forKey:@"imageWidth"];
		[self setWrappedValue:[NSNumber numberWithUnsignedInt:height] forKey:@"imageHeight"];
		
		// set format via preferredFormat
		[self setWrappedValue:UTI forKey:@"imageFormatUTI"];
		
		// set digest
		[self setWrappedValue:[imageData partiallyDigestString] forKey:@"imageDigest"];
		
		// cache image on disk
		NSString *cachePath = [self cacheAbsolutePath];
		
		// do we have a place to cache it?	
		NSFileManager *fm = [NSFileManager defaultManager];
		if ( ![fm fileExistsAtPath:[cachePath stringByDeletingLastPathComponent] isDirectory:NULL] )
		{
			// something happened to the cache directory, recreate it
			(void)[[[self media] document] createImagesCacheIfNecessary];
		}
		
		// is cache directory writable?
		if ( [fm isWritableFileAtPath:[cachePath stringByDeletingLastPathComponent]] )
		{		
			// cache it
			if ( [imageData writeToFile:cachePath atomically:NO] )
			{
				NSNumber *cacheSize = [[NSFileManager defaultManager] sizeOfFileAtPath:[self cacheAbsolutePath]];
				if ( nil != cacheSize )
				{
					[self setWrappedValue:cacheSize forKey:@"cacheSize"];
				}
				else
				{
					NSLog(@"error: unable to get size for cache %@", [self cacheAbsolutePath]);
				}
				TJT((@"cached %@_%@.%@ at %@ size %@",[[self media] name], [self name], [NSString filenameExtensionForUTI:[self formatUTI]], [cachePath lastPathComponent], cacheSize));
			}
		}
		else
		{
			// we can't write this cache file, put up an alert
			KTDocument *document = [[self media] document];
			NSWindow *documentWindow = [[document windowController] window];
			
			NSString *description = NSLocalizedString(@"The path ~/Library/Caches/Sandvox is not writeable.", "Alert: path not writeable");
			NSString *suggestion = NSLocalizedString(@"Please make sure that the above folder exists and is writeable. Without this, Sandvox may experience performance and/or publishing problems.", "Alert: path not writeable suggestion");
			NSArray *buttons = [NSArray arrayWithObject:NSLocalizedString(@"OK", "OK Button")];
			
			NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
				cachePath, NSFilePathErrorKey,
				description, NSLocalizedDescriptionKey,
				suggestion, NSLocalizedRecoverySuggestionErrorKey,
				buttons, NSLocalizedRecoveryOptionsErrorKey,
				nil];
			
			NSError *writeError = [NSError errorWithDomain:NSCocoaErrorDomain
													  code:NSFileWriteUnknownError
												  userInfo:errorInfo];
			NSAlert *writeAlert = [NSAlert alertWithError:writeError];
			[writeAlert beginSheetModalForWindow:documentWindow modalDelegate:nil didEndSelector:nil contextInfo:NULL];
		}
	}
	
	[self unlockPSCAndMOC];
}

- (void)recacheInPreferredFormat
{
	if ( kGeneratingPreview == [[[self media] document] publishingMode] )
	{
		// we could always post this and just have the receiver ignore,
		// but we don't need a notification storm during publishing either5
		// 
		//
		//	Not going to do this. This happens in threaded thumbnail generation -- don't want to do it then.
		// And when it's happening in the foreground thread, we're not going to get the notification
		// until it's too late.
		//
		// [[NSNotificationCenter defaultCenter] postNotificationName:kKTMediaIsBeingCachedNotification object:[[self media] document]];
		
		// we could also only send this for images over a certain size
	}

	NSAutoreleasePool *cachingPool = [[NSAutoreleasePool alloc] init];
	
	// recache, according to imageName
	NSString *name = [self name];
	if ( [name isEqualToString:@"faviconImage"] )
	{
		/// added lockPSCAndMOC to avoid deadlock of 3/20 where another 
		/// thread wants to save but is waiting to @synch(self)
		[self lockPSCAndMOC];
		
		@synchronized ( self )
		{
			// if we're being asked to recache, throw away the old cacheFile
			(void)[self removeCacheFile];

			// regenerate faviconData and cache it
			NSData *data = [self faviconData];
			NSAssert((nil != data), @"faviconData should not be nil if you want to cache it");
			[self cacheFaviconData:data];
		}
		[self unlockPSCAndMOC];
	}
	else
	{
		KTMedia *media = [self media];
		NSImage *scaledImage = [KTCachedImage scaledImageWithImageName:name media:media];
		NSAssert((nil != scaledImage), @"scaledImage should not be nil if you want to cache it");
		NSAssert(!NSEqualSizes(NSZeroSize,[scaledImage size]), @"scaledImage must not be zero size");
		
		[self lockPSCAndMOC];
		
		@synchronized ( self )
		{
			// if we're being asked to recache, throw away the old cacheFile
			(void)[self removeCacheFile];
			
			// cache image
			[self cacheImageInPreferredFormat:scaledImage];
		}
		[self unlockPSCAndMOC];
	}
	[cachingPool release];
}

- (void)recalculateSize
{
	// this should only be called on substituteOriginal CachedImages
	unsigned int width = 0;
	unsigned int height = 0;
	
	// do we need to calculate them?
	NSImage *anImage = [[self media] imageConvertedFromData];
	[anImage normalizeSize];
	width = [anImage size].width;
	height = [anImage size].height;
	
	[self setWrappedValue:[NSNumber numberWithUnsignedInt:width] forKey:@"imageWidth"];
	[self setWrappedValue:[NSNumber numberWithUnsignedInt:height] forKey:@"imageHeight"];
}

- (BOOL)removeCacheFile
{
    NSString *path = [self cacheAbsolutePath];

	// Note that the path returned above is path without resolving symlinks, neither is NSHomeDirectory
	// so the comparision is valid.
    // be cautious about removing things, doubly check that path!
    if ( [path hasPrefix:NSHomeDirectory()] && [path hasPrefix:[[[self media] document] imagesCachePath]] )
    {
        NSFileManager *fm = [NSFileManager defaultManager];
        BOOL isDir = NO;
        if ( [fm fileExistsAtPath:path isDirectory:&isDir] )
        {
            // be more cautious and make sure we're not removing an entire directory!
            if ( !isDir )
            {
                return [fm removeFileAtPath:path handler:nil];
            }
        }
		else
		{
			return YES; // we don't appear to have a cache file, so by definition it's removed
		}

    }

    return NO; // something happened, we refused to remove it
}

#pragma mark accesssors

// if these become a bottleneck, we could cache local copies in ivars

/*! returns full file path to cache file, nil if not applicable or couldn't create file */
- (NSString *)cacheAbsolutePath 	// returns path without resolving symbolic links
{
	NSString *result = nil;
	
	if ( ![self substituteOriginal] )
	{
		NSString *fileName = [self cacheName];
		if ( (nil != fileName) && ![fileName isEqualToString:@""] )
		{
			NSString *imagesCachePath = [[[self media] document] imagesCachePath];
			if ( (nil != imagesCachePath) && ![imagesCachePath isEqualToString:@""] )
			{
				result = [imagesCachePath stringByAppendingPathComponent:fileName];
			}
		}
	}
	
	return result;
}

- (BOOL)hasValidCacheFile
{
	BOOL result = NO;
	
	/// added lockPSCAndMOC to avoid deadlock of 3/20 where another 
	/// thread wants to save but is waiting to @sync(self)

	if ( [self substituteOriginal] )
	{
		result = NO;
	}
	
	else if ( (nil == [self cacheName]) || [[self cacheName] isEqualToString:@""] )
	{
		result = NO;
	}
	else
	{
		NSString *filePath = [self cacheAbsolutePath];
		
		if ( nil != filePath )
		{
			// are we actually still on disk?
			NSFileManager *fm = [NSFileManager defaultManager];
			if ( ![fm fileExistsAtPath:filePath] )
			{
				[self recacheInPreferredFormat];
				
				// try again
				if ( [fm fileExistsAtPath:filePath] )
				{
					result = YES;
				}
				else
				{
					result = NO;
				}
			}
			else
			{
				result = YES;
			}
		}
	}
	return result;
}

- (BOOL)hasValidCacheFileNoRecache
{
	BOOL result = NO;
	
	/// added lockPSCAndMOC to avoid deadlock of 3/20 where another 
	/// thread wants to save but is waiting to @sync(self)
	
	[self lockPSCAndMOC];
	
	@synchronized ( self )
	{
		if ( [self substituteOriginal] )
		{
			result = NO;
		}
		else if ( (nil == [self cacheName]) || [[self cacheName] isEqualToString:@""] )
		{
			result = NO;
		}
		else
		{
			NSString *filePath = [self cacheAbsolutePath];
			if ( nil != filePath )
			{
				NSFileManager *fm = [NSFileManager defaultManager];
				result = [fm fileExistsAtPath:filePath];
			}
			else
			{
				result = NO;
			}
		}
	}
	
	[self unlockPSCAndMOC];
	
	return result;
}

/*! returns name of cache file */
- (NSString *)cacheName
{
    return [self wrappedValueForKey:@"cacheName"];
}

/*! returns size (in bytes) of cache file */
- (NSNumber *)cacheSize
{
	NSNumber *result = [self wrappedValueForKey:@"cacheSize"];
	if ( (nil == result) || ([result intValue] == 0) )
	{
		// no size found, do we have something on disk?
		if ( [self hasValidCacheFileNoRecache] )
		{
			NSFileManager *fm = [NSFileManager defaultManager];
			result = [fm sizeOfFileAtPath:[self cacheAbsolutePath]];
		}
	}
	
	if ( (nil == result) || ([result intValue] == 0) )
	{
		return nil;
	}
	
	return result;
}

/*! returns NSData with contents of cache file */
- (NSData *)data
{
    // substitute original? 
    if ( [self substituteOriginal] )
    {
        return [[self media] data];
    }
	
	// or we can't write the cache file out so we do it in memory
	if (![self hasValidCacheFile])
	{
		NSImage *scaledImage = [KTCachedImage scaledImageWithImageName:[self name] media:[self media]];
		return [scaledImage representationForUTI:[self formatUTI]];
	}
    
    // NB: we have to make sure the cache file is legit first!
    NSString *path = [self cacheAbsolutePath];
    
    NSFileManager *fm = [NSFileManager defaultManager];
    if ( [fm isReadableFileAtPath:path] )
    {
        // on disk, but is it the right size?
        NSNumber *fileSize = [fm sizeOfFileAtPath:path];
        NSNumber *cacheSize = [self cacheSize];
        if ( nil == fileSize || nil == cacheSize || ![fileSize isEqualToNumber:cacheSize] )
        {
            // size doesn't look right, recache
            [self recacheInPreferredFormat];
        }
    }
    else
    {
        // not on disk?, recache
        [self recacheInPreferredFormat];
    }
    
    // at this point we should be good to go    
    NSData *result = [NSData dataWithContentsOfFile:path];
    return result;
}

/*! returns partial sha1 digest of underlying data */
- (NSString *)digest
{
    return [self wrappedValueForKey:@"imageDigest"];
}

/*! returns UTI of underlying data were it an NSImage */
- (NSString *)formatUTI;
{
	return [self wrappedValueForKey:@"imageFormatUTI"];
}

/*! returns UTI of underlying data were it an NSImage,
	generating cache file if needed to determine UTI
*/
- (NSString *)formatUTICachingIfNecessary
{
	NSString *result = nil;
	
	if ( [self substituteOriginal] )
	{
		// formatUTI should never have changed
		result = [self formatUTI];
	}
	else if ( [self hasValidCacheFileNoRecache] )
	{
		// formatUTI should have been computed
		// (but it's possible that old errors have left UTI nil)
		result = [self formatUTI];
	}
	
	if ( nil == result )
	{
		// we haven't been cached yet to determine the format
		// let's do that now...
		[self recacheInPreferredFormat];
		result = [self formatUTI];
	}
	
	return result;
}

/*! returns underlying imageHeight, as a scalar */
- (unsigned int)height
{
    return [[self wrappedValueForKey:@"imageHeight"] intValue];
}

/*! returns associcated media relationship */
- (KTMedia *)media
{
    return [self wrappedValueForKey:@"media"];
}

/*! returns underlying imageName */
- (NSString *)name
{
    return [self wrappedValueForKey:@"imageName"];
}

/*! returns whether an NSImage created from the original media object
    should be substituted -- generally because the original would be
    the same size and format as what would be generated here
*/
- (BOOL)substituteOriginal
{
    return [[self wrappedValueForKey:@"substituteOriginal"] boolValue];
}

/*! returns underlying imageWidth, as a scalar */
- (unsigned int)width
{
    return [[self wrappedValueForKey:@"imageWidth"] intValue];
}

#pragma mark paths

- (NSString *)mediaPathRelativeTo:(KTPage *)aPage
{
	return [[self media] mediaPathRelativeTo:aPage forImageName:[self name] allowFile:YES];
}

- (NSString *)enclosurePathRelativeTo:(KTPage *)aPage
{
	return [[self media] enclosurePathRelativeTo:aPage forImageName:[self name] allowFile:YES];
}

#pragma mark URLs

// Used for RSS feed; we need the URL where the image is found
- (NSString *)publishedURL
{
	KTMedia *media = [self media];
	NSString *publishedSiteURL = [[media document] publishedSiteURL];
	NSString *fileName = [media fileNameForImageName:[self name]];

	NSString *mediaPath = [[NSUserDefaults standardUserDefaults] valueForKey:@"DefaultMediaPath"];
	if ( nil == mediaPath )
	{
		NSLog(@"error: unable to determine DefaultMediaPath, check defaults");
		mediaPath = @"/";
	}
	
    NSString *result = [NSString stringWithFormat:@"%@%@/%@", publishedSiteURL, mediaPath, fileName];
	return result;
}

#pragma mark support

- (NSString *)verboseDescription
{
	NSString *string = [self managedObjectDescription];
	string = [string stringByAppendingFormat:@", mediaPathRelativeTo = %@, name = %@", [self mediaPathRelativeTo:nil], [self name]];
	return string;
}

/*!	A string for bindings/diagnostics */
- (NSString *)sizeString
{
	return [NSString stringWithFormat:@"Image Size: %.0f x %.0f", [self width], [self height]];
}

#pragma mark NSImage support

/*! returns autoreleased NSImage created from cache in ~/Library/Caches/Sandvox */
- (NSImage *)image
{
    // substitute original?
    if ( [self substituteOriginal] )
    {
        NSImage *image = [[self media] imageConvertedFromData];
        return image;
    }
    else
    {
        return [[[NSImage alloc] initWithData:[self data]] autorelease];
    }
}

// for bindings
- (NSData *)TIFFRepresentation
{
    NSImage *image = [self image];
    return [image TIFFRepresentation];
}

- (void)setTIFFRepresentation:(NSData *)data
{
    ; // no-op, used as a bindings companion only
    
    // maybe this needs to be turned into something that repopulates media?
}

// try not to call this any more than absolutely necessary
// as it runs png2ico in a separate thread
- (NSData *)faviconData
{
    NSImage *image = [[self media] imageConvertedFromDataOfThumbSize:128];	// make bigger than needed
    NSData *result = [image faviconRepresentation];
    
    return result;
}

// for debugging:

//- (void)didChangeValueForKey:(NSString *)key
//{
//    NSLog(@"%@ %@ %@ didChangeValueForKey:%@", [self class], [[self media] name], [self name], key);
//    [super didChangeValueForKey:key];
//}


@end
