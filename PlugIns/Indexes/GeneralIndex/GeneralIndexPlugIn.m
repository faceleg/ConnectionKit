//
//  GeneralIndex.m
//  GeneralIndex
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

#import "GeneralIndexPlugIn.h"


@implementation GeneralIndexPlugIn


#pragma mark SVIndexPlugIn

+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
                           @"hyperlinkTitles", 
                           @"showPermaLink", 
                           @"truncateChars", 
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // parse template
    [super writeHTML:context];
    
    // add dependencies
    [context addDependencyForKeyPath:@"hyperlinkTitles" ofObject:self];
    [context addDependencyForKeyPath:@"showPermaLink" ofObject:self];
    [context addDependencyForKeyPath:@"truncateChars" ofObject:self];
}


/*
 [[textblock property:item.titleHTML flags:"line" tag:h3 graphicalTextCode:h3 hyperlink:item]]
 or
 [[textblock property:item.titleHTML flags:"line" tag:h3 graphicalTextCode:h3]]
*/

- (void)writeTitleOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    if ( self.hyperlinkTitles) { [[context HTMLWriter] startAnchorElementWithPage:iteratedPage]; } // <a>
    
    [context writeTitleOfPage:iteratedPage
                  asPlainText:NO
             enclosingElement:@"span"
                   attributes:[NSDictionary dictionaryWithObject:@"in" forKey:@"class"]];
    
    if ( self.hyperlinkTitles ) { [[context HTMLWriter] endElement]; } // </a> 
}


/*
 [[summary item indexedCollection.collectionTruncateCharacters]]
 */

- (void)writeSummaryOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    //FIXME: summary needs to be truncated at truncateChars
    [iteratedPage writeSummary:context];
}


/*
<img[[idClass entity:Page property:item.thumbnail flags:"anchor" id:item.uniqueID]]
 src="[[mediainfo info:path media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 alt="[[=&item.titleText]]"
 width="[[mediainfo info:width media:item.thumbnail sizeToFit:thumbnailImageSize]]"
 height="[[mediainfo info:height media:item.thumbnail sizeToFit:thumbnailImageSize]]" />*/

- (void)writeThumbnailImageOfIteratedPage
{
    id<SVPlugInContext> context = [SVPlugIn currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    // Do a dry-run to see if there's actuall a thumbnail
    if ([iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:YES])
    {
        [[context HTMLWriter] startElement:@"div" className:@"article-thumbnail"];
        
        [iteratedPage writeThumbnail:context
                            maxWidth:64
                           maxHeight:64
                      imageClassName:nil
                              dryRun:NO];
        
        [[context HTMLWriter] endElement];
    }
}


#pragma mark Properties

@synthesize hyperlinkTitles = _hyperlinkTitles;
@synthesize showPermaLink = _showPermaLink;
@synthesize truncateChars = _truncateChars;

@end
