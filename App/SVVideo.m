// 
//  SVVideo.m
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//
/*
 SVVideo is a MediaGraphic, similar to SVImage in some ways, and SVAudio in others.
 
 The overall technique for writing out the markup for a video tag is based off the handy
 "Video for Everybody" technique http://camendesign.com/code/video_for_everybody .... 
 
 The logic for this is very similar to the SVAudio class, generating a <video> tag wrapping an
 Flash-based video player's <object> tags.  This combination covers almost 100% of browsers,
 but only if you choose the right source media!
 
 The format with the best "coverage" of browsers is an H.264 MP4.  Many browsers can play it with
 the <video> tag; those that can't, the Flash video player will cover.  However, to work on an iOS
 device, the file has to conform to some other constraints -- which I currently don't have a way to
 test yet!
 
 You could also specify an FLV file, and you would get good coverage, but no iOS compatibility.  If
 you provide a QuickTime, AVI, WMV, etc. the right embedding code will be generated, but the movie
 won't be visible on all computers.  (This is essentially what we had in Sandvox 1).
 
 As in the SVAudio class, we show some warnings in the inspector when the chosen format won't reach
 a wide range of browsers.
 
 Also, the technical approach is the same as SVAudio so it won't be repeated here.  To handle buggy
 browsers that don't know about what formats they can't play, we manually check for MP4 movies
 trying to play in a non-WebKit browser, or a different format being played in Safari.
 
 Unlike the audio object, a video has a natural size, and it can show a poster frame.  The poster
 frame can be set automatically; we do this by asking the specified file (if it's a file, not an 
 external URL) for its QuickLook preview. This is loaded asynchronously.  Or, the user can choose
 an image file (it should be the same size as the movie).  Later we may offer a way to choose any
 frame from the movie.  We may also want to get a poster frame from a remotely loaded movie.
 
 We also make use of QuickTime to try and load the movie, so that we can get the natural size
 (width by height) of the movie.  In many cases this loads right up, but in some cases (e.g. a WMV
 when you have Perian installed so that you can actually view the movie), it has to load for a
 moment before it will reach kMovieLoadStatePlayable before we can get the dimensions.
 
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

#import "SVVideo.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "KSSimpleURLConnection.h"
#import "SVVideoInspector.h"
#import <QTKit/QTKit.h>
#include <zlib.h>
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSError+Karelia.h"
#import "QTMovie+Karelia.h"
#import <QuickLook/QuickLook.h>
#import "KSThreadProxy.h"
#import "NSImage+KTExtensions.h"
#import "NSColor+Karelia.h"

@interface QTMovie (ApplePrivate)

- (BOOL) usesFigMedia;	// From Tim Monroe, WWDC2010.  Does this movie use the "modern" quicktime stack - possibly more likely to play on iOS

@end

@interface SVVideo ()

- (void)loadMovieFromURL:(NSURL *)movieSourceURL;
- (void)loadMovieFromAttributes:(NSDictionary *)anAttributes;
- (void)calculatePosterImageFromPlayableMovie:(QTMovie *)aMovie;
- (BOOL)calculateMovieDimensions:(QTMovie *)aMovie;
- (BOOL) enablePoster;
- (void)loadStateChanged:(NSNotification *)notif;

@end

@implementation SVVideo 

@synthesize posterFrameType = _posterFrameType;

//	NSLocalizedString(@"This is a placeholder for a video. The full video will appear once you publish this website, but to see the video in Sandvox, please enable live data feeds in the preferences.", "Live data feeds disabled message.")

//	NSLocalizedString(@"Please use the Inspector to enter the URL of a video.", "URL has not been specified - placeholder message")

#pragma mark -
#pragma mark Lifetime

- (void)awakeFromNew;
{
	self.controller = YES;
	self.preload = kPreloadNone;
	self.autoplay = NO;
	self.loop = NO;
	self.posterFrameType = kPosterFrameTypeAutomatic;
		
    // Show caption
    if ([[[self.container textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}


- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	self.dimensionCalculationMovie = nil;
	self.dimensionCalculationConnection = nil;	
	[super dealloc];
}

+ (NSArray *)plugInKeys;
{
    return [[super plugInKeys] arrayByAddingObjectsFromArray:
			[NSArray arrayWithObjects:
			 @"posterFrameType",
			 nil]];
}

#pragma mark -
#pragma mark General

+ (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObject:(NSString *)kUTTypeMovie];
	// If this doesn't work well, try the old method:
	// 	NSMutableSet *fileTypes = [NSMutableSet setWithArray:[QTMovie movieFileTypes:QTIncludeCommonTypes]];
	// [fileTypes minusSet:[NSSet setWithArray:[NSImage imageFileTypes]]];

}

- (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
	return @"com.karelia.sandvox.SVVideo";
}

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    result = [[[SVVideoInspector alloc] initWithNibName:@"SVVideoInspector" bundle:nil] autorelease];
    return result;
}

#pragma mark -
#pragma mark Poster Frame

- (id <SVMedia>)thumbnail
{
	return self.posterFrameType != kPosterFrameTypeNone ? self.posterFrame.media : nil;
}

+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObjects:@"posterFrame", @"posterFrameType", nil]; }

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
- (void)gotPosterJPEGData:(NSData *)jpegData;
{
	OBASSERT([NSThread isMainThread]);
	
	// Get the media or URL, so we have a good file name for the poster
	SVMedia *media = self.media;
	NSURL *videoURL = nil;
    if (media)
    {
		videoURL = [media fileURL];
	}
	else
	{
		videoURL = self.externalSourceURL;
	}
	if (videoURL)		// just in case we got cleared out from switching to an audio
	{
		// Rebuild URL by substituting in path. Create a FAKE URL for a synthesized thumbnail.
		NSString *newPath = [[[videoURL path] stringByDeletingPathExtension] stringByAppendingString:@".jpg"];
		
		NSURL *fakeURL = [[[NSURL alloc] initWithScheme:[videoURL scheme]
												   host:[videoURL host]
												   path:newPath]
						  autorelease];
		
		if (jpegData)
		{
            media = [[SVMedia alloc] initWithData:jpegData URL:fakeURL];
        }
        [self setPosterFrameWithMedia:media];
        [media release];
	}
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
											[NSNumber numberWithFloat:0.7], NSImageCompressionFactor,
											[NSNumber numberWithBool:NO], NSImageProgressive);
		
		jpegData = [bitmapImageRep representationUsingType:NSJPEGFileType properties:props];
		
		// [jpegData writeToFile:@"/Volumes/dwood/Desktop/quicklook.jpg" atomically:YES];
	}
	[[self ks_proxyOnThread:nil waitUntilDone:NO] gotPosterJPEGData:jpegData];
}

- (void)getPosterFrameFromQuickLook;
{
	SVMedia *media = self.media;
	if (media)
	{
		NSURL *mediaURL = [media fileURL];
		OBASSERT(mediaURL);
		NSInvocationOperation *operation = [[NSInvocationOperation alloc] initWithTarget:self
																				selector:@selector(getQuickLookForFileURL:)
																				  object:mediaURL];
		
		[[[self class] sharedQuickLookQueue] addOperation:operation];
        [operation release];
	}
}


#pragma mark -
#pragma mark Media

// May be called from migration, but didSetSource: is not called then.  If called from standard usage,
// then didSetSource: was already called, so we don't want to kick off the loading.

- (void) initializeProperties;
{
	if ([self.container constrainsProportions])    // generally true
    {
        /*/ Resize image to fit in space
		 NSUInteger width = self.width;
		 [self.container makeOriginalSize];
		 if (self.width > width) self.width = width;*/
    }
	
	if (nil == self.posterFrame || self.posterFrameType != kPosterTypeChoose)		// get poster frame image UNLESS we have an override chosen.
	{
		[self getPosterFrameFromQuickLook];
	}
	
	NSURL *movieSourceURL = nil;
	if (self.media)
    {
		movieSourceURL = [self.media mediaURL];
        
		[self setCodecType:[NSString UTIForFileAtPath:[movieSourceURL path]]];	// actually look at the file, not just its extension
	}
	else
	{
		movieSourceURL = self.externalSourceURL;
        
		[self setCodecType:[NSString UTIForFilenameExtension:[[movieSourceURL path] pathExtension]]];
	}
	
	// Try to make a QTMovie out of this, or parse as FLV which is a special case (since QT is not needed to show.)
	
	if ([NSThread isMainThread])
	{
		[self loadMovieFromURL:movieSourceURL];
	}
	else
	{
		[self performSelectorOnMainThread:@selector(loadMovieFromURL:) withObject:movieSourceURL waitUntilDone:YES];
		
		NSDate *timeoutDate = [NSDate dateWithTimeIntervalSinceNow:20];
		while (self.dimensionCalculationMovie
			   && [timeoutDate timeIntervalSinceNow] > 0
			   && [[[self.dimensionCalculationMovie ks_proxyOnThread:nil] attributeForKey:QTMovieLoadStateAttribute] intValue] < QTMovieLoadStateLoaded)
		{
			sleep(1);
		}
		[self loadStateChanged:nil];
	}
}

- (void)didAddToPage:(id <SVPage>)page;
{
	if (!_didInitializePropertiesWasCalled)
	{
		_didInitializePropertiesWasCalled = YES;
		[self initializeProperties];
	}
}


- (void)didSetSource;
{
	_didInitializePropertiesWasCalled = TRUE;		// don't let didAddToPage initialize the properties
	
    [super didSetSource];

	[self initializeProperties];
}


- (void) loadMovieFromURL:(NSURL *)movieSourceURL;
{
	BOOL openAsync = YES;			// I think this will be OK for both
	NSMutableDictionary *movieAttributes = [NSMutableDictionary dictionaryWithObjectsAndKeys: 
											movieSourceURL, QTMovieURLAttribute,
											[NSNumber numberWithBool:openAsync], QTMovieOpenAsyncOKAttribute,
											[NSNumber numberWithBool:YES], QTMovieDontInteractWithUserAttribute,
											nil];
	if (IMBRunningOnSnowLeopardOrNewer())
	{
		// Wait, DON'T do this necessarily ... Problem is that when we try to do betterPosterImage
		// (to determine poster image for remote URL) it won't allow us if we opened the movie
		// for playback only.
		// *** Canceling drag because exception 'QTDisallowedForInitializationPurposeException' (reason 'Tried to use QTMovie method quickTimeMovie, which is not allowed when QTMovieOpenForPlaybackAttribute is YES.') was raised during a dragging session
		
		// [movieAttributes setValue:[NSNumber numberWithBool:YES] forKey:@"QTMovieOpenForPlaybackAttribute"];	// From Tim Monroe @ WWDC'10, so we can check how movie was loaded
	}
	[self loadMovieFromAttributes:movieAttributes];
}

+ (BOOL)acceptsType:(NSString *)uti;
{
    return [uti conformsToUTI:(NSString *)kUTTypeVideo] || [uti conformsToUTI:(NSString *)kUTTypeMovie];
}

// Overrides to allow us to get our thumbnail (for index, or site outline) from poster frame.
- (id <SVMedia>)thumbnailMedia; { return self.posterFrame.media; }

- (id)imageRepresentation;
{
    SVMedia *media = [[self posterFrame] media];
    return (media.mediaData ? (id)media.mediaData : (id)media.mediaURL);
}

- (NSString *)imageRepresentationType
{
    SVMedia *media = [[self posterFrame] media];
    return (media.mediaData ? IKImageBrowserNSDataRepresentationType : IKImageBrowserNSURLRepresentationType);
}

#pragma mark -
#pragma mark Custom setters (instead of KVO)

- (void) setPosterFrameType:(PosterFrameType)aPosterFrameType
{
	PosterFrameType old = _posterFrameType;
	_posterFrameType = aPosterFrameType;
	switch(aPosterFrameType)
	{
		case kPosterTypeChoose:
			// Switching to choose from automatic? Clear out the image.
			[self setPosterFrameWithMedia:nil];
			break;
		case kPosterFrameTypeAutomatic:
			if (kPosterFrameTypeUndefined != old)	// possibly get new frame only if we already had some other value.
													// This is so that initial population does nothing.
			{
				// Switching to automatic? Queue request for quicklook
				if (self.media)
				{
					[self getPosterFrameFromQuickLook];
				}
				else if (self.externalSourceURL)
				{
					if (self.dimensionCalculationMovie)
					{
						[self calculatePosterImageFromPlayableMovie:self.dimensionCalculationMovie];
					}
					else
					{
						NSLog(@"Don't have movie to calculate poster frame from");
					}
				}
			}
			break;
		default:
			// Do nothing; don't mess with media
			break;
	}
}


#pragma mark -
#pragma mark Writing Tag

// Called from Audio as well as video since it's the same.
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
	NSString *movieSourcePath  = movieSourceURL ? [context relativeStringFromURL:movieSourceURL] : @"";
	NSString *posterSourcePath = posterSourceURL ? [context relativeStringFromURL:posterSourceURL] : @"";

	NSUInteger barHeight = self.controller ? 16 : 0;
	
	[context pushAttribute:@"classid" value:@"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"];	// Proper value?
	[context pushAttribute:@"codebase" value:@"http://www.apple.com/qtactivex/qtplugin.cab"];
	
	[context buildAttributesForElement:@"object" bindSizeToObject:self DOMControllerClass:nil  sizeDelta:NSMakeSize(0,barHeight)];

	// ID on <object> apparently required for IE8
	NSString *elementID = [context pushPreferredIdName:@"quicktime"];
    [context startElement:@"object"];
	
	if (posterSourceURL
		&& !self.autoplay)	// poster and not auto-starting? make it an href
	{
		[context writeParamElementWithName:@"src" value:posterSourcePath];
		[context writeParamElementWithName:@"href" value:movieSourcePath];
		[context writeParamElementWithName:@"target" value:@"myself"];
	}
	else
	{
		[context writeParamElementWithName:@"src" value:movieSourcePath];
	}
	
	[context writeParamElementWithName:@"autoplay" value:self.autoplay ? @"true" : @"false"];
	[context writeParamElementWithName:@"controller" value:self.controller ? @"true" : @"false"];
	[context writeParamElementWithName:@"loop" value:self.loop ? @"true" : @"false"];
	[context writeParamElementWithName:@"scale" value:@"tofit"];
	[context writeParamElementWithName:@"type" value:@"video/quicktime"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://www.apple.com/quicktime/download/"];	

	return elementID;
}

- (NSString *)startMicrosoftObject:(SVHTMLContext *)context
					movieSourceURL:(NSURL *)movieSourceURL;
{
	// I don't think there is any way to use the poster frame for a click to play
	NSString *movieSourcePath = movieSourceURL ? [context relativeStringFromURL:movieSourceURL] : @"";
	
	NSUInteger barHeight = self.controller ? 46 : 0;		// Windows media controller is 46 pixels (on windows; adjusted on macs)

	[context pushAttribute:@"classid" value:@"CLSID:6BF52A52-394A-11D3-B153-00C04F79FAA6"];
	[context buildAttributesForElement:@"object" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSMakeSize(0,barHeight)];

	// ID on <object> apparently required for IE8
	NSString *elementID = [context pushPreferredIdName:@"wmplayer"];
    [context startElement:@"object"];
	
	[context writeParamElementWithName:@"url" value:movieSourcePath];
	[context writeParamElementWithName:@"autostart" value:self.autoplay ? @"true" : @"false"];
	[context writeParamElementWithName:@"showcontrols" value:self.controller ? @"true" : @"false"];
	[context writeParamElementWithName:@"playcount" value:self.loop ? @"9999" : @"1"];
//	[context writeParamElementWithName:@"type" value:@"application/x-oleobject"];	... TOOK OUT, BREAKS DISPLAY ON MAC
	[context writeParamElementWithName:@"uiMode" value:@"mini"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://microsoft.com/windows/mediaplayer/en/download/"];

	return elementID;
}

- (NSString *)startVideo:(SVHTMLContext *)context
		  movieSourceURL:(NSURL *)movieSourceURL
		 posterSourceURL:(NSURL *)posterSourceURL;
{
	NSString *movieSourcePath  = movieSourceURL ? [context relativeStringFromURL:movieSourceURL] : @"";
	NSString *posterSourcePath = posterSourceURL ? [context relativeStringFromURL:posterSourceURL] : @"";

	// Actually write the video
	if ([[self container] shouldWriteHTMLInline]) [self.container buildClassName:context];
	
	if (self.controller)	[context pushAttribute:@"controls" value:@"controls"];		// boolean attribute
	if (self.autoplay)	[context pushAttribute:@"autoplay" value:@"autoplay"];
	[context pushAttribute:@"preload" value:[NSARRAY(@"metadata", @"none", @"auto") objectAtIndex:self.preload + 1]];
	if (self.loop)		[context pushAttribute:@"loop" value:@"loop"];
	
	if (posterSourceURL)	[context pushAttribute:@"poster" value:posterSourcePath];

	[context buildAttributesForElement:@"object" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSZeroSize];

	NSString *elementID = [context pushPreferredIdName:@"video"];
    [context startElement:@"video"];
	
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
	[context pushAttribute:@"type" value:[NSString MIMETypeForUTI:self.codecType]];
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
						  [NSString MIMETypeForUTI:self.codecType]]];
	[context writeString:@"\t// canPlayType is overoptimistic, so we have browser sniff.\n"];
	
	// we have mp4, so no ogv/webm, so force a fallback if NOT webkit-based.
	if ([self.codecType conformsToUTI:@"public.mpeg-4"]
		|| [self.codecType conformsToUTI:@"public.3gpp"]
		|| [self.codecType conformsToUTI:@"com.apple.protected-mpeg-4-video"])
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf('WebKit/') <= -1) {\n\t\t// Only webkit-browsers can currently play this natively\n\t\tfallback(video);\n\t}\n"];
	}
	else	// we have an ogv or webm (or something else?) so fallback if it's Safari, which won't handle it
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf(' "];
		[context writeString:([context isForEditing] ? @"Sandvox" : @"Safari")];	// Treat Sandvox like it's Safari
		[context writeString:@"') > -1) {\n\t\t// Safari can't play this natively\n\t\tfallback(video);\n\t}\n"];
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
	NSString *videoFlashFormat	= [defaults objectForKey:@"videoFlashFormat"];	// format pattern with %1$@ and %2$@ for movie, poster
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
		if (movieSourceURL)  movieSourcePath  = [context relativeStringFromURL:movieSourceURL];
		if (posterSourceURL) posterSourcePath = [context relativeStringFromURL:posterSourceURL];
	}
	// Ordering string arguments:
	// http://developer.apple.com/library/ios/#documentation/cocoa/Conceptual/LoadingResources/Strings/Strings.html%23//apple_ref/doc/uid/10000051i-CH6-99832
	NSDictionary *noPosterParamLookup
	= NSDICT(
			 @"video=%@",                                  @"f4player",	
			 @"file=%@",                                   @"jwplayer",	
			 @"flv=%@&margin=0",                           @"flvplayer",	
			 @"movie=%@",                                  @"osflv",		
			 @"config={\"playlist\":[{\"url\":\"%@\"}]}",  @"flowplayer");
	NSDictionary *posterParamLookup
	= NSDICT(
			 @"video=%1$@&thumbnail=%2$@",         @"f4player",
			 @"file=%1$@&image=%2$@&controlbar=over", @"jwplayer",
			 @"flv=%1$@&startimage=%2$@&margin=0", @"flvplayer",
			 @"movie=%1$@&previewimage=%2$@",      @"osflv",	
			 @"config={\"playlist\":[{\"url\":\"%2$@\"},{\"url\":\"%1$@\",\"autoPlay\":false,\"autoBuffering\":true}]}",
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
		NSDictionary *formatLookupDict = (posterSourceURL) ? posterParamLookup : noPosterParamLookup;
		flashVarFormatString = [formatLookupDict objectForKey:videoFlashPlayer];
	}
	
	// Now instantiate the string from the format
	NSMutableString *flashVars = nil;
	if (posterSourceURL)
	{
		flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePath, posterSourcePath];
	}
	else
	{
		flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePath];
	}
	
	
	if ([videoFlashPlayer isEqualToString:@"flvplayer"])
	{
		[flashVars appendFormat:@"&showplayer=%@", (self.controller) ? @"autohide" : @"never"];
		if (self.autoplay)				[flashVars appendString:@"&autoplay=1"];
		if (kPreloadAuto == self.preload)	[flashVars appendString:@"&autoload=1"];
		if (self.loop)					[flashVars appendString:@"&loop=1"];
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
		playerPath = [context relativeStringFromURL:playerURL];
	}
	
	if ([[self container] shouldWriteHTMLInline]) [self.container buildClassName:context];
	[context pushAttribute:@"type" value:@"application/x-shockwave-flash"];
	[context pushAttribute:@"data" value:playerPath];	
	
	[context buildAttributesForElement:@"object" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSMakeSize(0,barHeight)];

	// ID on <object> apparently required for IE8
	NSString *elementID = [context pushPreferredIdName:[playerPath lastPathComponent]];
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

	return elementID;
}

- (NSString *)cannotViewTitle:(SVHTMLContext *)context
{
	// Get a title to indicate that the movie cannot play inline.  (Suggest downloading, if we provide a link)
	KTPage *thePage = [context page];
	NSString *language = [thePage language];
	
	NSString *cannotViewTitle
	= [[NSBundle mainBundle] localizedStringForString:@"cannotViewTitleText"
											 language:language
											 fallback:
	   NSLocalizedStringWithDefaultValue(@"cannotViewTitleText",
										 nil,
										 [NSBundle mainBundle],
										 @"This browser cannot play the embedded video file.", @"Warning to show when a video cannot be played")];
	return cannotViewTitle;
}
- (void)writePosterImage:(SVHTMLContext *)context
	posterSourceURL:(NSURL *)posterSourceURL;
{
	NSString *posterSourcePath = posterSourceURL ? [context relativeStringFromURL:posterSourceURL] : @"";

	NSString *altForMovieFallback = [[posterSourcePath lastPathComponent] stringByDeletingPathExtension];// Cheating ... What would be a good alt ?
	
	[context pushAttribute:@"title" value:[self cannotViewTitle:context]];
	[context writeImageWithSrc:posterSourcePath alt:altForMovieFallback width:self.width height:self.height];
}


- (NSString *)startNoRemoteFlashVideo:(SVHTMLContext *)context;
{
	KTPage *thePage = [context page];
	NSString *language = [thePage language];
	
	NSString *noCrossDomainFlash = [[NSBundle mainBundle] localizedStringForString:@"noCrossDomainFlashText"
																	   language:language
																	   fallback:
								 NSLocalizedStringWithDefaultValue(@"noCrossDomainFlashText", nil, [NSBundle mainBundle], @"Unable to embed remotely-hosted Flash-based video.", @"Warning to show when a video cannot be played")];

	
	[context buildAttributesForElement:@"div" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSZeroSize];
	NSString *elementID = [context startElement:@"div" preferredIdName:@"nocrossdomain" className:nil attributes:nil];	// class, attributes already pushed
	[context writeElement:@"p" text:noCrossDomainFlash];
	// Poster may be shown next, so don't end....
	
	return elementID;
}

- (NSString *)startUnknown:(SVHTMLContext *)context;
{
	[context buildAttributesForElement:@"div" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSZeroSize];
	NSString *elementID = [context startElement:@"div" preferredIdName:@"unrecognized" className:nil attributes:nil];	// class, attributes already pushed
	[context writeElement:@"p" text:[self cannotViewTitle:context]];
	// Poster may be shown next, so don't end....

	return elementID;
}

- (void)writeHTML:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMedia *media = self.media;
	//[context addDependencyForKeyPath:@"media"			ofObject:self]; // don't need, graphic does for us
	[context addDependencyForKeyPath:@"posterFrameType"	ofObject:self];
	[context addDependencyForKeyPath:@"posterFrame"		ofObject:self];	// force rebuild if poster frame got changed
	[context addDependencyForKeyPath:@"controller"		ofObject:self];	// Note: other boolean properties don't affect display of page

	NSURL *movieSourceURL = self.externalSourceURL;
    if (media)
    {
	    movieSourceURL = [context addMedia:media];
	}

	// POSSIBLE OTHER TAGS TO CONSIDER:  public.3gpp2 public.mpeg com.microsoft.windows-media-wm
	// Determine tag(s) to use
	// video || flash (not mutually exclusive) are mutually exclusive with microsoft, quicktime
	NSString *type = self.codecType;
	BOOL videoTag = [type conformsToUTI:@"public.mpeg-4"]
		|| [type conformsToUTI:@"com.apple.protected-mpeg-4-video"]		// .m4v MIGHT BE OK
//		|| [type conformsToUTI:@"public.ogg-theora"]	// DON'T TRY TO PLAY THESE TYPES
//		|| [type conformsToUTI:@"public.webm"]			// SINCE WE CAN'T SEE IT IN WEBKIT
		|| [type conformsToUTI:@"public.3gpp"] ;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"avoidVideoTag"]) videoTag = NO;
	
	BOOL flvMedia = [type conformsToUTI:@"com.adobe.flash.video"];
	BOOL flashTag = flvMedia
		|| [type conformsToUTI:@"public.mpeg-4"]
		|| [type conformsToUTI:@"com.apple.protected-mpeg-4-video"]		// .m4v MIGHT BE OK
		|| [type conformsToUTI:@"public.3gpp"];
	if ([defaults boolForKey:@"avoidFlashVideo"]) flashTag = NO;
	
	BOOL flashDisallowedTag = (flvMedia && !self.media
		&& ![defaults boolForKey:@"videoFlashRemoteOverride"]);	// hidden pref to allow for remote URL
		
	if (flashDisallowedTag) flashTag = NO;
	
	BOOL microsoftTag = [type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-media-wmv"];
	
	// quicktime fallback, but not for mp4.  We may want to be more selective of mpeg-4 types though.
	// Also show quicktime when there is no media at all
	BOOL quicktimeTag = ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
	&& ![type conformsToUTI:@"public.mpeg-4"]
	&& ![type conformsToUTI:@"com.apple.protected-mpeg-4-video"]
	&& ![type conformsToUTI:@"public.3gpp"]
			;

	
	NSURL *posterSourceURL = nil;
	if (self.posterFrame
		&& [self enablePoster]
		&& !(quicktimeTag && self.externalSourceURL)		// don't do this if this is quicktime, with an external URL
															// since click on poster image doesn't take you to movie!
		&& !microsoftTag									// Also ignore poster frame for microsoft
		&& (self.posterFrameType > kPosterFrameTypeNone) )	// and of course don't do poster if we don't want it
	{
		// Convert to JPEG if the poster image needs scaling or converting.  
		// (Hard-wired here, sorry dudes)
		posterSourceURL = [context addImageMedia:self.posterFrame.media
										   width:self.width
										  height:self.height
											type:(NSString *)kUTTypeJPEG
                               preferredFilename:nil];
	}
		
	BOOL wroteUnknownTag = NO;	// will be set below if nothing can be generated
	NSString *videoID = nil;
		
	// START THE TAGS
	
	if (quicktimeTag)
	{
		[self startQuickTimeObject:context movieSourceURL:movieSourceURL posterSourceURL:posterSourceURL];
	}
	else if (microsoftTag)
	{
		[self startMicrosoftObject:context movieSourceURL:movieSourceURL];	// poster not used
	}
	else if (videoTag || flashTag)
	{
		if (videoTag)	// start the video tag
		{
			[SVVideo writeFallbackScriptOnce:context];
			videoID = [self startVideo:context movieSourceURL:movieSourceURL posterSourceURL:posterSourceURL]; 
		}
		
		if (flashTag)	// inner
		{
			[self startFlash:context movieSourceURL:movieSourceURL posterSourceURL:posterSourceURL];
		}
	}
	
	// Deeply nested is notification that the browser can't show the embedded video.

	if (flashDisallowedTag)
	{
		// Can't handle remotely hosted flash.  Do something similar to the unknown tag.
		[self startNoRemoteFlashVideo:context];
		wroteUnknownTag = YES;
	}
	else
	{
		[self startUnknown:context];
		wroteUnknownTag = YES;
	}


	
	// INNERMOST POSTER FRAME
	
	if (posterSourceURL)		// image within the video or object tag as a fallback
	{	
		[self writePosterImage:context posterSourceURL:posterSourceURL];
	}
	
	// END THE TAGS
	
	if (wroteUnknownTag)
	{
		OBASSERT([@"div" isEqualToString:[context topElement]]);
		[context endElement];
	}
		
	if (flashTag || quicktimeTag || microsoftTag)
	{
        //[context startElement:@"object"];
		OBASSERT([@"object" isEqualToString:[context topElement]]);
		[context endElement];	//  </object>
	}
		
	if (videoTag)		// we may have a video nested outside of an object
	{
		OBASSERT([@"video" isEqualToString:[context topElement]]);
		[context endElement];
		
		[self writePostVideoScript:context referringToID:videoID];
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
+ (NSSet *)keyPathsForValuesAffectingEnablePoster
{
    return [NSSet setWithObjects:@"preload", @"codecType", @"externalSourceURL", nil];
}

- (BOOL) enablePoster	// poster is not enabled in certain situations: Remote URL QuickTime, Microsoft tags.
{
	NSString *type = self.codecType;
	BOOL disable = (nil == type)
	|| (kPreloadAuto == self.preload)		// when preloading, you CAN'T do poster, apparently.
	|| [type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-media-wmv"]
	|| ( (([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
		  && ![type conformsToUTI:@"public.mpeg-4"]
		  && ![type conformsToUTI:@"com.apple.protected-mpeg-4-video"]
		  && ![type conformsToUTI:@"public.3gpp"]) && self.externalSourceURL );
	return !disable;
}

- (NSImage *)icon
{
	NSImage *result = nil;
	NSString *type = self.codecType;

	if (!type || (!self.media && !self.externalSourceURL))								// no movie
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type isEqualToString:@"unloadable-video"])	
	{
		// Special type ... A movie type that might be valid on some systems but can't be shown on this mac
		// (e.g. it might load if we had Perian, Flip4Mac, XiphQT ... but we don't.
		result = [NSImage imageFromOSType:kAlertStopIcon];
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible.  NOT YET IMPLEMENTED, AS QUICKTIME API CAN'T TELL US.
	{
		result =[ NSImage imageNamed:@"checkmark"];;
	}
	else if ([type conformsToUTI:@"public.mpeg-4"]
			 || [type conformsToUTI:@"public.3gpp"]
			 || [type conformsToUTI:@"com.apple.protected-mpeg-4-video"]
			 )			// might not be iOS compatible
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type conformsToUTI:@"com.adobe.flash.video"])
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if (self.media || [defaults boolForKey:@"videoFlashRemoteOverride"])
		{
			result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
		}
		else
		{
			result = [NSImage imageFromOSType:kAlertStopIcon];	// Not locally hosted media, and no override -- thus can't view.
		}
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

- (NSAttributedString *)info
{
	NSString *result = @"";
	NSString *type = self.codecType;
	
	if (!type || (!self.media && !self.externalSourceURL))								// no data?
	{
		result = NSLocalizedString(@"Use MPEG-4 (h.264) video for maximum compatibility.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type isEqualToString:@"unloadable-video"])	
	{
		// Special type ... A movie type that might be valid on some systems but can't be shown on this mac
		// (e.g. it might load if we had Perian, Flip4Mac, XiphQT ... but we don't.
		result = NSLocalizedString(@"Video cannot be loaded on this computer.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result = NSLocalizedString(@"Video is compatible with a wide range of devices.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.mpeg-4"]
			 || [type conformsToUTI:@"public.3gpp"]
			 || [type conformsToUTI:@"com.apple.protected-mpeg-4-video"]
			 )
	{
		result = NSLocalizedString(@"You will need to verify if this video will play on iOS devices.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"com.adobe.flash.video"])
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		if (self.media || [defaults boolForKey:@"videoFlashRemoteOverride"])
		{
			result = NSLocalizedString(@"Video will not play on iOS devices", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
		}
		else
		{
			result = NSLocalizedString(@"Unable to embed remotely-hosted Flash-based video.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");	// Not locally hosted media, and no override -- thus can't view.
		}

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
	result = [result stringByAppendingString:@" "];	// space between message and the hyperlinked "More"
	NSMutableDictionary *attribs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
							 [NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
							 nil];
	NSMutableAttributedString *info = [[[NSMutableAttributedString alloc] initWithString:result attributes:attribs] autorelease];
	NSString *helpFilePath = [[NSBundle mainBundle] pathForResource:@"Supported_Video_Formats" ofType:@"html" inDirectory:@"Sandvox Help/z"];
	
	NSURL *url = [[[NSURL alloc] initWithScheme:@"help" host:@"" path:helpFilePath] autorelease];
				   
	NSDictionary *linkAttribs
	= [NSDictionary dictionaryWithObjectsAndKeys:
	   url,
	   NSLinkAttributeName,
	   [NSNumber numberWithInteger:NSSingleUnderlineStyle], NSUnderlineStyleAttributeName,
	   [NSCursor pointingHandCursor], NSCursorAttributeName,
	   [NSColor linkColor], NSForegroundColorAttributeName,
	   nil];
	[attribs addEntriesFromDictionary:linkAttribs];
	
	[info appendAttributedString:
	 [[[NSAttributedString alloc] initWithString:NSLocalizedString(@"More", @"hyperlink to a page that will tell more details about the warning")
					   attributes:attribs] autorelease]];
    [attribs release];
	return info;
}

#pragma mark -
#pragma mark Loading movie to calculate dimensions or remote poster frame




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
	if (aMovie)
	{
		OBASSERT([NSThread isMainThread]);
	}
	[aMovie retain];
	[_dimensionCalculationMovie release];
	_dimensionCalculationMovie = aMovie;
}

- (void)loadMovieFromAttributes:(NSDictionary *)anAttributes
{
	// Ignore for background threads as there is no need to do this during a doc import
	// (STILL APPLICABLE FOR SANDVOX 2?
    OBASSERT([NSThread isMainThread]);
    
    [self setDimensionCalculationMovie:nil];	// will clear out any old movie, exit movies on thread
	NSError *error = nil;
	QTMovie *movie = nil;
		
	movie = [[QTMovie alloc] initWithAttributes:anAttributes
										   error:&error];
	if (movie
		&& [[movie tracks] count]
		&& (NSOrderedSame != QTTimeCompare([movie duration], QTZeroTime))
		&& ![movie ks_isDRMProtected] )
	{
		[self setDimensionCalculationMovie:movie];		// cache and retain for async loading.
	
		/// Case 18430: we only add observers on main thread
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(loadStateChanged:)
													 name:QTMovieLoadStateDidChangeNotification object:movie];
		
		[[NSNotificationCenter defaultCenter] postNotificationName:QTMovieLoadStateDidChangeNotification
															object:movie];
	}
	else	// No movie?  Maybe it's a format that QuickTime can't read.  We can try FLV
	{		
		// Since there is no movie, we can't calculate poster frame automatically, so set it to none.
		self.posterFrameType = kPosterFrameTypeNone;

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
				// we only need a bit of data so let's try this.
				// http://www.cocoabuilder.com/archive/cocoa/228846-is-there-more-efficient-way-to-get-the-first-4-bytes-off-nsinputstream-to-compare.html
				movieData = [NSData dataWithContentsOfURL:URL options:NSUncachedRead error:nil];
			}
			else	// not a file; load asynchronously
			{
				self.dimensionCalculationConnection = [[[KSSimpleURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URL] delegate:self] autorelease];
				self.dimensionCalculationConnection.bytesNeeded = 1024;	// Let's just get the first 1K ... should be enough.

				// I don't have the dimensions right now, however I am assuming that if we got this far then we are ok.
			}
		}
		if (nil != movieData)
		{
			NSSize dimensions = [QTMovie dimensionsFromUnloadableMovieData:movieData];
			// Only set natural size if we really have a value
			if (dimensions.width && dimensions.height)
			{
				[self setNaturalWidth:[NSNumber numberWithFloat:dimensions.width] height:[NSNumber numberWithFloat:dimensions.height]];
				
			}
			else	// QTMovie can't be created, and we can't find dimensions from data (FLV), so disallow!
			{
				[self setCodecType:@"unloadable-video"];	// force the unknown codecType.
			}
		}
	}
	if (movie)
	{
		[movie autorelease];
	}
}
	
// Asynchronous load returned -- try to set the dimensions.
- (void)connection:(KSSimpleURLConnection *)connection didFinishLoadingData:(NSData *)data response:(NSURLResponse *)response;
{
	NSSize dimensions = [QTMovie dimensionsFromUnloadableMovieData:data];
	// Only set natural size if we really have a value
	if (dimensions.width && dimensions.height)
	{
		[self setNaturalWidth:[NSNumber numberWithFloat:dimensions.width] height:[NSNumber numberWithFloat:dimensions.height]];
	}
	else	// QTMovie can't be created, and we can't find dimensions from data (FLV), so disallow!
	{
		[self setCodecType:@"unloadable-video"];	// force the unknown codecType.
	}
	self.dimensionCalculationConnection = nil;
}

- (void)connection:(KSSimpleURLConnection *)connection didFailWithError:(NSError *)error;
{
	LOG((@"Connection failed:%@", error));
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
		BOOL keepGoing = NO;
		long loadState = [[movie attributeForKey:QTMovieLoadStateAttribute] longValue];
		if (loadState >= kMovieLoadStateLoaded)
		{
			keepGoing = [self calculateMovieDimensions:movie];
		}
		// We might have dealloced ourself after this, so proceed carefully!

		if (keepGoing && (loadState >= kMovieLoadStatePlaythroughOK))
		{
			if (!self.media && self.posterFrameType == kPosterFrameTypeAutomatic)	// ONLY try to get poster image for a *remote* URL
			{
				[self calculatePosterImageFromPlayableMovie:movie];
			}
			
			[[NSNotificationCenter defaultCenter] removeObserver:self];
			self.dimensionCalculationMovie = nil;	// we are done with movie now!
		}
	}
}

- (void)calculatePosterImageFromPlayableMovie:(QTMovie *)aMovie;
{
	NSImage *posterImage = [aMovie betterPosterImage];
	if (posterImage)	// It's possible an image isn't returned.
	{
		NSData *JPEGData = [posterImage JPEGRepresentationWithCompressionFactor:0.9];
		[self gotPosterJPEGData:JPEGData];
	}
}

- (BOOL)calculateMovieDimensions:(QTMovie *)aMovie;
{
	BOOL keepGoing = YES;
	
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
	
	if (0 == movieSize.width || 0 == movieSize.height)
	{
		keepGoing = NO;	// since we are about to be deallocated -- and nothing retains self, be careful to not do more.
		// However, just to help  a bit more, try this....
		[[self retain] autorelease];		// kludgey way to hang onto this so that we don't have SELF go away immediately!
		
		// Chances are if we got here with zero width/height, there is just no video track -- so become an audio file!
		[self setCodecType:@"com.apple.quicktime-audio"];		// Our specialization of generic quicktime movie
		// This will re-create things as an audio....
		// Note: We should be sure that we don't do anything further as we unwind, since we're DONE with this movie.
	}
	else
	{
		[self setNaturalWidth:[NSNumber numberWithFloat:movieSize.width] height:[NSNumber numberWithFloat:movieSize.height]];
	}
	
	return keepGoing;
}


@end
