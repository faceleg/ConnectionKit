//
//  YouTubePlugIn.m
//  YouTubeElement
//
//  Copyright 2004-2010 Karelia Software. All rights reserved.
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

#import "YouTubePlugIn.h"
#import "YouTubeInspector.h"
#import "YouTubeCocoaExtensions.h"


#define YOUTUBE_BORDER_HEIGHT 20
#define YOUTUBE_CONTROLBAR_HEIGHT 25


@implementation YouTubePlugIn


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"userVideoCode", 
            @"color2", 
            @"color1", 
            @"widescreen", 
            @"showBorder", 
            @"includeRelatedVideos", 
            @"useCustomSecondaryColor", 
            @"privacy", 
            @"playHD", 
            nil];
}


#pragma mark Initialization

- (void)dealloc
{
	self.userVideoCode = nil;
	self.videoID = nil;
	self.color2 = nil;
	self.color1 = nil;
		
	[super dealloc];
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // see if we can start with the frontmost URL in the default browser
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    if ( location.URL && [location.URL youTubeVideoID] )
    {
        self.userVideoCode = [location.URL absoluteString];
    }
    
    // hint to user: prefer widescreen
    self.widescreen = YES;
    
    // Prepare initial colors
    self.useCustomSecondaryColor = NO;
    self.color2 = [YouTubePlugIn defaultPrimaryColor];  
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    [context addDependencyForKeyPath:@"widescreen" ofObject:self];
}

- (void)startObjectElement;
{
    id <SVPlugInContext> context = [SVPlugIn currentContext];
    
    if ([context liveDataFeeds])
    {
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:@"application/x-shockwave-flash"
                                                               forKey:@"type"];
        [[context HTMLWriter] startElement:@"object"
                          bindSizeToPlugIn:self
                                attributes:attributes];
    }
    else
    {
        NSDictionary *attributes = [NSDictionary dictionaryWithObject:@"svx-placeholder"
                                                               forKey:@"class"];
        [[context HTMLWriter] startElement:@"div" bindSizeToPlugIn:self attributes:attributes];
    }
}

- (void)endElement; { [[[SVPlugIn currentContext] HTMLWriter] endElement]; }


#pragma mark Metrics

- (NSUInteger)heightForWidth:(NSUInteger)width
{
    // check for widescreen
    NSUInteger result = (self.widescreen) ? (width * 9)/16 : (width * 3)/4;
    
    // always leave room for control bar
    result += YOUTUBE_CONTROLBAR_HEIGHT; // always leave room for the control bar

    // leave room for colored border, if applicable
    if ( self.showBorder ) { result += YOUTUBE_BORDER_HEIGHT; }
    
    return result;
}

- (NSUInteger)widthForHeight:(NSUInteger)height
{
    // subtract control bar
    NSUInteger videoHeight = height - YOUTUBE_CONTROLBAR_HEIGHT;
    
    // account for YouTube's (colored) border, if showing
    if ( self.showBorder ) videoHeight -= YOUTUBE_BORDER_HEIGHT;
        
    NSUInteger result = (self.widescreen) ? (videoHeight * 16)/9 : (videoHeight * 4)/3;
    return result;
}

- (NSUInteger)height
{
    return [self heightForWidth:[self width]];
}

- (void)setHeight:(NSUInteger)height;
{
    [self setWidth:[self widthForHeight:height]];
}

+ (NSSet *)keyPathsForValuesAffectingHeight;
{
    return [NSSet setWithObject:@"width"];
}

- (NSUInteger)minHeight
{
    return [self heightForWidth:[self minWidth]];
}

- (BOOL)constrainProportions; { return YES; }
+ (BOOL)isExplicitlySized; { return YES; }


#pragma mark Colors

+ (NSColor *)defaultPrimaryColor;
{
	return [NSColor colorWithCalibratedWhite:0.62 alpha:1.0];
}

- (void)resetColors;
{
	self.useCustomSecondaryColor = NO;
	self.color2 = [[self class] defaultPrimaryColor];
}


#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }


#pragma mark Thumbnail

- (NSURL *)thumbnailURL
{
	NSString *path = [[self bundle] pathForImageResource:@"YouTube"];
	NSURL *URL = [NSURL fileURLWithPath:path];
    return URL;
}


#pragma mark SVPlugInPasteboardReading

// returns an array of UTI strings of data types the receiver can read from the pasteboard and be initialized from. (required)
+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

// returns options for reading data of a specified type from a given pasteboard. (required)
+ (SVPlugInPasteboardReadingOptions)readingOptionsForType:(NSString *)type 
                                               pasteboard:(NSPasteboard *)pasteboard
{
    return SVPlugInPasteboardReadingAsWebLocation;
}

+ (NSUInteger)readingPriorityForPasteboardContents:(id)contents ofType:(NSString *)type
{
    id <SVWebLocation> location = contents;
    if ( [location conformsToProtocol:@protocol(SVWebLocation)] )
    {
        NSURL *URL = [location URL];
        if ( [URL youTubeVideoID] )
        {
            return KTSourcePrioritySpecialized;
        }
    }
    
	return KTSourcePriorityNone;
}

// returns an object initialized using the data in propertyList. (required since we're not using keyed archiving)
- (void)awakeFromPasteboardContents:(id)propertyList ofType:(NSString *)type
{
    id <SVWebLocation> location = propertyList;
    if ( [location conformsToProtocol:@protocol(SVWebLocation)] )
    {
        NSString *videoID = [[location URL] youTubeVideoID];
        if (videoID)
        {
            self.userVideoCode = [[location URL] absoluteString];
        }
    }
}


#pragma mark Properties

@synthesize videoID = _videoID;
@synthesize widescreen = _widescreen;
@synthesize playHD = _playHD;
@synthesize privacy = _privacy;
@synthesize showBorder = _showBorder;
@synthesize includeRelatedVideos = _includeRelatedVideos;
@synthesize useCustomSecondaryColor = _useCustomSecondaryColor;

@synthesize userVideoCode = _userVideoCode;
- (void)setUserVideoCode:(NSString *)string
{
    [_userVideoCode autorelease];
    _userVideoCode = [string copy];
    
    // When the user sets a video code, figure the ID from it
    NSString *videoID = nil;
    if ( nil != _userVideoCode ) videoID = [[NSURL URLWithString:self.userVideoCode] youTubeVideoID];
    self.videoID = videoID;
}

@synthesize color2 = _color2;
- (void)setColor2:(NSColor *)color
{
    [_color2 autorelease];
    _color2 = [color copy];
    
    // When the user adjusts the main colour WITHOUT having adjusted the secondary color, re-generate
	// a new second colour from it
	if ( !self.useCustomSecondaryColor )
	{
		NSColor *lightenedColor = [[NSColor whiteColor] blendedColorWithFraction:0.5 ofColor:_color2];
		
		myAutomaticallyUpdatingSecondaryColorFlag = YES;	// The flag is needed to stop us mis-interpeting the setter
		self.color1 = lightenedColor;
		myAutomaticallyUpdatingSecondaryColorFlag = NO;
	}
    
}

@synthesize color1 = _color1;
- (void)setColor1:(NSColor *)color
{
    [_color1 autorelease];
    _color1 = [color copy];
    
    // When the user sets their own secondary color mark it so no future changes are made by accident
	if ( !myAutomaticallyUpdatingSecondaryColorFlag )
	{
		self.useCustomSecondaryColor = YES;
	}
}

@end
