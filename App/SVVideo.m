// 
//  SVVideo.m
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//


#import "SVVideo.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "SVVideoInspector.h"
#import <QTKit/QTKit.h>
#include <zlib.h>
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"

@implementation SVVideo 

- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"autoplay"];
	[self removeObserver:self forKeyPath:@"controller"];
	[super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
	if ([keyPath isEqualToString:@"autoplay"])
	{
		if (self.autoplay.boolValue)	// if we turn on autoplay, we also turn on preload
		{
			self.preload = NSBOOL(YES);
		}
		
	}
	else if ([keyPath isEqualToString:@"controller"])
	{
		if (!self.controller.boolValue)	// if we turn off controller, we turn on autoplay so we can play!
		{
			self.autoplay = NSBOOL(YES);
		}
	}
}

+ (SVVideo *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVVideo *result = [NSEntityDescription insertNewObjectForEntityForName:@"Movie"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)willInsertIntoPage:(KTPage *)page;
{
	[self addObserver:self forKeyPath:@"autoplay"	options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"controller"	options:(NSKeyValueObservingOptionNew) context:nil];

    // Placeholder image
    if (![self media])
    {
        SVMediaRecord *media = // [[[page rootPage] master] makePlaceholdImageMediaWithEntityName:];
		[SVMediaRecord mediaWithBundledURL:[NSURL fileURLWithPath:@"/System/Library/Compositions/Sunset.mov"]
									entityName:@"GraphicMedia"
				insertIntoManagedObjectContext:[self managedObjectContext]];
		
		
        [self setMedia:media];
        [self setCodecType:[media typeOfFile]];
        
        [self makeOriginalSize];    // calling super will scale back down if needed
        [self setConstrainProportions:YES];
    }
    
    [super willInsertIntoPage:page];
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

@dynamic posterFrame;
@dynamic autoplay;
@dynamic controller;
@dynamic preload;
@dynamic loop;

- (void)writeBody:(SVHTMLContext *)context;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *type = [self codecType];
    // Image needs unique ID for DOM Controller to find
    
    SVMediaRecord *media = [self media];
	NSURL *movieSourceURL = [self externalSourceURL];
    if (media)
    {
	    movieSourceURL = [context addMedia:media width:[self width] height:[self height] type:[self codecType]];
	}
	
	NSString *movieSourcePath = @"";
	if (movieSourceURL)
	{
		movieSourcePath = [context relativeURLStringOfURL:movieSourceURL];
	}
	
	NSString *posterSourcePath = @"";
	NSURL *posterSourceURL = nil;
	if (self.posterFrame)
	{
		posterSourceURL = [context addMedia:self.posterFrame width:[self width] height:[self height] type:self.posterFrame.typeOfFile];
		posterSourcePath = [context relativeURLStringOfURL:posterSourceURL];
	}
	
	// video || flash (not mutually exclusive) are mutually exclusive with microsoft, quicktime
	
	BOOL videoTag = [type conformsToUTI:@"public.mpeg-4"] || [type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"];
	if ([defaults boolForKey:@"avoidVideoTag"]) videoTag = NO;
	
	BOOL flashTag = [type conformsToUTI:@"public.mpeg-4"] || [type conformsToUTI:@"com.adobe.flash.video"];
	if ([defaults boolForKey:@"avoidFlashVideo"]) flashTag = NO;
	
	BOOL microsoftTag = [type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"];
	
	// quicktime fallback, but not for mp4.  We may want to be more selective of mpeg-4 types though.
	BOOL quicktimeTag = ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
		&& ![type conformsToUTI:@"public.mpeg-4"];
		
	NSString *idNameVideo  = [@"video-" stringByAppendingString:[self elementID]];
	NSString *idNameObject = [@"object-" stringByAppendingString:[self elementID]];

	if (quicktimeTag)
	{
		[context pushElementAttribute:@"id" value:idNameObject];	// ID on <object> apparently required for IE8
		[context pushElementAttribute:@"width" value:[[self width] description]];
		[context pushElementAttribute:@"height" value:[[self height] description]];
		[context pushElementAttribute:@"classid" value:@"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"];	// Proper value?
		[context pushElementAttribute:@"codebase" value:@"http://www.apple.com/qtactivex/qtplugin.cab"];
		[context startElement:@"object"];
		
		if (self.posterFrame && !self.autoplay.boolValue)	// poster and not auto-starting? make it an href
		{
			[context writeParamElementWithName:@"src" value:posterSourcePath];
			[context writeParamElementWithName:@"href" value:movieSourcePath];
			[context writeParamElementWithName:@"target" value:@"myself"];
		}
		else
		{
			[context writeParamElementWithName:@"src" value:movieSourcePath];
		}

		[context writeParamElementWithName:@"autoplay" value:self.autoplay.boolValue ? @"true" : @"false"];
		[context writeParamElementWithName:@"controller" value:self.controller.boolValue ? @"true" : @"false"];
		[context writeParamElementWithName:@"loop" value:self.loop.boolValue ? @"true" : @"false"];
		[context writeParamElementWithName:@"scale" value:@"tofit"];
		[context writeParamElementWithName:@"type" value:@"video/quicktime"];
		[context writeParamElementWithName:@"pluginspage" value:@"http://www.apple.com/quicktime/download/"];
		
	}
	else if (microsoftTag)
	{
		// I don't think there is any way to use the poster frame for a click to play
		
		[context pushElementAttribute:@"id" value:idNameObject];	// ID on <object> apparently required for IE8
		[context pushElementAttribute:@"width" value:[[self width] description]];
		[context pushElementAttribute:@"height" value:[[self height] description]];
		[context pushElementAttribute:@"classid" value:@"CLSID:6BF52A52-394A-11D3-B153-00C04F79FAA6"];
		[context startElement:@"object"];

		[context writeParamElementWithName:@"url" value:movieSourcePath];
		[context writeParamElementWithName:@"autostart" value:self.autoplay.boolValue ? @"true" : @"false"];
		[context writeParamElementWithName:@"showcontrols" value:self.controller.boolValue ? @"true" : @"false"];
		[context writeParamElementWithName:@"playcount" value:self.loop.boolValue ? @"9999" : @"1"];
		[context writeParamElementWithName:@"type" value:@"application/x-oleobject"];
		[context writeParamElementWithName:@"uiMode" value:@"mini"];
		[context writeParamElementWithName:@"pluginspage" value:@"http://microsoft.com/windows/mediaplayer/en/download/"];
		
	}
	else if (videoTag || flashTag)
	{
		if (videoTag)	// start the video tag
		{
			// Write the fallback method.  COULD WRITE THIS IN JQUERY TO BE MORE TERSE?
			
			NSString *oneTimeScript = @"<script type='text/javascript'>\nfunction fallback(video) {\n while (video.firstChild) {\n  if (video.firstChild.nodeName == 'SOURCE') {\n   video.removeChild(video.firstChild);\n  } else {\n   video.parentNode.insertBefore(video.firstChild, video);\n  }\n }\n video.parentNode.removeChild(video);\n}\n</script>\n";
			
			NSRange whereOneTimeScript = [[context extraHeaderMarkup] rangeOfString:oneTimeScript];
			if (NSNotFound == whereOneTimeScript.location)
			{
				[[context extraHeaderMarkup] appendString:oneTimeScript];
			}
			
			
			// Actually write the video
			[context pushElementAttribute:@"id" value:idNameVideo];
			if ([self displayInline]) [self buildClassName:context];
			[context pushElementAttribute:@"width" value:[[self width] description]];
			[context pushElementAttribute:@"height" value:[[self height] description]];
			
			if (self.controller.boolValue)	[context pushElementAttribute:@"controls" value:@"controls"];		// boolean attribute
			if (self.autoplay.boolValue)	[context pushElementAttribute:@"autoplay" value:@"autoplay"];
			[context pushElementAttribute:@"preload" value:self.preload.boolValue ? @"auto" : @"none" ];
			if (self.loop.boolValue)		[context pushElementAttribute:@"loop" value:@"loop"];

			// POSTER: poster="....." Maybe some sort of iPad sniffing to disallow?
			
			[context startElement:@"video"];

			// source
			[context pushElementAttribute:@"src" value:movieSourcePath];
			[context pushElementAttribute:@"type" value:[NSString MIMETypeForUTI:type]];
			[context pushElementAttribute:@"onerror" value:@"fallback(this.parentNode)"];
			[context startElement:@"source"];
			[context endElement];
			
		}
		
		if (flashTag)	// inner
		{
			NSString *videoFlashPlayer	= [defaults objectForKey:@"videoFlashPlayer"];	// to override player type
				// Known types: f4player jwplayer flvplayer osflv flowplayer.  Otherwise must specify videoFlashFormat.
			if (!videoFlashPlayer) videoFlashPlayer = @"flvplayer";
			NSString *videoFlashPath	= [defaults objectForKey:@"videoFlashPath"];	// override must specify path/URL on server
			NSString *videoFlashExtras	= [defaults objectForKey:@"videoFlashExtras"];	// extra parameters to override for any player
			NSString *videoFlashFormat	= [defaults objectForKey:@"videoFlashFormat"];	// format pattern with %{value1}@ and %{value2}@ for movie, poster
			NSString *videoFlashBarHeight= [defaults objectForKey:@"videoFlashBarHeight"];	// height that the navigation bar adds
			BOOL videoFlashRequiresFullURL = [defaults boolForKey:@"videoFlashRequiresFullURL"];	// usually not, but YES for flowplayer
			
			if ([videoFlashPlayer isEqualToString:@"flowplayer"]) videoFlashRequiresFullURL = YES;
			
			NSDictionary *noPosterParamLookup
			= NSDICT(
					 @"video=%@",                                  @"f4player",	
					 @"file=%@",                                   @"jwplayer",	
					 @"flv=%@&margin=0",                           @"flvplayer",	
					 @"movie=%@",                                  @"osflv",		
					 @"config={\"playlist\":[{\"url\":\"%@\"}]}",  @"flowplayer");
			NSDictionary *posterParamLookup
			= NSDICT(
					 @"video=%{value1}@&thumbnail=%{value2}@",         @"f4player",
					 @"file=%{value1}@&image=%{value2}@",              @"jwplayer",
					 @"flv=%{value1}@&startimage=%{value2}@&margin=0", @"flvplayer",
					 @"movie=%{value1}@&previewimage=%{value2}@",      @"osflv",	
					 @"config={\"playlist\":[{\"url\":\"%{value2}@\"},{\"url\":\"%{value1}@\",\"autoPlay\":false,\"autoBuffering\":true}]}",
						@"flowplayer");
			NSDictionary *barHeightLookup
			= NSDICT(
					 [NSNumber numberWithShort:0],  @"f4player",	
					 [NSNumber numberWithShort:24], @"jwplayer",	
					 [NSNumber numberWithShort:0],  @"flvplayer",	
					 [NSNumber numberWithShort:25], @"osflv",		
					 [NSNumber numberWithShort:0],   @"flowplayer");
			
			NSUInteger barHeight = 0;
			if (videoFlashBarHeight)
			{
				barHeight= [videoFlashBarHeight intValue];
			}
			else
			{
				barHeight = [[barHeightLookup objectForKey:videoFlashPlayer] intValue];
			}

			NSString *flashVarFormatString = nil;
			if (videoFlashFormat)		// override format?
			{
				flashVarFormatString = videoFlashFormat;
			}
			else
			{
				NSDictionary *formatLookupDict = (self.posterFrame) ? posterParamLookup : noPosterParamLookup;
				flashVarFormatString = [formatLookupDict objectForKey:videoFlashPlayer];
			}

			// Now instantiate the string from the format
			NSMutableString *flashVars = nil;
			NSString *movieSourcePathOrURLString  = videoFlashRequiresFullURL ? [movieSourceURL  absoluteString] : movieSourcePath;
			NSString *posterSourcePathOrURLString = videoFlashRequiresFullURL ? [posterSourceURL absoluteString] : posterSourcePath;
			if (self.posterFrame)
			{
				flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePathOrURLString, posterSourcePathOrURLString];
			}
			else
			{
				flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePathOrURLString];
			}
			
			
			if ([videoFlashPlayer isEqualToString:@"flvplayer"])
			{
				[flashVars appendFormat:@"&showplayer=%@", (self.controller.boolValue) ? @"autohide" : @"never"];
				if (self.autoplay.boolValue)	[flashVars appendString:@"&autoplay=1"];
				if (self.preload.boolValue)		[flashVars appendString:@"&autoload=1"];
				if (self.loop.boolValue)		[flashVars appendString:@"&loop=1"];
			}
			if (videoFlashExtras)	// append other parameters (usually like key1=value1&key2=value2)
			{
				[flashVars appendString:@"&"];
				[flashVars appendString:videoFlashExtras];
			}
			
			NSString *playerPath = nil;
			if (videoFlashPath)
			{
				playerPath = videoFlashPath;		// specified by defaults
			}
			else
			{
				NSString *localPlayerPath = [[NSBundle mainBundle] pathForResource:@"player_flv_maxi" ofType:@"swf"];
				NSURL *playerURL = [context addResourceWithURL:[NSURL fileURLWithPath:localPlayerPath]];
				playerPath = [context relativeURLStringOfURL:playerURL];
			}
			
			[context pushElementAttribute:@"id" value:idNameObject];	// ID on <object> apparently required for IE8
			if ([self displayInline]) [self buildClassName:context];
			[context pushElementAttribute:@"type" value:@"application/x-shockwave-flash"];
			[context pushElementAttribute:@"data" value:playerPath];
			[context pushElementAttribute:@"width" value:[[self width] description]];
			
			NSUInteger heightWithBar = barHeight + [[self height] intValue];
			[context pushElementAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
			[context startElement:@"object"];
			
			[context writeParamElementWithName:@"movie" value:playerPath];
			[context writeParamElementWithName:@"flashvars" value:flashVars];
			
			NSDictionary *videoFlashExtraParams = [defaults objectForKey:@"videoFlashExtraParams"];
			if ([videoFlashExtraParams respondsToSelector:@selector(keyEnumerator)])	// sanity check
			{
				for (NSString *key in videoFlashExtraParams)
				{
					[context writeParamElementWithName:key value:[videoFlashExtraParams objectForKey:key]];
				}
			}
		}
		
		if (self.posterFrame)		// image within the video or object tag as a fallback
		{			
			// Get a title to indicate that the movie cannot play inline.  (Suggest downloading, if we provide a link)
			KTPage *thePage = [context page];
			NSString *language = [thePage language];
			NSString *cannotViewTitle = [[NSBundle mainBundle] localizedStringForString:@"cannotViewTitleText"
																						language:language
																						fallback:
												  NSLocalizedStringWithDefaultValue(@"cannotViewTitleText", nil, [NSBundle mainBundle], @"Cannot view this video from the browser.", @"Warning to show when a video cannot be played")];
			
			NSString *altForMovieFallback = [[posterSourcePath lastPathComponent] stringByDeletingPathExtension];// Cheating ... What would be a good alt ?
			
			[context pushElementAttribute:@"title" value:cannotViewTitle];
			[context writeImageWithSrc:posterSourcePath alt:altForMovieFallback width:[[self width] description] height:[[self height] description]];
		}
		
		if (flashTag || quicktimeTag || microsoftTag)	// time to end all of these objects
		{
			OBASSERT([@"object" isEqualToString:[context topElement]]);
			[context endElement];	//  </object>
		}
		
		if (videoTag)	// close the video tag
		{
			OBASSERT([@"video" isEqualToString:[context topElement]]);
			[context endElement];
			
			// Now write the post-video-tag surgery since onerror doesn't really work
			// This is hackish browser-sniffing!  Maybe later we can do away with this (especially if we can get > 1 video source)
			
			[context startJavascriptElementWithSrc:nil];
			[context stopWritingInline];
			[context writeString:[NSString stringWithFormat:@"var video = document.getElementById('%@');\n", idNameVideo]];
			[context writeString:[NSString stringWithFormat:@"if (video.canPlayType && video.canPlayType('%@')) {\n", [NSString MIMETypeForUTI:type]]];
			[context writeString:@"\t// canPlayType is overoptimistic, so we have browser sniff.\n"];
			
			// we have mp4, so no ogv/webm, so force a fallback if NOT webkit-based.
			if ([type conformsToUTI:@"public.mpeg-4"])
			{
				[context writeString:@"\tif (navigator.userAgent.indexOf('WebKit/') <= -1) {\n\t\t// Only webkit-browsers can currently play this natively\n\t\tfallback(video);\n\t}\n"];
			}
			else	// we have an ogv or webm (or something else?) so fallback if it's Safari, which won't handle it
			{
				[context writeString:@"\tif (navigator.userAgent.indexOf(' Safari/') > -1) {\n\t\t// Safari can't play this natively\n\t\tfallback(video);\n\t}\n"];
			}
			[context writeString:@"} else {\n\tfallback(video);\n"];
			[context endElement];
		}
		
	}
	else	// none of the above -- indicate that we don't know what to insert
	{
		[context pushElementAttribute:@"width" value:[[self width] description]];
		[context pushElementAttribute:@"height" value:[[self height] description]];
		[context startElement:@"div"];
		[context writeElement:@"p" text:NSLocalizedString(@"Unable to show video. Perhaps it is not a recognized video format.", @"Warning shown to user when video can't be embedded")];
		[context endElement];		// the div
	}
	
	
	
	
	 
    
    [context addDependencyOnObject:self keyPath:@"media"];
}




- (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
	return @"com.karelia.sandvox.SVVideo";
}

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    result = [[[SVVideoInspector alloc] initWithNibName:@"SVVideo" bundle:nil] autorelease];
    return result;
}


#pragma mark Publishing

@dynamic codecType;


#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return [self posterFrame]; }
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObject:@"posterFrame"]; }




- (void)setMediaWithURL:(NSURL *)URL;
{
    [super setMediaWithURL:URL];
    
    if ([self constrainProportions])    // generally true
    {
        // Resize image to fit in space
        NSNumber *width = [self width];
        [self makeOriginalSize];
        if ([[self width] isGreaterThan:width]) [self setWidth:width];
    }
    
    // Match file type
    [self setCodecType:[[self media] typeOfFile]];
}

- (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObject:(NSString *)kUTTypeMovie];
}

+ (NSSet *)keyPathsForValuesAffectingIcon
{
    return [NSSet setWithObjects:@"codecType", nil];
}
+ (NSSet *)keyPathsForValuesAffectingInfo
{
    return [NSSet setWithObjects:@"codecType", nil];
}


- (NSImage *)icon
{
	NSImage *result = nil;
	NSString *type = self.codecType;
	
	if (!type)												// no movie -- don't bother with icon
	{
		result = nil;
	}
	else if (![type conformsToUTI:(NSString *)kUTTypeMovie])			// BAD
	{
		result = [NSImage imageFromOSType:kAlertStopIcon];
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result =[ NSImage imageNamed:@"checkmark"];;
	}
	else if ([type conformsToUTI:@"public.mpeg-4"])			// might not be iOS compatible
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else													// everything else
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}

	return result;
}

- (NSString *)info
{
	NSString *result = @"";
	NSString *type = self.codecType;
	
	if (!type)												// no movie -- don't bother with icon
	{
		result = NSLocalizedString(@"Use MPEG-4 (h.264) video for maximum compatibility.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if (![type conformsToUTI:(NSString *)kUTTypeMovie])			// BAD
	{
		result = NSLocalizedString(@"Video cannot be played in most browsers.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result = NSLocalizedString(@"Video is compatible with a wide range of devices.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.mpeg-4"])			// might not be iOS compatible
	{
		result = NSLocalizedString(@"This video may not be compatible with iOS devices; please verify.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"])
	{
		result = NSLocalizedString(@"Video will only play on certain browsers.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"com.adobe.flash.video"])
	{
		result = NSLocalizedString(@"Video will not play on iOS devices", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"])
	{
		result = NSLocalizedString(@"Video will not play on Macs unless \\U201CFlip4Mac\\U201D is installed", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
	{
		result = NSLocalizedString(@"Video will not play on Windows PCs unless QuickTime is installed", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	return result;
}


@end



#pragma mark -
#pragma mark OLDER STUFF




//	LocalizedStringInThisBundle(@"This is a placeholder for a video. The full video will appear once you publish this website, but to see the video in Sandvox, please enable live data feeds in the preferences.", "Live data feeds disabled message.")

//	LocalizedStringInThisBundle(@"Please use the Inspector to enter the URL of a video.", "URL has not been specified - placeholder message")



/*
 
 See http://www.gidforums.com/t-12525.html for lots of ideas on more embedding, like
 swf, flv, rm/ram
 
 
 
 */

// Some example external URLs
// http://movies.apple.com/movies/us/apple/getamac_ads1/viruses_480x376.mov
// http://grimstveit.no/jakob/files/video/breakdance.wmv
// http://mindymcadams.com/photos/flowers/slideshow.swf

// Flash ref: http://www.macromedia.com/cfusion/knowledgebase/index.cfm?id=tn_12701


// WMV ref pages: http://msdn2.microsoft.com/en-us/library/ms867217.aspx
// http://msdn2.microsoft.com/en-us/library/ms983653.aspx
// http://www.mediacollege.com/video/format/windows-media/streaming/embed.html
// http://www.mioplanet.com/rsc/embed_mediaplayer.htm
// http://www.w3schools.com/media/media_playerref.asp



@interface SVVideo (Private)

- (BOOL)attemptToGetSize:(NSSize *)outSize fromSWFData:(NSData *)data;

- (QTMovie *)movie;
- (void)setMovie:(QTMovie *)aMovie;
- (void)loadMovie;

- (NSSize)movieSize;
- (void)setMovieSize:(NSSize)movieSize;

- (void)loadMovieFromAttributes:(NSDictionary *)anAttributes;

- (void)calculateMovieDimensions:(QTMovie *)aMovie;
- (NSSize)pageDimensions;

@end


#pragma mark -


@implementation SVVideo (MoreStuff)

#pragma mark awake

//- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
//{
//	
//	// we may not have a movieSize because we only started storing it as of version 1.1.2.
//	if (nil == [[self delegateOwner] objectForKey:@"movieSize"])		// have we not figured out dimensions yet?
//	{
//		[self loadMovie];
//	}
//}


#pragma mark -
#pragma mark Dealloc

//- (void)dealloc
//{
//	[self setMovie:nil];
//	[[NSNotificationCenter defaultCenter] removeObserver:self];
//	[super dealloc];
//}


#pragma mark -
#pragma mark Plugin




#pragma mark -
#pragma mark Media Storage


//- (void)plugin:(KTAbstractElement *)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
//{
//	// When setting the video load it to get dimensions etc. & update poster image
//	if ([key isEqualToString:@"video"])
//	{
//		[self loadMovie];
//		[self _updateThumbnail:value];
//	}
//    else if ([key isEqualToString:@"remoteURL"])
//    {
//		[self setMovieSize:NSZeroSize];	// force recalculation
//		[self loadMovie];
//    }
//    else if ([key isEqualToString:@"movieSource"])
//    {
//		[self setMovieSize:NSZeroSize];	// force recalculation
//		[self loadMovie];
//    }
//	
//    
//	// Update page thumbnail if appropriate
//	else if ([key isEqualToString:@"posterImage"])
//	{
//		KTAbstractElement *container = [self delegateOwner];
//		if (container && [container respondsToSelector:@selector(thumbnail)])
//		{
//			if ([container valueForKey:@"thumbnail"] == oldValue)
//			{
//				[container setValue:value forKey:@"thumbnail"];
//			}
//		}
//	}
//}


- (IBAction)chooseMovieFile:(id)sender
{
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:NO];
	[openPanel setAllowsMultipleSelection:NO];
	[openPanel setPrompt:LocalizedStringInThisBundle(@"Choose", "choose button - open panel")];
	
	// We want QT-compatible file types, but not still images
	NSMutableSet *fileTypes = [NSMutableSet setWithArray:[QTMovie movieFileTypes:QTIncludeCommonTypes]];
	[fileTypes minusSet:[NSSet setWithArray:[NSImage imageFileTypes]]];
	[fileTypes addObject:@"swf"];		// flash
	
	// TODO: Open the panel at a reasonable location
	[openPanel runModalForDirectory:nil
							   file:nil
							  types:[fileTypes allObjects]];
	
	NSArray *selectedPaths = [openPanel filenames];
	if (!selectedPaths || [selectedPaths count] == 0) {
		return;
	}
	
//	KTMediaContainer *video = [[[self delegateOwner] mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
//	[[self delegateOwner] setValue:video forKey:@"video"];
}


@end
