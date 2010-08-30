//
//  TweetButtonPlugIn.m
//  TweetButtonElement
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

#import "TweetButtonPlugIn.h"


@implementation TweetButtonPlugIn

/*
    <a href="http://twitter.com/share" class="twitter-share-button" data-count="vertical" data-via="talbchat" data-related="snailwrangler">Tweet</a><script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>
 */


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"tweetCountStyle", 
            @"tweetText", 
            @"tweetURL", 
            @"tweetVia", 
            @"tweetRelated1", 
            @"tweetRelated2", 
            nil];
}

// no-count button is 55 x 20
// horizontal button is 110  (at least) x 20
// vertical button is 55 x 62 (at least)

- (NSUInteger)width
{
    if ( STYLE_HORIZONTAL == self.tweetButtonStyle )
    {
        return 110;
    }
    else 
    {
        return [self minWidth];
    }
}

- (NSUInteger)height
{
    if ( STYLE_VERTICAL == self.tweetButtonStyle )
    {
        return 62;
    }
    else 
    {
        return [self minHeight];
    }
}

- (NSUInteger)minWidth { return 55; }
- (NSUInteger)minHeight { return 20; }


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

- (void)writeInnerHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"tweetCountStyle" ofObject:self];
    [context addDependencyForKeyPath:@"tweetText" ofObject:self];
    [context addDependencyForKeyPath:@"tweetURL" ofObject:self];
    [context addDependencyForKeyPath:@"tweetVia" ofObject:self];
    [context addDependencyForKeyPath:@"tweetRelated1" ofObject:self];
    [context addDependencyForKeyPath:@"tweetRelated2" ofObject:self];
    
    /*
     <a href="http://twitter.com/share" class="twitter-share-button" data-count="vertical" data-via="talbchat" data-related="snailwrangler">Tweet</a><script type="text/javascript" src="http://platform.twitter.com/widgets.js"></script>
     */
    
    NSMutableDictionary *attrs = [NSMutableDictionary dictionaryWithCapacity:5];
    // href
    [attrs setObject:@"http://twitter.com/share" forKey:@"href"];
    // class
    [attrs setObject:@"twitter-share-button" forKey:@"class"];
    // data-url (if no url, twitter uses url of page button is on)
    if ( self.tweetURL )
    {
        [attrs setObject:self.tweetURL forKey:@"data-url"];
    }
    // data-text (if no text, twitter uses title of page button is on)
    if ( self.tweetText )
    {
        [attrs setObject:self.tweetURL forKey:@"data-text"];
    }
    // data-count
    [attrs setObject:self.tweetButton forKey:@"data-count"];
    // data-via
    if ( self.tweetVia )
    {
        [attrs setObject:self.tweetVia forKey:@"data-via"];
    }
    // data-related
    if ( self.tweetRelated )
    {
        [attrs setObject:self.tweetRelated forKey:@"data-related"];
    }
    // data-lang (if no lang, en is assumed)
    NSString *language = [(id<SVPage>)[context page] language];
    if ( language && ![language isEqualToString:@"en"] )
    {
        [attrs setObject:language forKey:@"data-lang"];
    }
    
    // write anchor
    [[context HTMLWriter] startElement:@"a" attributes:attrs]; // <a>
    [[context HTMLWriter] writeText:@"Tweet"];
    [[context HTMLWriter] endElement]; // </a>
    
    // write <script> to endBody
    //FIXME: expose endBodyMarkup or better way to add script to context in protocol
    [[[context HTMLWriter] endBodyMarkup] appendString:@"<script type=\"text/javascript\" src=\"http://platform.twitter.com/widgets.js\"></script>"];
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
    return self.tweetRelated1;
}

@end
