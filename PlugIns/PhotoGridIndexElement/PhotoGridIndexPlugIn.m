//
//  PhotoGridIndexPlugIn.m
//  PhotoGridIndex
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
//  Community Note: This code is distributed under a modified BSD License.
//  We encourage you to share your Sandvox Plugins similarly.
//

#import "PhotoGridIndexPlugIn.h"


@implementation PhotoGridIndexPlugIn






- (void)awakeFromNew
{
    [super awakeFromNew];
	self.useColorBox = NO;		// Initially don't turn this on

    self.enableMaxItems = NO;
    self.maxItems = 10;
}


#pragma mark HTML Generation

- (void)writeHTML:(id <SVPlugInContext>)context
{
    // Extra CSS to handle caption functionality new to 2.0
    [context addCSSString:@".photogrid-index-bottom { clear:left; }"];
    
    // parse template
    [super writeHTML:context];
	
	// Connect ColorBox to any Photo Grids
	
	// FIXME: If we had more than one on a single page, both would try to hook up.
	// Maybe only output this if endBodyMarkup doesn't already contain a similar block.
	
	if (self.useColorBox)
	{		
		// FIXME: Really, to group multiple photo grids together, we need a function for rel to return a unique ID of the enclosing photogrid-index
		// FIXME: Instead of '.gridItem' could we search for all .gridItem with a sub-node of an a[rel='enclosure'] ? (To skip non-photo entries)
		
		NSString *previewOnlyOptions = [context isForEditing]
		?	@"			onLoad: function(){ $(this).blur() },\n"
		:	@"";
		
		NSString *feed = [NSString stringWithFormat:
						  @"<script type=\"text/javascript\">\n"
						  @"/* Connect Colorbox to Photo Grids */\n"
						  @"$(document).ready(function () {\n"
						  @"	$('.gridItem').colorbox({\n"
						  @"			href: function(){ return $(this).find(\"a[rel='enclosure']\").attr('href'); },\n"
						  @"			title: function(){ return $(this).text(); },\n"
						  @"%@"
						  @"%@"
						  @"	});\n"
						  @"});\n"
						  @"</script>\n",
						  [self colorBoxParametersWithGroupID:@"gridItem"],
						  previewOnlyOptions
						  ];
		[context addMarkupToEndOfBody:feed];
	}
}

- (void)writeHiddenLinkToPhoto
{
	if (self.useColorBox)
	{
		id<SVPlugInContext> context = [self currentContext]; 
		id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
		
		NSURL *URL = [context URLForImageRepresentationOfPage:iteratedPage
														width:0
													   height:0		// we want full-size
													  options:0];
		if (URL)
		{
			NSString *href = [context relativeStringFromURL:URL];
			[context startAnchorElementWithHref:href title:[iteratedPage title] target:nil rel:@"enclosure"];
			[context endElement];
		}
	}
}

- (void)writePlaceholderHTML:(id <SVPlugInContext>)context;
{
    if ( self.indexedCollection )
    {        
        // write thumbnail <DIV> of design's example image
        [context startElement:@"div" className:@"gridItem"];
        [context writeImageRepresentationOfPage:nil
                                width:128
                               height:128
                           attributes:nil
                              options:(SVImageScaleAspectFit | SVPageImageRepresentationLink)];
        [context startElement:@"h3"];
        if ([context page]) [context startAnchorElementWithPage:[context page]];
        [context startElement:@"span" attributes:[NSDictionary dictionaryWithObject:@"in" forKey:@"class"]];
        [context writeCharacters:SVLocalizedString(@"Example Photo", "placeholder image name")];
        [context endElement]; // </span>
        if ([context page]) [context endElement]; // </a>
        [context endElement]; // </h3>
        [context endElement]; // </div>
        
        // write (localized) placeholder image
        NSString *path = [[NSBundle bundleForClass:[self class]] pathForResource:@"placeholder" ofType:@"png"];
        NSURL *URL = [NSURL fileURLWithPath:path];
        [context addResourceAtURL:URL destination:SVDestinationResourcesDirectory options:0];
        
        NSDictionary *attrs = [NSDictionary dictionaryWithObjectsAndKeys:
                               [context relativeStringFromURL:URL], @"src",
                               [NSNumber numberWithInt:128], @"width",
                               [NSNumber numberWithInt:128], @"height",
                               nil];
        
        [context startElement:@"div" className:@"gridItem"];
        [context startElement:@"img" attributes:attrs];
        [context endElement]; // </img>
        [context endElement]; // </div>
        [context startElement:@"div" className:@"photogrid-index-bottom"];
        [context endElement]; // </div>
    }
    else
    {
        [context startElement:@"div" attributes:[NSDictionary dictionaryWithObject:@"gridItem" 
                                                                            forKey:@"class"]];
        [context writeCharacters:SVLocalizedString(@"Please specify the collection to use for the album.",
                                             "set photo collection")];
        [context endElement];
    }
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
    id<SVPlugInContext> context = [self currentContext]; 
    id<SVPage> iteratedPage = [context objectForCurrentTemplateIteration];
    
    [context writeImageRepresentationOfPage:iteratedPage
                            width:128
                           height:128
                       attributes:nil
                          options:(SVImageScaleAspectFit | SVPageImageRepresentationLink)];
}


@end
