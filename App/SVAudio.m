//
//  SVAudio.m
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010-2011 Karelia Software. All rights reserved.
//
/*
 SVAudio is a MediaGraphic, though unlike SVVideo and SVImage, its media is not visual (thus an
 audio doesn't have a real concept of a natural size.)  It defines a lot of the same methods that
 a plug-in using the SDK would use, but this is built-in and gets more internal access.
 
 The markup that this generates is based on "Audio For Everybody" (which is in turn based off of
 "Video For Everybody").  The idea is that we generate an HTML5 <audio> tag, but then within that
 tag, for browsers that can't handle this (*cough*IE*cough*), the outermost tag is ignored and
 a familiar <object> tag, ignored when the browser could handle the <audio> tag, is used to present
 the player.  Thus you get almost 100% coverage of the combination of the tags.
 
 However this approach really only works when you have the right kind of media.  For audio, it turns
 out that MP3 audio is handled by most browser with the <audio> tag; a Flash-based player handles
 the remaining browsers. And WAV audio is good too; the fallback in this case is a windows-media
 <object> tag, which can be handled by both IE and Mac-based browsers with QuickTime.
 
 In order to try to get as best of a "coverage" as possible, there are two methods here -- icon and
 info -- that give the user an indication that other audio formats might not be such a good idea.
 
 Still, we try to accomodate whatever formats we can.  If the audio format is one that the <audio>
 tag can handle (at least on some browsers), we will generate that.  If it's MP3, the Flash player
 code will be generated.  If it is a .wav, the windows media <object> tag is generated. And if it
 appears to be a QuickTime movie (presumably an audio-only movie), then the QuickTime <object> tag
 is generated.  The audio tag is always generated on the "outside" and then the others have an
 opportunity to be nested inside of that.  (If the file format is unknown, then a simple <div> with
 a note of a problem is generated.)
 
 There are some challenges with the audio tag, in that different browsers support different A/V
 file formats.  So Firefox & Opera can't handle an MP3; they need Ogg Vorbis.  Other Browsers
 (the webkit-based ones) do MP3, but not Ogg.  The Audio|Video for Everybody approach is to provide
 more than one source file; the browser picks the one it wants.  We're not doing that; we only have
 a mechanism for specifying a single source file, so we are going with another approach of surgical
 DOM manipulation if the <audio> tag is not going to work for the given browser.
 
 Ideally, we use an onerror() call after the last source to unlink the <audio> tag and expose the
 embedded <object> tag.  (We define a JavaScript function "fallback" to do this; it is written only
 one time per page, and works for both <audio> and <video> tags.)  Except that in Safari at least,
 the onerror() technique didn't work as of the writing of this class.  So we write some JavaScript
 right after the <audio> tag closes to check if the current browser supports the given audio format.
 Alas, *that* doesn't really work well either; so as a last-resort, if the browser still thinks it
 can play the audio, we do some browser user-agent sniffing to force the fallback to happen in two
 situations: MP3 on a non-WebKit browser, or WAV on Chrome. Maybe we don't need to do those checks
 but it doesn't hurt.
 
 While the Microsoft (windows media player) tags and the QuickTime tags are straightforward, the
 Flash tag is a bit tricker.  In trying to get this to work, I tested several MP3 players to make
 sure that this was a generic solution in case a better player comes along.  I put in a few user-
 default hooks to extend this if somebody wants to, though this is probably good enough as-is.
 
 A note about the playback options:  I couldn't find a way to have a hidden flash player.  I think
 that this won't be a big deal, though.  (Also, some Flash MP3 players I had tried don't have an
 option to preload the audio as soon as the page loads; the one we are bundling can do that though.)  
 
 At some point, I may want do actually do some loading and analysis of the given file to make sure
 that it will be able to play on iOS devices.
 
 */

#import "SVAudio.h"

#import "SVVideo.h"		// for script utility function
#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "SVMediaGraphicInspector.h"

#import "SVHTMLContext.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "NSImage+Karelia.h"
#import "NSColor+Karelia.h"

@interface SVAudio ()
- (void)loadAudio;		// after it has changed (URL or media), determine codecType; later we may kick off load to test properties
@end

@implementation SVAudio

#pragma mark Lifetime

- (void)awakeFromNew;
{
    [[self container] setConstrainsProportions:NO];
	self.controller = YES;
	self.preload = kPreloadAuto;
	self.autoplay = NO;
	self.loop = NO;
	
    // Show caption
    if ([[[self.container textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}

- (void)makeOriginalSize;
{
    [self setWidth:[NSNumber numberWithUnsignedInt:200] height:nil];
    [[self container] setConstrainsProportions:NO];
}

#pragma mark Metrics

- (NSNumber *)width;
{
    // Somewhat of a hack. Non-explicitly sized graphics (e.g. audio) get given auto width when placed as a pagelet. We need width of 200 so QuickTime does the right thing
    NSNumber *result = [super width];
    if (!result) result = [NSNumber numberWithInt:200];
    return result;
}

- (NSNumber *)height;
{
    // Used when generating HTML. We want to ignore whatever value is persisted (e.g. previous media was an image) and always write out with auto height
    return nil;
}

- (BOOL) validateHeight:(NSNumber **)height error:(NSError **)error;
{
    // Audio is unique among media, having auto height.
    return (*height == nil || [super validateHeight:height error:error]);
}

#pragma mark General
+ (NSArray *)allowedFileTypes;
{
	return [NSArray arrayWithObject:(NSString *)kUTTypeAudio];
}


- (NSString *)plugInIdentifier; // use standard reverse DNS-style string
{
	return @"com.karelia.sandvox.SVAudio";
}

+ (SVInspectorViewController *)makeInspectorViewController;
{
    SVInspectorViewController *result = nil;
    result = [[[SVMediaGraphicInspector alloc] initWithNibName:@"SVAudioInspector" bundle:nil] autorelease];
    return result;
}


#pragma mark -
#pragma mark Media

- (void)loadAudio;		// after it has changed (URL or media), determine codecType; later we may kick off load to test properties
{
	NSURL *movieSourceURL = nil;
	
	SVMedia *media = [self media];
	
    if (media)
    {
		movieSourceURL = [media mediaURL];
		[self setCodecType:[NSString UTIForFileAtPath:[movieSourceURL path]]];
	}
	else
	{
		movieSourceURL = [self externalSourceURL];
		[self setCodecType:[NSString UTIForFilenameExtension:[[movieSourceURL path] pathExtension]]];
	}
}


- (void)_mediaChanged;
{
	NSLog(@"SVAudio Media set.");
	
	[self loadAudio];
}

- (void)didSetSource;
{
    [super didSetSource];
	[self _mediaChanged];
}

#pragma mark -
#pragma mark Writing Tag

- (NSString *)startQuickTimeObject:(SVHTMLContext *)context
					audioSourceURL:(NSURL *)audioSourceURL;
{
	NSString *audioSourcePath  = audioSourceURL ? [context relativeStringFromURL:audioSourceURL] : @"";
	
	NSUInteger barHeight = self.controller ? 16 : 0;
	
	[context pushAttribute:@"classid" value:@"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"];	// Proper value?
	[context pushAttribute:@"codebase" value:@"http://www.apple.com/qtactivex/qtplugin.cab"];
	
	[context buildAttributesForElement:@"object" bindSizeToObject:self DOMControllerClass:nil  sizeDelta:NSMakeSize(0,barHeight)];
	
	// ID on <object> apparently required for IE8
	NSString *elementID = [context pushPreferredIdName:@"quicktime"];
    [context startElement:@"object"];
	
	[context writeParamElementWithName:@"src" value:audioSourcePath];
	
	[context writeParamElementWithName:@"autoplay" value:self.autoplay ? @"true" : @"false"];
	[context writeParamElementWithName:@"controller" value:self.controller ? @"true" : @"false"];
	[context writeParamElementWithName:@"loop" value:self.loop ? @"true" : @"false"];
	[context writeParamElementWithName:@"scale" value:@"tofit"];
	[context writeParamElementWithName:@"type" value:@"audio/quicktime"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://www.apple.com/quicktime/download/"];	

	return elementID;
}

- (NSString *)startMicrosoftObject:(SVHTMLContext *)context
					audioSourceURL:(NSURL *)audioSourceURL;
{
	NSString *audioSourcePath = audioSourceURL ? [context relativeStringFromURL:audioSourceURL] : @"";
	
	NSUInteger heightWithBar = self.controller ? 46 : 0;		// Windows media controller is 46 pixels (on windows; adjusted on macs)
	
	[context pushAttribute:@"width" value:self.width];
	[context pushAttribute:@"height" value:[NSNumber numberWithInteger:heightWithBar]];
	[context pushAttribute:@"classid" value:@"CLSID:6BF52A52-394A-11D3-B153-00C04F79FAA6"];

	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"object" preferredIdName:@"wmplayer" className:nil attributes:nil];	// class, attributes already pushed

	[context writeParamElementWithName:@"url" value:audioSourcePath];
	[context writeParamElementWithName:@"autostart" value:self.autoplay ? @"true" : @"false"];
	[context writeParamElementWithName:@"showcontrols" value:self.controller ? @"true" : @"false"];
	[context writeParamElementWithName:@"playcount" value:self.loop ? @"9999" : @"1"];
	[context writeParamElementWithName:@"type" value:@"application/x-oleobject"];
	[context writeParamElementWithName:@"uiMode" value:@"mini"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://microsoft.com/windows/mediaplayer/en/download/"];

	return elementID;
}

- (NSString *)startAudio:(SVHTMLContext *)context
		  audioSourceURL:(NSURL *)audioSourceURL;			// returns element ID
{
	NSString *audioSourcePath  = audioSourceURL ? [context relativeStringFromURL:audioSourceURL] : @"";
	
	// Actually write the audio
	if ([[self container] shouldWriteHTMLInline]) [self.container buildClassName:context];
	
	[context buildAttributesForElement:@"audio" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSZeroSize];
	
	if (self.controller)	[context pushAttribute:@"controls" value:@"controls"];		// boolean attribute
	if (self.autoplay)	[context pushAttribute:@"autoplay" value:@"autoplay"];
	[context pushAttribute:@"preload" value:[NSARRAY(@"metadata", @"none", @"auto") objectAtIndex:self.preload + 1]];
	if (self.loop)		[context pushAttribute:@"loop" value:@"loop"];
	
	NSString *elementID = [context startElement:@"audio" preferredIdName:@"audio" className:nil attributes:nil];	// class, attributes already pushed
	
	
	// source
	[context pushAttribute:@"src" value:audioSourcePath];
	if ([self codecType])
	{
		[context pushAttribute:@"type" value:[NSString MIMETypeForUTI:[self codecType]]];
	}
	[context pushAttribute:@"onerror" value:@"fallback(this.parentNode)"];
	[context startElement:@"source"];
	[context endElement];
	
	return elementID;
}

- (void)writePostAudioScript:(SVHTMLContext *)context referringToID:(NSString *)audioID
{
	OBPRECONDITION(context);
	OBPRECONDITION(audioID);
	// Now write the post-audio-tag surgery since onerror doesn't really work
	// This is hackish browser-sniffing!  Maybe later we can do away with this (especially if we can get > 1 audio source)
	
	[context startJavascriptElementWithSrc:nil];
	[context stopWritingInline];
	[context writeString:[NSString stringWithFormat:@"var audio = document.getElementById('%@');\n", audioID]];
	[context writeString:[NSString stringWithFormat:@"if (audio.canPlayType && audio.canPlayType('%@')) {\n",
						  [NSString MIMETypeForUTI:[self codecType]]]];
	[context writeString:@"\t// canPlayType is overoptimistic, so we have browser sniff.\n"];
	
	// See: http://www.findmebyip.com/litmus#html5-audio-codecs
	// We have mp3, so no ogg, so force a fallback if NOT webkit-based.
	if ([[self codecType] conformsToUTI:(NSString *)kUTTypeMP3])
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf('WebKit/') <= -1) {\n\t\t// Only webkit-browsers can currently play mp3 natively\n\t\tfallback(audio);\n\t}\n"];
	}
	// We have a .ogg, which won't play on Safari
	else if ([[self codecType] conformsToUTI:@"public.ogg-vorbis"])
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf(' "];
		[context writeString:([context isForEditing] ? @"Sandvox" : @"Safari")];	// Treat Sandvox like it's Safari
		[context writeString:@"') > -1) {\n"];
//		[context writeString:@"\tdocument.writeln('User agent Sandvox -- ' + navigator.userAgent);\n"];
		[context writeString:@"\t\t// Safari can't play this natively\n\t\tfallback(audio);\n\t}\n"];
	}
	// We have a .wav, which will play on all platforms with <audio> except Chrome, so force a fallback to Windows media object
	else if ([[self codecType] conformsToUTI:@"com.microsoft.waveform-audio"])
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf(' Chrome/') > -1) {\n\t\t// Chrome can't play mp3 natively\n\t\tfallback(audio);\n\t}\n"];
	}
	// Note: For other audio types, we're not going to try to fallback.  They are on their own if they use another format!
	
	[context writeString:@"} else {\n"];
//	[context writeString:@"\tdocument.writeln('falling back -- ' + navigator.userAgent);\n"];
	[context writeString:@"\tfallback(audio);\n}\n"];
	[context endElement];	
}

- (NSString *)startFlash:(SVHTMLContext *)context
		  audioSourceURL:(NSURL *)audioSourceURL;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL audioFlashRequiresFullURL = [defaults boolForKey:@"audioFlashRequiresFullURL"];	// usually not, but YES for flowplayer
	NSString *audioSourcePath = @"";
	if (audioFlashRequiresFullURL)
	{
		if (audioSourceURL)  audioSourcePath  = [audioSourceURL absoluteString];
	}
	else
	{
		if (audioSourceURL)  audioSourcePath  = [context relativeStringFromURL:audioSourceURL];
		}
	
	NSString *audioFlashPlayer	= [defaults objectForKey:@"audioFlashPlayer"];	// to override player type
	// Known types: flashmp3player dewplayer wpaudioplayer ....  Otherwise must specify audioFlashFormat.
	if (!audioFlashPlayer) audioFlashPlayer = @"flashmp3player";
	
	NSUInteger barHeight = 0;
	NSString *audioFlashBarHeight= [defaults objectForKey:@"audioFlashBarHeight"];	// height that the navigation bar adds
	if (audioFlashBarHeight)
	{
		barHeight= [audioFlashBarHeight intValue];
	}
	else
	{
		NSDictionary *barHeightLookup
		= NSDICT(
				 [NSNumber numberWithShort:20],		@"flashmp3player",	
				 [NSNumber numberWithShort:20],		@"dewplayer",	
				 [NSNumber numberWithShort:24],		@"wpaudioplayer");
		
		barHeight = [[barHeightLookup objectForKey:audioFlashPlayer] intValue];
	}
	
	NSString *flashVarFormatString = nil;
	NSString *audioFlashFormat	= [defaults objectForKey:@"audioFlashFormat"];	// format pattern with %@ for audio
	if (audioFlashFormat)		// override format?
	{
		flashVarFormatString = audioFlashFormat;
	}
	else
	{
		NSDictionary *paramLookup
		= NSDICT(
				 @"mp3=%@",							@"flashmp3player",	
				 @"mp3=%@",                         @"dewplayer",	
				 @"soundfile=%@",					@"wpaudioplayer");
		flashVarFormatString = [paramLookup objectForKey:audioFlashPlayer];
	}
	
	// Now instantiate the string from the format
	NSMutableString *flashVars = [NSMutableString stringWithFormat:flashVarFormatString, audioSourcePath];
	
	// Handle other options

	// Known types: flashmp3player dewplayer wpaudioplayer ....  Otherwise must specify audioFlashFormat.

	if ([audioFlashPlayer isEqualToString:@"flashmp3player"])
	{
		// Can't find way to hide the player; controller must always be showing
		if (self.autoplay)				[flashVars appendString:@"&autoplay=1"];
		if (kPreloadAuto == self.preload)	[flashVars appendString:@"&autoload=1"];
		if (self.loop)					[flashVars appendString:@"&loop=1"];
	}
	else if ([audioFlashPlayer isEqualToString:@"dewplayer"])
	{
		// Can't find way to hide the player; controller must always be showing
		if (self.autoplay)	[flashVars appendString:@"&autostart=1"];
		// Can't find a way to preload the audio
		if (self.loop)		[flashVars appendString:@"&autoreplay=1"];
	}
	else if ([audioFlashPlayer isEqualToString:@"wpaudioplayer"])
	{
		// Can't find way to hide the player; controller must always be showing
		if (self.autoplay)	[flashVars appendString:@"&autostart=1"];
		// Can't find a way to preload the audio
		if (self.loop)		[flashVars appendString:@"&loop=1"];
	}
	
	NSString *audioFlashExtras	= [defaults objectForKey:@"audioFlashExtras"];	// extra parameters to override for any player
	if (audioFlashExtras)	// append other parameters (usually like key1=value1&key2=value2)
	{
		[flashVars appendString:@"&"];
		[flashVars appendString:audioFlashExtras];
	}
	
	NSString *playerPath = nil;
	NSString *audioFlashPath	= [defaults objectForKey:@"audioFlashPath"];	// override must specify path/URL on server
	if (audioFlashPath)
	{
		playerPath = audioFlashPath;		// specified by defaults
	}
	else
	{
		NSString *localPlayerPath = [[NSBundle mainBundle] pathForResource:@"player_mp3_maxi" ofType:@"swf"];
		NSURL *playerURL = [context addResourceAtURL:[NSURL fileURLWithPath:localPlayerPath] destination:SVDestinationResourcesDirectory options:0];
		playerPath = [context relativeStringFromURL:playerURL];
	}
	
	if ([[self container] shouldWriteHTMLInline]) [self.container buildClassName:context];
	[context pushAttribute:@"type" value:@"application/x-shockwave-flash"];
	[context pushAttribute:@"data" value:playerPath];
	[context pushAttribute:@"width" value:self.width];
	
	NSUInteger heightWithBar = barHeight;
	[context pushAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	
	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"object" preferredIdName:audioFlashPlayer className:nil attributes:nil];	// class, attributes already pushed
	
	[context writeParamElementWithName:@"movie" value:playerPath];
	[context writeParamElementWithName:@"flashvars" value:flashVars];
	
	NSDictionary *audioFlashExtraParams = [defaults objectForKey:@"audioFlashExtraParams"];
	if ([audioFlashExtraParams respondsToSelector:@selector(keyEnumerator)])	// sanity check
	{
		for (NSString *key in audioFlashExtraParams)
		{
			[context writeParamElementWithName:key value:[audioFlashExtraParams objectForKey:key]];
		}
	}
	return elementID;
}


- (NSString *)startUnknown:(SVHTMLContext *)context;
{
	// Get a title to indicate that the movie cannot play inline.  (Suggest downloading, if we provide a link)
	KTPage *thePage = [context page];
	NSString *language = [thePage language];
	
	NSString *cannotPlayTitle
	= [[NSBundle mainBundle] localizedStringForString:@"cannotPlayTitleText"
											 language:language
											 fallback:
	   NSLocalizedStringWithDefaultValue(@"cannotPlayTitleText",
										 nil,
										 [NSBundle mainBundle],
										 @"This browser cannot play the embedded audio file.", @"Warning to show when an audio cannot be played")];
	
	[context buildAttributesForElement:@"div" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSZeroSize];
	 NSString *elementID = [context startElement:@"div" preferredIdName:@"unrecognized" className:nil attributes:nil];	// class, attributes already pushed
	[context writeElement:@"p" text:cannotPlayTitle];
	// don't end the div....

	return elementID;
}

- (void)writeHTML:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMedia *media = [self media];
	//[context addDependencyOnObject:self keyPath:@"media"];    // don't need, graphic does for us
	[context addDependencyOnObject:self keyPath:@"controller"];		// most boolean properties don't affect display of page
	
	NSURL *audioSourceURL = [self externalSourceURL];
    if (media)
    {
	    audioSourceURL = [context addMedia:media];
	}
	
	
	// Determine tag(s) to use
	// audio || flash (not mutually exclusive) are mutually exclusive with microsoft, quicktime
	// WAV: audio -> microsoft
	// MP3: audio -> flash
	// OGG: audio
	// mov: quicktime
	// MP4: audio
	// AIFF: audio
	
	/*
	 Audio (kUTTypeAudio) UTIs:
	 
	 kUTTypeMP3
	 kUTTypeMPEG4Audio but not kUTTypeAppleProtected\0x200BMPEG4Audio
	 public.ogg-vorbis
	 public.aiff-audio
	 com.microsoft.waveform-audio  (.wav)
	 */
	
	NSString *type = [self codecType];
	BOOL audioTag =
	   [type conformsToUTI:(NSString *)kUTTypeMP3]
//	|| [type conformsToUTI:@"public.ogg-vorbis"]		// DO NOT TRY TO SHOW OGG -- WON'T SHOW IN WEBKIT.
	|| [type conformsToUTI:@"com.microsoft.waveform-audio"]
	|| [type conformsToUTI:(NSString *)kUTTypeMPEG4Audio]
	|| [type conformsToUTI:@"public.aiff-audio"]
	|| [type conformsToUTI:@"public.aifc-audio"]
	|| [type conformsToUTI:@"public.au-audio"]
	;
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"avoidAudioTag"]) audioTag = NO;
	
	BOOL flashTag = [type conformsToUTI:(NSString *)kUTTypeMP3];
	if ([defaults boolForKey:@"avoidFlashAudio"]) flashTag = NO;
	
	BOOL microsoftTag = [type conformsToUTI:@"com.microsoft.waveform-audio"];
	
	// quicktime fallback, but not for mp4.  We may want to be more selective of mpeg-4 types though.
	// Also show quicktime when there is no media at all
	BOOL quicktimeTag =  [type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie]
	|| [type conformsToUTI:@"com.apple.quicktime-audio"];		// latter is our made-up tag for recognizing .mov without video track
	
	// BOOL unknownTag = !(audioTag || flashTag || microsoftTag || quicktimeTag);
	
	// WHEN EDITING, AND NO CONTROLLER, PUT IN SOMETHING VISIBLE SO WE CAN SELECT THE GRAPHIC.
	if (!self.controller && [context isForEditing])
	{
		[context pushAttribute:@"style"
						 value:[NSString stringWithFormat:
							 @"padding:1px 1px 1px 6px; color:#888; text-overflow:ellipsis; overflow:hidden; white-space:nowrap; width:%dpx;",
								self.width]];
		[context startElement:@"div"];
			
		[context pushAttribute:@"width" value:[NSNumber numberWithInt:16]];
		[context pushAttribute:@"height" value:[[NSNumber numberWithInteger:16] stringValue]];
		[context pushAttribute:@"src" value:[[NSURL fileURLWithPath:[[NSBundle mainBundle] pathForImageResource:@"sound_placeholder"]] absoluteString]];
		[context pushAttribute:@"style" value:@"vertical-align:text-bottom; padding-right:4px;"];
		[context startElement:@"img"];
		[context endElement];

		[context writeCharacters:[[audioSourceURL path] lastPathComponent]];
		[context endElement];
	}
	
	// START THE TAGS
	
	NSString *audioID = nil;
	if (audioTag)	// start the audio tag
	{
		[SVVideo writeFallbackScriptOnce:context];
		audioID = [self startAudio:context audioSourceURL:audioSourceURL]; 
	}
	if (quicktimeTag)
	{
		[self startQuickTimeObject:context audioSourceURL:audioSourceURL];
	}
	if (microsoftTag)
	{
		[self startMicrosoftObject:context audioSourceURL:audioSourceURL]; 
	}
	if (flashTag)
	{
		[self startFlash:context audioSourceURL:audioSourceURL]; 
	}

	// I would like to put a warning inside the object tags, but this seems to overpower the controller, at least on webkit.  So don't.
	// So only do this if it's truly playable.
	//if (unknownTag)
	{
		[self startUnknown:context];
	}
	
	// END THE TAGS, in reverse order

	//if (unknownTag)
	{
		OBASSERT([@"div" isEqualToString:[context topElement]]);
		[context endElement];
	}
	if (flashTag)
	{
		OBASSERT([@"object" isEqualToString:[context topElement]]);
		[context endElement];	//  </object>
	}
	if (microsoftTag)
	{
		OBASSERT([@"object" isEqualToString:[context topElement]]);
		[context endElement];	//  </object>
	}
	if (quicktimeTag)
	{
		OBASSERT([@"object" isEqualToString:[context topElement]]);
		[context endElement];	//  </object>
	}
	if (audioTag)
	{
		OBASSERT([@"audio" isEqualToString:[context topElement]]);
		[context endElement];
		
		[self writePostAudioScript:context referringToID:audioID];
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

	if (!type || (!self.media && !self.externalSourceURL))								// no data?
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type isEqualToString:@"unloadable-audio"])	
	{
		// Special type ... A movie type that might be valid on some systems but can't be shown on this mac
		// (e.g. it might load if we had Perian, Flip4Mac, XiphQT ... but we don't.
		result = [NSImage imageFromOSType:kAlertStopIcon];
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeAppleProtectedMPEG4Audio])
	{
		result = [NSImage imageFromOSType:kAlertStopIcon];
	}
	else if ([type conformsToUTI:@"com.microsoft.waveform-audio"])		// I *think* WAV is ok for <audio>, iOS, and Windows controller (windows & Quicktime)
	{
		result =[NSImage imageNamed:@"checkmark"];
	}
	else if ([type conformsToUTI:@"public.mp3.ios"])		// HAPPY!  everything-compatible  (This is only if there is a way to know for sure it's iOS compatible!
	{
		result =[NSImage imageNamed:@"checkmark"];
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeMP3])			// might not be iOS compatible
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie]
			 || [type conformsToUTI:@"public.aiff-audio"]
			 || [type conformsToUTI:@"public.aifc-audio"]
			 || [type conformsToUTI:@"public.au-audio"]
			 || [type conformsToUTI:@"com.apple.quicktime-audio"]
			 || [type conformsToUTI:(NSString *)kUTTypeMPEG4Audio])
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}
	else
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
		result = NSLocalizedString(@"Use .mp3 or .wav file for maximum compatibility.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type isEqualToString:@"unloadable-audio"])	
	{
		// Special type ... A movie type that might be valid on some systems but can't be shown on this mac
		// (e.g. it might load if we had Perian, Flip4Mac, XiphQT ... but we don't.
		result = NSLocalizedString(@"Audio cannot be loaded on this computer.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeAppleProtectedMPEG4Audio])
	{
		result = NSLocalizedString(@"Audio is protected and cannot play on other systems.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"com.microsoft.waveform-audio"])		// I *think* WAV is ok for <audio>, iOS, and Windows controller (windows & Quicktime)
	{
		result = NSLocalizedString(@"Audio is compatible with a wide range of devices.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.mp3.ios"])		// HAPPY!  everything-compatible  (This is only there is we know for sure it's iOS compatible!
	{
		result = NSLocalizedString(@"Audio is compatible with a wide range of devices.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeMP3])			// might not be iOS compatible
	{
		result = NSLocalizedString(@"You should verify that audio will play on iOS devices.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie]
			 || [type conformsToUTI:@"public.aiff-audio"]
			 || [type conformsToUTI:@"public.aifc-audio"]
			 || [type conformsToUTI:@"public.au-audio"]
			 || [type conformsToUTI:@"com.apple.quicktime-audio"]
			 || [type conformsToUTI:(NSString *)kUTTypeMPEG4Audio])
	{
		result = NSLocalizedString(@"Audio cannot be played in many browsers", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else		// Other kinds of audio files, or maybe not even an audio file, we don't handle them.
	{
		result = NSLocalizedString(@"Audio cannot be played in most browsers.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	result = [result stringByAppendingString:@" "];	// space between message and the hyperlinked "More"
	NSMutableDictionary *attribs = [[NSMutableDictionary alloc] initWithObjectsAndKeys:
									[NSFont systemFontOfSize:[NSFont smallSystemFontSize]], NSFontAttributeName,
									nil];
	NSMutableAttributedString *info = [[[NSMutableAttributedString alloc] initWithString:result attributes:attribs] autorelease];
	NSDictionary *linkAttribs
	= [NSDictionary dictionaryWithObjectsAndKeys:
	   [NSURL URLWithString:[NSString stringWithFormat:@"http://docs.karelia.com/z/Supported_Audio_Formats.html?type=%@", type]],
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

+ (NSString *) elementClassName; { return @"AudioElement"; }
+ (NSString *) contentClassName; { return @"audio"; }




@end
