//
//  FacebookPlugIn.m
//  FacebookElement
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
//  Community Note: This code is distributed under a modified BSD License.
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

// standard layout includes text, faces; box_count is button only, tall; button_count is button only, wide
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

- (void)awakeFromNew;
{
    [super awakeFromNew];
    [self setShowsTitle:NO];
    [self setShowFaces:NO];
    [self setLayout:BOX_COUNT_LAYOUT];
    [self setAction:LIKE_ACTION];
}

- (void)awakeFromFetch
{
    [super awakeFromFetch];
    
    // prior to 2.0.6, auto-width or height was possible so we need to correct that
    NSNumber *fixWidth = (nil != [self width]) ? [self width] : [self minWidth];
    NSNumber *fixHeight = (nil != [self height]) ? [self height] : [self minHeight];
    [self setWidth:fixWidth height:fixHeight];
}


#pragma mark HTML Generation

//<iframe src="http://www.facebook.com/plugins/like.php?href=www.karelia.com&amp;layout=standard&amp;show_faces=true&amp;width=250&amp;action=like&amp;font=lucida+grande&amp;colorscheme=light&amp;height=80" scrolling="no" frameborder="0" style="border:none; overflow:hidden; width:250px; height:80px;" allowTransparency="true"></iframe>

- (void)writeHTML:(id <SVPlugInContext>)context
{
    if ( [context liveDataFeeds] )
    {
        // determine size that we tell Facebook
        NSString *widthString = [[self width] stringValue];
        NSString *heightString = [[self height] stringValue];
        
        // determine src query parameters
        NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
        
        // href
        switch ( self.urlType )
        {
            case THIS_URL:
            {
                NSURL *pageURL = [context baseURL];
                if ( nil != pageURL )
                {
                    [parameters setObject:pageURL forKey:@"href"];
                }
            }
                break;
            case OTHER_URL:
            {
                if ( nil != self.urlString )
                {
                    [parameters setObject:self.urlString forKey:@"href"];
                }
            }
                break;
            default:
                break;
        }
        
        // layout
        switch ( self.layout )
        {
            case STANDARD_LAYOUT:
                [parameters setObject:@"standard" forKey:@"layout"];
                break;
            case BOX_COUNT_LAYOUT:
                [parameters setObject:@"box_count" forKey:@"layout"];
                break;
            case BUTTON_COUNT_LAYOUT:
                [parameters setObject:@"button_count" forKey:@"layout"];
                break;
            default:
                break;
        }
        
        // append show_faces
        if ( STANDARD_LAYOUT == self.layout )
        {
            if ( self.showFaces )
            {
                [parameters setObject:@"true" forKey:@"show_faces"];
            }
            else
            {
                [parameters setObject:@"false" forKey:@"show_faces"];
            }
        }
        
        // width
        [parameters setObject:widthString forKey:@"width"];

        // action
        switch ( self.action )
        {
            case LIKE_ACTION:
                [parameters setObject:@"like" forKey:@"action"];
                break;
            case RECOMMEND_ACTION:
                [parameters setObject:@"recommend" forKey:@"action"];
                break;
            default:
                break;
        }
        
        // colorscheme
        switch ( self.colorscheme )
        {
            case LIGHT_SCHEME:
                [parameters setObject:@"light" forKey:@"colorscheme"];
                break;
            case DARK_SCHEME:
                [parameters setObject:@"dark" forKey:@"colorscheme"];
                break;
            default:
                break;
        }
        
        // height
        [parameters setObject:heightString forKey:@"height"];
        
        // append locale
        NSString *language = [[context page] language];
        if ( language && ![language isEqualToString:@"en"] )
        {
            [parameters setObject:language forKey:@"locale"];
        }
        
        // turn it all into a URL
        NSURL *src = [NSURL svURLWithScheme:@"http"
                                       host:@"www.facebook.com"
                                       path:@"/plugins/like.php"
                            queryParameters:parameters];                      
        
        
        // style attribute
        NSString *style = [NSString stringWithFormat:@"border:none; overflow:hidden; width:%@px; height:%@px;", widthString, heightString];
        
        // package attributes
        NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                    [src absoluteString], @"src",
                                    @"no", @"scrolling",
                                    @"0", @"frameborder",
                                    style, @"style",
                                    @"true", @"allowTransparency",
                                    widthString, @"width",
                                    heightString, @"height",
                                    nil];
        
        // write iframe
        style = @"text-align:center; padding-top:10px; padding-bottom:10px;";
        [context startElement:@"div" attributes:[NSDictionary dictionaryWithObject:style forKey:@"style"]];
        (void)[context startResizableElement:@"iframe"
                                      plugIn:self
                                     options:0
                             preferredIdName:nil
                                  attributes:attributes];
        [context endElement]; // </iframe>
        [context endElement]; // </div>
    }
    
    // add dependencies
    [context addDependencyForKeyPath:@"showFaces" ofObject:self];
    [context addDependencyForKeyPath:@"action" ofObject:self];
    [context addDependencyForKeyPath:@"colorscheme" ofObject:self];
    [context addDependencyForKeyPath:@"layout" ofObject:self];
    [context addDependencyForKeyPath:@"urlType" ofObject:self];
    [context addDependencyForKeyPath:@"urlString" ofObject:self];
}

- (NSString *)placeholderString
{
    return SVLocalizedString(@"Facebook Button visible only when loading data from the Internet.", "");
}


#pragma mark Metrics

- (void)makeOriginalSize
{
    [self setWidth:[self minWidth] height:[self minHeight]];
}
    

+ (NSSet *)keyPathsForValuesAffectingMinWidth
{
    return [NSSet setWithObject:@"layout"];
}

- (NSNumber *)minWidth
{
    NSNumber *result = nil;
    
    switch ( self.layout )
    {
        case STANDARD_LAYOUT:
            //FIXME: this doesn't really work
            // currentContext is actually nil at this point, but if we had some way to know
            // that the plug-in is in the main body, the width should really be 450
            if ( [self currentContext] && ![[self currentContext] isWritingPagelet] )
            {
                result = [NSNumber numberWithInt:450];
            }
            else
            {
                result = [NSNumber numberWithInt:200];
            }
            break;
        case BUTTON_COUNT_LAYOUT:
            result = (self.action == RECOMMEND_ACTION) ? [NSNumber numberWithInt:140] : [NSNumber numberWithInt:90];
            break;
        case BOX_COUNT_LAYOUT:
            result = (self.action == RECOMMEND_ACTION) ? [NSNumber numberWithInt:110] : [NSNumber numberWithInt:55];
            break;
        default:
            result = [super minWidth];
            break;
    }
    
    return result;
}


+ (NSSet *)keyPathsForValuesAffectingMinHeight
{
    return [NSSet setWithObject:@"layout"];
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
            break;
        default:
            result = [super minHeight];
            break;
    }
    
    return result;
}


#pragma mark Properties

@synthesize showFaces = _showFaces;
@synthesize action = _action;
@synthesize colorscheme = _colorscheme;
@synthesize urlType = _urlType;
@synthesize urlString = _urlString;
@synthesize layout = _layout;

@end
