// 
//  SVVideo.m
//  Sandvox
//
//  Created by Mike on 05/04/2010.
//  Copyright 2010 Karelia Software. All rights reserved.
//

/*
 
 kUTTypeQuickTimeMovie,
 public.avi
 kUTTypeMPEG, 
 public.mpeg-4,
 com.microsoft.windows-​media-wmv
 
 com.adobe.flash-video
 public.ogg-theora
 public.webm
 
 
 
 Audio UTIs:
 kUTTypeMP3
 kUTTypeMPEG4Audio
 public.ogg-vorbis
  ... check that it's not kUTTypeAppleProtected​MPEG4Audio
 public.aiff-audio
 com.microsoft.waveform-​audio  (.wav)
 
 */
 
 

#import "SVVideo.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "SVVideoInspector.h"
#import <QTKit/QTKit.h>
#include <zlib.h>


@implementation SVVideo 

+ (SVVideo *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVVideo *result = [NSEntityDescription insertNewObjectForEntityForName:@"Movie"
                                                    inManagedObjectContext:context];
    return result;
}

@dynamic posterFrame;

- (void)writeBody:(SVHTMLContext *)context;
{
    // Image needs unique ID for DOM Controller to find
    NSString *idName = [@"video-" stringByAppendingString:[self elementID]];
    
    
    // Actually write the image
    [context pushElementAttribute:@"id" value:idName];
    if ([self displayInline]) [self buildClassName:context];
    
    SVMediaRecord *media = [self media];
	NSURL *URL = [self externalSourceURL];
    if (media)
    {
	    URL = [context addMedia:media width:[self width] height:[self height] type:[self typeToPublish]];
	}
	
	NSString *src = @"";
	if (URL)
	{
		src = [context relativeURLStringOfURL:URL];
	}
	 
	[context pushElementAttribute:@"src" value:src];
	[context pushElementAttribute:@"width" value:[[self width] description]];
	[context pushElementAttribute:@"height" value:[[self height] description]];
	[context startElement:@"video"];
	[context endElement];
    
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

@dynamic typeToPublish;


#pragma mark Thumbnail

- (id <IMBImageItem>)thumbnail { return [self posterFrame]; }
+ (NSSet *)keyPathsForValuesAffectingThumbnail { return [NSSet setWithObject:@"posterFrame"]; }



// OLD



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
