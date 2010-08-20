//
//  SVAudio.m
//  Sandvox
//
//  Created by Dan Wood on 8/6/10.
//  Copyright 2010 Karelia Software. All rights reserved.
//

#import "SVAudio.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "SVMediaGraphicInspector.h"

#import "SVHTMLContext.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import "QTMovie+Karelia.h"
#import "NSImage+Karelia.h"

@interface SVAudio ()
- (void)loadAudio;		// after it has changed (URL or media), determine codecType; later we may kick off load to test properties
@end

@implementation SVAudio

@dynamic autoplay;
@dynamic controller;
@dynamic preload;
@dynamic loop;
@dynamic codecType;	// determined from file's UTI, or by further analysis

#pragma mark -
#pragma mark Lifetime

+ (SVAudio *)insertNewAudioInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVAudio *result = [NSEntityDescription insertNewObjectForEntityForName:@"Audio"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)willInsertIntoPage:(KTPage *)page;
{
	[self addObserver:self forKeyPath:@"autoplay"			options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"controller"			options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"externalSourceURL"	options:(NSKeyValueObservingOptionNew) context:nil];
	[self addObserver:self forKeyPath:@"media"				options:(NSKeyValueObservingOptionNew) context:nil];
    [super willInsertIntoPage:page];
    
    // Show caption
    if ([[[self textAttachment] placement] intValue] != SVGraphicPlacementInline)
    {
        [self setShowsCaption:YES];
    }
}


- (void)dealloc
{
	[self removeObserver:self forKeyPath:@"autoplay"];
	[self removeObserver:self forKeyPath:@"controller"];
	[self removeObserver:self forKeyPath:@"externalSourceURL"];
	[self removeObserver:self forKeyPath:@"media"];
	[super dealloc];
}

#pragma mark -
#pragma mark General

- (BOOL)canMakeOriginalSize; { return NO; }		// Audio is media, but it doesn't have an original/natural size.

- (NSArray *) allowedFileTypes
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

- (void)setMediaWithURL:(NSURL *)URL;
{
 	OBPRECONDITION(URL);
	[super setMediaWithURL:URL];
        
    // Match file type
    [self setCodecType:[[self media] typeOfFile]];
}

#pragma mark -
#pragma mark KVO

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
	else if ([keyPath isEqualToString:@"media"] || [keyPath isEqualToString:@"externalSourceURL"])
	{		
		// Load the movie to figure out the codecType
		[self loadAudio];
	}
}

- (void)loadAudio;		// after it has changed (URL or media), determine codecType; later we may kick off load to test properties
{
	NSURL *movieSourceURL = nil;
//	BOOL openAsync = NO;
	
	SVMediaRecord *media = [self media];
	
    if (media)
    {
		movieSourceURL = [[media URLResponse] URL];
//		openAsync = YES;
		self.codecType = [NSString UTIForFileAtPath:[movieSourceURL path]];
	}
	else
	{
		movieSourceURL = [self externalSourceURL];
		self.codecType = [NSString UTIForFilenameExtension:[[movieSourceURL path] pathExtension]];
	}
//	if (movieSourceURL)
//	{
//		NSDictionary *movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
//						   movieSourceURL, QTMovieURLAttribute,
//						   [NSNumber numberWithBool:openAsync], QTMovieOpenAsyncOKAttribute,
//						   // 10.6 only :-( [NSNumber numberWithBool:YES], QTMovieOpenForPlaybackAttribute,	// From Tim Monroe @ WWDC2010, so we can check how movie was loaded
//						   nil];
//		[self loadMovieFromAttributes:movieAttributes];
//		
//	}
}




#pragma mark -
#pragma mark Writing Tag

// EXACTLY THE SAME IN AUDIO AND VIDEO. CONSIDER REFACTORING.
- (NSString *)idNameForTag:(NSString *)tagName
{
	return [NSString stringWithFormat:@"%@-%@", tagName, [self elementID]];
}

// EXACTLY THE SAME IN AUDIO AND VIDEO. CONSIDER REFACTORING.
- (void)writeFallbackScriptOnce:(SVHTMLContext *)context;
{
	// Write the fallback method.  COULD WRITE THIS IN JQUERY TO BE MORE TERSE?
	
	NSString *oneTimeScript = @"<script type='text/javascript'>\nfunction fallback(av) {\n while (av.firstChild) {\n  if (av.firstChild.nodeName == 'SOURCE') {\n   av.removeChild(av.firstChild);\n  } else {\n   av.parentNode.insertBefore(av.firstChild, av);\n  }\n }\n av.parentNode.removeChild(av);\n}\n</script>\n";
	
	NSRange whereOneTimeScript = [[context extraHeaderMarkup] rangeOfString:oneTimeScript];
	if (NSNotFound == whereOneTimeScript.location)
	{
		[[context extraHeaderMarkup] appendString:oneTimeScript];
	}
}

- (void)startQuickTimeObject:(SVHTMLContext *)context
			  audioSourceURL:(NSURL *)audioSourceURL;
{
	NSString *audioSourcePath  = audioSourceURL ? [context relativeURLStringOfURL:audioSourceURL] : @"";
	
	NSUInteger heightWithBar = self.controller.boolValue ? 16 : 0;
	
	[context pushElementAttribute:@"id" value:[self idNameForTag:@"object"]];	// ID on <object> apparently required for IE8
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	[context pushElementAttribute:@"classid" value:@"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"];	// Proper value?
	[context pushElementAttribute:@"codebase" value:@"http://www.apple.com/qtactivex/qtplugin.cab"];
	[context startElement:@"object"];
	
	[context writeParamElementWithName:@"src" value:audioSourcePath];
	
	[context writeParamElementWithName:@"autoplay" value:self.autoplay.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"controller" value:self.controller.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"loop" value:self.loop.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"scale" value:@"tofit"];
	[context writeParamElementWithName:@"type" value:@"audio/quicktime"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://www.apple.com/quicktime/download/"];	
}

- (void)startMicrosoftObject:(SVHTMLContext *)context
			  audioSourceURL:(NSURL *)audioSourceURL;
{
	NSString *audioSourcePath = audioSourceURL ? [context relativeURLStringOfURL:audioSourceURL] : @"";
	
	NSUInteger heightWithBar = self.controller.boolValue ? 46 : 0;		// Windows media controller is 46 pixels (on windows; adjusted on macs)
	
	[context pushElementAttribute:@"id" value:[self idNameForTag:@"object"]];	// ID on <object> apparently required for IE8
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	[context pushElementAttribute:@"classid" value:@"CLSID:6BF52A52-394A-11D3-B153-00C04F79FAA6"];
	[context startElement:@"object"];
	
	[context writeParamElementWithName:@"url" value:audioSourcePath];
	[context writeParamElementWithName:@"autostart" value:self.autoplay.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"showcontrols" value:self.controller.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"playcount" value:self.loop.boolValue ? @"9999" : @"1"];
	[context writeParamElementWithName:@"type" value:@"application/x-oleobject"];
	[context writeParamElementWithName:@"uiMode" value:@"mini"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://microsoft.com/windows/mediaplayer/en/download/"];
}

- (void)startAudio:(SVHTMLContext *)context
	audioSourceURL:(NSURL *)audioSourceURL;
{
	NSString *audioSourcePath  = audioSourceURL ? [context relativeURLStringOfURL:audioSourceURL] : @"";
	
	// Actually write the audio
	NSString *idName = [self idNameForTag:@"audio"];
	[context pushElementAttribute:@"id" value:idName];
	if ([self displayInline]) [self buildClassName:context];
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[self height] description]];
	
	if (self.controller.boolValue)	[context pushElementAttribute:@"controls" value:@"controls"];		// boolean attribute
	if (self.autoplay.boolValue)	[context pushElementAttribute:@"autoplay" value:@"autoplay"];
	[context pushElementAttribute:@"preload" value:self.preload.boolValue ? @"auto" : @"none" ];
	if (self.loop.boolValue)		[context pushElementAttribute:@"loop" value:@"loop"];
	
	[context startElement:@"audio"];
	
	
	// source
	[context pushElementAttribute:@"src" value:audioSourcePath];
	if ([self codecType])
	{
		[context pushElementAttribute:@"type" value:[NSString MIMETypeForUTI:[self codecType]]];
	}
	[context pushElementAttribute:@"onerror" value:@"fallback(this.parentNode)"];
	[context startElement:@"source"];
	[context endElement];
}

- (void)writePostAudioScript:(SVHTMLContext *)context
{
	// Now write the post-audio-tag surgery since onerror doesn't really work
	// This is hackish browser-sniffing!  Maybe later we can do away with this (especially if we can get > 1 audio source)
	
	[context startJavascriptElementWithSrc:nil];
	[context stopWritingInline];
	[context writeString:[NSString stringWithFormat:@"var audio = document.getElementById('%@');\n", [self idNameForTag:@"audio"]]];
	[context writeString:[NSString stringWithFormat:@"if (audio.canPlayType && audio.canPlayType('%@')) {\n",
						  [NSString MIMETypeForUTI:[self codecType]]]];
	[context writeString:@"\t// canPlayType is overoptimistic, so we have browser sniff.\n"];
	
	// we have mp4, so no ogv/webm, so force a fallback if NOT webkit-based.
	if ([[self codecType] conformsToUTI:@"public.mpeg-4"]
		|| [[self codecType] conformsToUTI:@"public.aiff-audio"]
		|| [[self codecType] conformsToUTI:@"public.aiff-audio"]
		)
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf('WebKit/') <= -1) {\n\t\t// Only webkit-browsers can currently play this natively\n\t\tfallback(audio);\n\t}\n"];
	}
	else	// we have an ogv or webm (or something else?) so fallback if it's Safari, which won't handle it
	{
		[context writeString:@"\tif (navigator.userAgent.indexOf(' Safari/') > -1) {\n\t\t// Safari can't play this natively\n\t\tfallback(audio);\n\t}\n"];
	}
	[context writeString:@"} else {\n\tfallback(audio);\n}\n"];
	[context endElement];	
}

- (void)startFlash:(SVHTMLContext *)context
	audioSourceURL:(NSURL *)audioSourceURL;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL audioFlashRequiresFullURL = [defaults boolForKey:@"audioFlashRequiresFullURL"];	// usually not, but YES for flowplayer
	NSString *audioSourcePath = @"";
	if (audioFlashRequiresFullURL)
	{
		if (audioSourceURL)  audioSourcePath  = [audioSourceURL  absoluteString];
	}
	else
	{
		if (audioSourceURL)  audioSourcePath  = [context relativeURLStringOfURL:audioSourceURL];
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
				 @"mp3=%@",                         @"flashmp3player",	
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
		if (self.autoplay.boolValue)	[flashVars appendString:@"&autoplay=1"];
		if (self.preload.boolValue)		[flashVars appendString:@"&autoload=1"];
		if (self.loop.boolValue)		[flashVars appendString:@"&loop=1"];
	}
	else if ([audioFlashPlayer isEqualToString:@"dewplayer"])
	{
		// Can't find way to hide the player; controller must always be showing
		if (self.autoplay.boolValue)	[flashVars appendString:@"&autostart=1"];
		// Can't find a way to preload the audio
		if (self.loop.boolValue)		[flashVars appendString:@"&autoreplay=1"];
	}
	else if ([audioFlashPlayer isEqualToString:@"wpaudioplayer"])
	{
		// Can't find way to hide the player; controller must always be showing
		if (self.autoplay.boolValue)	[flashVars appendString:@"&autostart=1"];
		// Can't find a way to preload the audio
		if (self.loop.boolValue)		[flashVars appendString:@"&loop=1"];
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
		NSString *localPlayerPath = [[NSBundle mainBundle] pathForResource:@"player_flv_maxi" ofType:@"swf"];
		NSURL *playerURL = [context addResourceWithURL:[NSURL fileURLWithPath:localPlayerPath]];
		playerPath = [context relativeURLStringOfURL:playerURL];
	}
	
	[context pushElementAttribute:@"id" value:[self idNameForTag:@"object"]];	// ID on <object> apparently required for IE8
	if ([self displayInline]) [self buildClassName:context];
	[context pushElementAttribute:@"type" value:@"application/x-shockwave-flash"];
	[context pushElementAttribute:@"data" value:playerPath];
	[context pushElementAttribute:@"width" value:[[self width] description]];
	
	NSUInteger heightWithBar = barHeight + [[self height] intValue];
	[context pushElementAttribute:@"height" value:[[NSNumber numberWithInteger:heightWithBar] stringValue]];
	[context startElement:@"object"];
	
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
}


-(void)startUnknown:(SVHTMLContext *)context;
{
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[self height] description]];
	[context startElement:@"div"];
	[context writeElement:@"p" text:NSLocalizedString(@"Unable to embed audio. Perhaps it is not a recognized audio format.", @"Warning shown to user when audio can't be embedded")];
	// don't end....
}

- (void)writeBody:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMediaRecord *media = [self media];
	[context addDependencyOnObject:self keyPath:@"media"];
	[context addDependencyOnObject:self keyPath:@"controller"];		// most boolean properties don't affect display of page
	
	NSURL *audioSourceURL = [self externalSourceURL];
    if (media)
    {
	    audioSourceURL = [context addMedia:media width:[self width] height:[self height] type:[self codecType]];
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
	 kUTTypeMPEG4Audio but not kUTTypeAppleProtected​MPEG4Audio
	 public.ogg-vorbis
	 public.aiff-audio
	 com.microsoft.waveform-audio  (.wav)
	 */
	
	NSString *type = [self codecType];
	BOOL audioTag = !media
	|| [type conformsToUTI:(NSString *)kUTTypeMP3]
	|| [type conformsToUTI:@"public.ogg-vorbis"]
	|| [type conformsToUTI:@"com.microsoft.waveform-audio"]
	|| [type conformsToUTI:(NSString *)kUTTypeMPEG4Audio]
	|| [type conformsToUTI:@"public.aiff-audio"]
	|| [type conformsToUTI:@"public.aifc-audio"]
	;
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults boolForKey:@"avoidAudioTag"]) audioTag = NO;
	
	BOOL flashTag = [type conformsToUTI:(NSString *)kUTTypeMP3];
	if ([defaults boolForKey:@"avoidFlashAudio"]) flashTag = NO;
	
	BOOL microsoftTag = [type conformsToUTI:@"com.microsoft.waveform-audio"];
	
	// quicktime fallback, but not for mp4.  We may want to be more selective of mpeg-4 types though.
	// Also show quicktime when there is no media at all
	BOOL quicktimeTag =  [type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie];
	
	BOOL unknownTag = !(audioTag || flashTag || microsoftTag || quicktimeTag);
	
	// START THE TAGS
	
	if (audioTag)	// start the audio tag
	{
		[self writeFallbackScriptOnce:context];
		[self startAudio:context audioSourceURL:audioSourceURL]; 
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
	if (unknownTag)
	{
		[self startUnknown:context];
		unknownTag = YES;
	}
	
	// END THE TAGS, in reverse order

	if (unknownTag)
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
		
		[self writePostAudioScript:context];
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
	else if ([type conformsToUTI:(NSString *)kUTTypeAppleProtectedMPEG4Audio])
	{
		result = [NSImage imageFromOSType:kAlertStopIcon];
	}
	else if ([type conformsToUTI:@"com.microsoft.waveform-audio"])		// I *think* WAV is ok for <audio>, iOS, and Windows controller (windows & Quicktime)
	{
		result =[NSImage imageNamed:@"checkmark"];
	}
	else if ([type conformsToUTI:@"public.mp3.ios"])		// HAPPY!  everything-compatible  (This is only there is we know for sure it's iOS compatible!
	{
		result =[NSImage imageNamed:@"checkmark"];
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeMP3])			// might not be iOS compatible
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if ([type conformsToUTI:@"public.ogg-vorbis"])
	{
		result = [NSImage imageNamed:@"caution"];			// like 10.6 NSCaution but better for small sizes
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie]
			 || [type conformsToUTI:@"public.aiff-audio"]
			 || [type conformsToUTI:@"public.aifc-audio"]
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


- (NSString *)info
{
	NSString *result = @"";
	NSString *type = self.codecType;
	
	if (!type || ![self media])								// no movie
	{
		result = NSLocalizedString(@"Use .mp3 or .wav file for maximum compatibility.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
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
	else if ([type conformsToUTI:@"public.ogg-vorbis"])
	{
		result = NSLocalizedString(@"Audio will only play on certain browsers.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie]
			 || [type conformsToUTI:@"public.aiff-audio"]
			 || [type conformsToUTI:@"public.aifc-audio"]
			 || [type conformsToUTI:(NSString *)kUTTypeMPEG4Audio])
	{
		result = NSLocalizedString(@"Audio will not play on Windows PCs unless QuickTime is installed", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else		// Other kinds of audio files, or maybe not even an audio file, we don't handle them.
	{
		result = NSLocalizedString(@"Audio cannot be played in most browsers.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	return result;
}





@end
