//
//  SVFlash.m
//  Sandvox
//
//  Created by Dan Wood on 9/9/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

/*
 SVFlash is a MediaGraphic, similar to SVVideo and SVAudio, but much simpler.
 
 We try to guess the dimensions of the flash file by parsing the file.
 One drawback about the fact that we won't know the dimensions of a movie until we have been able
 to load it on a page is that it's possible that one could create a bunch of "movie pages" and never
 load them into Sandvox to give them a chance to calculate their dimensions. I don't think that
 this is very likely; as soon as the site author has gone to a page to even see what the size is,
 Sandvox will be fetching the size.
 
 If somebody is trying to add an FLV, but doesn't have Perian or some other set of components, they
 are not going to be able to get the dimensions of the FLV file.  Fortunately we are able to scan
 the file and *usually* get the dimensions of the movie.  This doesn't seem to work on all FLV files
 but it is good enough.  If somebody really needs to use FLV, they could just install Perian on
 their own system; the flash player will take care of actually displaying the movie.
 
 Later on, we may want do dig into MP4 files and scrutinize them for all of the properties that are
 needed to ensure iOS compatibility.
 
 */

#import "SVFlash.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "KSSimpleURLConnection.h"
#import <QTKit/QTKit.h>
#include <zlib.h>
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "QTMovie+Karelia.h"
#import <QuickLook/QuickLook.h>
#import "KSThreadProxy.h"
#import "NSImage+KTExtensions.h"
#import "SVMediaGraphicInspector.h"

@interface QTMovie (ApplePrivate)

- (BOOL) usesFigMedia;	// From Tim Monroe, WWDC2010.  Does this movie use the "modern" quicktime stack - possibly more likely to play on iOS

@end

@interface SVFlash ()

- (void)loadMovie;
- (void)loadMovieFromAttributes:(NSDictionary *)anAttributes;
- (void)calculateMovieDimensions:(QTMovie *)aMovie;
- (void)calculateMoviePlayability:(QTMovie *)aMovie;
@end

@implementation SVFlash 

@dynamic posterFrame;
@dynamic posterFrameType;
@dynamic autoplay;
@dynamic controller;
@dynamic preload;
@dynamic loop;
@dynamic codecType;	// determined from movie's file UTI, or by further analysis

//	LocalizedStringInThisBundle(@"This is a placeholder for a video. The full video will appear once you publish this website, but to see the video in Sandvox, please enable live data feeds in the preferences.", "Live data feeds disabled message.")

//	LocalizedStringInThisBundle(@"Please use the Inspector to enter the URL of a video.", "URL has not been specified - placeholder message")

#pragma mark -
#pragma mark Lifetime

+ (SVFlash *)insertNewVideoInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVFlash *result = [NSEntityDescription insertNewObjectForEntityForName:@"Video"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)willInsertIntoPage:(KTPage *)page;
{
	[self setConstrainProportions:YES];		// We will likely want this on
	
    [super willInsertIntoPage:page];
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}


- (void)dealloc
{
	self.dimensionCalculationMovie = nil;
	self.dimensionCalculationConnection = nil;	
	[super dealloc];
}

#pragma mark -
#pragma mark General

- (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObject:(NSString *)kUTTypeMovie];
	// If this doesn't work well, try the old method:
	// 	NSMutableSet *fileTypes = [NSMutableSet setWithArray:[QTMovie movieFileTypes:QTIncludeCommonTypes]];
	// [fileTypes minusSet:[NSSet setWithArray:[NSImage imageFileTypes]]];
	
}

- (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
	return @"com.karelia.sandvox.SVFlash";
}

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    result = [[[SVMediaGraphicInspector alloc] initWithNibName:@"SVFlashInspector" bundle:nil] autorelease];
    return result;
}



#pragma mark -
#pragma mark Poster Frame

enum { kPosterFrameTypeNone = 0, kPosterFrameTypeAutomatic, kPosterTypeChoose };

- (id <SVMedia>)thumbnail
{
	return [self.posterFrameType intValue] != kPosterFrameTypeNone ? self.posterFrame : nil;
}
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObjects:@"posterFrame", @"posterFrameType", nil]; }

- (void)setPosterFrameWithContentsOfURL:(NSURL *)URL;   // autodeletes the old one
{
	SVMediaRecord *media = [SVMediaRecord mediaWithURL:URL entityName:@"PosterFrame" insertIntoManagedObjectContext:[self managedObjectContext] error:NULL];	
	[self replaceMedia:media forKeyPath:@"posterFrame"];
}

#pragma mark Poster Frame - QuickLook

+ (NSOperationQueue*) sharedQuickLookQueue;
{
	static NSOperationQueue *sSharedQuickLookQueue = nil;
	@synchronized(self)
	{
		if (sSharedQuickLookQueue == nil)
		{
			sSharedQuickLookQueue = [[NSOperationQueue alloc] init];
			sSharedQuickLookQueue.maxConcurrentOperationCount = 1;		// Since this is hitting the disk, let's just only let one at a time.
		}
	}
	return sSharedQuickLookQueue;
}

// Called back on main thread 
- (void)gotQuickLookData:(NSData *)jpegData;
{
	OBASSERT([NSThread isMainThread]);
	
	// Get the media or URL, so we have a good file name for the poster
	SVMediaRecord *media = [self media];
	NSURL *videoURL = nil;
    if (media)
    {
		videoURL = [media fileURL];
	}
	else
	{
		videoURL = [self externalSourceURL];
	}
	// Rebuild URL by substituting in path. Create a FAKE URL for a synthesized thumbnail.
	NSString *newPath = [[[videoURL path] stringByDeletingPathExtension] stringByAppendingPathComponent:@"synthesized.jpg"];
	
	NSURL *fakeURL = [[[NSURL alloc] initWithScheme:[videoURL scheme]
											   host:[videoURL host]
											   path:newPath]
					  autorelease];
	
	SVMediaRecord *posterMedia = nil;
	if (jpegData)
	{
		posterMedia = [SVMediaRecord mediaWithData:jpegData
											   URL:fakeURL
                                        entityName:@"PosterFrame"
                    insertIntoManagedObjectContext:[self managedObjectContext]];	
	}
	[self replaceMedia:posterMedia forKeyPath:@"posterFrame"];
	
}

- (void)getQuickLookForFileURL:(NSURL *)fileURL		// CALLED FROM OPERATION
{
	OBASSERT(![NSThread isMainThread]);
	OBPRECONDITION(fileURL);
	NSData *jpegData = nil;
	NSDictionary *options = NSDICT(NSBOOL(NO), (NSString *)kQLThumbnailOptionIconModeKey);
	CGImageRef cg = QLThumbnailImageCreate(kCFAllocatorDefault, 
										   (CFURLRef)fileURL, 
										   CGSizeMake(1920,1440), // Typical size of a very large (3:4) 1080p movie, should be *plenty* for poster
										   (CFDictionaryRef)options);
	if (cg)
	{
		NSBitmapImageRep *bitmapImageRep = [[[NSBitmapImageRep alloc] initWithCGImage:cg] autorelease];
		CGImageRelease(cg);
		// Get JPEG data since it will be easiest to keep it a web-happy format
		NSMutableDictionary *props = NSDICT(
											[NSNumber numberWithFloat:[NSImage preferredJPEGQuality]], NSImageCompressionFactor,
											[NSNumber numberWithBool:NO], NSImageProgressive);
		
		jpegData = [bitmapImageRep representationUsingType:NSJPEGFileType properties:props];
		
		// [jpegData writeToFile:@"/Volumes/dwood/Desktop/quicklook.jpg" atomically:YES];
	}
	[[self ks_proxyOnThread:nil waitUntilDone:NO] gotQuickLookData:jpegData];
}

- (void)getPosterFrameFromQuickLook;
{
	SVMediaRecord *media = self.media;
	if (media)
	{
		NSURL *mediaURL = [media fileURL];
		
		NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
																				selector:@selector(getQuickLookForFileURL:)
																				  object:mediaURL];
		
		[[[self class] sharedQuickLookQueue] addOperation:operation];			
	}
}


#pragma mark -
#pragma mark Media

- (void)setMediaWithURL:(NSURL *)URL;
{
 	OBPRECONDITION(URL);
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

#pragma mark -
#pragma mark Custom setters (instead of KVO)

- (void) setAutoplay:(NSNumber *)anAutoplay
{
	[self willChangeValueForKey:@"autoplay"];
	[self setPrimitiveValue:anAutoplay forKey:@"autoplay"];
	
	if (anAutoplay.boolValue)	// if we turn on autoplay, we also turn on preload
	{
		self.preload = [NSNumber numberWithInt:kPreloadAuto];
	}
	[self didChangeValueForKey:@"autoplay"];
}

- (void) setController:(NSNumber *)aController
{
	[self willChangeValueForKey:@"controller"];
	[self setPrimitiveValue:aController forKey:@"controller"];
	
	if (!aController.boolValue)	// if we turn off controller, we turn on autoplay so we can play!
	{
		self.autoplay = NSBOOL(YES);
	}
	[self didChangeValueForKey:@"controller"];
}

- (void) setPosterFrameType:(NSNumber *)aPosterFrameType
{
	[self willChangeValueForKey:@"posterFrameType"];
	[self setPrimitiveValue:aPosterFrameType forKey:@"posterFrameType"];
	
	switch(aPosterFrameType.intValue)
	{
		case kPosterTypeChoose:
			// Switching to choose from automatic? Clear out the image.
			[self replaceMedia:nil forKeyPath:@"posterFrame"];
			break;
		case kPosterFrameTypeAutomatic:
			// Switching to automatic? Queue request for quicklook
			[self getPosterFrameFromQuickLook];
			break;
		case kPosterFrameTypeNone:
			// Do nothing; don't mess with media
			break;
	}
	[self didChangeValueForKey:@"posterFrameType"];
}

- (void)_mediaChanged;
{
	NSLog(@"SVFlash Media set.");
	if (nil == self.posterFrame || [self.posterFrameType intValue] != kPosterTypeChoose)		// get poster frame image UNLESS we have an override chosen.
	{
		[self getPosterFrameFromQuickLook];
	}
	
	// Video changed - clear out the known width/height so we can recalculate
	self.naturalWidth = nil;
	self.naturalHeight = nil;
	
	// Load the movie to figure out the media size and codecType
	[self loadMovie];
}

- (void) setMedia:(SVMediaRecord *)aMedia
{
	[self willChangeValueForKey:@"media"];
	[self setPrimitiveValue:aMedia forKey:@"media"];
	
	[self _mediaChanged];
	
	[self didChangeValueForKey:@"media"];
}

- (void) setExternalSourceURL:(NSURL *)anExternalSourceURL
{
	[self willChangeValueForKey:@"externalSourceURL"];
	[self setPrimitiveValue:anExternalSourceURL forKey:@"externalSourceURL"];
	
	[self _mediaChanged];
	
	[self didChangeValueForKey:@"externalSourceURL"];
}

#pragma mark -
#pragma mark Writing Tag

// EXACTLY THE SAME IN AUDIO AND VIDEO. CONSIDER REFACTORING.
+ (void)writeFallbackScriptOnce:(SVHTMLContext *)context;
{
	// Write the fallback method.  COULD WRITE THIS IN JQUERY TO BE MORE TERSE?
	
	NSString *oneTimeScript = @"<script type='text/javascript'>\nfunction fallback(av) {\n while (av.firstChild) {\n  if (av.firstChild.nodeName == 'SOURCE') {\n   av.removeChild(av.firstChild);\n  } else {\n   av.parentNode.insertBefore(av.firstChild, av);\n  }\n }\n av.parentNode.removeChild(av);\n}\n</script>\n";
	
	NSRange whereOneTimeScript = [[context extraHeaderMarkup] rangeOfString:oneTimeScript];
	if (NSNotFound == whereOneTimeScript.location)
	{
		[[context extraHeaderMarkup] appendString:oneTimeScript];
	}
}

- (NSString *)startQuickTimeObject:(SVHTMLContext *)context
					movieSourceURL:(NSURL *)movieSourceURL
				   posterSourceURL:(NSURL *)posterSourceURL;
{
	NSString *movieSourcePath  = movieSourceURL ? [context relativeURLStringOfURL:movieSourceURL] : @"";
	NSString *posterSourcePath = posterSourceURL ? [context relativeURLStringOfURL:posterSourceURL] : @"";
	
	NSUInteger heightWithBar = [[self height] intValue]
	+ (self.controller.boolValue ? 16 : 0);
	
	[context pushAttribute:@"width" value:[[self width] description]];
	[context pushAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	[context pushAttribute:@"classid" value:@"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"];	// Proper value?
	[context pushAttribute:@"codebase" value:@"http://www.apple.com/qtactivex/qtplugin.cab"];
	
	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"div" preferredIdName:@"quicktime" className:nil attributes:nil];	// class, attributes already pushed
	
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
	
	return elementID;
}

- (NSString *)startMicrosoftObject:(SVHTMLContext *)context
					movieSourceURL:(NSURL *)movieSourceURL;
{
	// I don't think there is any way to use the poster frame for a click to play
	NSString *movieSourcePath = movieSourceURL ? [context relativeURLStringOfURL:movieSourceURL] : @"";
	
	NSUInteger heightWithBar = [[self height] intValue]
	+ (self.controller.boolValue ? 46 : 0);		// Windows media controller is 46 pixels (on windows; adjusted on macs)
	
	[context pushAttribute:@"width" value:[[self width] description]];
	[context pushAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	[context pushAttribute:@"classid" value:@"CLSID:6BF52A52-394A-11D3-B153-00C04F79FAA6"];
	
	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"object" preferredIdName:@"wmplayer" className:nil attributes:nil];	// class, attributes already pushed
	
	[context writeParamElementWithName:@"url" value:movieSourcePath];
	[context writeParamElementWithName:@"autostart" value:self.autoplay.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"showcontrols" value:self.controller.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"playcount" value:self.loop.boolValue ? @"9999" : @"1"];
	[context writeParamElementWithName:@"type" value:@"application/x-oleobject"];
	[context writeParamElementWithName:@"uiMode" value:@"mini"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://microsoft.com/windows/mediaplayer/en/download/"];
	
	return elementID;
}

- (NSString *)startVideo:(SVHTMLContext *)context
		  movieSourceURL:(NSURL *)movieSourceURL
		 posterSourceURL:(NSURL *)posterSourceURL;
{
	NSString *movieSourcePath  = movieSourceURL ? [context relativeURLStringOfURL:movieSourceURL] : @"";
	NSString *posterSourcePath = posterSourceURL ? [context relativeURLStringOfURL:posterSourceURL] : @"";
	
	// Actually write the video
	if ([self shouldWriteHTMLInline]) [self buildClassName:context];
	[context pushAttribute:@"width" value:[[self width] description]];
	[context pushAttribute:@"height" value:[[self height] description]];
	
	if (self.controller.boolValue)	[context pushAttribute:@"controls" value:@"controls"];		// boolean attribute
	if (self.autoplay.boolValue)	[context pushAttribute:@"autoplay" value:@"autoplay"];
	[context pushAttribute:@"preload" value:[NSARRAY(@"metadata", @"none", @"auto") objectAtIndex:self.preload.intValue + 1]];
	if (self.loop.boolValue)		[context pushAttribute:@"loop" value:@"loop"];
	
	if (self.posterFrame)	[context pushAttribute:@"poster" value:posterSourcePath];
	NSString *elementID = [context startElement:@"video" preferredIdName:@"video" className:nil attributes:nil];	// class, attributes already pushed
	
	// Remove poster on iOS < 4; prevents video from working
	[context startJavascriptElementWithSrc:nil];
	[context stopWritingInline];
	[context writeString:@"// Remove poster from buggy iOS before 4\n"];
	[context writeString:@"if (navigator.userAgent.match(/CPU( iPhone)*( OS )*([123][_0-9]*)? like Mac OS X/)) {\n"];
	[context writeString:[NSString stringWithFormat:@"\t$('#%@').removeAttr('poster');\n", elementID]];
	[context writeString:@"}\n"];
	[context endElement];	
	
	
	// source
	[context pushAttribute:@"src" value:movieSourcePath];
	[context pushAttribute:@"type" value:[NSString MIMETypeForUTI:[self codecType]]];
	[context pushAttribute:@"onerror" value:@"fallback(this.parentNode)"];
	[context startElement:@"source"];
	[context endElement];
	
	return elementID;
}

- (void)writePostVideoScript:(SVHTMLContext *)context referringToID:(NSString *)videoID;
{
	// Now write the post-video-tag surgery since onerror doesn't really work
	// This is hackish browser-sniffing!  Maybe later we can do away with this (especially if we can get > 1 video source)
	
	[context startJavascriptElementWithSrc:nil];
	[context stopWritingInline];
	[context writeString:[NSString stringWithFormat:@"var video = document.getElementById('%@');\n", videoID]];
	[context writeString:[NSString stringWithFormat:@"if (video.canPlayType && video.canPlayType('%@')) {\n",
						  [NSString MIMETypeForUTI:[self codecType]]]];
	[context writeString:@"\t// canPlayType is overoptimistic, so we have browser sniff.\n"];
	
	// we have mp4, so no ogv/webm, so force a fallback if NOT webkit-based.
	if ([[self codecType] conformsToUTI:@"public.mpeg-4"])
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf('WebKit/') <= -1) {\n\t\t// Only webkit-browsers can currently play this natively\n\t\tfallback(video);\n\t}\n"];
	}
	else	// we have an ogv or webm (or something else?) so fallback if it's Safari, which won't handle it
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf(' Safari/') > -1) {\n\t\t// Safari can't play this natively\n\t\tfallback(video);\n\t}\n"];
	}
	[context writeString:@"} else {\n\tfallback(video);\n}\n"];
	[context endElement];	
}


- (NSString *)startFlash:(SVHTMLContext *)context
		  movieSourceURL:(NSURL *)movieSourceURL
		 posterSourceURL:(NSURL *)posterSourceURL;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	NSString *videoFlashPlayer	= [defaults objectForKey:@"videoFlashPlayer"];	// to override player type
	// Known types: f4player jwplayer flvplayer osflv flowplayer.  Otherwise must specify videoFlashFormat.
	if (!videoFlashPlayer) videoFlashPlayer = @"flvplayer";
	NSString *videoFlashPath	= [defaults objectForKey:@"videoFlashPath"];	// override must specify path/URL on server
	NSString *videoFlashExtras	= [defaults objectForKey:@"videoFlashExtras"];	// extra parameters to override for any player
	NSString *videoFlashFormat	= [defaults objectForKey:@"videoFlashFormat"];	// format pattern with %{value1}@ and %{value2}@ for movie, poster
	NSString *videoFlashBarHeight= [defaults objectForKey:@"videoFlashBarHeight"];	// height that the navigation bar adds
	
	BOOL videoFlashRequiresFullURL = [defaults boolForKey:@"videoFlashRequiresFullURL"];	// usually not, but YES for flowplayer
	if ([videoFlashPlayer isEqualToString:@"flowplayer"]) videoFlashRequiresFullURL = YES;
	
	NSString *movieSourcePath = @"";
	NSString *posterSourcePath = @"";
	if (videoFlashRequiresFullURL)
	{
		if (movieSourceURL)  movieSourcePath  = [movieSourceURL  absoluteString];
		if (posterSourceURL) posterSourcePath = [posterSourceURL absoluteString];
	}
	else
	{
		if (movieSourceURL)  movieSourcePath  = [context relativeURLStringOfURL:movieSourceURL];
		if (posterSourceURL) posterSourcePath = [context relativeURLStringOfURL:posterSourceURL];
	}
	
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
			 @"file=%{value1}@&image=%{value2}@&controlbar=over", @"jwplayer",
			 @"flv=%{value1}@&startimage=%{value2}@&margin=0", @"flvplayer",
			 @"movie=%{value1}@&previewimage=%{value2}@",      @"osflv",	
			 @"config={\"playlist\":[{\"url\":\"%{value2}@\"},{\"url\":\"%{value1}@\",\"autoPlay\":false,\"autoBuffering\":true}]}",
			 @"flowplayer");
	NSDictionary *barHeightLookup
	= NSDICT(
			 [NSNumber numberWithShort:0],  @"f4player",	
			 [NSNumber numberWithShort:0], @"jwplayer",	
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
	if (self.posterFrame)
	{
		flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePath, posterSourcePath];
	}
	else
	{
		flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePath];
	}
	
	
	if ([videoFlashPlayer isEqualToString:@"flvplayer"])
	{
		[flashVars appendFormat:@"&showplayer=%@", (self.controller.boolValue) ? @"autohide" : @"never"];
		if (self.autoplay.boolValue)				[flashVars appendString:@"&autoplay=1"];
		if (kPreloadAuto == self.preload.intValue)	[flashVars appendString:@"&autoload=1"];
		if (self.loop.boolValue)					[flashVars appendString:@"&loop=1"];
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
	
	if ([self shouldWriteHTMLInline]) [self buildClassName:context];
	[context pushAttribute:@"type" value:@"application/x-shockwave-flash"];
	[context pushAttribute:@"data" value:playerPath];
	[context pushAttribute:@"width" value:[[self width] description]];
	
	NSUInteger heightWithBar = barHeight + [[self height] intValue];
	[context pushAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	
	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"object" preferredIdName:videoFlashPlayer className:nil attributes:nil];	// class, attributes already pushed
	
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
	
	return elementID;
}

- (void)writePosterImage:(SVHTMLContext *)context
		 posterSourceURL:(NSURL *)posterSourceURL;
{
	NSString *posterSourcePath = posterSourceURL ? [context relativeURLStringOfURL:posterSourceURL] : @"";
	
	// Get a title to indicate that the movie cannot play inline.  (Suggest downloading, if we provide a link)
	KTPage *thePage = [context page];
	NSString *language = [thePage language];
	NSString *cannotViewTitle = [[NSBundle mainBundle] localizedStringForString:@"cannotViewTitleText"
																	   language:language
																	   fallback:
								 NSLocalizedStringWithDefaultValue(@"cannotViewTitleText", nil, [NSBundle mainBundle], @"Cannot view this video from the browser.", @"Warning to show when a video cannot be played")];
	
	NSString *altForMovieFallback = [[posterSourcePath lastPathComponent] stringByDeletingPathExtension];// Cheating ... What would be a good alt ?
	
	[context pushAttribute:@"title" value:cannotViewTitle];
	[context writeImageWithSrc:posterSourcePath alt:altForMovieFallback width:[[self width] description] height:[[self height] description]];
}

- (NSString *)startUnknown:(SVHTMLContext *)context;
{
	[context pushAttribute:@"width" value:[[self width] description]];
	[context pushAttribute:@"height" value:[[self height] description]];
	NSString *elementID = [context startElement:@"div" preferredIdName:@"unrecognized" className:nil attributes:nil];	// class, attributes already pushed
	[context writeElement:@"p" text:NSLocalizedString(@"Unable to show video. Perhaps it is not a recognized video format.", @"Warning shown to user when video can't be embedded")];
	// Poster may be shown next, so don't end....
	
	return elementID;
}

- (void)writeBody:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMediaRecord *media = [self media];
	[context addDependencyOnObject:self keyPath:@"media"];
	[context addDependencyOnObject:self keyPath:@"posterFrameType"];
	[context addDependencyOnObject:self keyPath:@"posterFrame"];	// force rebuild if poster frame got changed
	[context addDependencyOnObject:self keyPath:@"controller"];		// Note: other boolean properties don't affect display of page
	
	NSURL *movieSourceURL = [self externalSourceURL];
    if (media)
    {
	    movieSourceURL = [context addMedia:media];
	}
	
	NSURL *posterSourceURL = nil;
	if (self.posterFrame)
	{
		// Convert to JPEG if the poster image is not already a JPEG or PNG or GIF (i.e. web-compatible images)
		NSString *convertType = (NSString *)kUTTypeJPEG;
		NSString *currentType = self.posterFrame.typeOfFile;
		if ([currentType conformsToUTI:(NSString *)kUTTypePNG]
			|| [currentType conformsToUTI:(NSString *)kUTTypeGIF]
			|| [currentType conformsToUTI:(NSString *)kUTTypeJPEG])
		{
			convertType = nil;		// already a web-ready image format; don't convert
		}
		posterSourceURL = [context addImageMedia:self.posterFrame width:[self width] height:[self height] type:convertType];
	}
	
	// Determine tag(s) to use
	// video || flash (not mutually exclusive) are mutually exclusive with microsoft, quicktime
	NSString *type = [self codecType];
	BOOL videoTag = [type conformsToUTI:@"public.mpeg-4"] || [type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"avoidVideoTag"]) videoTag = NO;
	
	BOOL flashTag = [type conformsToUTI:@"public.mpeg-4"] || [type conformsToUTI:@"com.adobe.flash.video"];
	if ([defaults boolForKey:@"avoidFlashVideo"]) flashTag = NO;
	
	BOOL microsoftTag = [type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"];
	
	// quicktime fallback, but not for mp4.  We may want to be more selective of mpeg-4 types though.
	// Also show quicktime when there is no media at all
	BOOL quicktimeTag = !media || ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
	&& ![type conformsToUTI:@"public.mpeg-4"];
	
	BOOL unknownTag = NO;	// will be set below if nothing can be generated
	NSString *videoID = nil;
	
	// START THE TAGS
	
	if (quicktimeTag)
	{
		[self startQuickTimeObject:context movieSourceURL:movieSourceURL posterSourceURL:posterSourceURL];
	}
	else if (microsoftTag)
	{
		[self startMicrosoftObject:context movieSourceURL:movieSourceURL]; 
	}
	else if (videoTag || flashTag)
	{
		if (videoTag)	// start the video tag
		{
			[SVFlash writeFallbackScriptOnce:context];
			videoID = [self startVideo:context movieSourceURL:movieSourceURL posterSourceURL:posterSourceURL]; 
		}
		
		if (flashTag)	// inner
		{
			[self startFlash:context movieSourceURL:movieSourceURL posterSourceURL:posterSourceURL]; 
		}
	}
	else	// completely unknown video type
	{
		[self startUnknown:context];
		unknownTag = YES;
	}
	
	// INNERMOST POSTER FRAME
	
	if (posterSourceURL)		// image within the video or object tag as a fallback
	{	
		[self writePosterImage:context posterSourceURL:posterSourceURL];
	}
	
	// END THE TAGS
	
	if (flashTag || quicktimeTag || microsoftTag)
	{
		OBASSERT([@"object" isEqualToString:[context topElement]]);
		[context endElement];	//  </object>
	}
	
	if (videoTag)		// we may have a video nested outside of an object
	{
		OBASSERT([@"video" isEqualToString:[context topElement]]);
		[context endElement];
		
		[self writePostVideoScript:context referringToID:videoID];
	}
	
	if (unknownTag)
	{
		OBASSERT([@"div" isEqualToString:[context topElement]]);
		[context endElement];
	}
}


#pragma mark Warnings

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
	
	if (!type || ![self media])								// no movie
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result =[ NSImage imageNamed:@"checkmark"];;
	}
	else if ([type conformsToUTI:@"public.mpeg-4"])			// might not be iOS compatible
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"])
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}
	else if ([type conformsToUTI:@"com.adobe.flash.video"])
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}
	else if ([type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"])
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}
	else	// Unknown video format, or not even a video
	{
		result = [NSImage imageFromOSType:kAlertStopIcon];
	}
	return result;
}

- (NSString *)info
{
	NSString *result = @"";
	NSString *type = self.codecType;
	
	if (!type || ![self media])								// no movie
	{
		result = NSLocalizedString(@"Use MPEG-4 (h.264) video for maximum compatibility.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result = NSLocalizedString(@"Video is compatible with a wide range of devices.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.mpeg-4"])			// might not be iOS compatible
	{
		result = NSLocalizedString(@"You will need to verify if this video will play on iOS devices.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
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
	else	// Unknown video format, or not even a video
	{
		result = NSLocalizedString(@"Video cannot be played in most browsers.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	return result;
}

#pragma mark -
#pragma mark Loading movie to calculate dimensions




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




/*	This accessor provides a means for temporarily storing the movie while information about it is asyncronously loaded
 */

@synthesize dimensionCalculationMovie = _dimensionCalculationMovie;
@synthesize dimensionCalculationConnection = _dimensionCalculationConnection;

- (void)setDimensionCalculationMovie:(QTMovie *)aMovie
{
	// If we are clearing out an existing movie, we're done, so exit movie on thread.  I hope this is right!
	if (nil == aMovie && nil != _dimensionCalculationMovie && ![NSThread isMainThread])
	{
		OSErr err = ExitMoviesOnThread();
		if (err != noErr) NSLog(@"Unable to ExitMoviesOnThread; %d", err);
	}
	[aMovie retain];
	[_dimensionCalculationMovie release];
	_dimensionCalculationMovie = aMovie;
}

// Loads or reloads the movie/flash from URL, path, or data.
- (void)loadMovie;
{
	NSDictionary *movieAttributes = nil;
	NSURL *movieSourceURL = nil;
	BOOL openAsync = NO;
	
	SVMediaRecord *media = [self media];
	
    if (media)
    {
		movieSourceURL = [media mediaURL];
		openAsync = YES;
		self.codecType = [NSString UTIForFileAtPath:[movieSourceURL path]];
	}
	else
	{
		movieSourceURL = [self externalSourceURL];
		self.codecType = [NSString UTIForFilenameExtension:[[movieSourceURL path] pathExtension]];
	}
	if (movieSourceURL)
	{
		movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
						   movieSourceURL, QTMovieURLAttribute,
						   [NSNumber numberWithBool:openAsync], QTMovieOpenAsyncOKAttribute,
						   // 10.6 only :-( [NSNumber numberWithBool:YES], QTMovieOpenForPlaybackAttribute,	// From Tim Monroe @ WWDC2010, so we can check how movie was loaded
						   nil];
		[self loadMovieFromAttributes:movieAttributes];
		
	}
}

- (void)loadMovieFromAttributes:(NSDictionary *)anAttributes
{
	// Ignore for background threads as there is no need to do this during a doc import
	// (STILL APPLICABLE FOR SANDVOX 2?
    if (![NSThread isMainThread]) return;
    
    
    [self setDimensionCalculationMovie:nil];	// will clear out any old movie, exit movies on thread
	NSError *error = nil;
	QTMovie *movie = nil;
	
	if (![NSThread isMainThread])
	{
		OSErr err = EnterMoviesOnThread(0);
		if (err != noErr) NSLog(@"Unable to EnterMoviesOnThread; %d", err);
	}
	
	movie = [[[QTMovie alloc] initWithAttributes:anAttributes
										   error:&error] autorelease];
	if (movie)
	{
		long movieLoadState = [[movie attributeForKey:QTMovieLoadStateAttribute] longValue];
		
		if (movieLoadState >= kMovieLoadStatePlayable)	// Do we have dimensions now?
		{
			[self calculatePosterImageFromPlayableMovie:movie];
			[self calculateMovieDimensions:movie];
			[self calculateMoviePlayability:movie];
			
			if (![NSThread isMainThread])	// we entered, so exit now that we're done with that
			{
				OSErr err = ExitMoviesOnThread();	// I hope this is 
				if (err != noErr) NSLog(@"Unable to ExitMoviesOnThread; %d", err);
			}
		}
		else	// not ready yet; wait until loaded if we are publishing
		{
			[self setDimensionCalculationMovie:movie];		// cache and retain for async loading.
			[movie setDelegate:self];
			
			/// Case 18430: we only add observers on main thread
			if ( [NSThread isMainThread] )
			{
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(loadStateChanged:)
															 name:QTMovieLoadStateDidChangeNotification object:movie];
			}
		}
	}
	else	// No movie?  Maybe it's a format that QuickTime can't read.  We can try FLV
	{
		if (![NSThread isMainThread])	// we entered, so exit now that we're done with that
		{
			OSErr err = ExitMoviesOnThread();	// I hope this is 
			if (err != noErr) NSLog(@"Unable to ExitMoviesOnThread; %d", err);
		}
		
		// get the data from what we stored in the quicktime initialization dictionary
		NSData *movieData = nil;
		if (nil != [anAttributes objectForKey:QTMovieDataReferenceAttribute])
		{
			movieData = [[anAttributes objectForKey:QTMovieDataReferenceAttribute] referenceData];
		}
		else if (nil != [anAttributes objectForKey:QTMovieFileNameAttribute])
		{
			movieData = [NSData dataWithContentsOfFile:[anAttributes objectForKey:QTMovieFileNameAttribute]];
		}
		else if (nil != [anAttributes objectForKey:QTMovieURLAttribute])
		{
			NSURL *URL = [anAttributes objectForKey:QTMovieURLAttribute];
			if ([URL isFileURL])
			{
				movieData = [NSData dataWithContentsOfURL:URL];
			}
			else	// not a file; load asynchronously
			{
				self.dimensionCalculationConnection = [[[KSSimpleURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URL]] autorelease];
				self.dimensionCalculationConnection.bytesNeeded = 1024;	// Let's just get the first 1K ... should be enough.
				self.naturalWidth = 0;	
				self.naturalHeight = 0;		// set to zero so we don't keep asking.  Hopefully answer comes soon.
			}
		}
		if (nil != movieData)
		{
			NSSize dimensions = [QTMovie dimensionsFromUnloadableMovieData:movieData];
			self.naturalWidth  = [NSNumber numberWithFloat:dimensions.width];
			self.naturalHeight = [NSNumber numberWithFloat:dimensions.height];	// even if it can't be figured out, at least it's not nil anymore
		}
	}
}

// Asynchronous load returned -- try to set the dimensions.
- (void)connection:(KSSimpleURLConnection *)connection didFinishLoadingData:(NSData *)data response:(NSURLResponse *)response;
{
	NSSize dimensions = [QTMovie dimensionsFromUnloadableMovieData:data];
	self.naturalWidth  = [NSNumber numberWithFloat:dimensions.width];
	self.naturalHeight = [NSNumber numberWithFloat:dimensions.height];	// even if it can't be figured out, at least it's not nil anymore
	self.dimensionCalculationConnection = nil;
}

- (void)connection:(KSSimpleURLConnection *)connection didFailWithError:(NSError *)error;
{
	// do nothing with the error, but clear out the connection.
	self.dimensionCalculationConnection = nil;
}


// Caches the movie from data.


// check for load state changes
- (void)loadStateChanged:(NSNotification *)notif
{
	QTMovie *movie = [notif object];
    if ([self.dimensionCalculationMovie isEqual:movie])
	{
		long loadState = [[movie attributeForKey:QTMovieLoadStateAttribute] longValue];
		if (loadState >= kMovieLoadStateLoaded)
		{
			[self calculatePosterImageFromPlayableMovie:movie];
			[self calculateMovieDimensions:movie];
			[self calculateMoviePlayability:movie];
			
			[[NSNotificationCenter defaultCenter] removeObserver:self];
			self.dimensionCalculationMovie = nil;	// we are done with movie now!
		}
	}
}

- (void)calculateMoviePlayability:(QTMovie *)aMovie;
{
	if ([aMovie respondsToSelector:@selector(usesFigMedia)])
	{
		if ([aMovie usesFigMedia])	// Modern quicktime stack - From Tim Monroe, sounds like movie must be this to play on iOS
		{
			// However, there is more to determine ... I'm going to put this aside for now.
		}
	}
	
}

- (void)calculateMovieDimensions:(QTMovie *)aMovie;
{
	NSSize movieSize = NSZeroSize;
	
	NSArray* vtracks = [aMovie tracksOfMediaType:QTMediaTypeVideo];
	if ([vtracks count] && [[vtracks objectAtIndex:0] respondsToSelector:@selector(apertureModeDimensionsForMode:)])
	{
		QTTrack* track = [vtracks objectAtIndex:0];
		//get the dimensions 
		
		// I'm getting a warning of being both deprecated AND unavailable!  WTF?  Any way to work around this?
		
		movieSize = [track apertureModeDimensionsForMode:QTMovieApertureModeClean];		// give a proper value for anamorphic movies like from case 41222.
	}
	if (NSEqualSizes(movieSize, NSZeroSize))
	{
		movieSize = [[aMovie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
		if (NSEqualSizes(NSZeroSize, movieSize))
		{
			movieSize = [[aMovie attributeForKey:QTMovieCurrentSizeAttribute] sizeValue];	// last resort
		}
	}
	self.naturalWidth  = [NSNumber numberWithFloat:movieSize.width];
	self.naturalHeight = [NSNumber numberWithFloat:movieSize.height];
}


@end
