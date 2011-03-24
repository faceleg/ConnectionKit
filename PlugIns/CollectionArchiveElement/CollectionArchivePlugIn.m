//
//  CollectionArchivePlugIn.m
//  CollectionArchiveElement
//
//  Copyright 2006-2011 Karelia Software. All rights reserved.
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

#import "CollectionArchivePlugIn.h"


// SVLocalizedString(@"Please turn on Publish Archives in the Collection Inspector.", "String_On_Page_Template")
// SVLocalizedString(@"Please add at least one page to this collection.", "String_On_Page_Template")


@implementation CollectionArchivePlugIn


#pragma mark Initialization

- (void)didAddToPage:(id <SVPage>)page
{
    BOOL isNew = (nil == self.indexedCollection);
    
    [super didAddToPage:page]; // sets indexedCollection
    
    if ( isNew && self.indexedCollection )
    {
        // attempt to set container's title to localized string
        NSString *title = [NSString stringWithFormat:@"%@ %@",
                           [self.indexedCollection title],
                           SVLocalizedString(@"Archive", @"title of object")];
        self.title = title;
    }
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    [super writeHTML:context];
    [context addDependencyForKeyPath:@"collectionGenerateArchives" ofObject:self.indexedCollection];
}


#pragma mark Metrics

- (void)makeOriginalSize;
{
    // default width to 200 so it is placed in sidebar
    [self setWidth:[NSNumber numberWithUnsignedInt:200] height:nil];
}


@end
