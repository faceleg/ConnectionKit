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
}


/*
 Audio UTIs:
 
 kUTTypeAudio
 
 kUTTypeMP3
 kUTTypeMPEG4Audio
 public.ogg-vorbis
 ... check that it's not kUTTypeAppleProtected​MPEG4Audio
 public.aiff-audio
 com.microsoft.waveform-​audio  (.wav)
 
 */



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


- (void)startVideo:(SVHTMLContext *)context
	movieSourceURL:(NSURL *)movieSourceURL;
{
	NSString *movieSourcePath  = movieSourceURL ? [context relativeURLStringOfURL:movieSourceURL] : @"";
	
	// Actually write the video
	NSString *idName = [self idNameForTag:@"video"];
	[context pushElementAttribute:@"id" value:idName];
	if ([self displayInline]) [self buildClassName:context];
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[self height] description]];
	
	if (self.controller.boolValue)	[context pushElementAttribute:@"controls" value:@"controls"];		// boolean attribute
	if (self.autoplay.boolValue)	[context pushElementAttribute:@"autoplay" value:@"autoplay"];
	[context pushElementAttribute:@"preload" value:self.preload.boolValue ? @"auto" : @"none" ];
	if (self.loop.boolValue)		[context pushElementAttribute:@"loop" value:@"loop"];
	
	[context startElement:@"video"];
	
	// Remove poster on iOS < 4; prevents video from working
	[context startJavascriptElementWithSrc:nil];
	[context stopWritingInline];
	[context writeString:@"// Remove poster from buggy iOS before 4\n"];
	[context writeString:@"if (navigator.userAgent.match(/CPU( iPhone)*( OS )*([123][_0-9]*)? like Mac OS X/)) {\n"];
	[context writeString:[NSString stringWithFormat:@"\t$('#%@').removeAttr('poster');\n", idName]];
	[context writeString:@"}\n"];
	[context endElement];	
	
	
	// source
	[context pushElementAttribute:@"src" value:movieSourcePath];
	[context pushElementAttribute:@"type" value:[NSString MIMETypeForUTI:[self codecType]]];
	[context pushElementAttribute:@"onerror" value:@"fallback(this.parentNode)"];
	[context startElement:@"source"];
	[context endElement];
}

- (void)writePostVideoScript:(SVHTMLContext *)context
{
	// Now write the post-video-tag surgery since onerror doesn't really work
	// This is hackish browser-sniffing!  Maybe later we can do away with this (especially if we can get > 1 video source)
	
	[context startJavascriptElementWithSrc:nil];
	[context stopWritingInline];
	[context writeString:[NSString stringWithFormat:@"var video = document.getElementById('%@');\n", [self idNameForTag:@"video"]]];
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


- (void)startFlash:(SVHTMLContext *)context
	movieSourceURL:(NSURL *)movieSourceURL;
{
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	BOOL videoFlashRequiresFullURL = [defaults boolForKey:@"videoFlashRequiresFullURL"];	// usually not, but YES for flowplayer
	NSString *movieSourcePath = @"";
	if (videoFlashRequiresFullURL)
	{
		if (movieSourceURL)  movieSourcePath  = [movieSourceURL  absoluteString];
	}
	else
	{
		if (movieSourceURL)  movieSourcePath  = [context relativeURLStringOfURL:movieSourceURL];
	}
	
	NSString *videoFlashPlayer	= [defaults objectForKey:@"videoFlashPlayer"];	// to override player type
	// Known types: f4player jwplayer flvplayer osflv flowplayer.  Otherwise must specify videoFlashFormat.
	if (!videoFlashPlayer) videoFlashPlayer = @"flvplayer";
	NSString *videoFlashPath	= [defaults objectForKey:@"videoFlashPath"];	// override must specify path/URL on server
	NSString *videoFlashExtras	= [defaults objectForKey:@"videoFlashExtras"];	// extra parameters to override for any player
	NSString *videoFlashFormat	= [defaults objectForKey:@"videoFlashFormat"];	// format pattern with %{value1}@ and %{value2}@ for movie, poster
	NSString *videoFlashBarHeight= [defaults objectForKey:@"videoFlashBarHeight"];	// height that the navigation bar adds
	
	if ([videoFlashPlayer isEqualToString:@"flowplayer"]) videoFlashRequiresFullURL = YES;
	
	NSDictionary *noPosterParamLookup
	= NSDICT(
			 @"video=%@",                                  @"f4player",	
			 @"file=%@",                                   @"jwplayer",	
			 @"flv=%@&margin=0",                           @"flvplayer",	
			 @"movie=%@",                                  @"osflv",		
			 @"config={\"playlist\":[{\"url\":\"%@\"}]}",  @"flowplayer");
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
		flashVarFormatString = [noPosterParamLookup objectForKey:videoFlashPlayer];
	}
	
	// Now instantiate the string from the format
	NSMutableString *flashVars = [NSMutableString stringWithFormat:flashVarFormatString, movieSourcePath];
	
	
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
	
	NSDictionary *videoFlashExtraParams = [defaults objectForKey:@"videoFlashExtraParams"];
	if ([videoFlashExtraParams respondsToSelector:@selector(keyEnumerator)])	// sanity check
	{
		for (NSString *key in videoFlashExtraParams)
		{
			[context writeParamElementWithName:key value:[videoFlashExtraParams objectForKey:key]];
		}
	}
}


-(void)startUnknown:(SVHTMLContext *)context;
{
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[self height] description]];
	[context startElement:@"div"];
	[context writeElement:@"p" text:NSLocalizedString(@"Unable to embed audio. Perhaps it is not a recognized audio format.", @"Warning shown to user when audio can't be embedded")];
	// Poster may be shown next, so don't end....
}

- (void)writeBody:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMediaRecord *media = [self media];
	[context addDependencyOnObject:self keyPath:@"media"];
	[context addDependencyOnObject:self keyPath:@"controller"];		// most boolean properties don't affect display of page
	
	NSURL *movieSourceURL = [self externalSourceURL];
    if (media)
    {
	    movieSourceURL = [context addMedia:media width:[self width] height:[self height] type:[self codecType]];
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
	
	BOOL unknownTag = NO;	// will be set below if 
	
	// START THE TAGS
	
	if (quicktimeTag)
	{
		// ??? [self startQuickTimeObject:context movieSourceURL:movieSourceURL];
	}
	else if (microsoftTag)
	{
		// [self startMicrosoftObject:context movieSourceURL:movieSourceURL]; 
	}
	else if (videoTag || flashTag)
	{
		if (videoTag)	// start the video tag
		{
			[self writeFallbackScriptOnce:context];
			
			[self startVideo:context movieSourceURL:movieSourceURL]; 
		}
		
		if (flashTag)	// inner
		{
			[self startFlash:context movieSourceURL:movieSourceURL]; 
			
		}
	}
	else	// completely unknown video type
	{
		[self startUnknown:context];
		unknownTag = YES;
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
		
		[self writePostVideoScript:context];
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
	
	if (!type || ![self media])								// no movie -- informational
	{
		result = [NSImage imageFromOSType:kAlertNoteIcon];
	}
	else if (![type conformsToUTI:(NSString *)kUTTypeMovie])// BAD
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
	
	if (!type || ![self media])								// no movie
	{
		result = NSLocalizedString(@"Use MP3 file for maximum compatibility.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if (![type conformsToUTI:(NSString *)kUTTypeMovie])// BAD
	{
		result = NSLocalizedString(@"Audio cannot be played in most browsers.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result = NSLocalizedString(@"Video is compatible with a wide range of devices.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.mpeg-4"])			// might not be iOS compatible
	{
		result = NSLocalizedString(@"You will need to verify if this video will play on iOS devices.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"])
	{
		result = NSLocalizedString(@"Video will only play on certain browsers.", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"com.adobe.flash.video"])
	{
		result = NSLocalizedString(@"Video will not play on iOS devices", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"])
	{
		result = NSLocalizedString(@"Video will not play on Macs unless \\U201CFlip4Mac\\U201D is installed", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
	{
		result = NSLocalizedString(@"Video will not play on Windows PCs unless QuickTime is installed", @"status of file chosen for audio. Should fit in 3 lines in inspector.");
	}
	return result;
}





@end
