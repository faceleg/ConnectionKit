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

@implementation SVVideo 

+ (SVVideo *)insertNewMovieInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVVideo *result = [NSEntityDescription insertNewObjectForEntityForName:@"Movie"
                                                    inManagedObjectContext:context];
    return result;
}

- (void)willInsertIntoPage:(KTPage *)page;
{
    // Placeholder image
    if (![self media])
    {
        SVMediaRecord *media = // [[[page rootPage] master] makePlaceholdImageMediaWithEntityName:];
		[SVMediaRecord placeholderMediaWithURL:[NSURL fileURLWithPath:@"/System/Library/Compositions/Sunset.mov"]
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
@dynamic kioskmode;
@dynamic loop;

- (void)writeBody:(SVHTMLContext *)context;
{
	NSString *type = [self codecType];
    // Image needs unique ID for DOM Controller to find
    NSString *idName = [@"video-" stringByAppendingString:[self elementID]];
    
    
    // Actually write the image
    [context pushElementAttribute:@"id" value:idName];
    if ([self displayInline]) [self buildClassName:context];
    
    SVMediaRecord *media = [self media];
	NSURL *URL = [self externalSourceURL];
    if (media)
    {
	    URL = [context addMedia:media width:[self width] height:[self height] type:[self codecType]];
	}
	
	NSString *src = @"";
	if (URL)
	{
		src = [context relativeURLStringOfURL:URL];
	}
	
	// video || flash (not mutually exclusive) are mutually exclusive with microsoft, quicktime
	
	BOOL videoTag = [type conformsToUTI:@"public.mpeg-4"] || [type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"];
	BOOL flashTag = [type conformsToUTI:@"public.mpeg-4"] || [type conformsToUTI:@"com.adobe.flash-video"];
	
	BOOL microsoftTag = [type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"];
	
	// quicktime fallback, but not for mp4.  We may want to be more selective of mpeg-4 types though.
	BOOL quicktimeTag = ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
		&& ![type conformsToUTI:@"public.mpeg-4"];
	
	if (quicktimeTag)
	{
		
	}
	else if (microsoftTag)
	{
		
		
		
	}
	else if (videoTag || flashTag)
	{
		if (videoTag)	// start the video tag
		{
			
		}
		
		if (flashTag)	// inner
		{
			
		}
		
		if (videoTag)	// close the video tag
		{
			
		}
		
	}
	else	// none of the above -- indicate that we don't know what to insert
	{
	
		
		
		
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
		result = NSLocalizedString(@"For maximum browser compatibility, please select a MPEG-4 (h.264) file.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if (![type conformsToUTI:(NSString *)kUTTypeMovie])			// BAD
	{
		result = NSLocalizedString(@"This does not seem to be a video file that can be shared on the web.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.h264.ios"])		// HAPPY!  everything-compatible
	{
		result = NSLocalizedString(@"This should be compatible with a wide range of devices, including Mac OS, iOS, and Windows.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.mpeg-4"])			// might not be iOS compatible
	{
		result = NSLocalizedString(@"This should be compatible with Macs and Windows.  Please test on an iOS device.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.ogg-theora"] || [type conformsToUTI:@"public.webm"])
	{
		result = NSLocalizedString(@"This will only play on certain browsers.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"com.adobe.flash-video"])
	{
		result = NSLocalizedString(@"This will play on Mac and Windows, but not iOS devices like iPhone or iPad.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:@"public.avi"] || [type conformsToUTI:@"com.microsoft.windows-​media-wmv"])
	{
		result = NSLocalizedString(@"This will play on PCs and only on Macs with \\U201Cflip4Mac\\U201D installed.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
	}
	else if ([type conformsToUTI:(NSString *)kUTTypeQuickTimeMovie] || [type conformsToUTI:(NSString *)kUTTypeMPEG])
	{
		result = NSLocalizedString(@"This will play on Macs and only Windows PCs with QuickTime installed.", @"status of movie chosen for video. Should fit in 3 lines in inspector.");
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
