//
//  KTSiteOutlineDataSource+Icons.m
//  Marvel
//
//  Created by Mike on 17/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVSiteOutlineViewController.h"

#import "KTElementPlugInWrapper.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "KTDocument.h"
#import "SVMediaRecord.h"
#import "SVSiteItem.h"

#import "NSArray+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSInvocation+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"
#import "NSString+Karelia.h"

#import "KSThreadProxy.h"

#import "assertions.h"


NSString *KTDisableCustomSiteOutlineIcons = @"DisableCustomSiteOutlineIcons";


@interface SVSiteOutlineViewController (IconsPrivate)

- (NSImage *)favicon;
- (NSImage *)cachedFavicon;

- (NSImage *)bundleIconForItem:(SVSiteItem *)item;

- (NSImage *)customIconForPage:(KTPage *)page;

- (void)addPageToCustomIconGenerationQueue:(KTPage *)page;
- (void)beginGeneratingCustomIconForPage:(KTPage *)page;

- (unsigned)maximumIconSize;
@end


#pragma mark -


@implementation SVSiteOutlineViewController (Icons)

#pragma mark General

- (void)setIcon:(NSImage *)icon forImageRepresentation:(id)rep;
{
    [_cachedImagesByRepresentation setObject:icon forKey:rep];
}

- (void)threaded_loadIconForItem:(SVSiteItem *)item imageRepresentation:(id)rep;
{
    CGImageSourceRef imageSource = IMB_CGImageSourceCreateWithImageItem(item, NULL);
    if (imageSource)
    {
        NSImage *result = [[NSImage alloc]
                           initWithThumbnailFromCGImageSource:imageSource
                           maxPixelSize:([self maximumIconSize] - 4)];   // shrink to fit shadow
        CFRelease(imageSource);
        
        if (result)	// Some files may not be able to provide a thumbnail, e.g. a .wmv movie
        {
            [result setBackgroundColor:[NSColor whiteColor]];
            
            [[self ks_proxyOnThread:nil waitUntilDone:NO] setIcon:result forImageRepresentation:rep];
            [result release];
        }
    }
}

- (NSImage *)cachedIconForImageRepresentation:(id)rep;
{
    return [_cachedImagesByRepresentation objectForKey:rep];
}

- (NSImage *)iconForItem:(SVSiteItem *)item isThumbnail:(BOOL *)isThumbnail;
{
	OBPRECONDITION(item);
	NSImage *result = nil;
    if (isThumbnail) *isThumbnail = NO;
	
	// The home page always appears as some kind of favicon
	if (item == [self rootPage])
	{
		result = [self favicon];
	}
	else
	{
        id rep = [item imageRepresentation];
        NSString *type = [item imageRepresentationType];
        NSUInteger maxSize = [self maximumIconSize];
        
        if ([type isEqualToString:IKImageBrowserNSImageRepresentationType])
        {
            result = [[rep copy] autorelease];
            [result setSize:NSMakeSize(maxSize, maxSize)];
            if (isThumbnail) *isThumbnail = NO;
        }
        else if (rep)
        {
            // Hopefully there's a cached copy
            result = [self cachedIconForImageRepresentation:rep];
            if (!result)
            {
                NSInvocation *invocation =
                [NSInvocation invocationWithSelector:@selector(threaded_loadIconForItem:imageRepresentation:)
                                              target:self
                                           arguments:[NSArray arrayWithObjects:item, rep, nil]];
                
                NSOperation *op = [[NSInvocationOperation alloc] initWithInvocation:invocation];
                [_queue addOperation:op];
                [op release];
            }
            
            if (isThumbnail) *isThumbnail = YES;
		}
	}
              
              
    if (!result) result = [self bundleIconForItem:item];
	
	
	// As a final resort, we fallback to the broken icon
	if (!result)
	{
		result = [NSImage brokenImage];
	}
	
	
    OBPOSTCONDITION(result);
	return result;
}

/*	Exactly as it says on the tin. Go through and reset all icon caches.
 */
- (void)invalidateIconCaches
{
	[self setCachedFavicon:nil];
	[_cachedPluginIcons removeAllObjects];
	[_cachedImagesByRepresentation removeAllObjects];
}

#pragma mark -
#pragma mark Favicon

- (NSImage *)favicon
{
	NSImage *result = [self cachedFavicon];
	
	// If there isn't a cached icon, try to create it
	if (!result)
	{
		id <IMBImageItem> faviconRecord = [[[self rootPage] master] favicon];
		
		// Create the thumbnail
        if (faviconRecord)
        {
            CGImageSourceRef imageSource = IMB_CGImageSourceCreateWithImageItem(faviconRecord, NULL);
            
            if (imageSource)
            {
                result = [[NSImage alloc] initWithThumbnailFromCGImageSource:imageSource
                                                                maxPixelSize:[self maximumIconSize]];
                CFRelease(imageSource);
            }
		}
        
		// If there is no favicon chosen, default to 32favicon
		if (!result)
		{
			NSString *path = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
            result = [[NSImage alloc] initWithThumbnailOfFile:path
                                               maxPixelSize:[self maximumIconSize]];
		}
        
        // Store
		[self setCachedFavicon:result];
        [result release];
	}
	
	return result;
}

- (NSImage *)cachedFavicon { return _cachedFavicon; }

- (void)setCachedFavicon:(NSImage *)icon
{
	[icon retain];
	[_cachedFavicon release];
	_cachedFavicon = icon;
}

#pragma mark -
#pragma mark Bundle Icons

/*	Support method for displaying the default bundle's icon for a page.
 *	If the page has an index, returns the index icon. Otherwise, the page plugin's icon.
 */
- (NSImage *)bundleIconForItem:(SVSiteItem *)item;
{
	OBPRECONDITION(item);
	
	NSImage *result = nil;
	SVMediaRecord *media = nil;
    
    KTElementPlugInWrapper *plugin = nil;
	if (nil != (media =[item mediaRepresentation]))
    {
		NSString *UTI = [media typeOfFile];
		if ([UTI conformsToUTI:(NSString *)kUTTypeHTML])
		{
			result = [NSImage imageNamed:@"plainText"];

		}
		else if ([UTI conformsToUTI:(NSString *)kUTTypePlainText])
		{
			result = [NSImage imageNamed:@"HTML"];
		}
		else
		{
			result = [NSImage imageNamed:@"download"];
		}
    }
    else if ([item externalLinkRepresentation])
    {
        result = [NSImage imageFromOSType:kGenericURLIcon];
    }
	
    if (!plugin)
	{
        plugin = nil;
		//plugin = [page plugin];
	}
	
	
	return result;	// Can be nil if no plugin is found
}

#pragma mark -
#pragma mark Custom Icons

- (NSImage *)customIconForPage:(KTPage *)page
{
	NSImage *result = [_cachedImagesByRepresentation objectForKey:page];
	
	if (!result)
	{
		result = [self bundleIconForItem:page];
	}
	
    OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Custom Icon Generation Queue

- (void)addPageToCustomIconGenerationQueue:(KTPage *)page
{
	// If the page is already in the queue, bump it to the top of the list
	unsigned index = [_customIconGenerationQueue indexOfObject:page];
	if (index != NSNotFound)
	{
		[_customIconGenerationQueue removeObjectAtIndex:index];
		[_customIconGenerationQueue insertObject:page atIndex:0];
	}
	
	// Otherwise add the page to the queue
	else
	{
		[_customIconGenerationQueue addObject:page];
		
		// Begin generating if there's space
		if (!_generatingCustomIcon)
		{
			[self beginGeneratingCustomIconForPage:page];
		}
	}
}

- (void)beginGeneratingCustomIconForPage:(KTPage *)page
{
	// We only ever generate 1 icon at a time since it's a pretty low priority task
	OBASSERTSTRING(!_generatingCustomIcon, @"Can only generate 1 icon at a time");
	
	// Remove the page from the queue
	[_customIconGenerationQueue removeObject:page];
	
	// Detach thread for generation if possible
	NSString *iconSourcePath = [[[page customSiteOutlineIcon] file] currentPath];
	if (iconSourcePath)
	{
		_generatingCustomIcon = [page retain];
		
		BOOL mask = NO;
		if (![self displaySmallPageIcons])
		{
			mask = [page shouldMaskCustomSiteOutlinePageIcon:page];
		}
		
		NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:
			page, @"page",
			[NSNumber numberWithBool:mask], @"mask",
			iconSourcePath, @"file", nil];
		
		[NSThread detachNewThreadSelector:@selector(threadedGenerateCustomIcon:)
								 toTarget:self
							   withObject:parameters];
	}
}

- (void)didGenerateCustomIcon:(NSImage *)icon forPage:(KTPage *)page
{
	OBPRECONDITION(page);
    
    
    // Update the cache. We want to retain, not copy the key
    if (icon)
    {
        [_cachedImagesByRepresentation setObject:icon forKey:page copyKeyFirst:NO];
    }
    else
    {
        [_cachedImagesByRepresentation removeObjectForKey:page];
    }
	
    
	// Remove page from generating list
	[_generatingCustomIcon release];	_generatingCustomIcon = nil;
	
    
	// Refresh Site Outline for new icon
	if (icon)
    {
        [[self outlineView] setItemNeedsDisplay:page childrenNeedDisplay:NO];
    }
	
    
	// Generate the first icon in queue
	if ([_customIconGenerationQueue count] > 0)
	{
		[self beginGeneratingCustomIconForPage:[_customIconGenerationQueue objectAtIndex:0]];
	}
}

- (void)threadedGenerateCustomIconForPage:(KTPage *)page fromFile:(NSString *)path mask:(BOOL)mask
{
	// Create the icon
	NSImage *result;
	unsigned iconSize = [self maximumIconSize];
	
	if (mask)
	{
		result = [[[self class] maskedIconOfFile:path size:iconSize] retain];
	}
	else
	{
		result = [[NSImage alloc] initWithThumbnailOfFile:path maxPixelSize:iconSize];
	}
	
	// Notify the main thread that we're done
	[[self ks_proxyOnThread:nil] didGenerateCustomIcon:result forPage:page];
	
	// Tidy up
	[result release];
}

- (void)threadedGenerateCustomIcon:(NSDictionary *)parameters
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	[self threadedGenerateCustomIconForPage:[parameters objectForKey:@"page"]
								   fromFile:[parameters objectForKey:@"file"]
									   mask:[parameters boolForKey:@"mask"]];
	
	[pool release];
}

#pragma mark -
#pragma mark Support

/*	Either 32 / 16 pixels depending on the users displaySmallPageIcons setting.
 *	Then multiply by the scale factor.
 */
- (unsigned)maximumIconSize
{
	// Get the scale factor if needed
	static float sScaleFactor;
	if (!sScaleFactor)
	{
		sScaleFactor = [[[self outlineView] window] userSpaceScaleFactor];
	}
	
	// Figure out the size
	if ([self displaySmallPageIcons])
	{
		return sScaleFactor * 16.0;
	}
	else
	{
		return sScaleFactor * 32.0;
	}
}

@end
