//
//  YouTubePlugIn.m
//  YouTubeElement
//
//  Copyright 2004-2011 Karelia Software. All rights reserved.
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


@implementation YouTubePlugIn


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"userVideoCode", 
            //@"videoID", 
            @"privacy", 
            @"widescreen", 
            @"includeRelatedVideos", 
            nil];
}


#pragma mark Initialization

- (void)dealloc
{
	self.userVideoCode = nil;
	self.videoID = nil;
		
	[super dealloc];
}

- (void)setInitialProperties
{
    self.widescreen = YES;
    self.includeRelatedVideos = NO;
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // see if we can start with the frontmost URL in the default browser
    id<SVWebLocation> location = [[NSWorkspace sharedWorkspace] fetchBrowserWebLocation];
    if ( [[location URL] youTubeVideoID] )
    {
        self.userVideoCode = [[location URL] absoluteString];
        
        if ( [location title] )
        {
            self.title = [location title];
        }
    }
    
    [self setInitialProperties];
}


#pragma mark Migration

- (void)awakeFromSourceProperties:(NSDictionary *)properties
{
    [super awakeFromSourceProperties:properties];
    [self setWidth:[properties objectForKey:@"videoWidth"] height:[properties objectForKey:@"videoHeight"]];
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    [context addDependencyForKeyPath:@"userVideoCode" ofObject:self];
    [context addDependencyForKeyPath:@"videoID" ofObject:self];
    [context addDependencyForKeyPath:@"privacy" ofObject:self];
    [context addDependencyForKeyPath:@"widescreen" ofObject:self];
    [context addDependencyForKeyPath:@"includeRelatedVideos" ofObject:self];
}

//<iframe title="YouTube video player" width="425" height="349" src="http://www.youtube.com/embed/R-mUh4MOuvk?rel=0" frameborder="0" <iframe title="YouTube video player" width="480" height="390" src="http://www.youtube.com/embed/ulluhQQd9Bw?rel=0" frameborder="0" allowfullscreen></iframe>></iframe>

- (void)writeIFrameEmbed
{
    id <SVPlugInContext> context = [self currentContext];
    
    NSString *embedHost = (self.privacy) ? @"www.youtube-nocookie.com" : @"www.youtube.com";
    NSString *embed = [NSString stringWithFormat:@"http://%@/embed/%@", embedHost, [self videoID]];
    if ( !self.includeRelatedVideos )
    {
        embed = [embed stringByAppendingString:@"?rel=0"];
    }
    
    NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"YouTube video player", @"title",
                                embed, @"src",
                                @"0", @"frameborder",
                                nil];
    [context startElement:@"iframe" 
         bindSizeToPlugIn:self 
          preferredIdName:@"youtube"
               attributes:attributes];
    [context endElement]; // </iframe>
}

- (void)writeNoLiveData
{
    id <SVPlugInContext> context = [self currentContext];
    [context startElement:@"div" 
         bindSizeToPlugIn:self 
          preferredIdName:@"youtube"
               attributes:nil];
    
    NSString *message = SVLocalizedString(@"This is a placeholder for the YouTube video at:", 
                                          "Live data feeds are disabled");
    [context writePlaceholderWithText:message options:0];
    
    [context startElement:@"p"];
    [context startAnchorElementWithHref:[self userVideoCode] 
                                               title:[self userVideoCode] 
                                              target:nil 
                                                 rel:nil];
    [context endElement]; // </a>
    [context endElement]; // </p>
    
    message = SVLocalizedString(@"To see the video in Sandvox, please enable live data feeds in the Preferences.", 
                                "Live data feeds are disabled");
    [context writePlaceholderWithText:message options:0];
    
    [context endElement]; // </div>
}

- (void)writeNoVideoFound
{
    id <SVPlugInContext> context = [self currentContext];
    [context startElement:@"div" 
         bindSizeToPlugIn:self 
          preferredIdName:@"youtube"
               attributes:nil];
    NSString *message = SVLocalizedString(@"Sorry, but no YouTube video was found for the code you entered.", 
                                          "User entered an invalid YouTube code");
    [context writePlaceholderWithText:message options:0];
    [context endElement];
}

- (void)writeNoVideoSpecified
{
    id <SVPlugInContext> context = [self currentContext];
    [context startElement:@"div" 
         bindSizeToPlugIn:self 
          preferredIdName:@"youtube"
               attributes:nil];
    NSString *message = SVLocalizedString(@"Please use the Inspector to specify a YouTube video.", 
                                          "No video code has been entered yet");
    [context writePlaceholderWithText:message options:0];
    [context endElement];    
}


#pragma mark Metrics

- (NSNumber *)constrainedAspectRatio;
{
    float result = (self.widescreen ? 16.0f/9.0f : 4.0f/3.0f);
    return [NSNumber numberWithFloat:result];
}

+ (BOOL)isExplicitlySized; { return YES; }

- (void)makeOriginalSize;
{
    float height = 490 / [[self constrainedAspectRatio] floatValue];
    [self setWidth:[NSNumber numberWithInt:490] height:[NSNumber numberWithUnsignedInteger:height]];
}


#pragma mark Summaries

- (NSString *)summaryHTMLKeyPath { return @"captionHTML"; }

- (BOOL)summaryHTMLIsEditable { return YES; }


#pragma mark Thumbnail

- (NSURL *)thumbnailURL
{
	NSString *path = [[NSBundle bundleForClass:[self class]] pathForImageResource:@"YouTube"];
	NSURL *URL = [NSURL fileURLWithPath:path];
    return URL;
}


#pragma mark SVPlugInPasteboardReading

+ (NSArray *)readableTypesForPasteboard:(NSPasteboard *)pasteboard;
{
    return SVWebLocationGetReadablePasteboardTypes(pasteboard);
}

+ (SVPasteboardPriority)priorityForPasteboardItem:(id <SVPasteboardItem>)item;
{
    NSURL *URL = [item URL];
    if ( [URL youTubeVideoID] )
    {
        return SVPasteboardPrioritySpecialized;
    }
    return [super priorityForPasteboardItem:item];
}

- (BOOL)awakeFromPasteboardItems:(NSArray *)items;
{
    if ( items && [items count] )
    {
        id <SVPasteboardItem>item = [items objectAtIndex:0];
        
        NSString *videoID = [[item URL] youTubeVideoID];
        if (videoID)
        {
            self.userVideoCode = [[item URL] absoluteString];
        }
        
        NSString *title = [item title];
        if ( title )
        {
            self.title = title;
        }
        
        [self setInitialProperties];
        
        return YES;
    }
    
    return NO;    
}


#pragma mark Properties

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

@synthesize videoID = _videoID;
@synthesize privacy = _privacy;
@synthesize widescreen = _widescreen;
@synthesize includeRelatedVideos = _includeRelatedVideos;

@end
