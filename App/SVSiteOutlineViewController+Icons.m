//
//  KTSiteOutlineDataSource+Icons.m
//  Marvel
//
//  Created by Mike on 17/01/2008.
//  Copyright 2008-2009 Karelia Software. All rights reserved.
//

#import "SVSiteOutlineViewController.h"

#import "KTElementPlugin.h"
#import "KTMaster.h"
#import "KTMediaContainer.h"
#import "KTPage.h"
#import "KTMediaFile.h"
#import "KTDocument.h"
#import "SVSiteItem.h"

#import "NSArray+Karelia.h"
#import "NSDictionary+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSObject+Karelia.h"
#import "NSOutlineView+KTExtensions.h"
#import "NSManagedObjectContext+KTExtensions.h"

#import "KSThreadProxy.h"

#import "assertions.h"


NSString *KTDisableCustomSiteOutlineIcons = @"DisableCustomSiteOutlineIcons";


@interface SVSiteOutlineViewController (IconsPrivate)

- (NSImage *)favicon;
- (NSImage *)cachedFavicon;

- (NSImage *)bundleIconForItem:(SVSiteItem *)item;

- (NSImage *)customIconForPage:(KTPage *)page;
+ (NSImage *)maskedIconOfFile:(NSString *)path size:(float)iconSize;
+ (NSImage *)customPageIconMaskImage;
+ (NSImage *)customPageIconCoverImage;

- (void)addPageToCustomIconGenerationQueue:(KTPage *)page;
- (void)beginGeneratingCustomIconForPage:(KTPage *)page;

- (unsigned)maximumIconSize;
@end


#pragma mark -


@implementation SVSiteOutlineViewController (Icons)

#pragma mark -
#pragma mark General

- (NSImage *)iconForItem:(SVSiteItem *)item;
{
	OBPRECONDITION(item);
	NSImage *result = nil;
	
	// The home page always appears as some kind of favicon
	if (item == [self rootPage])
	{
		result = [self favicon];
	}
	else
	{
		// Custom icon if available
		KTMediaContainer *customIcon = [item customSiteOutlineIcon];
		if (customIcon && ![[NSUserDefaults standardUserDefaults] boolForKey:KTDisableCustomSiteOutlineIcons])
		{
			result = [self customIconForPage:(KTPage *)item];
		}
		// Fallback to the plugin's bundle icon
		else
		{
			result = [self bundleIconForItem:item];
		}
	}
	
	
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
	[_cachedCustomPageIcons removeAllObjects];
}

#pragma mark -
#pragma mark Favicon

- (NSImage *)favicon
{
	NSImage *result = [self cachedFavicon];
	
	// If there isn't a cached icon, try to create it
	if (!result)
	{
		KTMediaContainer *faviconSource = [[[self rootPage] master] favicon];
		NSString *faviconSourcePath = [[faviconSource file] currentPath];
		
		// If there is no favicon chosen, default to 32favicon
		if (!faviconSourcePath)
		{
			faviconSourcePath = [[NSBundle mainBundle] pathForImageResource:@"32favicon"];
		}
		
		// Create the thumbnail
		result = [[NSImage alloc] initWithContentsOfFile:faviconSourcePath ofMaximumSize:[self maximumIconSize]];
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

- (NSImage *)iconForPlugin:(KTAbstractHTMLPlugin *)plugin
{
	OBPRECONDITION(plugin);
	
	NSString *bundleIdentifier = [plugin identifier];
	OBASSERT(bundleIdentifier);
	NSImage *result = [_cachedPluginIcons objectForKey:bundleIdentifier];
	
	if (!result)
	{
		result = [plugin pluginIcon];
		[_cachedPluginIcons setObject:result forKey:bundleIdentifier];
	}
	
    OBPOSTCONDITION(result);
	return result;
}

/*	Support method for displaying the default bundle's icon for a page.
 *	If the page has an index, returns the index icon. Otherwise, the page plugin's icon.
 */
- (NSImage *)bundleIconForItem:(SVSiteItem *)item;
{
	OBPRECONDITION(item);
	
	KTAbstractHTMLPlugin *plugin;
	if ([item isCollection] && [(KTPage *)item index])
	{
		plugin = [[(KTPage *)item index] plugin];
	}
	else
	{
        plugin = nil;
		//plugin = [page plugin];
	}
	
	
	NSImage *result = nil;
	if (plugin)
	{
		result = [self iconForPlugin:plugin];
	}
	
	return result;	// Can be nil if no plugin is found
}

#pragma mark -
#pragma mark Custom Icons

- (NSImage *)customIconForPage:(KTPage *)page
{
	NSImage *result = [_cachedCustomPageIcons objectForKey:page];
	
	if (!result)
	{
		result = [self bundleIconForItem:page];
		
		NSString *iconSourcePath = [[[page customSiteOutlineIcon] file] currentPath];
		if (iconSourcePath)
		{
			// Begin generating the thumbnail in the background. In the meantime, display the default icon.
			[self addPageToCustomIconGenerationQueue:page];
		}
	}
	
    OBPOSTCONDITION(result);
	return result;
}

/*	Takes the image at the path and masks it to the specified size.
 */
+ (NSImage *)maskedIconOfFile:(NSString *)path size:(float)iconSize
{
	NSImage *result = nil;
    
    
    // Fetch the thumbnail dimensions. If this fails, there's no point trying to make an icon
	CGImageSourceRef iconSource = CGImageSourceCreateWithURL((CFURLRef)[NSURL fileURLWithPath:path], NULL);
    if (iconSource)
    {
        NSDictionary *properties = (NSDictionary *)CGImageSourceCopyPropertiesAtIndex(iconSource, 0, NULL);
        float width = [properties floatForKey:(NSString *)kCGImagePropertyPixelWidth];
        float height = [properties floatForKey:(NSString *)kCGImagePropertyPixelHeight];
        CFRelease(iconSource);
        [properties release];
        
        
        // Create the "canvas"
        NSRect iconRect = NSMakeRect(0.0, 0.0, iconSize, iconSize);
        result = [[[NSImage alloc] initWithSize:iconRect.size] autorelease];
        [result setCachedSeparately:YES];
        [result lockFocus];
        
        
        // Draw the mask
        [[self customPageIconMaskImage] drawInRect:iconRect fromRect:NSZeroRect
                                         operation:NSCompositeSourceOver fraction:1.0];
        
        
        // Figure out the max size for the thumbnail that gives a cropToFit behavior
        float largeDimension;	float smallDimension;
        if (height > width)
        {
            largeDimension = height;	smallDimension = width;
        }
        else
        {
            largeDimension = width;		smallDimension = height;
        }
        float maxSize = ceilf(largeDimension * (iconSize / smallDimension));
        
        
        // Draw the thumbnail
        NSImage *thumbnail = [[NSImage alloc] initWithContentsOfFile:path ofMaximumSize:maxSize];
        float thumbOriginX = 0.5 * ([thumbnail size].width - iconSize);
        float thumbOriginY = 0.5 * ([thumbnail size].height - iconSize);
        NSRect thumbSourceRect = NSMakeRect(thumbOriginX, thumbOriginY, iconSize, iconSize);
        [thumbnail drawInRect:iconRect fromRect:thumbSourceRect operation:NSCompositeSourceAtop fraction:1.0];
        [thumbnail release];
        
        
        
        // Draw the cover image
        [[self customPageIconCoverImage] drawInRect:iconRect fromRect:NSZeroRect
                                          operation:NSCompositeSourceOver fraction:1.0];
        
        
        // Tidy up
        [result unlockFocus];
    }
    
    return result;
}

+ (NSImage *)customPageIconMaskImage
{
	static NSImage *result;
	
	if (!result)
	{
		result = [[NSImage imageNamed:@"pagemask"] retain];
	}
	
	return result;
}

+ (NSImage *)customPageIconCoverImage
{
	static NSImage *result;
	
	if (!result)
	{
		result = [[NSImage imageNamed:@"pageborder"] retain];
	}
	
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
        [_cachedCustomPageIcons setObject:icon forKey:page copyKeyFirst:NO];
    }
    else
    {
        [_cachedCustomPageIcons removeObjectForKey:page];
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
		result = [[NSImage alloc] initWithContentsOfFile:path ofMaximumSize:iconSize];
	}
	
	// Notify the main thread that we're done
	[[self proxyForMainThread] didGenerateCustomIcon:result forPage:page];
	
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
