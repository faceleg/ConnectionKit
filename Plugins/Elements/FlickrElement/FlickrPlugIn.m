//
//  FlickrPageletDelegate.m
//  FlickrPagelet
//
//  Copyright 2006-2009 Karelia Software. All rights reserved.
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

#import "FlickrPlugIn.h"
#import "FlickrInspector.h"


// LocalizedStringInThisBundle(@"Flickr (Placeholder)", "String_On_Page_Template")


@implementation FlickrPlugIn

/*
 PlugIn properties we use:
 
	flickrID
	tag
	number
	flashStyle
	random
	showInfo
 
 See:   http://www.flickr.com/badge_new.gne
 
 */

#pragma mark -
#pragma mark SVPlugIn

+ (NSSet *)plugInKeys
{ 
    return [NSSet setWithObjects:@"flickrID", @"tag", @"number", @"flashStyle", @"random", @"showInfo", nil];
}

- (void)dealloc
{
    self.flickrID = nil;
    self.tag = nil;
    [super dealloc];
}

#pragma mark -
#pragma mark HTML Generation

- (void)writeHTML:(SVHTMLContext *)context
{
    if ( self.flashStyle )
    {
        // If we are using flickr badge in flash style, it uses iframe, so we can't be strict.
        [context limitToMaxDocType:KTXHTMLTransitionalDocType];
    }
    [super writeHTML:context];
}


#pragma mark -
#pragma mark Properties

@synthesize flickrID = _flickrID;
@synthesize tag = _tag;
@synthesize number = _number;
@synthesize flashStyle = _flashStyle;
@synthesize random = _random;
@synthesize showInfo = _showInfo;
@end
