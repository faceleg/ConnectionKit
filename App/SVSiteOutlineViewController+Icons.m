//
//  KTSiteOutlineDataSource+Icons.m
//  Marvel
//
//  Created by Mike on 17/01/2008.
//  Copyright 2008-2011 Karelia Software. All rights reserved.
//

#import "SVSiteOutlineViewController.h"

#import "KTElementPlugInWrapper.h"
#import "KTMaster.h"
#import "KTPage.h"
#import "KTDocument.h"
#import "SVImageItem.h"
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

#import <QuickLook/QuickLook.h>


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

- (NSImage *)cachedIconForImageRepresentation:(id)rep;
{
    return [_cachedImagesByRepresentation objectForKey:rep];
}

- (NSImage *)iconForItem:(SVSiteItem *)item isThumbnail:(BOOL *)isThumbnail;
{
	OBPRECONDITION(item);
	NSImage *result = nil;
    if (isThumbnail) *isThumbnail = NO;
	
	NSUInteger maxSize = [self maximumIconSize];
    
    // The home page always appears as some kind of favicon
	if ([item isRoot])
	{
		result = [self favicon];
	}
	else
	{
        id rep = [item imageRepresentation];
        NSString *type = [item imageRepresentationType];
        
        if ([type isEqualToString:IKImageBrowserNSImageRepresentationType])
        {
            result = [[rep copy] autorelease];
            [result setSize:NSMakeSize(maxSize, maxSize)];
            if (isThumbnail) *isThumbnail = NO;
        }
        else if ([type isEqualToString:IKImageBrowserQuickLookPathRepresentationType])
        {
            // TODO: Run this on background thread and cache result
            CFURLRef url = (CFURLRef)([rep isKindOfClass:[NSString class]] ? [NSURL fileURLWithPath:rep] : rep);
            
            CGImageRef image = QLThumbnailImageCreate(NULL, url, CGSizeMake(maxSize, maxSize), NULL);
            if (image)
            {
                NSBitmapImageRep *bitmap = [[NSBitmapImageRep alloc] initWithCGImage:image];
                CFRelease(image);
                
                result = [NSImage imageWithBitmap:bitmap];
                [bitmap release];
            }
        }
        else if (rep)
        {
            // Hopefully there's a cached copy
            result = [self cachedIconForImageRepresentation:rep];
            if (!result)
            {
                [_cachedImagesByRepresentation setObject:[NSNull null] forKey:rep];
                
                SVImageItem *imageItem = [[SVImageItem alloc] initWithIMBImageItem:item];
                
                NSOperation *op = [[NSInvocationOperation alloc]
                                   initWithTarget:self
                                   selector:@selector(threaded_loadIconWithItem:)
                                   object:imageItem];
                
                
                [_queue addOperation:op];
                [imageItem release];
                [op release];
            }
            else if ((id)result == [NSNull null])   // it hasn't loaded yet
            {
                result = nil;
            }
            
            if (result && isThumbnail) *isThumbnail = YES;
		}
	}
              
              
    if (!result)
    {
        result = [self bundleIconForItem:item];
        
        // As a final resort, we fallback to the broken icon
        if (!result)
        {
            result = [NSImage brokenImage];
        }
        
        result = [[result copy] autorelease];
        [result setSize:NSMakeSize(maxSize, maxSize)];
    }
	
	
	
    OBPOSTCONDITION(result);
	return result;
}

- (void)didLoadIcon:(NSImage *)icon withItem:(SVImageItem *)item;
{
    [_cachedImagesByRepresentation setObject:icon forKey:[item imageRepresentation]];
    
    // Redraw any items affected
    NSOutlineView *outlineView = [self outlineView];
    NSRange visibleRows = [outlineView rowsInRect:[outlineView visibleRect]];
    
    for (int aRow = visibleRows.location; aRow < visibleRows.location + visibleRows.length; aRow++)
    {
        SVSiteItem *anItem = [[outlineView itemAtRow:aRow] representedObject];
        if ([item isEqualToIMBImageItem:anItem])
        {
            NSRect displayRect = [outlineView rectOfRow:aRow];
            [outlineView setNeedsDisplayInRect:displayRect];
        }
    }
}

- (void)threaded_loadIconWithItem:(SVImageItem *)item;
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
            
            [[self ks_proxyOnThread:nil waitUntilDone:NO] didLoadIcon:result withItem:item];
            [result release];
        }
    }
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
		SVMediaRecord *faviconRecord = [[[[[[[self content] arrangedObjects] childNodes] firstObjectKS] representedObject] master] favicon];
		
		// Create the thumbnail
        if (faviconRecord)
        {
            SVImageItem *imageItem = [[SVImageItem alloc]
                                      initWithImageRepresentation:[[faviconRecord media] imageRepresentation]
                                      type:[[faviconRecord media] imageRepresentationType]];
            
            CGImageSourceRef imageSource = IMB_CGImageSourceCreateWithImageItem(imageItem, NULL);
            [imageItem release];
            
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

// APPEARS NOT TO BE FULLY USED, FOR THE TEXT/HTML STUFF....

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
			result = [NSImage imageNamed:@"textPage"];

		}
		else if ([UTI conformsToUTI:(NSString *)kUTTypePlainText])
		{
			result = [NSImage imageNamed:@"htmlPage"];
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
