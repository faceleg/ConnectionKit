//
//  YouTubeElementDelegate.m
//  KTPlugins
//
//  Copyright (c) 2004-2006, Karelia Software. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  *  Redistribution of source code must retain the above copyright notice,
//     this list of conditions and the follow disclaimer.
//
//  *  Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other material provided with the distribution.
//
//  *  Neither the name of Karelia Software nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS-IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUR OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
//
//  Community Note: This code is distrubuted under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "YouTubeElementDelegate.h"

#import "NSMutableSet+Karelia.h"
#import <SandvoxPlugin.h>
#import <QTKit/QTKit.h>
#include <zlib.h>

#import <KSPathInfoField.h>


/*
 
Some alternatives to YouTube and Google Video:
 
 MetaCafe
 Vimeo
 Revver
 Viddler
 http://v.youku.com/v_show/id_cf00XOTc3MzgwNA==.html
video.aol.com
 blip.tv
 
 
 
 These are the services we looked at: blip.tv, Brightcove.tv, ClipShack, Crackle, DailyMotion, Sony eyeVio, Google Video, Megavideo, Metacafe, Motionbox, Revver, Spike (ifilm), Stage6, Veoh, Viddler, Vimeo, Yahoo Video, and YouTube.
 
, LiveLeak, LiveVideo, , SoapBox, Break
 
 
 */


 
 
 

@interface YouTubeElementDelegate (Private)

- (void)updateDependentThumbnailsFrom:(KTMediaContainer *)oldFile to:(KTMediaContainer *)newFile;

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

static NSArray *sSources = nil;

@implementation YouTubeElementDelegate

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	if (!sSources)
	{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSString *path = [bundle pathForResource:@"sources" ofType:@"plist"];
		sSources = [[NSArray arrayWithContentsOfFile:path] retain];
		NSLog(@"%@", [sSources description]);
	}
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	// set default properties
	if ( isNewObject )
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie autoplay"] forKey:@"autoplay"];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie controller"] forKey:@"controller"];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie kioskmode"] forKey:@"kioskmode"];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie loop"] forKey:@"loop"];
		
	}

}


- (void)awakeFromDragWithDictionary:(NSDictionary *)aDataSourceDictionary
{
	[super awakeFromDragWithDictionary:aDataSourceDictionary];
	
	// grab media
	KTMediaContainer *video =
		[[[self delegateOwner] mediaManager] mediaContainerWithDataSourceDictionary:aDataSourceDictionary];
	
	[[self delegateOwner] setValue:video forKey:@"video"];
	
	// set title
	NSString *title = [aDataSourceDictionary valueForKey:kKTDataSourceTitle];
	if ( nil == title )
	{
		// No title specified; use file name (minus extension)
		title = [[aDataSourceDictionary valueForKey:kKTDataSourceFileName] stringByDeletingPathExtension];
	}
	
	// set caption
	if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceCaption])
	{
		[[self delegateOwner] setObject:[[aDataSourceDictionary objectForKey:kKTDataSourceCaption] escapedEntities]
									forKey:@"captionHTML"];
	}
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


#pragma mark -
#pragma mark Plugin


/*!	Cut a strict down -- we shouldn't have strict with the 'embed' tag
*/
// Called via recursiveComponentPerformSelector
- (void)findMinimumDocType:(void *)aDocTypePointer forPage:(KTPage *)aPage
{
	int *docType = (int *)aDocTypePointer;
	
	if (*docType > KTXHTMLTransitionalDocType)
	{
		*docType = KTXHTMLTransitionalDocType;
	}
}

/*	When a user updates one of these settings, update the defaults accordingly
 */
- (void)setDelegateOwner:(id)plugin
{
	NSSet *keyPaths = [NSSet setWithObjects:@"autoplay", @"controller", @"kioskmode", @"loop", nil];
	
	[[self delegateOwner] removeObserver:self forKeyPaths:keyPaths];
	[super setDelegateOwner:plugin];
	[plugin addObserver:self forKeyPaths:keyPaths options:NSKeyValueObservingOptionNew context:NULL];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (object == [self delegateOwner])
	{
		id newValue = [change objectForKey:NSKeyValueChangeNewKey];
		if (newValue && newValue != [NSNull null])
		{
			if ([keyPath isEqualToString:@"autoplay"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"movie autoplay"];
			}
			
			if ([keyPath isEqualToString:@"controller"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"movie controller"];
			}
			
			if ([keyPath isEqualToString:@"kioskmode"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"movie kioskmode"];
			}
			
			if ([keyPath isEqualToString:@"loop"]) {
				[[NSUserDefaults standardUserDefaults] setObject:newValue forKey:@"movie loop"];
			}
		}
	}
}

#pragma mark -
#pragma mark Media Storage



- (BOOL)pathInfoField:(KSPathInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp
{
	BOOL fileShouldBeExternal = NO;
	if (dragOp & NSDragOperationLink)
	{
		fileShouldBeExternal = YES;
	}
	
	KTMediaContainer *video = [[[self delegateOwner] mediaManager] mediaContainerWithDraggingInfo:sender
																			   preferExternalFile:fileShouldBeExternal];
																				  
	[[self delegateOwner] setValue:video forKey:@"video"];
	
	return YES;
}

/*	We want to support all video types but not images
 */
- (NSArray *)supportedDragTypesForPathInfoField:(KSPathInfoField *)pathInfoField
{
	return [NSArray array];
}


#pragma mark -
#pragma mark HTML template



#pragma mark accessors

- (id) sources
{
	return sSources;
}

- (id)currentSource
{
	return nil;
}

- (id)videoID
{
	return nil;
}


#pragma mark -
#pragma mark Page Thumbnail

/*	Whenever the user tries to "clear" the thumbnail image, we'll instead reset it to match the page content.
 */
- (BOOL)pageShouldClearThumbnail:(KTPage *)page
{
	KTMediaContainer *posterImage = [[self delegateOwner] valueForKeyPath:@"posterImage"];
	[[self delegateOwner] setThumbnail:posterImage];
	
	return NO;
}

#pragma mark -
#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }

@end
