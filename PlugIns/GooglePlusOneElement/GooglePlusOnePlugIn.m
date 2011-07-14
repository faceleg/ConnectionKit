//
//  GooglePlusOnePlugIn.m
//  GooglePlusOneElement
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

#import "GooglePlusOnePlugIn.h"


enum BUTTON_SIZES { SMALL = 0, STANDARD, MEDIUM, TALL};


@implementation GooglePlusOnePlugIn


#pragma mark - SVPlugIn

+ (NSArray *)plugInKeys
{ 
    return [NSArray arrayWithObjects:
            @"buttonSize", 
            nil];
}

- (BOOL)requiresPageLoad
{
    return YES;
}


#pragma mark - Initialization

- (void)awakeFromNew;
{
    [super awakeFromNew];
    
    // set initial properties
    [self setShowsTitle:NO];
    self.buttonSize = 1;
}    


#pragma mark - HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // add dependencies
    [context addDependencyForKeyPath:@"buttonSize" ofObject:self];
    
    if ( [context liveDataFeeds] )
    {
        // write the magic Google incantation
        NSString *sizeString = @"";
        switch ( self.buttonSize )
        {
            case SMALL:
                sizeString = @" size=\"small\"";
                break;
            case MEDIUM:
                sizeString = @" size=\"medium\"";
                break;
            case TALL:
                sizeString = @" size=\"tall\"";
                break;
            default:
            case STANDARD:
                break;
        }
        [context writeHTMLString:[NSString stringWithFormat:@"<g:plusone%@></g:plusone>", sizeString]];
        
        // add plusone JavaScript
        NSString *language = [[context page] language];
        NSString *googleMarkup = 
        @"<script type=\"text/javascript\" src=\"https://apis.google.com/js/plusone.js\">\n"
        "  {lang: '%@'}\n"
        "</script>\n";
        [context addMarkupToEndOfBody:[NSString stringWithFormat:googleMarkup, language]];
    }
}

- (NSString *)placeholderString
{
    return SVLocalizedString(@"+1 visible only when loading data from the Internet.", "");
}

#pragma mark - Properties

@synthesize buttonSize = _buttonSize;
@end
