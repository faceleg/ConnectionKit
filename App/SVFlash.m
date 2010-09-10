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
 
 Icon source: http://sharealogo.com/computer/adobe-flash-8-vector-logo-download/ modified with Opacity
 
 // Example: http://mindymcadams.com/photos/flowers/slideshow.swf
 // Flash ref: http://kb2.adobe.com/cps/127/tn_12701.html
 
 */

#import "SVFlash.h"

#import "SVHTMLContext.h"
#import "SVMediaRecord.h"
#import "KSSimpleURLConnection.h"
#include <zlib.h>
#import "NSImage+Karelia.h"
#import "NSString+Karelia.h"
#import "NSBundle+Karelia.h"
#import <QuickLook/QuickLook.h>
#import "KSThreadProxy.h"
#import "NSImage+KTExtensions.h"
#import "SVMediaGraphicInspector.h"


@implementation SVFlash 

@dynamic autoplay;
@dynamic showMenu;
@dynamic loop;
@dynamic flashvars;

//	LocalizedStringInThisBundle(@"This is a placeholder for a Flash file. The full Flash presentation will appear once you publish this website, but to see the Flash in Sandvox, please enable live data feeds in the preferences.", "Live data feeds disabled message.")

//	LocalizedStringInThisBundle(@"Please use the Inspector to enter the URL of a Flash.", "URL has not been specified - placeholder message")

#pragma mark -
#pragma mark Lifetime

+ (SVFlash *)insertNewFlashInManagedObjectContext:(NSManagedObjectContext *)context;
{
    SVFlash *result = [NSEntityDescription insertNewObjectForEntityForName:@"Flash"
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



#pragma mark -
#pragma mark General

- (NSArray *) allowedFileTypes
{
	return [NSArray arrayWithObject:@"com.adobe.shockwave-flash"];
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




- (id <SVMedia>)thumbnail
{
	return nil;		// can't determine thumbnail;
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
}

#pragma mark -
#pragma mark Custom setters (instead of KVO)



- (void)_mediaChanged;
{
	NSLog(@"SVFlash Media set.");
	
	// Flash changed - clear out the known width/height so we can recalculate
	self.naturalWidth = nil;
	self.naturalHeight = nil;
	
	// Load the movie to figure out the media size and codecType
	// [self loadMovie];
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


- (NSString *)writeFlash:(SVHTMLContext *)context
		  flashSourceURL:(NSURL *)flashSourceURL;
{
	NSString *flashSourcePath  = flashSourceURL ? [context relativeURLStringOfURL:flashSourceURL] : @"";
	
	[context pushAttribute:@"width" value:[[self width] description]];
	[context pushAttribute:@"height" value:[[self height] description]];
	[context pushAttribute:@"classid" value:@"clsid:02BF25D5-8C17-4B23-BC80-D3488ABDDC6B"];	// Proper value?
	[context pushAttribute:@"codebase" value:@"http://www.apple.com/qtactivex/qtplugin.cab"];
	
	// ID on <object> apparently required for IE8
	NSString *elementID = [context startElement:@"div" preferredIdName:@"flash" className:nil attributes:nil];	// class, attributes already pushed
	
	[context writeParamElementWithName:@"src" value:flashSourcePath];
	
	[context writeParamElementWithName:@"autoplay" value:self.autoplay.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"loop" value:self.loop.boolValue ? @"true" : @"false"];
	[context writeParamElementWithName:@"scale" value:@"tofit"];
	[context writeParamElementWithName:@"type" value:@"video/quicktime"];
	[context writeParamElementWithName:@"pluginspage" value:@"http://www.apple.com/quicktime/download/"];	
	
	[context endElement];
	
	return elementID;
}



- (NSString *)writeUnknown:(SVHTMLContext *)context;
{
	[context pushAttribute:@"width" value:[[self width] description]];
	[context pushAttribute:@"height" value:[[self height] description]];
	NSString *elementID = [context startElement:@"div" preferredIdName:@"unrecognized" className:nil attributes:nil];	// class, attributes already pushed
	[context writeElement:@"p" text:NSLocalizedString(@"Unable to show Flash. Perhaps it is not a recognized file format.", @"Warning shown to user when Flash can't be embedded")];
	// Poster may be shown next, so don't end....

	OBASSERT([@"div" isEqualToString:[context topElement]]);
	[context endElement];

	return elementID;
}

- (void)writeBody:(SVHTMLContext *)context;
{
	// Prepare Media
	
	SVMediaRecord *media = [self media];
	[context addDependencyOnObject:self keyPath:@"media"];
	
	NSURL *flashSourceURL = [self externalSourceURL];
    if (media)
    {
	    flashSourceURL = [context addMedia:media];
	}
		
	// need to get type from file media or URL dot-extension
	
	BOOL flashTag = YES; // [type conformsToUTI:@"com.adobe.shockwave-flash"];
		
	if (flashTag)	// inner
	{
		[self writeFlash:context flashSourceURL:flashSourceURL]; 
	}
	else	// completely unknown file type
	{
		[self writeUnknown:context];
	}
}



#pragma mark -
#pragma mark Loading flash to calculate dimensions





/*	This accessor provides a means for temporarily storing the flash while information about it is asyncronously loaded
 */


//
//// Asynchronous load returned -- try to set the dimensions.
//- (void)connection:(KSSimpleURLConnection *)connection didFinishLoadingData:(NSData *)data response:(NSURLResponse *)response;
//{
//	NSSize dimensions; //  = [QTMovie dimensionsFromUnloadableMovieData:data];
//	self.naturalWidth  = [NSNumber numberWithFloat:dimensions.width];
//	self.naturalHeight = [NSNumber numberWithFloat:dimensions.height];	// even if it can't be figured out, at least it's not nil anymore
//	self.dimensionCalculationConnection = nil;
//}
//
//- (void)connection:(KSSimpleURLConnection *)connection didFailWithError:(NSError *)error;
//{
//	// do nothing with the error, but clear out the connection.
//	self.dimensionCalculationConnection = nil;
//}


// Caches the flash from data.




@end
