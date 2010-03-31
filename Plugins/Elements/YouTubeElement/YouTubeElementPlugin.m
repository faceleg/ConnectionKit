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
@end


@implementation YouTubeElementPlugin

@synthesize userVideoCode = _userVideoCode;
@synthesize videoID = _videoID;
@synthesize color1 = _color1;
@synthesize color2 = _color2;
@synthesize videoSize = _videoSize;
@synthesize widescreen = _widescreen;
@synthesize playHD = _playHD;
@synthesize privacy = _privacy;
@synthesize showBorder = _showBorder;
@synthesize includeRelatedVideos = _includeRelatedVideos;
@synthesize useCustomSecondaryColor = _useCustomSecondaryColor;

+ (Class)inspectorViewControllerClass { return [YouTubeElementInspector class]; }
+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"userVideoCode", @"videoSize", @"color2", @"color1", @"widescreen", @"showBorder", @"includeRelatedVideos", @"useCustomSecondaryColor", @"privacy", @"playHD", nil];
}

+ (NSSet *)keyPathsForValuesAffectingVideoWidth
{
    return [NSSet setWithObjects:@"videoSize", @"widescreen", @"showBorder", nil];
}
+ (NSSet *)keyPathsForValuesAffectingVideoHeight
{
    return [NSSet setWithObjects:@"videoSize", @"widescreen", @"showBorder", nil];
}
+ (NSSet *)keyPathsForValuesAffectingSizeToolTip
{
    return [NSSet setWithObjects:@"videoWidth", @"widescreen", nil];
}


#pragma mark lifetime

- (id)initWithArguments:(NSDictionary *)arguments
{
    self = [super initWithArguments:arguments];
    
    
    // Observer storage
    [self addObserver:self
		  forKeyPaths:[NSSet setWithObjects:@"userVideoCode", @"color2", @"color1", nil]
			  options:NSKeyValueObservingOptionNew
			  context:NULL];
	
    return self;
}

- (void)dealloc
{
	// Remove old observations
	[self removeObserver:self forKeyPaths:[NSSet setWithObjects:@"userVideoCode", @"color2", @"color1", nil]];
		
	// Relase iVars
	self.userVideoCode = nil;
	self.videoID = nil;
	self.color2 = nil;
	self.color1 = nil;
		
	[super dealloc];
}


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
			self.userVideoCode = [URL absoluteString];
		}
		
		// Initial size depends on our location
		YouTubeVideoSize videoSize = YouTubeVideoSizeSmall;//([element isKindOfClass:[KTPagelet class]]) ? YouTubeVideoSizeSidebar : YouTubeVideoSizeSmall;
		self.videoSize = videoSize;
		self.widescreen = YES;
		
		// Prepare initial colors
		self.useCustomSecondaryColor = NO;
		self.color2 = [YouTubeElementPlugin defaultPrimaryColor];
	}
	
// Here we want to NOT allow resizing of element if it's in the sidebar.
//	// Pagelets cannot adjust their size
//	if ([element isKindOfClass:[KTPagelet class]])
//	{
//		[videoSizeSlider setEnabled:NO];
//	}
//	// Pages should have a thumbnail
//	else
	{
		
		/*
		 
			NOT YET WORKING IN SANDVOX 2
		 
		if (![(KTPage *)element thumbnail])
		{
			[(KTPage *)element setThumbnail:[self defaultThumbnail]];
		}
		 */
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
			self.userVideoCode = URLString;
		}
	}
}

*/


#pragma mark -
#pragma mark Plugin

- (void)observeValueForKeyPath:(NSString *)keyPath
					  ofObject:(id)object
					    change:(NSDictionary *)change
					   context:(void *)context
{
	// When the user sets a video code, figure the ID from it
	if ([keyPath isEqualToString:@"userVideoCode"])
	{
		NSString *videoID = nil;
		if (self.userVideoCode) videoID = [[NSURL URLWithString:self.userVideoCode] youTubeVideoID];
		
		self.videoID = videoID;
	}
	
		
	
	// When the user adjusts the main colour WITHOUT having adjusted the secondary color, re-generate
	// a new second colour from it
	else if ([keyPath isEqualToString:@"color2"] && !self.useCustomSecondaryColor)
	{
		NSColor *lightenedColor = [[NSColor whiteColor] blendedColorWithFraction:0.5 ofColor:self.color2];
		
		myAutomaticallyUpdatingSecondaryColorFlag = YES;	// The flag is needed to stop us mis-interpeting the setter
		self.color1 = lightenedColor;
		myAutomaticallyUpdatingSecondaryColorFlag = NO;
	}
	
	
	// When the user sets their own secondary color mark it so no future changes are made by accident
	else if ([keyPath isEqualToString:@"color1"] && !myAutomaticallyUpdatingSecondaryColorFlag)
	{
		self.useCustomSecondaryColor = YES;
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

#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }

#pragma mark Size

- (NSString *)sizeToolTip;
{
	NSString *result = nil;
	static NSArray *sToolTipsNormal = nil;
	static NSArray *sToolTipsWide = nil;
	if (!sToolTipsWide)
	{		
		sToolTipsNormal = [[NSArray alloc] initWithObjects:
						   NSLocalizedString(@"200 pixels wide including any border.", "tooltip description of slider value"),
						   NSLocalizedString(@"320 pixels wide; original size for classic, flat-screen videos.", "tooltip description of slider value"),
						   NSLocalizedString(@"425 pixels wide; standard size of classic YouTube video.", "tooltip description of slider value"),
						   NSLocalizedString(@"480 pixels wide; double size for classic, flat-screen videos.", "tooltip description of slider value"),
						   NSLocalizedString(@"560 pixels wide.", "tooltip description of slider value"),
						   NSLocalizedString(@"640 pixels wide.", "tooltip description of slider value"),
						   NSLocalizedString(@"853 pixels wide. (Wide design required.)", "tooltip description of slider value"),
						   NSLocalizedString(@"1280 pixels wide. (Wide design required.)", "tooltip description of slider value"),
					 nil];
		sToolTipsWide = [[NSArray alloc] initWithObjects:
						 NSLocalizedString(@"200 pixels wide including any border.", "tooltip description of slider value"),
						 NSLocalizedString(@"320 pixels wide.", "tooltip description of slider value"),
						 NSLocalizedString(@"425 pixels wide.", "tooltip description of slider value"),
						 NSLocalizedString(@"480 pixels wide.", "tooltip description of slider value"),
						 NSLocalizedString(@"560 pixels wide.", "tooltip description of slider value"),
						 NSLocalizedString(@"640 pixels wide; 360p size", "tooltip description of slider value"),
						 NSLocalizedString(@"853 pixels wide; 480p size. (Wide design required.)", "tooltip description of slider value"),
						 NSLocalizedString(@"1280 pixels wide; 720p size. (Wide design required.)", "tooltip description of slider value"),
						 nil];
	}
	if (self.videoSize < NUMBER_OF_VIDEO_SIZES)
	{
		if (self.widescreen)
		{
			result = [sToolTipsWide objectAtIndex:self.videoSize];
		}
		else
		{
			result = [sToolTipsNormal objectAtIndex:self.videoSize];
		}
	}
	return result;
}

- (unsigned) videoWidth
{
	unsigned widths[] = { 200, 320, 425, 480, 560, 640, 853, 1280	};
	
	unsigned result = widths[1];
	
	if (self.videoSize < NUMBER_OF_VIDEO_SIZES)
	{
		result = widths[self.videoSize];
	}
	if (self.showBorder && self.videoSize != YouTubeVideoSizeSidebar)	// do not increase width for sidebar!
	{
		result += 20;
	}	
	return result;
}



- (unsigned) videoHeight
{
	unsigned heights[]		= { 150, 240, 319, 360, 420, 480, 640, 960	};	// above width * 3/4
	unsigned heightsWide[]	= { 113, 180, 239, 270, 315, 360, 480, 720	};	// above width * 9/16
	unsigned result = 0;
	
	if (self.widescreen)
	{
		result = heightsWide[1];
		if (self.videoSize == YouTubeVideoSizeSidebar && self.showBorder)	// special case for bordered in sidebar
		{
			// Borders leaves 180 pixels for width of video
			result = 101;
		}
		else if (self.videoSize < NUMBER_OF_VIDEO_SIZES)
		{
			result = heightsWide[self.videoSize];
		}
	}
	else
	{
		result = heights[1];
		if (self.videoSize == YouTubeVideoSizeSidebar && self.showBorder)	// special case for bordered in sidebar
		{
			// Borders leaves 180 pixels for width of video
			result = 135;
		}
		else if (self.videoSize < 8)
		{
			result = heights[self.videoSize];
		}
	}	
	if (self.showBorder && self.videoSize != YouTubeVideoSizeSidebar) 
	{
		result += 20;
	}
	result += 25;	// room for the control bar.
	
	return result;
}


#pragma mark -
#pragma mark Colors

+ (NSColor *)defaultPrimaryColor;
{
	return [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
}

- (void)resetColors;
{
	self.useCustomSecondaryColor = NO;
	self.color2 = [[self class] defaultPrimaryColor];
}

#pragma mark Pasteboard

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
	return [KSWebLocation readableTypesForPasteboard:nil];
}

- (id)initWithPasteboardPropertyList:(id)propertyList
                              ofType:(NSString *)type;
{
    // Only accept YouTube video URLs
    KSWebLocation *location = [[KSWebLocation alloc] initWithPasteboardPropertyList:propertyList
                                                                             ofType:type];
    
    if (location)
    {
        NSString *videoID = [[location URL] youTubeVideoID];
        if (videoID)
        {
            self = [self init];
            [self setVideoID:videoID];
        }
        else
        {
            [self release]; self = nil;
        }
        
        [location release];
    }
    else
    {
        [self release]; self = nil;
    }
	
    return self;
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
