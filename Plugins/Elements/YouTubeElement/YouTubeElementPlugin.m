//
//  YouTubeElementPlugin.m
//  YouTubeElement
//
//  Created by Dan Wood on 2/23/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "YouTubeElementPlugin.h"
#import "YouTubeElementInspector.h"
#import "YouTubeCocoaExtensions.h"

@interface YouTubeElementPlugin ()
- (KTMediaContainer *)defaultThumbnail;
@end


@implementation YouTubeElementPlugin

+ (Class)inspectorViewControllerClass { return [YouTubeElementInspector class]; }
+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"userVideoCode", @"videoSize", @"color2", @"color1", @"showBorder", @"includeRelatedVideos", nil];
}

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	if (isNewObject)
	{
		// Try to load video from web browser
		NSURL *URL = nil;
		[NSAppleScript getWebBrowserURL:&URL title:NULL source:NULL];
		if (URL && [URL youTubeVideoID])
		{
			[self setValue:[URL absoluteString] forKey:@"userVideoCode"];
		}
		
		// Initial size depends on our location
		YouTubeVideoSize videoSize = YouTubeVideoSizeDefault;//([element isKindOfClass:[KTPagelet class]]) ? YouTubeVideoSizePageletWidth : YouTubeVideoSizeDefault;
		[self setInteger:videoSize forKey:@"videoSize"];
		
		// Prepare initial colors
		[self resetColors];
	}
	
	
	// Pages should have a thumbnail
	else
	{
		if (![(KTPage *)self thumbnail])
		{
			[(KTPage *)self setThumbnail:[self defaultThumbnail]];
		}
	}
}

/* ???? WHAT HAPPENS WITH THIS?
 
- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	// Look for a YouTube URL
	NSString *URLString = [aDataSourceDictionary valueForKey:kKTDataSourceURLString];
	if (URLString)
	{
		NSURL *URL = [NSURL URLWithString:URLString];
		if (URL && [URL youTubeVideoID])
		{
			[self setValue:URLString forKey:@"userVideoCode"];
		}
	}
}

*/


#pragma mark -
#pragma mark Plugin

- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue;
{
	// When the user sets a video code, figure the ID from it
	if ([key isEqualToString:@"userVideoCode"])
	{
		NSString *videoID = nil;
		if (value) videoID = [[NSURL URLWithString:value] youTubeVideoID];
		
		[plugin setValue:videoID forKey:@"videoID"];
	}
	
	
	// Update video width & height to match chosen size
	else if ([key isEqualToString:@"videoSize"] || [key isEqualToString:@"showBorder"])
	{
		YouTubeVideoSize videoSize = [plugin integerForKey:@"videoSize"];
		unsigned videoWidth = [self videoWidthForSize:videoSize];
		[plugin setInteger:videoWidth forKey:@"videoWidth"];
		[plugin setInteger:[self videoHeightForSize:videoSize] forKey:@"videoHeight"];
	}
	
	
	// When the user adjusts the main colour WITHOUT having adjusted the secondary color, re-generate
	// a new second colour from it
	else if ([key isEqualToString:@"color2"] && ![plugin boolForKey:@"useCustomSecondaryColor"])
	{
		NSColor *lightenedColor = [[NSColor whiteColor] blendedColorWithFraction:0.5 ofColor:value];
		
		myAutomaticallyUpdatingSecondaryColorFlag = YES;	// The flag is needed to stop us
		[plugin setValue:lightenedColor forKey:@"color1"];	// mis-interpeting the setter
		myAutomaticallyUpdatingSecondaryColorFlag = NO;
	}
	
	
	// When the user sets their own secondary color mark it so no future changes are made by accident
	else if ([key isEqualToString:@"color1"] && !myAutomaticallyUpdatingSecondaryColorFlag)
	{
		[plugin setBool:YES forKey:@"useCustomSecondaryColor"];
	}
}


/*	Cut a strict down -- we shouldn't have strict with the 'embed' tag
 */
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	
	if (*docType > KTXHTMLTransitionalDocType)
	{
		*docType = KTXHTMLTransitionalDocType;
	}
}

#pragma mark -
#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }

#pragma mark -
#pragma mark Thumbnail

/*	Instead of clearing the thumbnail, reset it to the default.
 */
- (BOOL)pageShouldClearThumbnail:(KTPage *)page
{
	[page setThumbnail:[self defaultThumbnail]];
	return NO;
}

- (KTMediaContainer *)defaultThumbnail
{
	NSString *iconPath = [[self bundle] pathForImageResource:@"YouTube"];
	OBASSERT(iconPath);
	
	KTMediaContainer *result = [[self mediaManager] mediaContainerWithPath:iconPath];
	OBPOSTCONDITION(result);
	return result;
}

#pragma mark -
#pragma mark Width

- (unsigned)videoWidthForSize:(YouTubeVideoSize)size
{
	unsigned result = 425;
	
	switch (size)
	{
		case YouTubeVideoSizePageletWidth:
			result = 200;	// width regardless of border size
			break;
		case YouTubeVideoSizeNatural:
			result = ([self boolForKey:@"showBorder"]) ? 347 : 320;
			break;
		case YouTubeVideoSizeDefault:
			result = 425;	// Do what YouTube does, fixed width regardless of border
			break;
		case YouTubeVideoSizeSidebarPageWidth:
			result = 480;
			break;
		default:
			OBASSERT_NOT_REACHED("Unknown YouTube video size");
	}
	
	return result;
}

- (unsigned)videoHeightForSize:(YouTubeVideoSize)size;
{
	unsigned result = 0;
	
	if ([self boolForKey:@"showBorder"])
	{
		switch (size)
		{
			case YouTubeVideoSizePageletWidth:
				result = 178;
				break;
			case YouTubeVideoSizeNatural:
				result = 308;
				// empirical width to force video itself to be exactly 320 pixels wide
				break;
			case YouTubeVideoSizeDefault:
				result = 373;
				break;
			case YouTubeVideoSizeSidebarPageWidth:
				result = 414;
				break;
			default:
				OBASSERT_NOT_REACHED("Unknown YouTube video size");
		}
	}
	else
	{
		switch (size)
		{
			case YouTubeVideoSizePageletWidth:
				result = 169;
				break;
			case YouTubeVideoSizeNatural:
				result = 269;
				break;
			case YouTubeVideoSizeDefault:
				result = 355;
				break;
			case YouTubeVideoSizeSidebarPageWidth:
				result = 397;
				break;
			default:
				OBASSERT_NOT_REACHED("Unknown YouTube video size");
		}
	}
	return result;
}

#pragma mark -
#pragma mark Colors

+ (NSColor *)defaultPrimaryColor
{
	return [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
}

- (IBAction)resetColors
{
	[self setBool:NO forKey:@"useCustomSecondaryColor"];
	[self setValue:[[self class] defaultPrimaryColor] forKey:@"color2"];
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
	return [KSWebLocation webLocationPasteboardTypes];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)sender
{
    return 1;
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
	KTSourcePriority result = KTSourcePriorityNone;
    
	NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > dragIndex)
	{
		NSURL *URL = [[webLocations objectAtIndex:dragIndex] URL];
		if ([URL youTubeVideoID])
		{
			result = KTSourcePrioritySpecialized;
		}
	}
	
	return result;
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;
{
	BOOL result = NO;
    
	NSArray *webLocations = [KSWebLocation webLocationsFromPasteboard:pasteboard readWeblocFiles:YES ignoreFileURLs:YES];
	
	if ([webLocations count] > dragIndex)
	{
		NSURL *URL = [[webLocations objectAtIndex:dragIndex] URL];
		NSString *title = [[webLocations objectAtIndex:dragIndex] title];
		
		[aDictionary setValue:[URL absoluteString] forKey:kKTDataSourceURLString];
        if (!KSISNULL(title))
		{
			[aDictionary setObject:title forKey:kKTDataSourceTitle];
		}
		
		result = YES;
	}
    
    return result;
}



@end
