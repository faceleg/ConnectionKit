//
//  FacebookPlugIn.m
//  FacebookElement
//
//  Copyright (c) 2010 Karelia Software. All rights reserved.
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


// http://developers.facebook.com/docs/reference/plugins/like#
// href - the URL to like. The XFBML version defaults to the current page.
// layout - there are three options.
//  standard - displays social text to the right of the button and friends' profile photos below. Minimum width: 225 pixels. Default width: 450 pixels. Height: 35 pixels (without photos) or 80 pixels (with photos).
//  button_count - displays the total number of likes to the right of the button. Minimum width: 90 pixels. Default width: 90 pixels. Height: 20 pixels.
//  box_count - displays the total number of likes above the button. Minimum width: 55 pixels. Default width: 55 pixels. Height: 65 pixels.
// show_faces - specifies whether to display profile photos below the button (standard layout only)
// width - the width of the Like button.
// action - the verb to display on the button. Options: 'like', 'recommend'
// font - the font to display in the button. Options: 'arial', 'lucida grande', 'segoe ui', 'tahoma', 'trebuchet ms', 'verdana'
// colorscheme - the color scheme for the like button. Options: 'light', 'dark'
// ref - a label for tracking referrals; must be less than 50 characters and can contain alphanumeric characters and some punctuation (currently +/=-.:_). The ref attribute causes two parameters to be added to the referrer URL when a user clicks a link from a stream story about a Like action:
//  fb_ref - the ref parameter
//f b_source - the stream type ('home', 'profile', 'search', 'other') in which the click occurred and the story type ('oneline' or 'multiline'), concatenated with an underscore.


#import "FacebookPlugIn.h"


// tags in xib, converted to text in iframe
enum URLTYPES { THIS_URL, OTHER_URL };
enum ACTIONS { LIKE_ACTION = 0, RECOMMEND_ACTION };
enum COLORSCHEMES { LIGHT_SCHEME = 0, DARK_SCHEME };
enum LAYOUTS { STANDARD_LAYOUT = 0, BOX_COUNT_LAYOUT, BUTTON_COUNT_LAYOUT };


@implementation FacebookPlugIn


#pragma mark SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"urlType",
            @"urlString",
            @"showFaces", 
            @"action", 
            @"colorscheme", 
            @"layout", 
            nil];
}


#pragma mark HTML Generation

//<iframe src="http://www.facebook.com/plugins/like.php?href=www.karelia.com&amp;layout=standard&amp;show_faces=true&amp;width=250&amp;action=like&amp;font=lucida+grande&amp;colorscheme=light&amp;height=80" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:250px; height:80px;" allowTransparency="true"></iframe>

- (void)writeHTML:(id <SVPlugInContext>)context
{
    //FIXME: do I need to call super? document answer
    [super writeHTML:context];
    
    if ( [context liveDataFeeds] )
    {
        // determine full src
        NSMutableString *srcString = [[@"http://www.facebook.com/plugins/like.php?" mutableCopy] autorelease];
        
        // append href
        switch ( self.urlType )
        {
            case THIS_URL:
                {
                    id<SVPage> page = [context page];
                    NSURL *pageURL = [page feedURL]; //FIXME: how do we get URL of page? using feedURL for now
                    [srcString appendFormat:@"href=%@", [pageURL absoluteString]];
                }
                break;
            case OTHER_URL:
                {
                    NSString *href = (nil != self.urlString) ? self.urlString : @"";
                    [srcString appendFormat:@"href=%@", href];
                }
                break;
            default:
                break;
        }
        
        // append layout
        switch ( self.layout )
        {
            case STANDARD_LAYOUT:
                [srcString appendString:@"&layout=standard"];
                break;
            case BOX_COUNT_LAYOUT:
                [srcString appendString:@"&layout=box_count"];
                break;
            case BUTTON_COUNT_LAYOUT:
                [srcString appendString:@"&layout=button_count"];
            default:
                break;
        }
        
        // append show_faces
        if ( self.showFaces )
        {
            [srcString appendString:@"&show_faces=true"];
        }
        else
        {
            [srcString appendString:@"&show_faces=false"];
        }
        
        // append width?
        [srcString appendFormat:@"&width=%@", [[self width] stringValue]];

        // append action
        switch ( self.action )
        {
            case LIKE_ACTION:
                [srcString appendString:@"&action=like"];
                break;
            case RECOMMEND_ACTION:
                [srcString appendString:@"&action=recommend"];
                break;
            default:
                break;
        }
        
        // append colorscheme
        switch ( self.colorscheme )
        {
            case LIGHT_SCHEME:
                [srcString appendString:@"&colorscheme=light"];
                break;
            case DARK_SCHEME:
                [srcString appendString:@"&colorscheme=dark"];
                break;
            default:
                break;
        }
        
        // append height?
        [srcString appendFormat:@"&height=%@", [[self height] stringValue]];
        
        // append locale
        NSString *language = [[context page] language];
        if ( language && ![language isEqualToString:@"en"] )
        {
            [srcString appendFormat:@"&locale=%@", language];
        }
        
        // package attributes
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    srcString, @"src",
                                    @"no", @"scrolling",
                                    @"0", @"frameborder",
                                    @"true", @"allowTransparency",
                                    nil];
        
        // write iframe
        [context startElement:@"iframe" bindSizeToPlugIn:self attributes:attributes];
        [context endElement];
    }
    else 
    {
        //FIXME: phrase this better for user
        NSString *noLiveFeeds = LocalizedStringInThisBundle(@"Facebook Like Button visible only when loading data from the Internet", "");
        [context writeText:noLiveFeeds];
    }
    
    // add dependencies
    [context addDependencyForKeyPath:@"showFaces" ofObject:self];
    [context addDependencyForKeyPath:@"action" ofObject:self];
    [context addDependencyForKeyPath:@"colorscheme" ofObject:self];
    [context addDependencyForKeyPath:@"layout" ofObject:self];
}


#pragma mark Metrics

- (NSNumber *)minWidth
{
    NSNumber *result = nil;
    
    switch ( self.layout )
    {
        case STANDARD_LAYOUT:
            result = [NSNumber numberWithInt:225];
            break;
        case BOX_COUNT_LAYOUT:
            result = [NSNumber numberWithInt:55];
            break;
        case BUTTON_COUNT_LAYOUT:
            result = [NSNumber numberWithInt:90];
        default:
            break;
    }
    
    return result;
}

- (NSNumber *)minHeight
{
    NSNumber *result = nil;
    
    switch ( self.layout )
    {
        case STANDARD_LAYOUT:
            result = (self.showFaces) ? [NSNumber numberWithInt:80] : [NSNumber numberWithInt:35];
            break;
        case BOX_COUNT_LAYOUT:
            result = [NSNumber numberWithInt:65];
            break;
        case BUTTON_COUNT_LAYOUT:
            result = [NSNumber numberWithInt:20];
        default:
            break;
    }
    
    return result;
}


#pragma mark Resizing

+ (BOOL)isExplicitlySized
{
    return YES;
}

- (void)makeOriginalSize
{
    switch ( self.layout )
    {
        case STANDARD_LAYOUT:
            [self setWidth:[NSNumber numberWithInt:450]
                    height:((self.showFaces) ? [NSNumber numberWithInt:80] : [NSNumber numberWithInt:35])];
            break;
        case BOX_COUNT_LAYOUT:
            [self setWidth:[NSNumber numberWithInt:55] height:[NSNumber numberWithInt:65]];
            break;
        case BUTTON_COUNT_LAYOUT:
            [self setWidth:[NSNumber numberWithInt:90] height:[NSNumber numberWithInt:20]];
        default:
            break;
    }
}

#pragma mark Properties

@synthesize showFaces = _showFaces;
@synthesize action = _action;
@synthesize colorscheme = _colorscheme;
@synthesize layout = _layout;
@synthesize urlType = _urlType;
@synthesize urlString = _urlString;

@end
