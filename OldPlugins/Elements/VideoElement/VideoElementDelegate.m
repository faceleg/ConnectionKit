//
//  VideoElementDelegate.m
//  Sandvox SDK
//
//  Copyright 2004-2009 Karelia Software. All rights reserved.
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


//	LocalizedStringInThisBundle(@"This is a placeholder for a video. The full video will appear once you publish this website, but to see the video in Sandvox, please enable live data feeds in the preferences.", "Live data feeds disabled message.")

//	LocalizedStringInThisBundle(@"Please use the Inspector to enter the URL of a video.", "URL has not been specified - placeholder message")



#import "VideoElementDelegate.h"

#import "SandvoxPlugin.h"
#import <QTKit/QTKit.h>
#include <zlib.h>

#import <KSPathInfoField.h>

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

 

@interface VideoElementDelegate ()

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

@interface QTMovie (iMediaHack)
- (NSImage *)betterPosterImage;
@end


#pragma mark -


@implementation VideoElementDelegate

#pragma mark awake

- (void)awakeFromBundleAsNewlyCreatedObject:(BOOL)isNewObject
{
	[super awakeFromBundleAsNewlyCreatedObject:isNewObject];
	
	// set default properties
	if ( isNewObject )
	{
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie autoplay"] forKey:@"autoplay"];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie controller"] forKey:@"controller"];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie kioskmode"] forKey:@"kioskmode"];
		[[self delegateOwner] setBool:[defaults boolForKey:@"movie loop"] forKey:@"loop"];
		
// TODO: Track these values so they will go into defaults when we set, for future movie creation
	}

	// we may not have a movieSize because we only started storing it as of version 1.1.2.
	if (nil == [[self delegateOwner] objectForKey:@"movieSize"])		// have we not figured out dimensions yet?
	{
		[self loadMovie];
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
    [[self delegateOwner] setTitleText:title];
	
	// set caption
	if (nil != [aDataSourceDictionary objectForKey:kKTDataSourceCaption])
	{
		[[self delegateOwner] setObject:[[aDataSourceDictionary objectForKey:kKTDataSourceCaption] stringByEscapingHTMLEntities]
									forKey:@"captionHTML"];
	}
}

#pragma mark -
#pragma mark Dealloc

- (void)dealloc
{
	[self setMovie:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super dealloc];
}


#pragma mark -
#pragma mark Plugin

- (void)addPageTextToHead:(NSMutableString *)ioString forPage:(KTPage *)aPage
{
	NSString *bundleResourcePath = [[self bundle] pathForResource:@"AC_QuickTime" ofType:@"js"];
	if (bundleResourcePath)
	{
		NSURL *resourceURL = [[[[self page] site] hostProperties] URLForResourceFile:[bundleResourcePath lastPathComponent]];
		NSString *relativePath = [resourceURL stringRelativeToURL:[aPage URL]];
		
		NSString *jsString = [NSString stringWithFormat:
			@"<script src=\"%@\" type=\"text/javascript\"></script>\n", relativePath];
		
		// Only append string if it's not already there (e.g. if there's > 1 element)
		if (NSNotFound == [ioString rangeOfString:jsString].location)
		{
			[ioString appendString:jsString];
		}
	}
}

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

- (void)_updateThumbnail:(KTMediaContainer *)mediaContainer
{
	NSString *moviePath = [[mediaContainer file] currentPath];
	NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
								moviePath, QTMovieFileNameAttribute,
								[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
								nil];
	
	NSError *error = nil;
	QTMovie *movie = [[QTMovie alloc] initWithAttributes:attributes error:&error];
	
	NSImage *posterImage = nil;
	if (movie)
	{
		posterImage = [movie betterPosterImage]; 
		[movie release];
	}
	
	// Handle a missing thumbnail, like when we have a .wmv file
	if (!posterImage || NSEqualSizes(NSZeroSize, [posterImage size]) )
	{
		NSString *quickTimePath = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:@"com.apple.quicktimeplayer"];
		if (quickTimePath)
		{
			posterImage = [[NSWorkspace sharedWorkspace] iconForFile:quickTimePath];
		}
		else
		{
			posterImage = [NSImage imageNamed:@"NSDefaultApplicationIcon"];	// last resort!
		}
	}
	
	
	KTMediaContainer *posterImageMedia = [[self mediaManager] mediaContainerWithImage:posterImage];
	[[self delegateOwner] setValue:posterImageMedia forKey:@"posterImage"];
}

- (void)plugin:(id)plugin didSetValue:(id)value forPluginKey:(NSString *)key oldValue:(id)oldValue
{
	// When setting the video load it to get dimensions etc. & update poster image
	if ([key isEqualToString:@"video"])
	{
		[self loadMovie];
		[self _updateThumbnail:value];
	}
    else if ([key isEqualToString:@"remoteURL"])
    {
        [self loadMovie];
    }
    else if ([key isEqualToString:@"movieSource"])
    {
        [self loadMovie];
    }
	
    
	// Update page thumbnail if appropriate
	else if ([key isEqualToString:@"posterImage"])
	{
		id container = [self delegateOwner];
		if (container && [container respondsToSelector:@selector(thumbnail)])
		{
			if ([container valueForKey:@"thumbnail"] == oldValue)
			{
				[container setValue:value forKey:@"thumbnail"];
			}
		}
	}
}

- (NSSet *)requiredMediaIdentifiers
{
	NSMutableSet *result = [NSMutableSet setWithCapacity:2];
	
	[result addObjectIgnoringNil:[[self delegateOwner] valueForKeyPath:@"video.identifier"]];
	[result addObjectIgnoringNil:[[self delegateOwner] valueForKeyPath:@"posterImage.identifier"]];
	
	return result;
}

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
	
	KTMediaContainer *video = [[[self delegateOwner] mediaManager] mediaContainerWithPath:[selectedPaths firstObjectKS]];
	[[self delegateOwner] setValue:video forKey:@"video"];
}

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
	NSMutableSet *movieTypes = [NSMutableSet setWithArray:[QTMovie movieUnfilteredPasteboardTypes]];
	[movieTypes minusSet:[NSSet setWithArray:[NSImage imagePasteboardTypes]]];
	return [movieTypes allObjects];
}

- (BOOL)pathInfoField:(KSPathInfoField *)filed shouldAllowFileDrop:(NSString *)path
{
	BOOL result = NO;
	
	if ([NSString UTI:[NSString UTIForFileAtPath:path] conformsToUTI:(NSString *)kUTTypeMovie])
	{
		result = YES;
	} 
	
	return result;
}

#pragma mark -
#pragma mark Flash

/*
 A flash 8 file that's 0x65EE4F bytes long
 
 00000000  46 57 53 08 4f ee 65 00  78 00 06 0e 00 00 12 c0  |FWS.O.e.x.......|
 00000010  00 00 1e 22 0c 43 02 00  00 00 84 04 0b 2b df 02  |...".C.......+..|
 00000020  3f 03 14 00 00 00 96 09  00 00 57 46 5f 44 4f 4e  |?.........WF_DON|
 00000030  45 00 96 03 00 00 30 00  1d 00 0a 0f 01 00 21 0c  |E.....0.......!.|
 
 Nbits     	     nBits = UB[5]     	     Bits used for each subsequent field     
 Xmin     	     SB[nBits]     	     X minimum position for rectangle in twips     
 Xmax     	     SB[nBits]     	     X maximum position for rectangle in twips     
 Ymin     	     SB[nBits]     	     Y minimum position for rectangle in twips     
 Ymax     	     SB[nBits]     	     Y maximum position for rectangle in twips     
	};
 
Here's a CWF -- compressed flash file, file size 0x7A849E
 
 00000000  43 57 53 06 88 be 7d 00  78 da e4 ba 07 58 13 db  |CWS...}.x....X..|
 00000010  b6 00 bc 33 24 90 d0 a4  77 14 29 91 2e 45 82 0a  |...3$...w.)..E..|
 00000020  62 04 94 8e 48 2f 4a 4d  42 0b 01 01 11 44 3d 51  |b...H/JMB....D=Q|
 00000030  b1 60 05 85 08 44 14 15  50 54 7a 2f 62 6c 08 08  |.`...D..PTz/bl..|
 
After deflating starting at byte 8, you get:
 78 9C 00 07 40 F8 BF 78 DA E4 BA 07 58 13 DB B6 | x...@..x....X...
 00 BC 33 24 90 D0 A4 77 14 29 91 2E 45 82 0A 62 | ..3$...w.)..E..b
 04 94 8E 48 2F 4A 4D 42 0B 01 01 11 44 3D 51 B1 | ...H/JMB....D=Q.

 */ 

// based loosely on swfparse.c from http://www.fontimages.org.uk/
- (int)getBits:(int)numberOfBits
{
	int result = 0;
	int i, shift;
	for(i = 0 ; i < numberOfBits ; i += shift)
	{	
		if (!myBitOffset)
		{	
			myCurrentByte = *myBytePointer++;	// to next byte
			myBitOffset = 8;
		}
		shift = numberOfBits - i;
		if(shift > myBitOffset)	shift = myBitOffset;
		result <<= shift;
		result |= (myCurrentByte >> (myBitOffset -= shift)) & ((1 << shift) - 1);
	}
	return result;
}

- (BOOL)attemptToGetSize:(NSSize *)outSize fromSWFData:(NSData *)data
{
	BOOL result = NO;
	myBytePointer = (char *) [data bytes];
	
	@synchronized (self)	// since we store temporary stuff in ivars
	{
		BOOL isCompressed = NO;
		if ( [data length] > 20
			 && (myBytePointer[0] == 'F' || (isCompressed = myBytePointer[0] == 'C')  ) 
			 && myBytePointer[1] == 'W'
			 && myBytePointer[2] == 'S' )	// verify flash format
		{
			// Initialize ivars for the scanning
			myBitOffset = 0;
			myCurrentByte = 0;
			myBytePointer += 4;					// point to the 4th byte where the size data are
			int dataLength = NSSwapLittleIntToHost(*((int*)myBytePointer));

			myBytePointer += 4;					// point to the 8th byte where the rectangle data are

			if (isCompressed)
			{
				NSMutableData *outputData = [NSMutableData dataWithLength: dataLength - 8];
					
				z_stream z = {0};
				z.next_in = (Bytef*)myBytePointer;
				z.avail_in = [data length] - 8;
				z.next_out = (Bytef *)[outputData bytes];
				z.avail_out = dataLength - 8;
		
				(void) inflateInit((z_streamp)&z);
				(void) inflate(&z, Z_FINISH);
				(void) inflateEnd((z_streamp)&z);
				
				myBytePointer = (char *)[outputData bytes];
			}
			
			int numBits = [self getBits:5];
			int xx1		= [self getBits:numBits] / 20.0;
			int xx2		= [self getBits:numBits] / 20.0;
			int yy1		= [self getBits:numBits] / 20.0;
			int yy2		= [self getBits:numBits] / 20.0;
		
			if (nil != outSize)
			{
				*outSize = NSMakeSize(xx2-xx1, yy2-yy1);
			}
			result = YES;
		}
	}
	myBytePointer = nil;	// clean up, no sense hanging onto pointer
	return result;
}



#pragma mark -
#pragma mark HTML template

- (NSString *)videoPreviewTemplate
{
	static NSString *result;
	if (!result)
	{
		NSString *templatePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PreviewTemplate" ofType:@"html"];
		OBASSERT(templatePath);
		
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

- (NSString *)videoPublishingTemplate
{
	static NSString *result;
	if (!result)
	{
		NSString *templatePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"PublishingTemplate" ofType:@"html"];
		OBASSERT(templatePath);
		
		result = [[NSString alloc] initWithContentsOfFile:templatePath];
	}
	
	return result;
}

- (NSSize)pageDimensions
{
	int minHeight = 128;
	BOOL sizeIsKnown = (nil != [[self delegateOwner] objectForKey:@"movieSize"]);
	NSSize result = [self movieSize];		// start out with 100%
									// Scale down if too wide to fit
	int maxWidth = 0;
	id container = [self delegateOwner];
	if ( [container isKindOfClass:[KTPage class]] )
	{
		if ([((KTPage *)container) includeSidebar])
		{
			maxWidth = 320;
			minHeight = 240;
		}
		else
		{
			maxWidth = 640;
			minHeight = 480;
		}
	}
	else
	{
		[NSException raise:@"KTMediaException" format:@"unknown container type for video element"];
	}
	// now scale
	if (result.width > maxWidth)
	{
		float newHeight = result.height * (maxWidth / result.width);
		result = NSMakeSize(maxWidth, newHeight);
	}
	
	// regardless of whether there was a movie, adjust the size for controllers & mid size
	if (!sizeIsKnown || 0 == result.width)	// appropriate for audio (zero dimension) and unknown sizes
	{
		result.width = maxWidth;	// nice width that will work for sidebar and not
	}
	if (!sizeIsKnown)	// if no height, and no movie set, set an arbitrary height.
	{
		result.height = minHeight;		// arbitrary value to show the "Q" logo that is a TV 3:4 ratio
	}
	if ([[[self delegateOwner] valueForKey:@"controller"] boolValue])
	{
		if (![[self delegateOwner] boolForKey:@"isFlash"] && ![[self delegateOwner] boolForKey:@"isWindowsMedia"])
		{
			result.height += 16;	// room for controller, 16 pixels with the quicktime controller
		}
		else if ([[self delegateOwner] boolForKey:@"isWindowsMedia"])
		{
			result.height += 46;	// room for controller, 46 pixels for the windows controller
		}
	}
	if (!sizeIsKnown)
	{
		NSLog(@"Warning: movie size is not known for video element");
	}
	
	
	return result;
}

- (int)height	// don't let the width or height be zero
{
	NSSize size = [self pageDimensions];
	return size.height;
}

- (int)width	// don't let the width or height be zero
{
	NSSize size = [self pageDimensions];
	return size.width;
}

#pragma mark accessors

/*	This accessor provides a means for temporarily storing the movie while information about it is asyncronously loaded
 */
- (QTMovie *)movie { return myMovie; }

- (void)setMovie:(QTMovie *)aMovie
{
	// If we are clearing out an existing movie, we're done, so exit movie on thread.  I hope this is right!
	if (nil == aMovie && nil != myMovie && ![NSThread isMainThread])
	{
		OSErr err = ExitMoviesOnThread();	// I hope this is 
		if (err != noErr) NSLog(@"Unable to ExitMoviesOnThread; %d", err);
	}
	[aMovie retain];
	[myMovie release];
	myMovie = aMovie;
}


- (NSSize)movieSize
{
	NSSize result = NSZeroSize;
	NSString *sizeString = [[self delegateOwner] objectForKey:@"movieSize"];
	if (nil != sizeString && ![sizeString isEqualToString:@""])
	{
		result = NSSizeFromString(sizeString);
	}
	return result;
}

- (void)setMovieSize:(NSSize)movieSize
{
	NSString *sizeString = NSStringFromSize(movieSize);
	[[self delegateOwner] setObject:sizeString forKey:@"movieSize"];
}

#pragma mark -
#pragma mark Movie loading & size calculation

// Loads or reloads the movie/flash from URL, path, or data.
- (void)loadMovie
{
	NSDictionary *movieAttributes = nil;
	
	if ([[[self delegateOwner] valueForKey:@"movieSource"] intValue] == 1)
	{
		// Load from a URL
		NSString *movieURLString = [[self delegateOwner] valueForKey:@"remoteURL"];
		if (movieURLString && ![movieURLString isEmptyString])
		{
			NSURL *movieURL = [KSURLFormatter URLFromString:movieURLString];
			if (movieURL)
			{
				movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
					movieURL, QTMovieURLAttribute,
					[NSNumber numberWithBool:YES], QTMovieOpenAsyncOKAttribute,
					nil];
			}
		}
	}
	else
	{
		// Load from a local file
		NSString *moviePath = [[self delegateOwner] valueForKeyPath:@"video.file.currentPath"];
		if (moviePath)
		{
			movieAttributes = [NSDictionary dictionaryWithObjectsAndKeys: 
				moviePath, QTMovieFileNameAttribute,
				[NSNumber numberWithBool:NO], QTMovieOpenAsyncOKAttribute,
				nil];
		}
	}
	
	
	// Now try to do the real loading using the movie attributes
	if (movieAttributes)
	{
		[self loadMovieFromAttributes:movieAttributes];
	}
}

// Caches the movie from data.

- (void)loadMovieFromAttributes:(NSDictionary *)anAttributes
{
	// Ignore for background threads as there is no need to do this during a doc import
    if (![NSThread isMainThread]) return;
    
    
    [self setMovie:nil];	// will clear out any old movie, exit movies on thread
	BOOL isFlash = NO;
	BOOL isWindowsMedia = NO;
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
		// See if this is a Flash movie
		QTTrack *lastTrack = [[movie tracks] lastObject];
		QTMedia *media = [lastTrack media];
		isFlash = (QTMediaTypeFlash == [media attributeForKey:QTMediaTypeAttribute]);
		 
		long movieLoadState = [[movie attributeForKey:QTMovieLoadStateAttribute] longValue];
		
		if (movieLoadState >= kMovieLoadStatePlayable)	// Do we have dimensions now?
		{
			[self calculateMovieDimensions:movie];
			//[self calculatePageDimensions];		// shrink down, add controller bar space, etc.
			
			if (![NSThread isMainThread])	// we entered, so exit now that we're done with that
			{
				OSErr err = ExitMoviesOnThread();	// I hope this is 
				if (err != noErr) NSLog(@"Unable to ExitMoviesOnThread; %d", err);
			}
		}
		else	// not ready yet; wait until loaded if we are publishing
		{
			[self setMovie:movie];		// cache and retain for async loading.
			[movie setDelegate:self];
			
			/// Case 18430: we only add observers on main thread
			if ( [NSThread isMainThread] )
			{
				[[NSNotificationCenter defaultCenter] addObserver:self
														 selector:@selector(loadStateChanged:)
															 name:QTMovieLoadStateDidChangeNotification object:movie];
			}
			
			// OBASSERT_NOT_REACHED("Took out some old 1.5 code here, which TT and MGA thought unused.");
			// DJW: I got here by entering an external URL of a .mov file into the inspector.
			
/* This is the code that was taken out. I'lll leave it commented out for now since -documentIsPublishing is gone.
			
			// I don't know if we will EVER get to this point.  However, when I force it to happen,
			// it seems to be OK.  The idea is that if we are getting here for the first time 
			// when publishing, wait until we get the information we need.
			if ([self documentIsPublishing])
			{
				BOOL doContinue = YES;	// if we get a zero, I think that means we ran out of events so stop
				while (doContinue && (nil == [[self delegateOwner] objectForKey:@"movieSize"]))
				{
					//NSLog(@"Starting RunLoop waiting for %p size = %@", movie, [[self pluginProperties] objectForKey:@"movieSize"]);
					doContinue = [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate: [NSDate dateWithTimeIntervalSinceNow:3.0] ];
					//NSLog(@"%d Ended RunLoop waiting for %p size = %@", doContinue, movie, [[self pluginProperties] objectForKey:@"movieSize"]);
				}
				if (!doContinue)	// I don't think I'll ever get this but just in case.
				{
					NSLog(@"waiting for movie data to load; gave up.  Please report this to support@karelia.com");
				}
			}	
*/
			
			
		}
	}
	else	// No movie?  Maybe it's flash -- get dimensions now.
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
			movieData = [NSData dataWithContentsOfURL:[anAttributes objectForKey:QTMovieURLAttribute]];		// will block, but this only happens once.
		}
		if (nil != movieData)
		{
			NSSize aSize = NSZeroSize;
			if ([self attemptToGetSize:&aSize fromSWFData:movieData])
			{
				isFlash = YES;
				[self setMovieSize:aSize];
				//[self calculatePageDimensions];
			}	// We're done!  
		}
	}
	
	// test if it's WMV or WMA. Do this regardless of whether we created a movie, so that even if there is no flip4mac,
	// we will still provide something useful.  However, we won't know the dimensions!
	
	
	//  We may want to have other file types/extensions that use the WindowsMedia type, e.g. avi.

	
	
	if (!isFlash)	// no need to test if it's flash
	{
		// Poor man's check for WMV. Check file extension, mime type
		if (nil != [anAttributes objectForKey:QTMovieDataReferenceAttribute])
		{
			NSString *mimeType = [[anAttributes objectForKey:QTMovieDataReferenceAttribute] MIMEType];
			isWindowsMedia = [mimeType hasSuffix:@"x-ms-wmv"] || [mimeType hasSuffix:@"x-ms-wma"] || [mimeType hasSuffix:@"avi"];
		}
		else if (nil != [anAttributes objectForKey:QTMovieFileNameAttribute])
		{
			NSString *extension = [[[anAttributes objectForKey:QTMovieFileNameAttribute] pathExtension] lowercaseString];
			isWindowsMedia = [extension isEqualToString:@"wmv"] || [extension isEqualToString:@"wma"] || [extension isEqualToString:@"avi"];
		}
		else if (nil != [anAttributes objectForKey:QTMovieURLAttribute])
		{
			NSString *extension = [[[[anAttributes objectForKey:QTMovieURLAttribute] path] pathExtension] lowercaseString];
			isWindowsMedia = [extension isEqualToString:@"wmv"] || [extension isEqualToString:@"wma"] || [extension isEqualToString:@"avi"];
		}
		
		//			// Dig deeper and figure out if this is WMV.  Haven't gotten working yet.
		//			
		//			NSEnumerator *enumerator = [[movie tracks] objectEnumerator];
		//			QTTrack *track;
		//			
		//			while ((track = [enumerator nextObject]) != nil)
		//			{
		//				QTMedia *media = [track media];
		//				
		//				OSType codec = [media sampleDescriptionCodec];
		//				NSString *codecName = [media sampleDescriptionCodecName];
		//				
		//				if (codec >= 'WMV1' && codec <= 'WMV9')
		//				{
		//					isWindowsMedia = YES;
		//				}
		//				// break;
		//			}
	}
	
	[[self delegateOwner] setValue:[NSNumber numberWithBool:isFlash] forKey:@"isFlash"];
	[[self delegateOwner] setValue:[NSNumber numberWithBool:isWindowsMedia] forKey:@"isWindowsMedia"];
}

// check for load state changes
- (void)loadStateChanged:(NSNotification *)notif
{
	QTMovie *movie = [notif object];
    if ([[self movie] isEqual:movie])
	{
		long loadState = [[movie attributeForKey:QTMovieLoadStateAttribute] longValue];
		if (loadState >= kMovieLoadStateLoaded && NSEqualSizes([self movieSize], NSZeroSize))
		{
			[self calculateMovieDimensions:movie];
			//[self calculatePageDimensions];		// shrink down, add controller bar space, etc.
			
			[[NSNotificationCenter defaultCenter] removeObserver:self];
			[self setMovie:nil];	// we are done with movie now!
		}
	}
}


- (void)calculateMovieDimensions:(QTMovie *)aMovie
{
	NSSize movieSize = NSZeroSize;
	
	NSArray* vtracks = [aMovie tracksOfMediaType:QTMediaTypeVideo];
	if ([vtracks count] && [[vtracks objectAtIndex:0] respondsToSelector:@selector(apertureModeDimensionsForMode:)])
	{
		QTTrack* track = [vtracks objectAtIndex:0];
		//get the dimensions 
		
		// I'm getting a warning of being both deprecated AND unavailable!  WTF?  Any way to work around this?
		
		movieSize = [track apertureModeDimensionsForMode:QTMovieApertureModeClean];		// 10.5 only, but it gives a proper value for anamorphic movies like from case 41222.
	}
	if (NSEqualSizes(movieSize, NSZeroSize))
	{
		movieSize = [[aMovie attributeForKey:QTMovieNaturalSizeAttribute] sizeValue];
		if (NSEqualSizes(NSZeroSize, movieSize))
		{
			movieSize = [[aMovie attributeForKey:QTMovieCurrentSizeAttribute] sizeValue];
		}
	}
	
//	NSLog(@"Calculated size of %@ to %@", aMovie, NSStringFromSize(movieSize));
	[self setMovieSize:movieSize];
}

//- (NSArray *)reservedMediaRefNames
//{
//	return [NSArray arrayWithObject:@"VideoElement"];
//}


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

#pragma mark -
#pragma mark RSS Feed

- (NSArray *)pageWillReturnFeedEnclosures:(KTPage *)page
{
	NSArray *result = nil;
	
	if ([[self delegateOwner] integerForKey:@"movieSource"] == 0)
    {
        KTMediaContainer *video = [[self delegateOwner] valueForKey:@"video"];
        if ([[video file] currentPath])
        {
            result = [NSArray arrayWithObject:video];
        }
    }
    
	return result;
}

#pragma mark -
#pragma mark Data Migrator

- (BOOL)importPluginProperties:(NSDictionary *)oldPluginProperties
                    fromPlugin:(NSManagedObject *)oldPlugin
                         error:(NSError **)error
{
    id element = [self delegateOwner];
    
    // Import the video
    KTMediaContainer *video = [[self mediaManager] mediaContainerWithMediaRefNamed:@"VideoElement" element:oldPlugin];
    [element setValue:video forKey:@"video"];
    [element setInteger:(video) ? 0 : 1 forKey:@"movieSource"];
    
    // Import other properties
    [element setValuesForKeysWithDictionary:oldPluginProperties];
    
    return YES;
}

#pragma mark -
#pragma mark Data Source

+ (NSArray *)supportedPasteboardTypesForCreatingPagelet:(BOOL)isCreatingPagelet;
{
    return [NSArray arrayWithObjects:
            NSFilenamesPboardType,
            QTMoviePasteboardType,		
            nil];
}

+ (unsigned)numberOfItemsFoundOnPasteboard:(NSPasteboard *)sender
{
    return 1;
}

+ (KTSourcePriority)priorityForItemOnPasteboard:(NSPasteboard *)pboard atIndex:(unsigned)dragIndex creatingPagelet:(BOOL)isCreatingPagelet;
{
    [pboard types];
    
	if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
	{
		NSArray *fileNames = [pboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [fileNames count])
		{
			NSString *fileName = [fileNames objectAtIndex:dragIndex];
			if ( nil != fileName )
			{
				// check to see if it's an image file
				NSString *aUTI = [NSString UTIForFileAtPath:fileName];	// takes account as much as possible
				
				if ( [NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeAppleProtectedMPEG4Audio] )
				{
					return KTSourcePriorityNone;	// disallow protected audio; don't try to play as audio
				}
				else if ( [NSString UTI:aUTI conformsToUTI:(NSString *)kUTTypeAudiovisualContent] )
				{
					return KTSourcePriorityIdeal;
				}
				else
				{
					return KTSourcePriorityNone;	// not an image
				}
			}
		}
	}
	else if (nil != [pboard availableTypeFromArray:[NSArray arrayWithObject:QTMoviePasteboardType]])
	{
		return KTSourcePriorityIdeal;	// there is an image, so it's probably OK
	}
    return KTSourcePriorityNone;	// doesn't actually have any image data
}

+ (BOOL)populateDataSourceDictionary:(NSMutableDictionary *)aDictionary
                      fromPasteboard:(NSPasteboard *)pasteboard
                             atIndex:(unsigned)dragIndex
				  forCreatingPagelet:(BOOL)isCreatingPagelet;

{
    BOOL result = NO;
    NSString *filePath = nil;
    
    NSArray *orderedTypes = [self supportedPasteboardTypesForCreatingPagelet:isCreatingPagelet];
    
	
    NSString *bestType = [pasteboard availableTypeFromArray:orderedTypes];
    if ( [bestType isEqualToString:NSFilenamesPboardType] )
    {
		NSArray *filePaths = [pasteboard propertyListForType:NSFilenamesPboardType];
		if (dragIndex < [filePaths count])
		{
			filePath = [filePaths objectAtIndex:dragIndex];
			if ( nil != filePath )
			{
				[aDictionary setValue:
                 [[NSFileManager defaultManager] resolvedAliasPath:filePath]
							   forKey:kKTDataSourceFilePath];
				[aDictionary setValue:[filePath lastPathComponent] forKey:kKTDataSourceFileName];
				result = YES;
			}
		}
    }
	else
	{
		; // QT on pasteboard ... I think I can just leave the pasteboard alone?
	}
    
    return result;
}

@end
