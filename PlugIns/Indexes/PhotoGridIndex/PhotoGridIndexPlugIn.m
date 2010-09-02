//
//  PhotoGridIndex.m
//  PhotoGridIndex
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

#import "PhotoGridIndexPlugIn.h"
#import "SVPageletPlugIn.h"


@implementation PhotoGridIndexPlugIn

#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // Extra CSS to handle caption functionality new to 2.0
    [context addCSSString:@".photogrid-index-bottom { clear:left; }"];
    
    // parse template
    [super writeHTML:context];
        
    // add dependencies
    [context addDependencyForKeyPath:@"indexedCollection" ofObject:self];
    [context addDependencyForKeyPath:@"indexedCollection.childPages" ofObject:self];
}


/*
<img[[idClass entity:Page property:aPage.thumbnail flags:"anchor" id:aPage.identifier]]
src="[[mediainfo info:path media:aPage.thumbnail sizeToFit:thumbnailImageSize]]"
alt="[[=&aPage.title]]"
width="[[mediainfo info:width media:aPage.thumbnail sizeToFit:thumbnailImageSize]]"
height="[[mediainfo info:height media:aPage.thumbnail sizeToFit:thumbnailImageSize]]" />
 */

- (void)writeThumbnailImageOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    [[context HTMLWriter] writeThumbnailImageOfPage:iteratedPage 
                                          className:@"" 
                                           maxWidth:128 
                                          maxHeight:128];
}

- (NSSize)thumbnailImageSize { return NSMakeSize(128.0, 128.0); }

@end
