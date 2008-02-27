//
//  KTMedia+ScaledImages.m
//  KTComponents
//
//  Created by Terrence Talbot on 4/13/06.
//  Copyright 2006 Karelia Software. All rights reserved.
//

// REQUIRES Quartz.framework

#import "KTMedia.h"

#import "KTDesign.h"
#import "assertions.h"
#import "NSString-Utilities.h"
#import <QuartzCore/CoreImage.h> // needed for Core Image

static NSImage *sMaskImage;
static NSImage *sCoverImage;

static CIImage *sCIMaskImage;
static CIImage *sCICoverImage;
static id sSelectorLocker;

// these rely on sCIMaskImage and sCICoverImager which are static to this file
@interface NSImage ( docIconCompositing )
- (NSImage *)scaleAndMask32ThumbnailusingCoreImage:(BOOL)useCoreImage;
@end


@implementation KTMedia ( ScaledImages )

+ (void)initialize
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	sSelectorLocker = [[NSObject alloc] init];	// lock for @synchronized below

	sMaskImage = [[NSImage imageNamed:@"pagemask"] retain];
	sCoverImage = [[NSImage imageNamed:@"pageborder"] retain];
	sCIMaskImage  = [[sMaskImage toCIImage] retain];
	sCICoverImage = [[sCoverImage toCIImage] retain];
	
	if (!sMaskImage) NSLog(@"Couldn't load mask image");
	if (!sCoverImage) NSLog(@"Couldn't load cover image");
    
    [self setKeys:[NSArray arrayWithObjects:@"thumbnailImage", nil]
		triggerChangeNotificationsForDependentKey:@"thumbnailData"];
	[pool release];
}

- (NSArray *)allCachedImages
{
	NSArray *result = nil;
	
	NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(media == %@)", self];
    result = [[self managedObjectContext] objectsWithEntityName:@"CachedImage"
                                                                     predicate:predicate
                                                                         error:NULL];
	
//	NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//		self, @"$MEDIA",
//		nil];
//	
//	result = [[self managedObjectContext] objectsWithFetchRequestTemplateWithName:@"CachedImagesWithMedia"
//																		   substitutionVariables:dictionary
//																						   error:NULL];
	
	return result;
}

- (BOOL)removeAllCacheFiles
{
	BOOL result = YES;
	
	NSEnumerator *e = [[self allCachedImages] objectEnumerator];
	KTCachedImage *cachedImage;
	while ( cachedImage = [e nextObject] )
	{
		result = (result && [cachedImage removeCacheFile]);
	}
	
	return result;
}

- (BOOL)hasCachedImageForImageName:(NSString *)anImageName
{
	return (nil != [self cachedImageForImageName:anImageName]);
}

/*! returns image data for anImageName (should already be in preferred format) */
- (NSData *)dataForImageName:(NSString *)anImageName
{	
	//LOG((@"asking %@ dataForImageName: %@", [self name], anImageName));
    // if cached icon, just return the data from that image
    NSImage *icon = [myCachedIcons valueForKey:anImageName];
    if ( nil != icon)
    {
        return [icon TIFFRepresentation]; // for Site Outline
    }
    
    // if we can substitute original, just return our data
	if ( [self substituteOriginalForImageName:anImageName] )
	{
		return [self data]; // return imageFromData
	}
    
    // otherwise, we should have a KTCachedImage for anImageName
    KTCachedImage *cachedImage = [self cachedImageForImageName:anImageName];
    if ( nil != cachedImage )
    {
        return [cachedImage data];
    }
	else
	{
		// try to make a cachedImage
		KTCachedImage *image = [self imageForImageName:anImageName];
		return [image data];
	}
    
    // shouldn't get here
    NSLog(@"error: dataForImageName: %@ returning nil! -- shouldn't happen -- please report!", anImageName);
    return nil;
}

- (void)threadedSiteOutlineViewImageForImageName:(NSString *)anImageName
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	/// moving lockPSCAndMOC within autorelease pool
	/// otherwise we were getting leak complaints when searching
	/// sharedDocumentController for MOCs
	[self lockPSCAndMOC];

	// scale and mask it
	NSDictionary *typeInfo = [KTDesign infoForMediaUse:anImageName];
	float width = [[typeInfo valueForKey:@"width"] floatValue];
	BOOL mask = [[typeInfo valueForKey:@"mask"] boolValue];
	
	NSImage *thumbImage = [self imageConvertedFromDataOfThumbSize:128];		// Make it a bit bigger than we need so it will scale down better
	if (thumbImage)
	{
		if (mask && 32 == width)
		{
			
			// DON'T USE CORE IMAGE HERE ...
			// CoreImage seems to read the bitmap data from the GPU on the main thread which
			// was blocking the application for up to 5 seconds at a time
			thumbImage = [thumbImage scaleAndMask32ThumbnailusingCoreImage:NO];
		}				
		[thumbImage normalizeSize];
	
		// cache it in memory
		[myCachedIcons setValue:thumbImage forKey:anImageName];
		isCreatingSiteOutlineImage = NO;
		
		[self performSelectorOnMainThread:@selector(siteOutlineImageCreated) withObject:nil waitUntilDone:NO];
	}
	else
	{
		NSLog(@"error: no data for Media when generating outline thumbnail!");
	}
	
	/// moving unlockPSCAndMOC inside pool, per above
	[self unlockPSCAndMOC];

	[pool release];
}

- (void)siteOutlineImageCreated
{
	[[NSNotificationCenter defaultCenter] postNotificationName:@"kKTSiteOutlineNeedsRefreshingNotification" 
														object:[[[self document] root] uniqueID]];
}

/*! returns KTCachedImage or NSImage corresponding to anImageName */
- (id)imageForImageName:(NSString *)anImageName
{
	KTCachedImage *cachedImage = nil;
	
	/// avoid deadlock with cachedImageForImageName:
	[self lockPSCAndMOC];
	
	@synchronized(sSelectorLocker)
	{
		//TJT((@"%@ imageForImageName:%@", [self managedObjectDescription], anImageName));
		
		// are we being asked for a UI icon?
		NSDictionary *typeInfo = [KTDesign infoForMediaUse:anImageName];
		NSString *behaviorType = [typeInfo valueForKey:@"behavior"];
		if ( [behaviorType isEqualToStringCaseInsensitive:@"scaleForUI"] )
		{
			if ( kGeneratingPreview == [[self document] publishingMode] )
			{
				NSImage *icon = [myCachedIcons valueForKey:anImageName];
				if ( nil == icon )
				{
					// scale and mask it
					unsigned int width = [[typeInfo valueForKey:@"width"] intValue];
					//				unsigned int height  = [[typeInfo valueForKey:@"height"] intValue];
					BOOL mask = [[typeInfo valueForKey:@"mask"] boolValue];
					
					// create an NSImage
					NSImage *imageFromData = nil;
					if ( nil != [self threadSafeValueForKeyPath:@"thumbnailData.contents"] )
					{
						NSData *imageData = [self threadSafeValueForKeyPath:@"thumbnailData.contents"];
						imageFromData = [[[NSImage alloc] initWithData:imageData] autorelease];
					}
					else
					{
						if ([anImageName isEqualToString:@"outlineIconImage"] || [anImageName isEqualToString:@"outlineSmallIconImage"])
						{
							//TJT((@"creating %@ for %@", anImageName, [self managedObjectDescription]));
							if ( [self isMovie] )
							{
								imageFromData = [self posterImage];
							}
							else
							{
								if (!isCreatingSiteOutlineImage)
								{
									isCreatingSiteOutlineImage = YES;
									[NSThread detachNewThreadSelector:@selector(threadedSiteOutlineViewImageForImageName:) toTarget:self withObject:anImageName];
								}
								/// balance lock at beginning of method
								[self unlockPSCAndMOC];
								return nil;
							}
						}
						else
						{
							// Happens only in the foreground thread on-demand -- rootOutlineIconImage
							imageFromData = [self imageConvertedFromDataOfThumbSize:128];	// make bigger than needed
						}
					}
					icon = imageFromData;
					if (mask && 32 == width)
					{
						icon = [imageFromData scaleAndMask32ThumbnailusingCoreImage:YES];
					}				
					[icon normalizeSize];
					
					// cache it in memory
					[myCachedIcons setValue:icon forKey:anImageName];
				}
				
				/// balance lock at beginning of method
				[self unlockPSCAndMOC];
				return icon;
			}
			else
			{
				LOG((@"asked to generate scaled icon for UI while publishing!"));
				/// balance lock at beginning of method
				[self unlockPSCAndMOC];
				return nil;
			}
		}
	
		cachedImage = [self cachedImageForImageName:anImageName];
		if ( nil == cachedImage )
		{
			// we suspend undo registration when creating CachedImages
			BOOL suspendUndo = [[self managedObjectContext] isEqual:[[self document] managedObjectContext]];
			if ( suspendUndo )
			{
				[[[self managedObjectContext] undoManager] disableUndoRegistration];
			}
			
			if ( [anImageName isEqualToString:@"originalAsImage"] )
			{
				cachedImage = [KTCachedImage cachedImageSubstitutingOriginalForImageName:anImageName
																				   media:self];
			}
			else
			{
				cachedImage = [KTCachedImage cachedImageWithImageName:anImageName media:self];
			}
			
			if ( suspendUndo )
			{
				[[[self managedObjectContext] undoManager] enableUndoRegistration];
			}
		}
    
		// cache for upload
		if ( ![typeInfo valueForKey:@"upload"] || ([[typeInfo valueForKey:@"upload"] boolValue] == YES) )
		{
			[[self mediaManager] cacheReference:cachedImage];
		}
	}

	/// balance lock at beginning of method
	[self unlockPSCAndMOC];
	return cachedImage;
}

/*! returns CachedImage where 'imageName like anImageName' */
- (KTCachedImage *)cachedImageForImageName:(NSString *)anImageName
{
    KTCachedImage *result = nil;
	
	/// added lockPSC to avoid deadlock when creating thumbnails
	[self lockPSCAndMOC];
    
	/// added sSelectorLocker since may be called by imageForImageName:
	/// or by other methods in other threads which do not
	@synchronized(sSelectorLocker)
	{
		NSPredicate *predicate = [NSPredicate predicateWithFormat:@"(imageName == %@) && (media == %@)", anImageName, self];
		NSArray *cachedImages = [[self managedObjectContext] objectsWithEntityName:@"CachedImage"
																		 predicate:predicate
																			 error:NULL];
		
//		NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:
//			anImageName, @"$IMAGE_NAME",
//			self, @"$MEDIA",
//			nil];
//		
//		NSArray *cachedImages = [[self managedObjectContext] objectsWithFetchRequestTemplateWithName:@"CachedImagesWithImageNameAndMedia"
//																		  substitutionVariables:dictionary
//																						  error:NULL];
//		
		if ( [cachedImages count] == 1 )
		{
			result = [cachedImages objectAtIndex:0];
		}
		else if ( [cachedImages count] > 1 )
		{
			result = [cachedImages objectAtIndex:0];
		}
	}
	
	/// unlockPSC
	[self unlockPSCAndMOC];
    
    return result;
}

- (BOOL)hasValidCacheForImageName:(NSString *)anImageName
{
	BOOL result = NO;
	
	KTCachedImage *cachedImage = [self cachedImageForImageName:anImageName];
	if ( nil != cachedImage )
	{
		if ( [cachedImage substituteOriginal] )
		{
			result = YES; // we have nothing to scale, we're valid
		}
		else
		{
			result = [cachedImage hasValidCacheFileNoRecache];
		}
	}
	
	return result;
}

// NB: this is obviously not hugely efficient. pre-load a static table?
- (NSString *)imageNameForTag:(NSString *)aTag
{
	NSAssert((nil != aTag), @"aTag should not be nil");
	
	NSDictionary *types = [[self class] defaultMediaUses];
	NSEnumerator *e = [[types allKeys] objectEnumerator];
	NSString *imageName;
	while ( imageName = [e nextObject] )
	{
		NSDictionary *typeInfo = [types valueForKey:imageName];
		NSString *typeTag = [typeInfo valueForKey:@"tag"];
		if ( nil == typeTag )
		{
			continue;
		}
		if ( [typeTag isEqualToString:aTag] )
		{
			return imageName;
		}		
	}
	
	return nil; // we didn't find it
}


#pragma mark -
#pragma mark Other

- (NSString *)MIMETypeForImageName:(NSString *)anImageName
{
	NSString *result = nil;
	
	if ( [anImageName isEqualToString:@"originalAsImage"] )
	{
		result = [self MIMEType];
	}
	else
	{
		KTCachedImage *cachedImage = [self cachedImageForImageName:anImageName];
		NSString *UTI = [cachedImage formatUTI];
		result = [NSString MIMETypeForUTI:UTI];
	}
	
	return result;
}

- (KTCachedImage *)originalAsImage
{
    return [self imageForImageName:@"originalAsImage"];
}

- (void)removeImageForImageName:(NSString *)anImageName
{
    // is it an icon? if so, just remove it from the in-memory cache
    if ( nil != [myCachedIcons valueForKey:anImageName] )
    {
        [myCachedIcons removeObjectForKey:anImageName];
        return;
    }
    
    // do we have a CachedImage
    KTCachedImage *cachedImage = [self cachedImageForImageName:anImageName];
    if ( nil != cachedImage )
    {
        (void)[cachedImage removeCacheFile];
		KTManagedObjectContext *context = (KTManagedObjectContext *)[self managedObjectContext];
		[context lockPSCAndSelf];
        [context deleteObject:cachedImage];
		[[self document] saveContext:context onlyIfNecessary:NO];
		[context unlockPSCAndSelf];
        return;
    }
}

- (NSMutableSet *)substitutableImageNames
{
    return mySubstitutableImageNames; 
}

- (void)setSubstitutableImageNames:(NSMutableSet *)aSubstitutableImageNames
{
    [aSubstitutableImageNames retain];
    [mySubstitutableImageNames release];
    mySubstitutableImageNames = aSubstitutableImageNames;
}

- (BOOL)substituteOriginalForImageName:(NSString *)anImageName
{
	NSEnumerator *e = [[[self substitutableImageNames] allObjects] objectEnumerator];
	NSString *imageName;
	while ( imageName = [e nextObject] )
	{
		if ( [imageName isEqualToString:anImageName] )
		{
			return YES;
		}
	}
	return NO;
}

@end

// for outline view
@implementation NSImage ( docIconCompositing )

- (NSImage *)scaleAndMask32ThumbnailusingCoreImage:(BOOL)useCoreImage;
{
	int width = 32;
	int height = 32;
	if (useCoreImage)
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		float sharpenFactor = [defaults floatForKey:@"KTSharpeningFactor"];
		CIImage *im = [self toCIImage];
		// Show the top/center of the image.  This crop & center it.
		im = [im scaleToWidth:width height:height behavior:kCropToRect alignment:NSImageAlignTop opaqueEdges:YES];
		im = [im sharpenLuminanceWithFactor:sharpenFactor];
		
		// Mask it out
		CIFilter *f = [CIFilter filterWithName:@"CISourceInCompositing"];
		[f setValue:im forKey:@"inputImage"];
		[f setValue:sCIMaskImage forKey:@"inputBackgroundImage"];
		im = [f valueForKey:@"outputImage"];
		
		// And cover with the page
		f = [CIFilter filterWithName:@"CISourceOverCompositing"];
		[f setValue:sCICoverImage forKey:@"inputImage"];
		[f setValue:im forKey:@"inputBackgroundImage"];
		im = [f valueForKey:@"outputImage"];

		return [im toNSImage];
	}
	else
	{
		int w,h,nw,nh;
		w = nw = [self size].width;
		h = nh = [self size].height;
		
		if (w>width || h>height)
		{
			float wr, hr;
			
			// ratios
			wr = w/(float)width;
			hr = h/(float)height;
			
			if (wr>hr) // landscape
			{
				nw = w/hr;
				nh = height;
			}
			else // portrait
			{
				nh = h/wr;
				nw = width;
			}
		}
		
		NSImage *icon = [[[NSImage alloc] initWithSize:NSMakeSize(width, height)] autorelease];
		[icon setCachedSeparately:YES];
		[icon lockFocus];
		OBASSERT([NSGraphicsContext currentContext]);
		[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
		[sMaskImage drawInRect:NSMakeRect(0,0,width,height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		NSRect rect = NSMakeRect((width/2)-(nw/2), (height/2)-(nh/2), nw, nh);
		[self drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceAtop fraction:1.0];
		[sCoverImage drawInRect:NSMakeRect(0,0,width,height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		[icon unlockFocus];
		return icon;
	}		
}

@end
