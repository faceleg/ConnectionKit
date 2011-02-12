//
//  TweetButtonPlugIn.m
//  TweetButtonElement
//
//  Copyright (c) 2011 Karelia Software. All rights reserved.
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

#import "TweetButtonPlugIn.h"


#define LocalizedStringInThisBundle(key, comment) [[NSBundle bundleForClass:[self class]] localizedStringForKey:(key) value:@"" table:nil]


@implementation TweetButtonPlugIn

/*
    <a href="http://twitter.com/share" class="twitter-share-button" data-count="vertical" data-via="talbchat" data-related="snailwrangler">Tweet</a><script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>
 */


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"tweetButtonStyle", 
            @"tweetText", 
            @"tweetURL", 
            @"tweetVia", 
            @"tweetRelated1", 
            @"tweetRelated2", 
            nil];
}

- (void)awakeFromNew;
{
    [super awakeFromNew];
    [self setShowsTitle:NO];
}

// no-count button is 55 x 20
// horizontal button is 110  (at least) x 20
// vertical button is 55 x 62 (at least)

- (NSNumber *)width
{
    if ( STYLE_HORIZONTAL == self.tweetButtonStyle )
    {
        return [NSNumber numberWithUnsignedInteger:110];
    }
    else 
    {
        return [self minWidth];
    }
}

- (NSNumber *)height
{
    if ( STYLE_VERTICAL == self.tweetButtonStyle )
    {
        return [NSNumber numberWithUnsignedInteger:62];
    }
    else 
    {
        return [self minHeight];
    }
}

- (NSNumber *)minWidth { return [NSNumber numberWithInt:55]; }
- (NSNumber *)minHeight { return [NSNumber numberWithInt:20]; }


#pragma mark Initialization

- (void)dealloc
{
	self.tweetText = nil;
	self.tweetURL = nil;
	self.tweetVia = nil;
	self.tweetRelated1 = nil;
	self.tweetRelated2 = nil;
    
	[super dealloc];
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{  
    if ( [context liveDataFeeds] )
    {
        NSMutableDictionary *tweetAttrs = [NSMutableDictionary dictionaryWithCapacity:5];
        // href
        [tweetAttrs setObject:@"http://twitter.com/share" forKey:@"href"];
        // class
        [tweetAttrs setObject:@"twitter-share-button" forKey:@"class"];
        // data-url (if no url, twitter uses url of page button is on)
        if ( self.tweetURL )
        {
            [tweetAttrs setObject:self.tweetURL forKey:@"data-url"];
        }
        // data-text (if no text, twitter uses title of page button is on)
        if ( self.tweetText )
        {
            [tweetAttrs setObject:self.tweetText forKey:@"data-text"];
        }
        // data-count
        [tweetAttrs setObject:self.tweetButton forKey:@"data-count"];
        // data-via
        if ( self.tweetVia )
        {
            [tweetAttrs setObject:self.tweetVia forKey:@"data-via"];
        }
        // data-related
        if ( self.tweetRelated )
        {
            [tweetAttrs setObject:self.tweetRelated forKey:@"data-related"];
        }
        // data-lang (if no lang, en is assumed)
        NSString *language = [(id<SVPage>)[context page] language];
        if ( language && ![language isEqualToString:@"en"] )
        {
            [tweetAttrs setObject:language forKey:@"data-lang"];
        }
        
        NSDictionary *divAttrs = [NSDictionary dictionaryWithObject:@"text-align:center; padding-top:10px; padding-bottom:10px;" 
                                                             forKey:@"style"];
        [context startElement:@"div" attributes:divAttrs];

        // write anchor
        [context startElement:@"a" attributes:tweetAttrs]; // <a>
        [context writeText:@"Tweet"];
        [context endElement]; // </a>
        
        [context endElement]; // </div>
        
        // write <script> to endBody
        [context addMarkupToEndOfBody:@"<script type=\"text/javascript\" src=\"http://platform.twitter.com/widgets.js\"></script>"];
    }
    else 
    {
        NSString *noLiveFeeds = LocalizedStringInThisBundle(@"Tweet Button visible only when loading data from the Internet.", "");
        [context writePlaceholderWithText:noLiveFeeds];
    }
    
    // add dependencies
    [context addDependencyForKeyPath:@"tweetButtonStyle" ofObject:self];
    [context addDependencyForKeyPath:@"tweetText" ofObject:self];
    [context addDependencyForKeyPath:@"tweetURL" ofObject:self];
    [context addDependencyForKeyPath:@"tweetVia" ofObject:self];
    [context addDependencyForKeyPath:@"tweetRelated1" ofObject:self];
    [context addDependencyForKeyPath:@"tweetRelated2" ofObject:self];
}

#pragma mark Properties

@synthesize tweetButtonStyle = _tweetButtonStyle;
@synthesize tweetText = _tweetText;
@synthesize tweetURL = _tweetURL;
@synthesize tweetVia = _tweetVia;
@synthesize tweetRelated1 = _tweetRelated1;
@synthesize tweetRelated2 = _tweetRelated2;

- (NSString *)tweetButton
{
    NSString *result = nil;
    
    switch (self.tweetButtonStyle)
    {
        case STYLE_NONE:
            result = @"none";
            break;
        case STYLE_VERTICAL:
            result = @"vertical";
            break;
        case STYLE_HORIZONTAL:
            result = @"horizontal";
            break;
        default:
            break;
    }
    
    return result;
}

- (NSString *)tweetRelated
{
    BOOL hasRelated1 = self.tweetRelated1.length > 0;
    BOOL hasRelated2 = self.tweetRelated2.length > 0;
    
    if ( hasRelated1 && hasRelated2 )
    {
        return [NSString stringWithFormat:@"%@:%@", self.tweetRelated1, self.tweetRelated2];
    }
    else if ( hasRelated1 )
    {
        return self.tweetRelated1;
    }
    else if ( hasRelated2 )
    {
        return self.tweetRelated2;
    }
    else 
    {
        return nil;
    }
}

@end
