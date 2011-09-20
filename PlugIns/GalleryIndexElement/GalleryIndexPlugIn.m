//
//  GalleryIndexPlugIn.m
//  GalleryIndex
//
//  Copyright 2011 Karelia Software. All rights reserved.
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


#import "GalleryIndexPlugIn.h"

@implementation GalleryIndexPlugIn

// Properties of this index only
@synthesize showCollectionTitle	= _showCollectionTitle;
@synthesize showCollectionThumbnail = _showCollectionThumbnail;


+ (NSArray *)plugInKeys
{ 
    NSArray *plugInKeys = [NSArray arrayWithObjects:
						   @"showCollectionTitle",
						   @"showCollectionThumbnail",						   
                           nil];    
    return [[super plugInKeys] arrayByAddingObjectsFromArray:plugInKeys];
}


- (void)awakeFromNew
{
    [super awakeFromNew];
	
	self.showCollectionTitle		= YES;
	self.showCollectionThumbnail	= YES;	

	self.useColorBox = YES;		// Turn this on and LEAVE IT ON since it doesn't make sense without it!

}

/* Must be called by subclass at the appropriate spot. */

- (void)writeInvisibleLinksToImages:(id <SVPlugInContext>)context;
{
	// Write out the invisible links
	
	for (id <SVPage> aPage in self.indexedPages)
	{
		NSURL *URL = [context URLForImageRepresentationOfPage:aPage
														width:0
													   height:0		// we want full-size
													  options:0];
		if (URL)
		{
			NSString *href = [context relativeStringFromURL:URL];
			[context startAnchorElementWithHref:href title:[aPage title] target:nil rel:@"enclosure"];
			[context endElement];
		}
	}
}

- (void)writeHTML:(id <SVPlugInContext>)context
{
	[super writeHTML:context];	// super will deal with placeholder, vars, main script, etc.

	// add dependencies
	
	[context addDependencyForKeyPath:@"showCollectionTitle"		ofObject:self];
	[context addDependencyForKeyPath:@"showCollectionThumbnail"	ofObject:self];

	// Link (if showing) for the indexed photos
	
	if ([self.indexedPages count])
	{
		NSBundle *bundle = [NSBundle bundleForClass:[self class]];
		NSString *language = [[self indexedCollection] language];

		BOOL showingSomething = NO;
		
		// Build up HTML to show the slideshow, based on the indexed pages
		NSString *idName = [context startElement:@"div"
								 preferredIdName:@"gallery"
									   className:nil
									  attributes:nil];
		
		if (self.showCollectionThumbnail)
		{
			showingSomething = YES;
			
			NSString *title = nil;
			if (self.autoStartSlideshow)
			{
				title = [bundle localizedStringForString:@"Click to start slideshow."	language:language fallback:SVLocalizedString(@"Click to start slideshow.", @"Tooltip")];
			}
			else
			{
				title	= [bundle localizedStringForString:@"Click to view gallery."	language:language fallback:SVLocalizedString(@"Click to view gallery.", @"Tooltip")];
			}
			
			// Do I do something along these lines?
			// [context buildAttributesForElement:@"img" bindSizeToObject:self DOMControllerClass:nil sizeDelta:NSZeroSize];
			
			// Here, I write out a FIXED size thumbnail of the collection.
			// What I want to do is to have this size be user-resizable instead....
			
			[context writeImageRepresentationOfPage:[self indexedCollection]
									width:128
								   height:128
							   attributes:[NSDictionary dictionaryWithObjectsAndKeys:title, @"title", nil]
								  options:(SVImageScaleAspectFit | SVImageScaleUpAvoid | (1 << 5)/*SVPageImageRepresentationLink*/)];
		}
		
		if (self.showCollectionTitle)
		{
			showingSomething = YES;
						
			[context startElement:@"div"];
			[context startAnchorElementWithPage:[self indexedCollection]];
			[context writeCharacters:[self.indexedCollection title]];
			[context endElement];
			[context endElement];
		}
		
		// We need an "invisible" badge if we didn't have a link to show
		
		if (!showingSomething && [context isForEditing])
		{
			[context writePlaceholderWithText:SVLocalizedString(@"Gallery", "placeholder for invisible gallery index") options:(1 << 0)]; // SVPlaceholderInvisible
		}
		
		// If we have something to show, hook up gallery (or slideshow) to start when item is clicked.
		
		if (showingSomething)
		{			
			NSString *clickScript = [NSString stringWithFormat:
									 @"<script type=\"text/javascript\">\n"
									 @"/* Start colorbox when clicking on '#%@' */\n"
									 @"$(document).ready(function () {\n"
									 @"	$('#%@').click(function(event) {\n"
									 @"		event.preventDefault()\n"
									 @"		$(this).find(\"a[rel='enclosure']\").colorbox({\n"
									 @"			open: true,\n"
									 @"%@"
									 @"		});\n"
									 @"	});\n"
									 @"});\n"
									 @"</script>\n", idName, idName, [self colorBoxParametersWithGroupID:idName]];
			[context addMarkupToEndOfBody:clickScript];			
		}
		else
		{
			// This is kind of hidden, but I don't want to advertise it since it is not worth showing the extra complexity.
			// When no controls, this means the gallery should automatically open when the page loads.
			
			NSString *autostartScript = [NSString stringWithFormat:
										 @"<script type=\"text/javascript\">\n"
										 @"/* Automatically open colorbox in '#%@' */\n"
										 @"$(document).ready(function () {\n"
										 @"		$('#%@').find(\"a[rel='enclosure']\").colorbox({\n"
										 @"			open: true,\n"
										 @"%@"
										 @"	});\n"
										 @"});\n"
										 @"</script>\n", idName, idName, [self colorBoxParametersWithGroupID:idName]];
			[context addMarkupToEndOfBody:autostartScript];			
		}
		
		// Ready for the invisible links, inside this element
		[self writeInvisibleLinksToImages:context];

		// Done - end the DIV.

		[context endElement]; // </div>
	}
}


@end
